package store

import (
	"log"
	"time"

	"github.com/google/uuid"

	"github.com/cometchat/marketplace-backend/internal/auth"
	"github.com/cometchat/marketplace-backend/internal/models"
)

// DemoPassword is the shared password for every seeded account. It exists only
// to make the baseline runnable/testable out of the box and is documented in
// the README — it is NOT a real credential.
const DemoPassword = "Password123!"

// Seed populates the store with one account per role plus sample listings, an
// inquiry, a favorite, and a report so the API is explorable immediately.
func Seed(s Store) {
	hash, err := auth.HashPassword(DemoPassword)
	if err != nil {
		log.Fatalf("seed: hashing password: %v", err)
	}
	now := time.Now().UTC()

	mkUser := func(role models.Role, name, email string) *models.User {
		u := &models.User{
			ID:           uuid.NewString(),
			Role:         role,
			Name:         name,
			Email:        email,
			PasswordHash: hash,
			CreatedAt:    now,
		}
		if err := s.CreateUser(u); err != nil {
			log.Fatalf("seed: create user %s: %v", email, err)
		}
		return u
	}

	buyer := mkUser(models.RoleBuyer, "Bailey Buyer", "buyer@example.com")
	seller := mkUser(models.RoleSeller, "Sam Seller", "seller@example.com")
	mkUser(models.RoleSupport, "Sage Support", "support@example.com")
	mkUser(models.RoleAdmin, "Avery Admin", "admin@example.com")

	mkListing := func(title, desc, category string, cents int) *models.Listing {
		l := &models.Listing{
			ID:          uuid.NewString(),
			SellerID:    seller.ID,
			Title:       title,
			Description: desc,
			PriceCents:  cents,
			Category:    category,
			Status:      models.ListingActive,
			Photos:      []string{},
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := s.CreateListing(l); err != nil {
			log.Fatalf("seed: create listing: %v", err)
		}
		return l
	}

	bike := mkListing("Vintage road bike", "Steel frame, recently serviced.", "sports", 24500)
	mkListing("Mechanical keyboard", "Tactile switches, barely used.", "electronics", 8900)
	mkListing("Oak dining table", "Seats six, minor scratches.", "furniture", 15000)

	inq := &models.Inquiry{
		ID:        uuid.NewString(),
		ListingID: bike.ID,
		BuyerID:   buyer.ID,
		SellerID:  seller.ID,
		Status:    models.InquiryOpen,
		Message:   "Is the bike still available? Would you take $220?",
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := s.CreateInquiry(inq); err != nil {
		log.Fatalf("seed: create inquiry: %v", err)
	}

	if err := s.AddFavorite(&models.Favorite{UserID: buyer.ID, ListingID: bike.ID, CreatedAt: now}); err != nil {
		log.Fatalf("seed: add favorite: %v", err)
	}

	report := &models.Report{
		ID:         uuid.NewString(),
		TargetType: models.ReportTargetListing,
		TargetID:   bike.ID,
		ReporterID: buyer.ID,
		Reason:     "Seller stopped responding after payment discussion.",
		Status:     models.ReportOpen,
		InquiryID:  inq.ID,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if err := s.CreateReport(report); err != nil {
		log.Fatalf("seed: create report: %v", err)
	}

	log.Printf("seeded demo data: 4 users (password %q), 3 listings, 1 inquiry, 1 report", DemoPassword)
}
