package server

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/auth"
	"github.com/cometchat/marketplace-backend/internal/models"
	"github.com/cometchat/marketplace-backend/internal/store"
)

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type authResponse struct {
	Token string       `json:"token"`
	User  *models.User `json:"user"`
}

// handleLogin verifies credentials and returns a session token.
func (s *Server) handleLogin(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	u, err := s.store.GetUserByEmail(strings.TrimSpace(req.Email))
	if err != nil || !auth.CheckPassword(u.PasswordHash, req.Password) {
		// Same message for unknown email and wrong password (no user enumeration).
		errorJSON(c, http.StatusUnauthorized, "invalid email or password")
		return
	}
	if u.Banned {
		errorJSON(c, http.StatusForbidden, "account is banned")
		return
	}
	token, err := s.auth.Issue(u)
	if err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not issue token")
		return
	}
	c.JSON(http.StatusOK, authResponse{Token: token, User: u})
}

type registerRequest struct {
	Name     string      `json:"name"`
	Email    string      `json:"email"`
	Password string      `json:"password"`
	Role     models.Role `json:"role"`
}

// handleRegister creates a new account. Self-service registration is limited to
// buyer/seller; support and admin are provisioned out-of-band.
func (s *Server) handleRegister(c *gin.Context) {
	var req registerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.TrimSpace(req.Email)
	if req.Name == "" || req.Email == "" || len(req.Password) < 8 {
		errorJSON(c, http.StatusBadRequest, "name, email and an 8+ char password are required")
		return
	}
	if req.Role != models.RoleBuyer && req.Role != models.RoleSeller {
		errorJSON(c, http.StatusBadRequest, "role must be 'buyer' or 'seller'")
		return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not hash password")
		return
	}
	u := &models.User{
		ID:           newID(),
		Role:         req.Role,
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: hash,
		CreatedAt:    nowUTC(),
	}
	if err := s.store.CreateUser(u); err != nil {
		if err == store.ErrConflict {
			errorJSON(c, http.StatusConflict, "email already registered")
			return
		}
		errorJSON(c, http.StatusInternalServerError, "could not create account")
		return
	}
	token, err := s.auth.Issue(u)
	if err != nil {
		errorJSON(c, http.StatusInternalServerError, "could not issue token")
		return
	}
	c.JSON(http.StatusCreated, authResponse{Token: token, User: u})
}

// handleMe returns the current authenticated user.
func (s *Server) handleMe(c *gin.Context) {
	c.JSON(http.StatusOK, currentUser(c))
}
