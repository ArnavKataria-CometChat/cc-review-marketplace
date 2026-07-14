// Package cometchat is a thin, server-side wrapper over the CometChat REST
// (Chat) API. It provisions a CometChat user per app user, mints per-user auth
// tokens for the frontends to log in with, and manages the dispute groups.
//
// The fullAccess REST API Key it uses must NEVER reach a client — it lives only
// here, in the backend, read from the environment. Clients only ever receive
// the App ID, Region and a short-lived, per-user auth token.
package cometchat

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/cometchat/marketplace-backend/internal/models"
)

// ErrDisabled is returned by every call when the client has no credentials.
var ErrDisabled = errors.New("cometchat: not configured")

// Client talks to the CometChat Chat REST API for one app + region.
type Client struct {
	appID   string
	region  string
	restKey string
	base    string
	http    *http.Client
}

// New builds a Client from credentials. When any of them is missing the client
// is disabled — Enabled() reports false and every call returns ErrDisabled — so
// the rest of the service runs unchanged when CometChat isn't configured.
func New(appID, region, restKey string) *Client {
	c := &Client{
		appID:   strings.TrimSpace(appID),
		region:  strings.TrimSpace(region),
		restKey: strings.TrimSpace(restKey),
		http:    &http.Client{Timeout: 10 * time.Second},
	}
	if c.Enabled() {
		// Per the REST API docs the host is scoped to the app + region and the
		// key travels in the lowercase `apikey` header.
		c.base = fmt.Sprintf("https://%s.api-%s.cometchat.io/v3", c.appID, c.region)
	}
	return c
}

// Enabled reports whether the client has enough credentials to make calls.
func (c *Client) Enabled() bool {
	return c != nil && c.appID != "" && c.region != "" && c.restKey != ""
}

// AppID and Region are safe to hand to clients (only the REST key is secret).
func (c *Client) AppID() string  { return c.appID }
func (c *Client) Region() string { return c.region }

// DisputeGUID is the deterministic group id for an inquiry's dispute group.
// Keeping it derived from the inquiry id makes escalation idempotent and lets
// every client resolve the same GUID without a round-trip.
func DisputeGUID(inquiryID string) string { return "dispute-" + inquiryID }

// SyncUser creates (or updates, if it already exists) the CometChat user that
// mirrors an app user. The app's RBAC role is stored in `metadata.appRole`; the
// top-level `role` field is left unset because it must map to a role that has
// been predefined in the CometChat dashboard, whereas metadata is free-form.
func (c *Client) SyncUser(ctx context.Context, u *models.User) error {
	if !c.Enabled() {
		return ErrDisabled
	}
	metadata := map[string]any{"appRole": string(u.Role)}
	_, err := c.do(ctx, http.MethodPost, "/users", map[string]any{
		"uid":      u.ID,
		"name":     u.Name,
		"metadata": metadata,
	})
	var apiErr *apiError
	if errors.As(err, &apiErr) && apiErr.alreadyExists() {
		// Already provisioned — keep name/role in sync instead.
		_, err = c.do(ctx, http.MethodPut, "/users/"+url.PathEscape(u.ID), map[string]any{
			"name":     u.Name,
			"metadata": metadata,
		})
	}
	return err
}

// MintAuthToken issues a fresh per-user auth token the client SDK logs in with.
func (c *Client) MintAuthToken(ctx context.Context, uid string) (string, error) {
	if !c.Enabled() {
		return "", ErrDisabled
	}
	body, err := c.do(ctx, http.MethodPost, "/users/"+url.PathEscape(uid)+"/auth_tokens", map[string]any{
		"force": true,
	})
	if err != nil {
		return "", err
	}
	var resp struct {
		Data struct {
			AuthToken string `json:"authToken"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		return "", fmt.Errorf("cometchat: decode auth token: %w", err)
	}
	if resp.Data.AuthToken == "" {
		return "", errors.New("cometchat: empty auth token in response")
	}
	return resp.Data.AuthToken, nil
}

// CreateGroup provisions a private group with the given members. Owner and
// moderators steer the conversation (support), participants are the parties
// (buyer + seller). Creation is idempotent: if the GUID already exists the call
// succeeds so re-flagging a report never errors.
func (c *Client) CreateGroup(ctx context.Context, guid, name, description, owner string, moderators, participants []string) error {
	if !c.Enabled() {
		return ErrDisabled
	}
	members := map[string]any{}
	if len(moderators) > 0 {
		members["moderators"] = moderators
	}
	if len(participants) > 0 {
		members["participants"] = participants
	}
	body := map[string]any{
		"guid":        guid,
		"name":        name,
		"type":        "private",
		"description": description,
		"members":     members,
	}
	if owner != "" {
		body["owner"] = owner
	}
	_, err := c.do(ctx, http.MethodPost, "/groups", body)
	var apiErr *apiError
	if errors.As(err, &apiErr) && apiErr.alreadyExists() {
		return nil
	}
	return err
}

// DeleteGroup removes a group (and thereby its conversation). A missing group is
// treated as success so purging is idempotent.
func (c *Client) DeleteGroup(ctx context.Context, guid string) error {
	if !c.Enabled() {
		return ErrDisabled
	}
	_, err := c.do(ctx, http.MethodDelete, "/groups/"+url.PathEscape(guid), nil)
	var apiErr *apiError
	if errors.As(err, &apiErr) && apiErr.status == http.StatusNotFound {
		return nil
	}
	return err
}

// apiError carries a non-2xx CometChat response.
type apiError struct {
	status int
	body   string
}

func (e *apiError) Error() string { return fmt.Sprintf("cometchat: http %d: %s", e.status, e.body) }

// alreadyExists reports whether the error is a "resource already exists"
// conflict — CometChat returns 409, and its error codes end in _ALREADY_EXISTS.
func (e *apiError) alreadyExists() bool {
	return e.status == http.StatusConflict || strings.Contains(e.body, "ALREADY_EXISTS")
}

// do performs one authenticated JSON request and returns the raw response body.
func (c *Client) do(ctx context.Context, method, path string, payload any) ([]byte, error) {
	var reader io.Reader
	if payload != nil {
		buf, err := json.Marshal(payload)
		if err != nil {
			return nil, fmt.Errorf("cometchat: encode request: %w", err)
		}
		reader = bytes.NewReader(buf)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, reader)
	if err != nil {
		return nil, fmt.Errorf("cometchat: build request: %w", err)
	}
	req.Header.Set("apikey", c.restKey)
	req.Header.Set("Accept", "application/json")
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("cometchat: %s %s: %w", method, path, err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("cometchat: read response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, &apiError{status: resp.StatusCode, body: string(body)}
	}
	return body, nil
}
