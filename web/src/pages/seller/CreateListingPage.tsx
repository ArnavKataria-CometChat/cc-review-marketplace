import { Link, useNavigate } from "react-router-dom";

import * as api from "../../api/endpoints";
import { ListingForm } from "../../components/ListingForm";

export function CreateListingPage() {
  const navigate = useNavigate();

  return (
    <div className="page narrow">
      <Link to="/seller/listings" className="back-link">
        ← My listings
      </Link>
      <div className="page-head">
        <h1>New listing</h1>
      </div>
      <ListingForm
        submitLabel="Publish listing"
        onSubmit={async (value) => {
          const created = await api.createListing(value);
          navigate(`/listings/${created.id}`);
        }}
      />
    </div>
  );
}
