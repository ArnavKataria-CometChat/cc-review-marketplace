// Shared create/edit form for listings. Prices are entered in dollars and
// converted to the integer cents the backend stores; photos are entered as a
// comma/newline separated list of URLs.

import { useState } from "react";

import type { Listing } from "../api/types";
import { parsePhotos } from "./util";

export interface ListingFormValue {
  title: string;
  description: string;
  priceCents: number;
  category: string;
  photos: string[];
}

const CATEGORIES = ["electronics", "furniture", "sports", "clothing", "books", "other"];

export function ListingForm({
  initial,
  submitLabel,
  onSubmit,
}: {
  initial?: Listing;
  submitLabel: string;
  onSubmit: (value: ListingFormValue) => Promise<void>;
}) {
  const [title, setTitle] = useState(initial?.title ?? "");
  const [description, setDescription] = useState(initial?.description ?? "");
  const [price, setPrice] = useState(initial ? (initial.priceCents / 100).toString() : "");
  const [category, setCategory] = useState(initial?.category ?? "electronics");
  const [photosRaw, setPhotosRaw] = useState((initial?.photos ?? []).join("\n"));
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const priceCents = Math.round(Number(price) * 100);
    if (!title.trim() || !category.trim()) {
      setError("Title and category are required.");
      return;
    }
    if (!Number.isFinite(priceCents) || priceCents <= 0) {
      setError("Price must be greater than zero.");
      return;
    }
    setSubmitting(true);
    try {
      await onSubmit({
        title: title.trim(),
        description: description.trim(),
        priceCents,
        category: category.trim(),
        photos: parsePhotos(photosRaw),
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save listing");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form className="card form" onSubmit={submit}>
      {error && <div className="form-error">{error}</div>}
      <label>
        Title
        <input value={title} onChange={(e) => setTitle(e.target.value)} required />
      </label>
      <label>
        Description
        <textarea rows={4} value={description} onChange={(e) => setDescription(e.target.value)} />
      </label>
      <div className="form-row">
        <label>
          Price (USD)
          <input type="number" min="0" step="0.01" value={price} onChange={(e) => setPrice(e.target.value)} required />
        </label>
        <label>
          Category
          <select value={category} onChange={(e) => setCategory(e.target.value)}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label>
        Photo URLs
        <textarea
          rows={3}
          value={photosRaw}
          onChange={(e) => setPhotosRaw(e.target.value)}
          placeholder="One URL per line (or comma separated)"
        />
        <span className="hint">Optional. Paste image URLs, one per line.</span>
      </label>
      <button className="btn btn-primary" type="submit" disabled={submitting}>
        {submitting ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}
