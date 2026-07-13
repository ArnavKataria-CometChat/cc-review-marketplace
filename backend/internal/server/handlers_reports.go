package server

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

type createReportRequest struct {
	TargetType models.ReportTargetType `json:"targetType"`
	TargetID   string                  `json:"targetId"`
	Reason     string                  `json:"reason"`
	InquiryID  string                  `json:"inquiryId"` // optional: dispute a thread
}

// handleCreateReport files a moderation/dispute report. Any authenticated user
// may report a listing, user or message.
func (s *Server) handleCreateReport(c *gin.Context) {
	u := currentUser(c)
	var req createReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	switch req.TargetType {
	case models.ReportTargetListing, models.ReportTargetUser, models.ReportTargetMessage:
	default:
		errorJSON(c, http.StatusBadRequest, "targetType must be listing, user or message")
		return
	}
	if strings.TrimSpace(req.TargetID) == "" || strings.TrimSpace(req.Reason) == "" {
		errorJSON(c, http.StatusBadRequest, "targetId and reason are required")
		return
	}
	// If an inquiry is referenced, the reporter must be a participant.
	if req.InquiryID != "" {
		inq, err := s.store.GetInquiry(req.InquiryID)
		if err != nil {
			errorJSON(c, http.StatusNotFound, "inquiry not found")
			return
		}
		if u.ID != inq.BuyerID && u.ID != inq.SellerID {
			errorJSON(c, http.StatusForbidden, "not a participant of that inquiry")
			return
		}
	}
	r := &models.Report{
		ID:         newID(),
		TargetType: req.TargetType,
		TargetID:   strings.TrimSpace(req.TargetID),
		ReporterID: u.ID,
		Reason:     strings.TrimSpace(req.Reason),
		Status:     models.ReportOpen,
		InquiryID:  req.InquiryID,
		CreatedAt:  nowUTC(),
		UpdatedAt:  nowUTC(),
	}
	if err := s.store.CreateReport(r); err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not create report")
		return
	}
	c.JSON(http.StatusCreated, r)
}

// handleListReports returns the dispute queue, optionally filtered by ?status=.
func (s *Server) handleListReports(c *gin.Context) {
	f := store.ReportFilter{Status: models.ReportStatus(c.Query("status"))}
	c.JSON(http.StatusOK, gin.H{"reports": s.store.ListReports(f)})
}

// handleGetReport returns a report plus the context support needs: the disputed
// listing, the parties, and the inquiry thread anchor.
func (s *Server) handleGetReport(c *gin.Context) {
	r, err := s.store.GetReport(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "report not found")
		return
	}
	resp := gin.H{"report": r}
	if reporter, err := s.store.GetUser(r.ReporterID); err == nil {
		resp["reporter"] = reporter
	}
	if r.TargetType == models.ReportTargetListing {
		if l, err := s.store.GetListing(r.TargetID); err == nil {
			resp["listing"] = l
		}
	}
	if r.InquiryID != "" {
		if inq, err := s.store.GetInquiry(r.InquiryID); err == nil {
			resp["inquiry"] = inq
			if buyer, err := s.store.GetUser(inq.BuyerID); err == nil {
				resp["buyer"] = buyer
			}
			if seller, err := s.store.GetUser(inq.SellerID); err == nil {
				resp["seller"] = seller
			}
		}
	}
	c.JSON(http.StatusOK, resp)
}

type patchReportRequest struct {
	Status *models.ReportStatus `json:"status"`
}

// handlePatchReport lets support/admin advance a report. Flagging a report that
// references an inquiry escalates that thread to a dispute — in Phase B this is
// where the buyer+seller+support CometChat group gets created.
func (s *Server) handlePatchReport(c *gin.Context) {
	r, err := s.store.GetReport(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "report not found")
		return
	}
	var req patchReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Status == nil {
		errorJSON(c, http.StatusBadRequest, "status is required")
		return
	}
	switch *req.Status {
	case models.ReportOpen, models.ReportFlagged, models.ReportResolved:
	default:
		errorJSON(c, http.StatusBadRequest, "invalid status")
		return
	}
	r.Status = *req.Status
	r.UpdatedAt = nowUTC()
	if err := s.store.UpdateReport(r); err != nil {
		errorJSON(c, storeErrStatus(err), "could not update report")
		return
	}

	// Escalation seam: flagging a thread-linked report marks the inquiry as a
	// dispute; resolving it clears the flag and closes the thread.
	if r.InquiryID != "" {
		if inq, err := s.store.GetInquiry(r.InquiryID); err == nil {
			switch *req.Status {
			case models.ReportFlagged:
				inq.Flagged = true
			case models.ReportResolved:
				inq.Flagged = false
				inq.Status = models.InquiryClosed
			}
			inq.UpdatedAt = nowUTC()
			_ = s.store.UpdateInquiry(inq)
		}
	}

	s.audit(c, "report.update", r.ID, "status -> "+string(r.Status))
	c.JSON(http.StatusOK, r)
}
