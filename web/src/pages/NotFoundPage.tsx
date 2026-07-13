import { Link } from "react-router-dom";

export function NotFoundPage() {
  return (
    <div className="page narrow center-state">
      <h1>404 — Not found</h1>
      <p className="muted">That page doesn't exist.</p>
      <Link to="/" className="btn btn-primary">
        Back to browse
      </Link>
    </div>
  );
}
