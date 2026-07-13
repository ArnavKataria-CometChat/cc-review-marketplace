import { useMemo, useState } from "react";

import * as api from "../api/endpoints";
import type { ListingQuery } from "../api/endpoints";
import { ListingCard } from "../components/ListingCard";
import { EmptyState, ErrorState, Spinner } from "../components/ui";
import { useAsync } from "../components/useAsync";

// A curated category list keeps the filter UI simple; the backend accepts any
// free-text category so this is just a convenience.
const CATEGORIES = ["electronics", "furniture", "sports", "clothing", "books", "other"];

export function BrowsePage() {
  // `query` is the committed filter that actually drives the fetch; the inputs
  // below stage changes until the user submits.
  const [query, setQuery] = useState<ListingQuery>({});
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("");
  const [minPrice, setMinPrice] = useState("");
  const [maxPrice, setMaxPrice] = useState("");

  const { data: listings, loading, error } = useAsync(() => api.listListings(query), [query]);

  const activeCount = useMemo(() => (listings ? listings.length : 0), [listings]);

  const applyFilters = (e: React.FormEvent) => {
    e.preventDefault();
    setQuery({
      search: search.trim() || undefined,
      category: category || undefined,
      minPrice: minPrice ? Math.round(Number(minPrice) * 100) : undefined,
      maxPrice: maxPrice ? Math.round(Number(maxPrice) * 100) : undefined,
    });
  };

  const clear = () => {
    setSearch("");
    setCategory("");
    setMinPrice("");
    setMaxPrice("");
    setQuery({});
  };

  return (
    <div className="page">
      <div className="page-head">
        <h1>Browse listings</h1>
      </div>

      <form className="filters card" onSubmit={applyFilters}>
        <input
          className="filter-search"
          placeholder="Search listings…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="">All categories</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <input
          className="filter-price"
          type="number"
          min="0"
          placeholder="Min $"
          value={minPrice}
          onChange={(e) => setMinPrice(e.target.value)}
        />
        <input
          className="filter-price"
          type="number"
          min="0"
          placeholder="Max $"
          value={maxPrice}
          onChange={(e) => setMaxPrice(e.target.value)}
        />
        <button className="btn btn-primary" type="submit">
          Apply
        </button>
        <button className="btn btn-ghost" type="button" onClick={clear}>
          Clear
        </button>
      </form>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && listings && listings.length === 0 && (
        <EmptyState>No listings match your filters.</EmptyState>
      )}
      {!loading && !error && listings && listings.length > 0 && (
        <>
          <p className="muted result-count">{activeCount} listing(s)</p>
          <div className="grid">
            {listings.map((l) => (
              <ListingCard key={l.id} listing={l} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
