package server

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
)

// handleAdminListUsers returns every user (admin moderation view).
func (s *Server) handleAdminListUsers(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"users": s.store.ListUsers()})
}

type adminPatchUserRequest struct {
	Banned *bool        `json:"banned"`
	Role   *models.Role `json:"role"`
}

// handleAdminPatchUser bans/unbans a user or changes their role.
func (s *Server) handleAdminPatchUser(c *gin.Context) {
	actor := currentUser(c)
	target, err := s.store.GetUser(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "user not found")
		return
	}
	var req adminPatchUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if target.ID == actor.ID && req.Banned != nil && *req.Banned {
		errorJSON(c, http.StatusBadRequest, "cannot ban yourself")
		return
	}
	if req.Role != nil {
		if !req.Role.Valid() {
			errorJSON(c, http.StatusBadRequest, "invalid role")
			return
		}
		target.Role = *req.Role
	}
	if req.Banned != nil {
		target.Banned = *req.Banned
	}
	if err := s.store.UpdateUser(target); err != nil {
		errorJSON(c, storeErrStatus(err), "could not update user")
		return
	}
	s.audit(c, "user.update", target.ID, "moderated user")
	c.JSON(http.StatusOK, target)
}

// handleAdminRemoveListing takes a listing down (status -> removed) and purges
// the CometChat conversations tied to it (the dispute groups of its flagged
// inquiries).
func (s *Server) handleAdminRemoveListing(c *gin.Context) {
	l, err := s.store.GetListing(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "listing not found")
		return
	}
	l.Status = models.ListingRemoved
	l.UpdatedAt = nowUTC()
	if err := s.store.UpdateListing(l); err != nil {
		errorJSON(c, storeErrStatus(err), "could not remove listing")
		return
	}
	s.purgeListingConversations(c.Request.Context(), l.ID)
	s.audit(c, "listing.remove", l.ID, "listing removed by admin")
	c.JSON(http.StatusOK, l)
}

// handleAdminAudit returns the full audit log (most recent first).
func (s *Server) handleAdminAudit(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"audit": s.store.ListAudit()})
}
