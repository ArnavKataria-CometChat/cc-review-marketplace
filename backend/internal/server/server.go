// Package server wires the HTTP routes, middleware and handlers together.
package server

import (
	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/auth"
	"github.com/cometchat/marketplace-backend/internal/config"
	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

// Server holds shared dependencies for the HTTP handlers.
type Server struct {
	cfg   config.Config
	store store.Store
	auth  *auth.Manager
}

// New builds a Server.
func New(cfg config.Config, s store.Store, a *auth.Manager) *Server {
	return &Server{cfg: cfg, store: s, auth: a}
}

// Router constructs the gin engine with all routes and guards installed.
func (s *Server) Router() *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

	// --- Public auth ---
	r.POST("/auth/login", s.handleLogin)
	r.POST("/auth/register", s.handleRegister)

	// --- Listings: browsing is public; writes require a seller ---
	r.GET("/listings", s.handleListListings)
	r.GET("/listings/:id", s.handleGetListing)

	// --- Authenticated area ---
	authed := r.Group("/")
	authed.Use(s.requireAuth())
	{
		authed.GET("/users/me", s.handleMe)

		// Seller-owned listing management.
		authed.POST("/listings", s.requireRole(models.RoleSeller), s.handleCreateListing)
		authed.PATCH("/listings/:id", s.handlePatchListing) // owner (seller) or admin

		// Inquiries (buyer↔seller thread anchor).
		authed.POST("/inquiries", s.requireRole(models.RoleBuyer), s.handleCreateInquiry)
		authed.GET("/inquiries", s.handleListInquiries) // role-scoped inside handler
		authed.PATCH("/inquiries/:id", s.handlePatchInquiry)

		// Favorites (buyer).
		authed.POST("/favorites", s.requireRole(models.RoleBuyer), s.handleAddFavorite)
		authed.GET("/favorites", s.requireRole(models.RoleBuyer), s.handleListFavorites)
		authed.DELETE("/favorites/:listingId", s.requireRole(models.RoleBuyer), s.handleRemoveFavorite)

		// Reports: any authenticated user can file one.
		authed.POST("/reports", s.handleCreateReport)

		// Support + admin: dispute queue and detail.
		support := authed.Group("/")
		support.Use(s.requireRole(models.RoleSupport, models.RoleAdmin))
		{
			support.GET("/reports", s.handleListReports)
			support.GET("/reports/:id", s.handleGetReport)
			support.PATCH("/reports/:id", s.handlePatchReport)
		}

		// Admin-only moderation + audit.
		admin := authed.Group("/admin")
		admin.Use(s.requireRole(models.RoleAdmin))
		{
			admin.GET("/users", s.handleAdminListUsers)
			admin.PATCH("/users/:id", s.handleAdminPatchUser) // ban/unban, change role
			admin.DELETE("/listings/:id", s.handleAdminRemoveListing)
			admin.GET("/audit", s.handleAdminAudit)
		}
	}

	return r
}
