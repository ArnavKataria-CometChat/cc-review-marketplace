package store

import (
	"sort"
	"strings"
	"sync"

	"github.com/cometchat/marketplace-backend/internal/models"
)

// Memory is a thread-safe in-memory Store. It is intentionally simple: the goal
// of Phase A is a working, buildable baseline, not durable persistence.
type Memory struct {
	mu        sync.RWMutex
	users     map[string]*models.User
	listings  map[string]*models.Listing
	inquiries map[string]*models.Inquiry
	favorites map[string]*models.Favorite // key: userID + "|" + listingID
	reports   map[string]*models.Report
	audit     []*models.AuditEntry
}

// NewMemory returns an empty in-memory store.
func NewMemory() *Memory {
	return &Memory{
		users:     make(map[string]*models.User),
		listings:  make(map[string]*models.Listing),
		inquiries: make(map[string]*models.Inquiry),
		favorites: make(map[string]*models.Favorite),
		reports:   make(map[string]*models.Report),
	}
}

func favKey(userID, listingID string) string { return userID + "|" + listingID }

// ---- Users ----

func (m *Memory) CreateUser(u *models.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, existing := range m.users {
		if strings.EqualFold(existing.Email, u.Email) {
			return ErrConflict
		}
	}
	m.users[u.ID] = u
	return nil
}

func (m *Memory) GetUser(id string) (*models.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	u, ok := m.users[id]
	if !ok {
		return nil, ErrNotFound
	}
	return u, nil
}

func (m *Memory) GetUserByEmail(email string) (*models.User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, u := range m.users {
		if strings.EqualFold(u.Email, email) {
			return u, nil
		}
	}
	return nil, ErrNotFound
}

func (m *Memory) ListUsers() []*models.User {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.User, 0, len(m.users))
	for _, u := range m.users {
		out = append(out, u)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out
}

func (m *Memory) UpdateUser(u *models.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.users[u.ID]; !ok {
		return ErrNotFound
	}
	m.users[u.ID] = u
	return nil
}

// ---- Listings ----

func (m *Memory) CreateListing(l *models.Listing) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.listings[l.ID] = l
	return nil
}

func (m *Memory) GetListing(id string) (*models.Listing, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	l, ok := m.listings[id]
	if !ok {
		return nil, ErrNotFound
	}
	return l, nil
}

func (m *Memory) ListListings(f ListingFilter) []*models.Listing {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.Listing, 0)
	search := strings.ToLower(strings.TrimSpace(f.Search))
	for _, l := range m.listings {
		if !f.IncludeHidden && l.Status != models.ListingActive {
			continue
		}
		if f.SellerID != "" && l.SellerID != f.SellerID {
			continue
		}
		if f.Category != "" && !strings.EqualFold(l.Category, f.Category) {
			continue
		}
		if f.MinPriceCents > 0 && l.PriceCents < f.MinPriceCents {
			continue
		}
		if f.MaxPriceCents > 0 && l.PriceCents > f.MaxPriceCents {
			continue
		}
		if search != "" {
			hay := strings.ToLower(l.Title + " " + l.Description)
			if !strings.Contains(hay, search) {
				continue
			}
		}
		out = append(out, l)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}

func (m *Memory) UpdateListing(l *models.Listing) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.listings[l.ID]; !ok {
		return ErrNotFound
	}
	m.listings[l.ID] = l
	return nil
}

// ---- Inquiries ----

func (m *Memory) CreateInquiry(i *models.Inquiry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.inquiries[i.ID] = i
	return nil
}

func (m *Memory) GetInquiry(id string) (*models.Inquiry, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	i, ok := m.inquiries[id]
	if !ok {
		return nil, ErrNotFound
	}
	return i, nil
}

func (m *Memory) FindInquiry(listingID, buyerID string) (*models.Inquiry, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, i := range m.inquiries {
		if i.ListingID == listingID && i.BuyerID == buyerID {
			return i, nil
		}
	}
	return nil, ErrNotFound
}

func (m *Memory) ListInquiries(f InquiryFilter) []*models.Inquiry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.Inquiry, 0)
	for _, i := range m.inquiries {
		if f.BuyerID != "" && i.BuyerID != f.BuyerID {
			continue
		}
		if f.SellerID != "" && i.SellerID != f.SellerID {
			continue
		}
		if f.FlaggedOnly && !i.Flagged {
			continue
		}
		out = append(out, i)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}

func (m *Memory) UpdateInquiry(i *models.Inquiry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.inquiries[i.ID]; !ok {
		return ErrNotFound
	}
	m.inquiries[i.ID] = i
	return nil
}

// ---- Favorites ----

func (m *Memory) AddFavorite(fav *models.Favorite) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := favKey(fav.UserID, fav.ListingID)
	if _, ok := m.favorites[key]; ok {
		return ErrConflict
	}
	m.favorites[key] = fav
	return nil
}

func (m *Memory) RemoveFavorite(userID, listingID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := favKey(userID, listingID)
	if _, ok := m.favorites[key]; !ok {
		return ErrNotFound
	}
	delete(m.favorites, key)
	return nil
}

func (m *Memory) ListFavorites(userID string) []*models.Favorite {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.Favorite, 0)
	for _, fav := range m.favorites {
		if fav.UserID == userID {
			out = append(out, fav)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}

// ---- Reports ----

func (m *Memory) CreateReport(r *models.Report) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.reports[r.ID] = r
	return nil
}

func (m *Memory) GetReport(id string) (*models.Report, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	r, ok := m.reports[id]
	if !ok {
		return nil, ErrNotFound
	}
	return r, nil
}

func (m *Memory) ListReports(f ReportFilter) []*models.Report {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.Report, 0)
	for _, r := range m.reports {
		if f.Status != "" && r.Status != f.Status {
			continue
		}
		out = append(out, r)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}

func (m *Memory) UpdateReport(r *models.Report) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.reports[r.ID]; !ok {
		return ErrNotFound
	}
	m.reports[r.ID] = r
	return nil
}

// ---- Audit ----

func (m *Memory) AddAudit(e *models.AuditEntry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.audit = append(m.audit, e)
	return nil
}

func (m *Memory) ListAudit() []*models.AuditEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*models.AuditEntry, len(m.audit))
	copy(out, m.audit)
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}
