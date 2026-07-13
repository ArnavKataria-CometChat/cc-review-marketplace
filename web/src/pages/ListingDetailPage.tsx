import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";

import * as api from "../api/endpoints";
import { useAuth } from "../auth/AuthContext";
import { Badge, ErrorState, Spinner, statusTone } from "../components/ui";
import { errMessage, useAsync } from "../components/useAsync";
import { formatMoney } from "../components/util";
import { ReportDialog } from "../components/ReportDialog";

export function ListingDetailPage() {
  const { id = "" } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();

  const { data: listing, loading, error } = useAsync(() => api.getListing(id), [id]);

  // Buyers see whether they've already favorited this listing.
  const { data: favorites, reload: reloadFavorites } = useAsync(
    () => (user?.role === "buyer" ? api.listFavorites() : Promise.resolve([])),
    [user?.role, id],
  );

  const [contactMessage, setContactMessage] = useState("");
  const [contacting, setContacting] = useState(false);
  const [showContact, setShowContact] = useState(false);
  const [showReport, setShowReport] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  if (loading) return <Spinner />;
  if (error) return <ErrorState message={error} />;
  if (!listing) return <ErrorState message="Listing not found." />;

  const isOwner = user?.id === listing.sellerId;
  const isBuyer = user?.role === "buyer";
  const isAdmin = user?.role === "admin";
  const isFavorited = !!favorites?.some((f) => f.listingId === listing.id);
  const canInquire = isBuyer && !isOwner && listing.status === "active";

  const submitInquiry = async (e: React.FormEvent) => {
    e.preventDefault();
    setActionError(null);
    setContacting(true);
    try {
      const inq = await api.createInquiry(listing.id, contactMessage.trim());
      // Land the buyer on their inquiries list where the new thread appears.
      navigate("/inquiries", { state: { highlight: inq.id } });
    } catch (err) {
      setActionError(errMessage(err));
    } finally {
      setContacting(false);
    }
  };

  const toggleFavorite = async () => {
    setActionError(null);
    try {
      if (isFavorited) await api.removeFavorite(listing.id);
      else await api.addFavorite(listing.id);
      reloadFavorites();
    } catch (err) {
      setActionError(errMessage(err));
    }
  };

  return (
    <div className="page detail-page">
      <Link to="/" className="back-link">
        ← Back to browse
      </Link>

      <div className="detail-grid">
        <div className="detail-gallery card">
          {listing.photos.length > 0 ? (
            listing.photos.map((p, i) => <img key={i} src={p} alt={`${listing.title} ${i + 1}`} />)
          ) : (
            <div className="listing-thumb-placeholder large">No photos</div>
          )}
        </div>

        <aside className="detail-side">
          <div className="card">
            <div className="detail-head">
              <span className="price price-lg">{formatMoney(listing.priceCents)}</span>
              <Badge tone={statusTone(listing.status)}>{listing.status}</Badge>
            </div>
            <h1 className="detail-title">{listing.title}</h1>
            <span className="category-chip">{listing.category}</span>
            <p className="detail-desc">{listing.description || "No description provided."}</p>

            {notice && <div className="form-success">{notice}</div>}
            {actionError && <div className="form-error">{actionError}</div>}

            <div className="detail-actions">
              {canInquire && !showContact && (
                <button className="btn btn-primary btn-block" onClick={() => setShowContact(true)}>
                  Contact seller
                </button>
              )}
              {isBuyer && (
                <button className="btn btn-ghost btn-block" onClick={toggleFavorite}>
                  {isFavorited ? "★ Saved" : "☆ Save to favorites"}
                </button>
              )}
              {isOwner && (
                <>
                  <Link className="btn btn-ghost btn-block" to={`/seller/listings/${listing.id}/edit`}>
                    Edit listing
                  </Link>
                  {listing.status === "active" && (
                    <button
                      className="btn btn-ghost btn-block"
                      onClick={async () => {
                        try {
                          await api.patchListing(listing.id, { status: "sold" });
                          setNotice("Marked as sold.");
                        } catch (err) {
                          setActionError(errMessage(err));
                        }
                      }}
                    >
                      Mark as sold
                    </button>
                  )}
                </>
              )}
              {isAdmin && (
                <button
                  className="btn btn-danger btn-block"
                  onClick={async () => {
                    try {
                      await api.adminRemoveListing(listing.id);
                      setNotice("Listing removed.");
                    } catch (err) {
                      setActionError(errMessage(err));
                    }
                  }}
                >
                  Remove listing (admin)
                </button>
              )}
              {user && (
                <button className="btn btn-link" onClick={() => setShowReport(true)}>
                  Report this listing
                </button>
              )}
              {!user && (
                <p className="muted">
                  <Link to="/login">Log in</Link> to contact the seller or save this listing.
                </p>
              )}
            </div>

            {showContact && canInquire && (
              <form className="contact-form" onSubmit={submitInquiry}>
                <label>
                  Message to seller
                  <textarea
                    rows={4}
                    value={contactMessage}
                    onChange={(e) => setContactMessage(e.target.value)}
                    placeholder="Hi! Is this still available?"
                    required
                  />
                </label>
                <div className="row-actions">
                  <button className="btn btn-primary" type="submit" disabled={contacting}>
                    {contacting ? "Sending…" : "Send inquiry"}
                  </button>
                  <button className="btn btn-ghost" type="button" onClick={() => setShowContact(false)}>
                    Cancel
                  </button>
                </div>
              </form>
            )}
          </div>
        </aside>
      </div>

      {showReport && (
        <ReportDialog
          targetType="listing"
          targetId={listing.id}
          onClose={() => setShowReport(false)}
          onSubmitted={() => {
            setShowReport(false);
            setNotice("Report submitted. Support will review it.");
          }}
        />
      )}
    </div>
  );
}
