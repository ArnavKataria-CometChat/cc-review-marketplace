package server

import (
	"time"

	"github.com/google/uuid"
)

func newID() string     { return uuid.NewString() }
func nowUTC() time.Time { return time.Now().UTC() }
