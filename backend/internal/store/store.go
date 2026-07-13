// Package store defines the persistence interface for the marketplace and an
// in-memory implementation. The interface keeps handlers decoupled from storage
// so a real database can be swapped in without touching HTTP code.
package store

import (
	"errors"

	"github.com/cometchat/marketplace-backend/internal/models"
)

// ErrNotFound is returned when a requested entity does not exist.
var ErrNotFound = errors.New("not found")

// ErrConflict is returned on a uniqueness violation (e.g. duplicate email).
var ErrConflict = errors.New("conflict")

// ListingFilter narrows a listing query. Zero-value fields are ignored.
type ListingFilter struct {
	Search        string // matches title/description (case-insensitive)
	Category      string
	MinPriceCents int
	MaxPriceCents int // 0 means no upper bound
	SellerID      string
	IncludeHidden bool // include sold/removed listings (owner/admin views)
}

// InquiryFilter narrows an inquiry query.
type InquiryFilter struct {
	BuyerID    string
	SellerID   string
	FlaggedOnly bool
}

// ReportFilter narrows a report query.
type ReportFilter struct {
	Status models.ReportStatus // empty means any
}

// Store is the persistence contract for all domain entities.
type Store interface {
	// Users
	CreateUser(u *models.User) error
	GetUser(id string) (*models.User, error)
	GetUserByEmail(email string) (*models.User, error)
	ListUsers() []*models.User
	UpdateUser(u *models.User) error

	// Listings
	CreateListing(l *models.Listing) error
	GetListing(id string) (*models.Listing, error)
	ListListings(f ListingFilter) []*models.Listing
	UpdateListing(l *models.Listing) error

	// Inquiries
	CreateInquiry(i *models.Inquiry) error
	GetInquiry(id string) (*models.Inquiry, error)
	FindInquiry(listingID, buyerID string) (*models.Inquiry, error)
	ListInquiries(f InquiryFilter) []*models.Inquiry
	UpdateInquiry(i *models.Inquiry) error

	// Favorites
	AddFavorite(fav *models.Favorite) error
	RemoveFavorite(userID, listingID string) error
	ListFavorites(userID string) []*models.Favorite

	// Reports
	CreateReport(r *models.Report) error
	GetReport(id string) (*models.Report, error)
	ListReports(f ReportFilter) []*models.Report
	UpdateReport(r *models.Report) error

	// Audit
	AddAudit(e *models.AuditEntry) error
	ListAudit() []*models.AuditEntry
}
