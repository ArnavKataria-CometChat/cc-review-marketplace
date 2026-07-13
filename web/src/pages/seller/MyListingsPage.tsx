import { Link } from "react-router-dom";

import * as api from "../../api/endpoints";
import { useAuth } from "../../auth/AuthContext";
import type { Listing } from "../../api/types";
import { Badge, EmptyState, ErrorState, Spinner, statusTone } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";
import { formatMoney } from "../../components/util";

export function MyListingsPage() {
  const { user } = useAuth();
  // The baseline browse endpoint returns only *active* listings and has no
  // seller filter, so we scope to the current seller client-side. Sold/removed
  // listings drop off this active feed (reachable by direct link).
  const { data: listings, loading, error, reload } = useAsync(() => api.listListings(), []);
  const mine = (listings ?? []).filter((l) => l.sellerId === user?.id);

  const markSold = async (l: Listing) => {
    try {
      await api.patchListing(l.id, { status: "sold" });
      reload();
    } catch (err) {
      alert(errMessage(err));
    }
  };

  return (
    <div className="page">
      <div className="page-head">
        <h1>My listings</h1>
        <Link to="/seller/listings/new" className="btn btn-primary">
          + New listing
        </Link>
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && mine.length === 0 && (
        <EmptyState>No active listings. Create one to start selling.</EmptyState>
      )}
      {!loading && !error && mine.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Category</th>
              <th>Price</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {mine.map((l) => (
              <tr key={l.id}>
                <td>
                  <Link to={`/listings/${l.id}`}>{l.title}</Link>
                </td>
                <td>{l.category}</td>
                <td>{formatMoney(l.priceCents)}</td>
                <td>
                  <Badge tone={statusTone(l.status)}>{l.status}</Badge>
                </td>
                <td className="row-actions">
                  <Link className="btn btn-ghost btn-sm" to={`/seller/listings/${l.id}/edit`}>
                    Edit
                  </Link>
                  {l.status === "active" && (
                    <button className="btn btn-ghost btn-sm" onClick={() => markSold(l)}>
                      Mark sold
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
