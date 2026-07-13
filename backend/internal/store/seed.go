package store

import (
	"fmt"
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

// listingPhotos returns two sized URLs for a HAND-CURATED Unsplash photo that
// actually depicts the listing (picked per item, not keyword-guessed). Unsplash's
// image CDN resizes via query params and permits hotlinking, so these render
// out of the box and stay stable. `photoID` is the Unsplash "<epoch>-<hash>" id.
func listingPhotos(photoID string) []string {
	base := "https://images.unsplash.com/photo-" + photoID
	return []string{
		base + "?w=600&h=400&fit=crop",
		base + "?w=600&h=400&fit=crop&crop=entropy",
	}
}

// Seed populates the store with a realistic, non-empty dataset: 20 users across
// all roles, 20 photo-backed listings, plus inquiries, favorites, and reports
// (including a FLAGGED report — the anchor for the Phase B dispute group) so
// every screen and role-scoped view is populated on first run.
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

	// --- 20 users -----------------------------------------------------------
	// Memorable demo logins (one per role, shown on the login screen) FIRST...
	buyer := mkUser(models.RoleBuyer, "Bailey Buyer", "buyer@example.com")
	seller := mkUser(models.RoleSeller, "Sam Seller", "seller@example.com")
	mkUser(models.RoleSupport, "Sage Support", "support@example.com")
	mkUser(models.RoleAdmin, "Avery Admin", "admin@example.com")

	// ...then padded to 20 with additional sellers and buyers.
	sellerNames := []string{
		"Nora Fields", "Diego Marsh", "Priya Rao", "Liam Chen", "Maya Okafor",
		"Tomas Vidal", "Hana Kim", "Ivan Petrov", "Grace Mwangi",
	}
	buyerNames := []string{
		"Ella Ford", "Omar Haddad", "Ruby Lane", "Kenji Sato",
		"Sofia Ruiz", "Aaron Blake", "Lena Voss",
	}

	sellers := []*models.User{seller}
	for i, n := range sellerNames {
		sellers = append(sellers, mkUser(models.RoleSeller, n, fmt.Sprintf("seller%d@example.com", i+1)))
	}
	buyers := []*models.User{buyer}
	for i, n := range buyerNames {
		buyers = append(buyers, mkUser(models.RoleBuyer, n, fmt.Sprintf("buyer%d@example.com", i+1)))
	}
	// users total: 4 demo + 9 sellers + 7 buyers = 20.

	// --- 20 listings (photo-backed), round-robin across sellers -------------
	type spec struct {
		title, desc, category, photo  string
		cents                          int
		status                         models.ListingStatus
	}
	specs := []spec{
		{"Vintage road bike", "Steel frame, recently serviced, new tires.", "sports", "1485965120184-e220f721d03e", 24500, models.ListingActive},
		{"Mechanical keyboard", "Tactile brown switches, barely used.", "electronics", "1587829741301-dc798b83add3", 8900, models.ListingActive},
		{"Oak dining table", "Seats six, solid oak, minor scratches.", "furniture", "1505409628601-edc9af17fda6", 15000, models.ListingActive},
		{"Noise-cancelling headphones", "Over-ear, great battery life.", "electronics", "1505740420928-5e560c06d30e", 12900, models.ListingActive},
		{"Mid-century armchair", "Reupholstered walnut frame.", "furniture", "1634712282287-14ed57b9cc89", 18500, models.ListingActive},
		{"Mountain bike helmet", "Size M, MIPS, worn twice.", "sports", "1591511275477-88f079d88154", 4500, models.ListingActive},
		{"Espresso machine", "Dual boiler, descaled monthly.", "home", "1620807773206-49c1f2957417", 32000, models.ListingActive},
		{"Acoustic guitar", "Dreadnought, spruce top, with case.", "music", "1510915361894-db8b60106cb1", 21000, models.ListingActive},
		{"Road running shoes", "Size 10, ~50 miles on them.", "fashion", "1542291026-7eec264c27ff", 5500, models.ListingActive},
		{"Bookshelf, 5-tier", "White, flat-pack, all screws included.", "furniture", "1593430980369-68efc5a5eb34", 6000, models.ListingActive},
		{"DSLR camera", "24MP, two lenses, low shutter count.", "electronics", "1495707902641-75cac588d2e9", 47500, models.ListingActive},
		{"Yoga mat set", "Mat, blocks, and strap.", "sports", "1599901860904-17e6ed7083a0", 3500, models.ListingActive},
		{"Ceramic dinnerware", "Service for eight, no chips.", "home", "1571987530791-58e3e7744d99", 7800, models.ListingActive},
		{"Electric scooter", "25km range, folds flat.", "auto", "1565300480288-deb407e6ae15", 39900, models.ListingActive},
		{"Wool overcoat", "Charcoal, size L, dry-cleaned.", "fashion", "1608635680046-aebf91c1a9c8", 9900, models.ListingSold},
		{"Board game bundle", "Six modern strategy games.", "toys", "1629760946220-5693ee4c46ac", 6200, models.ListingActive},
		{"Standing desk", "Electric, dual motor, 120cm.", "furniture", "1622131278701-eb225474ffd2", 28000, models.ListingActive},
		{"Garden tool set", "Spade, fork, shears, gloves.", "garden", "1617576683096-00fc8eecb3af", 4200, models.ListingActive},
		{"Vinyl record collection", "40 classic rock LPs.", "music", "1580656449278-e8381933522c", 15500, models.ListingActive},
		{"Drone with 4K camera", "Three batteries, hard case.", "electronics", "1473968512647-3e447244af8f", 52000, models.ListingRemoved},
	}

	listings := make([]*models.Listing, 0, len(specs))
	for i, sp := range specs {
		owner := sellers[i%len(sellers)]
		l := &models.Listing{
			ID:          uuid.NewString(),
			SellerID:    owner.ID,
			Title:       sp.title,
			Description: sp.desc,
			PriceCents:  sp.cents,
			Category:    sp.category,
			Status:      sp.status,
			Photos:      listingPhotos(sp.photo),
			CreatedAt:   now.Add(time.Duration(-i) * time.Hour),
			UpdatedAt:   now,
		}
		if err := s.CreateListing(l); err != nil {
			log.Fatalf("seed: create listing %q: %v", sp.title, err)
		}
		listings = append(listings, l)
	}

	// --- inquiries: buyer<->seller threads across the first 12 listings -----
	inqMsgs := []string{
		"Is this still available? Would you take a bit less?",
		"Can you do local pickup this weekend?",
		"Any scratches or issues not shown in the photos?",
		"Would you consider shipping it?",
		"Is the price negotiable for a quick sale?",
	}
	inquiries := make([]*models.Inquiry, 0)
	for i := 0; i < 12; i++ {
		l := listings[i]
		b := buyers[i%len(buyers)]
		if b.ID == l.SellerID { // never inquire on your own listing
			b = buyers[(i+1)%len(buyers)]
		}
		inq := &models.Inquiry{
			ID:        uuid.NewString(),
			ListingID: l.ID,
			BuyerID:   b.ID,
			SellerID:  l.SellerID,
			Status:    models.InquiryOpen,
			Message:   inqMsgs[i%len(inqMsgs)],
			CreatedAt: now.Add(time.Duration(-i) * 30 * time.Minute),
			UpdatedAt: now,
		}
		if err := s.CreateInquiry(inq); err != nil {
			log.Fatalf("seed: create inquiry: %v", err)
		}
		inquiries = append(inquiries, inq)
	}

	// --- favorites: several buyers save several listings --------------------
	for i := 0; i < 15; i++ {
		b := buyers[i%len(buyers)]
		l := listings[(i*3)%len(listings)]
		if err := s.AddFavorite(&models.Favorite{UserID: b.ID, ListingID: l.ID, CreatedAt: now}); err != nil {
			log.Fatalf("seed: add favorite: %v", err)
		}
	}

	// --- reports: an open, a resolved, and a FLAGGED one (Phase B dispute
	//     group anchor: buyer + seller + support on a flagged inquiry) -------
	reports := []struct {
		inq    *models.Inquiry
		reason string
		status models.ReportStatus
	}{
		{inquiries[0], "Seller stopped responding after payment discussion.", models.ReportFlagged},
		{inquiries[3], "Item description doesn't match the photos.", models.ReportOpen},
		{inquiries[6], "Resolved after seller issued a refund.", models.ReportResolved},
	}
	for _, r := range reports {
		rep := &models.Report{
			ID:         uuid.NewString(),
			TargetType: models.ReportTargetListing,
			TargetID:   r.inq.ListingID,
			ReporterID: r.inq.BuyerID,
			Reason:     r.reason,
			Status:     r.status,
			InquiryID:  r.inq.ID,
			CreatedAt:  now,
			UpdatedAt:  now,
		}
		if err := s.CreateReport(rep); err != nil {
			log.Fatalf("seed: create report: %v", err)
		}
	}

	log.Printf("seeded demo data: 20 users (password %q), %d listings (with photos), %d inquiries, 15 favorites, %d reports",
		DemoPassword, len(listings), len(inquiries), len(reports))
}
