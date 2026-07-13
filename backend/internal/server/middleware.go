package server

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

const ctxUserKey = "currentUser"

// requireAuth validates the Bearer token, loads the user, and rejects banned
// accounts. On success the *models.User is stashed on the gin context.
func (s *Server) requireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		if token == "" || token == header {
			errorJSON(c, http.StatusUnauthorized, "missing bearer token")
			return
		}
		claims, err := s.auth.Verify(token)
		if err != nil {
			errorJSON(c, http.StatusUnauthorized, "invalid or expired token")
			return
		}
		u, err := s.store.GetUser(claims.UserID)
		if err != nil {
			errorJSON(c, http.StatusUnauthorized, "account no longer exists")
			return
		}
		if u.Banned {
			errorJSON(c, http.StatusForbidden, "account is banned")
			return
		}
		c.Set(ctxUserKey, u)
		c.Next()
	}
}

// requireRole allows the request through only if the current user's role is in
// the allowed set. Must run after requireAuth.
func (s *Server) requireRole(allowed ...models.Role) gin.HandlerFunc {
	allowSet := make(map[models.Role]bool, len(allowed))
	for _, r := range allowed {
		allowSet[r] = true
	}
	return func(c *gin.Context) {
		u := currentUser(c)
		if u == nil {
			errorJSON(c, http.StatusUnauthorized, "authentication required")
			return
		}
		if !allowSet[u.Role] {
			errorJSON(c, http.StatusForbidden, "insufficient role")
			return
		}
		c.Next()
	}
}

// currentUser returns the authenticated user from the context, or nil.
func currentUser(c *gin.Context) *models.User {
	v, ok := c.Get(ctxUserKey)
	if !ok {
		return nil
	}
	u, _ := v.(*models.User)
	return u
}

// audit records a privileged action performed by the current user.
func (s *Server) audit(c *gin.Context, action, target, details string) {
	u := currentUser(c)
	if u == nil {
		return
	}
	_ = s.store.AddAudit(&models.AuditEntry{
		ID:        newID(),
		ActorID:   u.ID,
		ActorRole: u.Role,
		Action:    action,
		Target:    target,
		Details:   details,
		CreatedAt: nowUTC(),
	})
}

// storeErrStatus maps a store error to an HTTP status.
func storeErrStatus(err error) int {
	switch err {
	case store.ErrNotFound:
		return http.StatusNotFound
	case store.ErrConflict:
		return http.StatusConflict
	default:
		return http.StatusInternalServerError
	}
}
