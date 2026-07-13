// Command marketplace-backend is the REST API for the peer-to-peer marketplace.
//
// Phase A baseline: full RBAC (buyer/seller/support/admin), listings, inquiries,
// favorites, reports and admin moderation. No chat/calling — those seams are
// left for a Phase B CometChat integration.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cometchat/marketplace-backend/internal/auth"
	"github.com/cometchat/marketplace-backend/internal/config"
	"github.com/cometchat/marketplace-backend/internal/server"
	"github.com/cometchat/marketplace-backend/internal/store"
)

func main() {
	cfg := config.Load()

	st := store.NewMemory()
	if cfg.SeedDemoData {
		store.Seed(st)
	}

	authMgr := auth.NewManager(cfg.JWTSecret, cfg.TokenTTL)
	srv := server.New(cfg, st, authMgr)

	httpServer := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           srv.Router(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("marketplace-backend listening on :%s", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Graceful shutdown.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
	log.Println("stopped")
}
