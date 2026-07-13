import * as api from "../../api/endpoints";
import { Badge, EmptyState, ErrorState, Spinner } from "../../components/ui";
import { useAsync } from "../../components/useAsync";
import { formatDate } from "../../components/util";

export function AdminAuditPage() {
  const { data: audit, loading, error } = useAsync(() => api.adminAudit(), []);

  return (
    <div className="page">
      <div className="page-head">
        <h1>Audit log</h1>
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && audit && audit.length === 0 && (
        <EmptyState>No privileged actions recorded yet.</EmptyState>
      )}
      {!loading && !error && audit && audit.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Actor</th>
              <th>Action</th>
              <th>Target</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            {audit.map((e) => (
              <tr key={e.id}>
                <td className="muted">{formatDate(e.createdAt)}</td>
                <td>
                  <Badge tone="blue">{e.actorRole}</Badge> <code>{e.actorId.slice(0, 8)}</code>
                </td>
                <td>
                  <code>{e.action}</code>
                </td>
                <td className="muted">
                  <code>{e.target.slice(0, 8)}</code>
                </td>
                <td>{e.details}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
