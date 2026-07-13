// Renders a single inquiry thread with its listing context. Because the
// inquiries endpoint returns only ids, each card resolves its own listing.
// `perspective` tweaks the labels for buyer vs seller inboxes.

import { Link } from "react-router-dom";

import * as api from "../api/endpoints";
import type { Inquiry } from "../api/types";
import { Badge, statusTone } from "./ui";
import { useAsync } from "./useAsync";
import { formatDate, formatMoney } from "./util";

export function InquiryCard({
  inquiry,
  perspective,
  actions,
  highlight,
}: {
  inquiry: Inquiry;
  perspective: "buyer" | "seller" | "support";
  actions?: React.ReactNode;
  highlight?: boolean;
}) {
  const { data: listing, loading, error } = useAsync(() => api.getListing(inquiry.listingId), [inquiry.listingId]);

  return (
    <div className={`card inquiry-card${highlight ? " highlight" : ""}`}>
      <div className="inquiry-head">
        <div>
          {loading && <span className="muted">Loading listing…</span>}
          {error && <span className="muted">Listing unavailable</span>}
          {listing && (
            <Link to={`/listings/${listing.id}`} className="inquiry-listing-title">
              {listing.title}
            </Link>
          )}
        </div>
        <div className="inquiry-badges">
          {inquiry.flagged && <Badge tone="red">disputed</Badge>}
          <Badge tone={statusTone(inquiry.status)}>{inquiry.status}</Badge>
          {listing && <span className="price">{formatMoney(listing.priceCents)}</span>}
        </div>
      </div>

      <p className="inquiry-message">“{inquiry.message}”</p>

      <div className="inquiry-meta muted">
        <span>
          {perspective === "seller" ? "From buyer" : perspective === "support" ? "Buyer↔Seller thread" : "You asked"} ·{" "}
          {formatDate(inquiry.createdAt)}
        </span>
        {actions && <span className="inquiry-actions">{actions}</span>}
      </div>
    </div>
  );
}
