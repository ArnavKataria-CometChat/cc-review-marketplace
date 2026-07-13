// Package config loads runtime configuration from the environment.
//
// No secrets are hard-coded: everything comes from env vars with sensible,
// clearly-non-production defaults so the service still boots for local dev.
package config

import (
	"os"
	"time"
)

// Config holds all runtime configuration for the server.
type Config struct {
	Port          string
	JWTSecret     string
	TokenTTL      time.Duration
	SeedDemoData  bool

	// CometChat placeholders — unused in Phase A (no chat is wired up), but
	// documented and read here so the deployment surface is ready for Phase B.
	CometChatAppID  string
	CometChatRegion string
	CometChatAPIKey string
}

// Load reads configuration from the environment, applying defaults.
func Load() Config {
	return Config{
		Port:            getenv("PORT", "8080"),
		JWTSecret:       getenv("JWT_SECRET", "dev-only-insecure-secret-change-me"),
		TokenTTL:        getdur("TOKEN_TTL", 24*time.Hour),
		SeedDemoData:    getbool("SEED_DEMO_DATA", true),
		CometChatAppID:  os.Getenv("COMETCHAT_APP_ID"),
		CometChatRegion: os.Getenv("COMETCHAT_REGION"),
		CometChatAPIKey: os.Getenv("COMETCHAT_API_KEY"),
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getbool(key string, def bool) bool {
	switch os.Getenv(key) {
	case "1", "true", "TRUE", "yes":
		return true
	case "0", "false", "FALSE", "no":
		return false
	default:
		return def
	}
}

func getdur(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
