import { Link } from "react-router-dom";

export function ForbiddenPage() {
  return (
    <div className="page narrow center-state">
      <h1>403 — Not allowed</h1>
      <p className="muted">Your role doesn't have access to that screen.</p>
      <Link to="/" className="btn btn-primary">
        Back to browse
      </Link>
    </div>
  );
}
