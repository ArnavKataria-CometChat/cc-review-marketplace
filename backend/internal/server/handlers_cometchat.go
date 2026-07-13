package server

import (
	"context"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/cometchat"
	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

// cometChatTokenResponse is what the frontends need to log into CometChat: the
// non-secret App ID + Region and a short-lived, per-user auth token. The REST
// API Key is deliberately absent — it never leaves the backend.
type cometChatTokenResponse struct {
	AppID     string `json:"appId"`
	Region    string `json:"region"`
	UID       string `json:"uid"`
	AuthToken string `json:"authToken"`
}

// handleCometChatToken provisions (just-in-time) the caller's CometChat user and
// returns a fresh auth token. This is the single bootstrap endpoint every client
// calls after login to bring up chat/calling.
func (s *Server) handleCometChatToken(c *gin.Context) {
	if !s.cc.Enabled() {
		errorJSON(c, http.StatusServiceUnavailable, "chat is not configured")
		return
	}
	u := currentUser(c)
	ctx := c.Request.Context()

	if err := s.cc.SyncUser(ctx, u); err != nil {
		log.Printf("cometchat: sync user %s: %v", u.ID, err)
		errorJSON(c, http.StatusBadGateway, "could not provision chat user")
		return
	}
	token, err := s.cc.MintAuthToken(ctx, u.ID)
	if err != nil {
		log.Printf("cometchat: mint token for %s: %v", u.ID, err)
		errorJSON(c, http.StatusBadGateway, "could not issue chat token")
		return
	}
	c.JSON(http.StatusOK, cometChatTokenResponse{
		AppID:     s.cc.AppID(),
		Region:    s.cc.Region(),
		UID:       u.ID,
		AuthToken: token,
	})
}

// escalateDispute idempotently provisions the buyer+seller+support CometChat
// group for a flagged inquiry (GUID: dispute-<inquiryId>). It is best-effort:
// chat being unreachable must not break the report workflow, so every failure
// is logged rather than surfaced to the caller.
func (s *Server) escalateDispute(ctx context.Context, inq *models.Inquiry) {
	if !s.cc.Enabled() {
		return
	}
	buyer, err := s.store.GetUser(inq.BuyerID)
	if err != nil {
		log.Printf("cometchat: dispute %s: buyer lookup: %v", inq.ID, err)
		return
	}
	seller, err := s.store.GetUser(inq.SellerID)
	if err != nil {
		log.Printf("cometchat: dispute %s: seller lookup: %v", inq.ID, err)
		return
	}

	// Support agents mediate the dispute; add every support user as a moderator.
	var support []*models.User
	for _, u := range s.store.ListUsers() {
		if u.Role == models.RoleSupport {
			support = append(support, u)
		}
	}

	// Each participant must exist in CometChat before joining the group.
	for _, u := range append([]*models.User{buyer, seller}, support...) {
		if err := s.cc.SyncUser(ctx, u); err != nil {
			log.Printf("cometchat: dispute %s: sync %s: %v", inq.ID, u.ID, err)
		}
	}

	var supportUIDs []string
	for _, u := range support {
		supportUIDs = append(supportUIDs, u.ID)
	}
	owner := ""
	if len(supportUIDs) > 0 {
		owner = supportUIDs[0]
	}

	name := "Dispute"
	if l, err := s.store.GetListing(inq.ListingID); err == nil {
		name = "Dispute · " + l.Title
	}

	if err := s.cc.CreateGroup(ctx, cometchat.DisputeGUID(inq.ID), name,
		"Marketplace dispute between buyer and seller, mediated by support.",
		owner, supportUIDs, []string{buyer.ID, seller.ID}); err != nil {
		log.Printf("cometchat: dispute %s: create group: %v", inq.ID, err)
	}
}

// closeDispute tears down the dispute group when a report is resolved.
func (s *Server) closeDispute(ctx context.Context, inq *models.Inquiry) {
	if !s.cc.Enabled() {
		return
	}
	if err := s.cc.DeleteGroup(ctx, cometchat.DisputeGUID(inq.ID)); err != nil {
		log.Printf("cometchat: dispute %s: delete group: %v", inq.ID, err)
	}
}

// purgeListingConversations removes CometChat conversations tied to a listing
// when an admin takes it down — currently the dispute groups of its flagged
// inquiries. Best-effort, same as escalation.
func (s *Server) purgeListingConversations(ctx context.Context, listingID string) {
	if !s.cc.Enabled() {
		return
	}
	for _, inq := range s.store.ListInquiries(store.InquiryFilter{}) {
		if inq.ListingID == listingID && inq.Flagged {
			if err := s.cc.DeleteGroup(ctx, cometchat.DisputeGUID(inq.ID)); err != nil {
				log.Printf("cometchat: purge listing %s: delete group %s: %v", listingID, inq.ID, err)
			}
		}
	}
}
