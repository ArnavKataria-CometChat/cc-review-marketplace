package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/cometchat/marketplace-backend/internal/auth"
	"github.com/cometchat/marketplace-backend/internal/config"
	"github.com/cometchat/marketplace-backend/internal/store"
)

func newTestServer(t *testing.T) (*gin.Engine, store.Store) {
	t.Helper()
	gin.SetMode(gin.TestMode)
	st := store.NewMemory()
	store.Seed(st)
	cfg := config.Config{JWTSecret: "test-secret", TokenTTL: time.Hour}
	a := auth.NewManager(cfg.JWTSecret, cfg.TokenTTL)
	return New(cfg, st, a).Router(), st
}

func do(t *testing.T, r *gin.Engine, method, path, token string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func login(t *testing.T, r *gin.Engine, email string) string {
	t.Helper()
	w := do(t, r, http.MethodPost, "/auth/login", "", gin.H{
		"email": email, "password": store.DemoPassword,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("login %s: got %d: %s", email, w.Code, w.Body.String())
	}
	var resp struct {
		Token string `json:"token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Token == "" {
		t.Fatalf("login %s: empty token", email)
	}
	return resp.Token
}

func TestLoginAndMe(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "buyer@example.com")
	w := do(t, r, http.MethodGet, "/users/me", tok, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("me: got %d", w.Code)
	}
}

func TestLoginBadPassword(t *testing.T) {
	r, _ := newTestServer(t)
	w := do(t, r, http.MethodPost, "/auth/login", "", gin.H{
		"email": "buyer@example.com", "password": "wrong",
	})
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestUnauthenticatedRejected(t *testing.T) {
	r, _ := newTestServer(t)
	w := do(t, r, http.MethodGet, "/users/me", "", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestBuyerCannotCreateListing(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "buyer@example.com")
	w := do(t, r, http.MethodPost, "/listings", tok, gin.H{
		"title": "x", "category": "misc", "priceCents": 100,
	})
	if w.Code != http.StatusForbidden {
		t.Fatalf("buyer creating listing: expected 403, got %d", w.Code)
	}
}

func TestSellerCanCreateListing(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "seller@example.com")
	w := do(t, r, http.MethodPost, "/listings", tok, gin.H{
		"title": "Camera", "category": "electronics", "priceCents": 5000,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("seller creating listing: expected 201, got %d: %s", w.Code, w.Body.String())
	}
}

func TestBuyerCannotAccessAdminRoutes(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "buyer@example.com")
	w := do(t, r, http.MethodGet, "/admin/users", tok, nil)
	if w.Code != http.StatusForbidden {
		t.Fatalf("buyer admin route: expected 403, got %d", w.Code)
	}
}

func TestAdminCanListUsers(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "admin@example.com")
	w := do(t, r, http.MethodGet, "/admin/users", tok, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("admin list users: expected 200, got %d", w.Code)
	}
}

func TestSupportSeesDisputeQueue(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "support@example.com")
	w := do(t, r, http.MethodGet, "/reports", tok, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("support reports: expected 200, got %d", w.Code)
	}
}

func TestSellerCannotSeeDisputeQueue(t *testing.T) {
	r, _ := newTestServer(t)
	tok := login(t, r, "seller@example.com")
	w := do(t, r, http.MethodGet, "/reports", tok, nil)
	if w.Code != http.StatusForbidden {
		t.Fatalf("seller reports: expected 403, got %d", w.Code)
	}
}

func TestCometChatTokenDisabledWhenUnconfigured(t *testing.T) {
	// The test server has no CometChat credentials, so the bootstrap endpoint
	// must degrade gracefully to 503 rather than erroring or panicking.
	r, _ := newTestServer(t)
	tok := login(t, r, "buyer@example.com")
	w := do(t, r, http.MethodPost, "/cometchat/token", tok, nil)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("cometchat token (unconfigured): expected 503, got %d: %s", w.Code, w.Body.String())
	}
}

func TestCometChatTokenRequiresAuth(t *testing.T) {
	r, _ := newTestServer(t)
	w := do(t, r, http.MethodPost, "/cometchat/token", "", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("cometchat token (no auth): expected 401, got %d", w.Code)
	}
}

func TestBrowseListingsPublic(t *testing.T) {
	r, _ := newTestServer(t)
	w := do(t, r, http.MethodGet, "/listings?category=sports", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("browse: expected 200, got %d", w.Code)
	}
}
