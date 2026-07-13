// Compact listing tile used on the browse grid and favorites page.

import { Link } from "react-router-dom";

import type { Listing } from "../api/types";
import { Badge, statusTone } from "./ui";
import { formatMoney } from "./util";

export function ListingCard({ listing }: { listing: Listing }) {
  const cover = listing.photos[0];
  return (
    <Link to={`/listings/${listing.id}`} className="card listing-card">
      <div className="listing-thumb">
        {cover ? (
          <img src={cover} alt={listing.title} loading="lazy" />
        ) : (
          <div className="listing-thumb-placeholder">No photo</div>
        )}
      </div>
      <div className="listing-card-body">
        <div className="listing-card-head">
          <span className="price">{formatMoney(listing.priceCents)}</span>
          {listing.status !== "active" && <Badge tone={statusTone(listing.status)}>{listing.status}</Badge>}
        </div>
        <h3 className="listing-title">{listing.title}</h3>
        <span className="category-chip">{listing.category}</span>
      </div>
    </Link>
  );
}
