// Package models defines the domain entities for the marketplace.
package models

import "time"

// Role is a user's access level. RBAC is enforced against these four values.
type Role string

const (
	RoleBuyer   Role = "buyer"
	RoleSeller  Role = "seller"
	RoleSupport Role = "support"
	RoleAdmin   Role = "admin"
)

// Valid reports whether r is one of the known roles.
func (r Role) Valid() bool {
	switch r {
	case RoleBuyer, RoleSeller, RoleSupport, RoleAdmin:
		return true
	}
	return false
}

// ListingStatus is the lifecycle state of a listing.
type ListingStatus string

const (
	ListingActive  ListingStatus = "active"
	ListingSold    ListingStatus = "sold"
	ListingRemoved ListingStatus = "removed"
)

// InquiryStatus is the state of a buyer↔seller inquiry thread.
type InquiryStatus string

const (
	InquiryOpen   InquiryStatus = "open"
	InquiryClosed InquiryStatus = "closed"
)

// ReportTargetType is what a report points at.
type ReportTargetType string

const (
	ReportTargetListing ReportTargetType = "listing"
	ReportTargetUser    ReportTargetType = "user"
	ReportTargetMessage ReportTargetType = "message"
)

// ReportStatus is the moderation state of a report.
type ReportStatus string

const (
	ReportOpen     ReportStatus = "open"
	ReportFlagged  ReportStatus = "flagged"
	ReportResolved ReportStatus = "resolved"
)

// User is a marketplace account. PasswordHash is never serialized to clients.
type User struct {
	ID           string    `json:"id"`
	Role         Role      `json:"role"`
	Name         string    `json:"name"`
	Email        string    `json:"email"`
	Banned       bool      `json:"banned"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"createdAt"`
}

// Listing is an item for sale, owned by a seller.
type Listing struct {
	ID          string        `json:"id"`
	SellerID    string        `json:"sellerId"`
	Title       string        `json:"title"`
	Description string        `json:"description"`
	PriceCents  int           `json:"priceCents"`
	Category    string        `json:"category"`
	Status      ListingStatus `json:"status"`
	Photos      []string      `json:"photos"`
	CreatedAt   time.Time     `json:"createdAt"`
	UpdatedAt   time.Time     `json:"updatedAt"`
}

// Inquiry anchors a buyer↔seller thread about a specific listing. In Phase B
// this is the key a CometChat 1:1 conversation (and voice call) is keyed on.
type Inquiry struct {
	ID        string        `json:"id"`
	ListingID string        `json:"listingId"`
	BuyerID   string        `json:"buyerId"`
	SellerID  string        `json:"sellerId"`
	Status    InquiryStatus `json:"status"`
	Message   string        `json:"message"`
	// Flagged marks that a report escalated this thread into a dispute. In
	// Phase B a flagged inquiry becomes a buyer+seller+support CometChat group.
	Flagged   bool      `json:"flagged"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// Favorite is a buyer's saved listing. The pair (UserID, ListingID) is unique.
type Favorite struct {
	UserID    string    `json:"userId"`
	ListingID string    `json:"listingId"`
	CreatedAt time.Time `json:"createdAt"`
}

// Report is a moderation/dispute record raised against a target.
type Report struct {
	ID         string           `json:"id"`
	TargetType ReportTargetType `json:"targetType"`
	TargetID   string           `json:"targetId"`
	ReporterID string           `json:"reporterId"`
	Reason     string           `json:"reason"`
	Status     ReportStatus     `json:"status"`
	// InquiryID optionally links a report to the inquiry thread it disputes,
	// so support gets the buyer/seller/thread context in one place.
	InquiryID string    `json:"inquiryId,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// AuditEntry records a privileged action for the admin audit log.
type AuditEntry struct {
	ID        string    `json:"id"`
	ActorID   string    `json:"actorId"`
	ActorRole Role      `json:"actorRole"`
	Action    string    `json:"action"`
	Target    string    `json:"target"`
	Details   string    `json:"details"`
	CreatedAt time.Time `json:"createdAt"`
}
