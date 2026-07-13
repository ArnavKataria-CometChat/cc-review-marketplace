// Package auth handles password hashing and stateless JWT session tokens.
package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/cometchat/marketplace-backend/internal/models"
)

// ErrInvalidToken is returned when a token cannot be parsed or is expired.
var ErrInvalidToken = errors.New("invalid or expired token")

// Manager issues and verifies session tokens. A session carries the stable
// server-side user id and role — the identity Phase B maps to a CometChat user.
type Manager struct {
	secret []byte
	ttl    time.Duration
}

// NewManager creates a token manager.
func NewManager(secret string, ttl time.Duration) *Manager {
	return &Manager{secret: []byte(secret), ttl: ttl}
}

// Claims is the JWT payload for a session.
type Claims struct {
	UserID string      `json:"uid"`
	Role   models.Role `json:"role"`
	jwt.RegisteredClaims
}

// HashPassword returns a bcrypt hash of the given plaintext password.
func HashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	return string(b), err
}

// CheckPassword reports whether plain matches the stored bcrypt hash.
func CheckPassword(hash, plain string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}

// Issue mints a signed JWT for the given user.
func (m *Manager) Issue(u *models.User) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: u.ID,
		Role:   u.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   u.ID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.ttl)),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(m.secret)
}

// Verify parses and validates a token string, returning its claims.
func (m *Manager) Verify(tokenStr string) (*Claims, error) {
	claims := &Claims{}
	tok, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return m.secret, nil
	})
	if err != nil || !tok.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}
