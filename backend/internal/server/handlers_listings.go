package server

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

// handleListListings returns active listings, filtered by query params:
// ?search=&category=&minPrice=&maxPrice= (prices in cents).
func (s *Server) handleListListings(c *gin.Context) {
	f := store.ListingFilter{
		Search:        c.Query("search"),
		Category:      c.Query("category"),
		MinPriceCents: atoiDefault(c.Query("minPrice"), 0),
		MaxPriceCents: atoiDefault(c.Query("maxPrice"), 0),
	}
	c.JSON(http.StatusOK, gin.H{"listings": s.store.ListListings(f)})
}

// handleGetListing returns a single listing. Removed listings are hidden from
// everyone except the owning seller, support and admin.
func (s *Server) handleGetListing(c *gin.Context) {
	l, err := s.store.GetListing(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "listing not found")
		return
	}
	if l.Status == models.ListingRemoved {
		u := currentUser(c) // may be nil on this public route
		privileged := u != nil && (u.ID == l.SellerID || u.Role == models.RoleSupport || u.Role == models.RoleAdmin)
		if !privileged {
			errorJSON(c, http.StatusNotFound, "listing not found")
			return
		}
	}
	c.JSON(http.StatusOK, l)
}

type createListingRequest struct {
	Title       string   `json:"title"`
	Description string   `json:"description"`
	PriceCents  int      `json:"priceCents"`
	Category    string   `json:"category"`
	Photos      []string `json:"photos"`
}

// handleCreateListing lets a seller publish a new listing.
func (s *Server) handleCreateListing(c *gin.Context) {
	u := currentUser(c)
	var req createListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Category = strings.TrimSpace(req.Category)
	if req.Title == "" || req.Category == "" {
		errorJSON(c, http.StatusBadRequest, "title and category are required")
		return
	}
	if req.PriceCents <= 0 {
		errorJSON(c, http.StatusBadRequest, "priceCents must be positive")
		return
	}
	if req.Photos == nil {
		req.Photos = []string{}
	}
	l := &models.Listing{
		ID:          newID(),
		SellerID:    u.ID,
		Title:       req.Title,
		Description: strings.TrimSpace(req.Description),
		PriceCents:  req.PriceCents,
		Category:    req.Category,
		Status:      models.ListingActive,
		Photos:      req.Photos,
		CreatedAt:   nowUTC(),
		UpdatedAt:   nowUTC(),
	}
	if err := s.store.CreateListing(l); err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not create listing")
		return
	}
	c.JSON(http.StatusCreated, l)
}

type patchListingRequest struct {
	Title       *string                `json:"title"`
	Description *string                `json:"description"`
	PriceCents  *int                   `json:"priceCents"`
	Category    *string                `json:"category"`
	Photos      *[]string              `json:"photos"`
	Status      *models.ListingStatus  `json:"status"` // e.g. mark sold
}

// handlePatchListing updates a listing. Only the owning seller (or an admin) may
// edit it; sellers may set status active/sold, admins may also remove.
func (s *Server) handlePatchListing(c *gin.Context) {
	u := currentUser(c)
	l, err := s.store.GetListing(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "listing not found")
		return
	}
	isOwner := u.ID == l.SellerID
	isAdmin := u.Role == models.RoleAdmin
	if !isOwner && !isAdmin {
		errorJSON(c, http.StatusForbidden, "not your listing")
		return
	}

	var req patchListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Title != nil {
		if strings.TrimSpace(*req.Title) == "" {
			errorJSON(c, http.StatusBadRequest, "title cannot be empty")
			return
		}
		l.Title = strings.TrimSpace(*req.Title)
	}
	if req.Description != nil {
		l.Description = strings.TrimSpace(*req.Description)
	}
	if req.PriceCents != nil {
		if *req.PriceCents <= 0 {
			errorJSON(c, http.StatusBadRequest, "priceCents must be positive")
			return
		}
		l.PriceCents = *req.PriceCents
	}
	if req.Category != nil {
		l.Category = strings.TrimSpace(*req.Category)
	}
	if req.Photos != nil {
		l.Photos = *req.Photos
	}
	if req.Status != nil {
		switch *req.Status {
		case models.ListingActive, models.ListingSold:
			// sellers and admins may toggle active/sold
		case models.ListingRemoved:
			if !isAdmin {
				errorJSON(c, http.StatusForbidden, "only admin may remove listings")
				return
			}
		default:
			errorJSON(c, http.StatusBadRequest, "invalid status")
			return
		}
		l.Status = *req.Status
	}
	l.UpdatedAt = nowUTC()
	if err := s.store.UpdateListing(l); err != nil {
		errorJSON(c, storeErrStatus(err), "could not update listing")
		return
	}
	if isAdmin && !isOwner {
		s.audit(c, "listing.update", l.ID, "admin edited listing")
	}
	c.JSON(http.StatusOK, l)
}

func atoiDefault(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}
