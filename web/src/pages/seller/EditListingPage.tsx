import { Link, useNavigate, useParams } from "react-router-dom";

import * as api from "../../api/endpoints";
import { ListingForm } from "../../components/ListingForm";
import { ErrorState, Spinner } from "../../components/ui";
import { useAsync } from "../../components/useAsync";

export function EditListingPage() {
  const { id = "" } = useParams();
  const navigate = useNavigate();
  const { data: listing, loading, error } = useAsync(() => api.getListing(id), [id]);

  if (loading) return <Spinner />;
  if (error) return <ErrorState message={error} />;
  if (!listing) return <ErrorState message="Listing not found." />;

  return (
    <div className="page narrow">
      <Link to="/seller/listings" className="back-link">
        ← My listings
      </Link>
      <div className="page-head">
        <h1>Edit listing</h1>
      </div>
      <ListingForm
        initial={listing}
        submitLabel="Save changes"
        onSubmit={async (value) => {
          await api.patchListing(listing.id, value);
          navigate(`/listings/${listing.id}`);
        }}
      />
    </div>
  );
}
