import * as api from "../../api/endpoints";
import { ListingCard } from "../../components/ListingCard";
import { EmptyState, ErrorState, Spinner } from "../../components/ui";
import { useAsync } from "../../components/useAsync";

export function FavoritesPage() {
  const { data: favorites, loading, error } = useAsync(() => api.listFavorites(), []);

  const withListing = (favorites ?? []).filter((f) => f.listing);

  return (
    <div className="page">
      <div className="page-head">
        <h1>Favorites</h1>
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && withListing.length === 0 && (
        <EmptyState>No saved listings yet. Tap “Save to favorites” on any listing.</EmptyState>
      )}
      {!loading && !error && withListing.length > 0 && (
        <div className="grid">
          {withListing.map((f) => (
            <ListingCard key={f.listingId} listing={f.listing!} />
          ))}
        </div>
      )}
    </div>
  );
}
