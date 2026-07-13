package server

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

type createInquiryRequest struct {
	ListingID string `json:"listingId"`
	Message   string `json:"message"`
}

// handleCreateInquiry opens (or returns the existing) buyer↔seller thread for a
// listing. This is the anchor a Phase B CometChat 1:1 conversation keys on.
func (s *Server) handleCreateInquiry(c *gin.Context) {
	u := currentUser(c)
	var req createInquiryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	l, err := s.store.GetListing(req.ListingID)
	if err != nil || l.Status == models.ListingRemoved {
		errorJSON(c, http.StatusNotFound, "listing not found")
		return
	}
	if l.SellerID == u.ID {
		errorJSON(c, http.StatusBadRequest, "cannot inquire on your own listing")
		return
	}
	// One thread per (listing, buyer): return the existing one if present.
	if existing, err := s.store.FindInquiry(l.ID, u.ID); err == nil {
		c.JSON(http.StatusOK, existing)
		return
	}
	inq := &models.Inquiry{
		ID:        newID(),
		ListingID: l.ID,
		BuyerID:   u.ID,
		SellerID:  l.SellerID,
		Status:    models.InquiryOpen,
		Message:   strings.TrimSpace(req.Message),
		CreatedAt: nowUTC(),
		UpdatedAt: nowUTC(),
	}
	if err := s.store.CreateInquiry(inq); err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not create inquiry")
		return
	}
	c.JSON(http.StatusCreated, inq)
}

// handleListInquiries returns inquiries scoped to the caller's role:
//   - buyer:   inquiries they opened
//   - seller:  inquiries on their listings
//   - support: flagged (disputed) inquiries only
//   - admin:   all inquiries
func (s *Server) handleListInquiries(c *gin.Context) {
	u := currentUser(c)
	var f store.InquiryFilter
	switch u.Role {
	case models.RoleBuyer:
		f.BuyerID = u.ID
	case models.RoleSeller:
		f.SellerID = u.ID
	case models.RoleSupport:
		f.FlaggedOnly = true
	case models.RoleAdmin:
		// no filter: all inquiries
	}
	c.JSON(http.StatusOK, gin.H{"inquiries": s.store.ListInquiries(f)})
}

type patchInquiryRequest struct {
	Status *models.InquiryStatus `json:"status"`
}

// handlePatchInquiry lets a participant (buyer/seller) close/reopen the thread;
// admin may also change status. Support is read-only here.
func (s *Server) handlePatchInquiry(c *gin.Context) {
	u := currentUser(c)
	inq, err := s.store.GetInquiry(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "inquiry not found")
		return
	}
	isParticipant := u.ID == inq.BuyerID || u.ID == inq.SellerID
	if !isParticipant && u.Role != models.RoleAdmin {
		errorJSON(c, http.StatusForbidden, "not a participant")
		return
	}
	var req patchInquiryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Status != nil {
		if *req.Status != models.InquiryOpen && *req.Status != models.InquiryClosed {
			errorJSON(c, http.StatusBadRequest, "invalid status")
			return
		}
		inq.Status = *req.Status
	}
	inq.UpdatedAt = nowUTC()
	if err := s.store.UpdateInquiry(inq); err != nil {
		errorJSON(c, storeErrStatus(err), "could not update inquiry")
		return
	}
	c.JSON(http.StatusOK, inq)
}
