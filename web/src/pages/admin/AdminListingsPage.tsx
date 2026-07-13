import { Link } from "react-router-dom";

import * as api from "../../api/endpoints";
import type { Listing } from "../../api/types";
import { Badge, EmptyState, ErrorState, Spinner, statusTone } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";
import { formatMoney } from "../../components/util";

export function AdminListingsPage() {
  // The baseline browse endpoint returns active listings; admin moderation acts
  // on those (removing sets status -> removed, which drops them from the feed).
  const { data: listings, loading, error, reload } = useAsync(() => api.listListings(), []);

  const remove = async (l: Listing) => {
    if (!confirm(`Remove "${l.title}"? This takes it down for everyone.`)) return;
    try {
      await api.adminRemoveListing(l.id);
      reload();
    } catch (err) {
      alert(errMessage(err));
    }
  };

  return (
    <div className="page">
      <div className="page-head">
        <h1>Listing moderation</h1>
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && listings && listings.length === 0 && <EmptyState>No active listings.</EmptyState>}
      {!loading && !error && listings && listings.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Seller</th>
              <th>Price</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {listings.map((l) => (
              <tr key={l.id}>
                <td>
                  <Link to={`/listings/${l.id}`}>{l.title}</Link>
                </td>
                <td className="muted">
                  <code>{l.sellerId.slice(0, 8)}</code>
                </td>
                <td>{formatMoney(l.priceCents)}</td>
                <td>
                  <Badge tone={statusTone(l.status)}>{l.status}</Badge>
                </td>
                <td className="row-actions">
                  <button className="btn btn-danger btn-sm" onClick={() => remove(l)}>
                    Remove
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
