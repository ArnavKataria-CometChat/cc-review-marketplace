package server

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

type addFavoriteRequest struct {
	ListingID string `json:"listingId"`
}

// handleAddFavorite saves a listing to the buyer's favorites.
func (s *Server) handleAddFavorite(c *gin.Context) {
	u := currentUser(c)
	var req addFavoriteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	if _, err := s.store.GetListing(req.ListingID); err != nil {
		errorJSON(c, http.StatusNotFound, "listing not found")
		return
	}
	fav := &models.Favorite{UserID: u.ID, ListingID: req.ListingID, CreatedAt: nowUTC()}
	if err := s.store.AddFavorite(fav); err != nil {
		if err == store.ErrConflict {
			c.JSON(http.StatusOK, fav) // idempotent
			return
		}
		errorJSON(c, http.StatusInternalServerError, "could not add favorite")
		return
	}
	c.JSON(http.StatusCreated, fav)
}

// handleListFavorites returns the buyer's favorites with their listings inlined.
func (s *Server) handleListFavorites(c *gin.Context) {
	u := currentUser(c)
	favs := s.store.ListFavorites(u.ID)
	type entry struct {
		*models.Favorite
		Listing *models.Listing `json:"listing,omitempty"`
	}
	out := make([]entry, 0, len(favs))
	for _, f := range favs {
		l, _ := s.store.GetListing(f.ListingID)
		out = append(out, entry{Favorite: f, Listing: l})
	}
	c.JSON(http.StatusOK, gin.H{"favorites": out})
}

// handleRemoveFavorite unsaves a listing.
func (s *Server) handleRemoveFavorite(c *gin.Context) {
	u := currentUser(c)
	if err := s.store.RemoveFavorite(u.ID, c.Param("listingId")); err != nil {
		errorJSON(c, http.StatusNotFound, "favorite not found")
		return
	}
	c.Status(http.StatusNoContent)
}
