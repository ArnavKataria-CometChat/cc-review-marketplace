import { useState } from "react";
import { Link } from "react-router-dom";

import * as api from "../../api/endpoints";
import type { ReportStatus } from "../../api/types";
import { Badge, EmptyState, ErrorState, Spinner, statusTone } from "../../components/ui";
import { useAsync } from "../../components/useAsync";
import { formatDate } from "../../components/util";

const FILTERS: { label: string; value: ReportStatus | "" }[] = [
  { label: "All", value: "" },
  { label: "Open", value: "open" },
  { label: "Flagged", value: "flagged" },
  { label: "Resolved", value: "resolved" },
];

export function DisputeQueuePage() {
  const [status, setStatus] = useState<ReportStatus | "">("");
  const { data: reports, loading, error } = useAsync(
    () => api.listReports(status || undefined),
    [status],
  );

  return (
    <div className="page">
      <div className="page-head">
        <h1>Dispute queue</h1>
      </div>

      <div className="tabs">
        {FILTERS.map((f) => (
          <button
            key={f.value}
            className={`tab${status === f.value ? " active" : ""}`}
            onClick={() => setStatus(f.value)}
          >
            {f.label}
          </button>
        ))}
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && reports && reports.length === 0 && (
        <EmptyState>No reports in this queue.</EmptyState>
      )}
      {!loading && !error && reports && reports.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Target</th>
              <th>Reason</th>
              <th>Thread</th>
              <th>Status</th>
              <th>Filed</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {reports.map((r) => (
              <tr key={r.id}>
                <td>
                  <Badge tone="neutral">{r.targetType}</Badge>
                </td>
                <td className="truncate">{r.reason}</td>
                <td>{r.inquiryId ? "linked" : "—"}</td>
                <td>
                  <Badge tone={statusTone(r.status)}>{r.status}</Badge>
                </td>
                <td className="muted">{formatDate(r.createdAt)}</td>
                <td>
                  <Link className="btn btn-ghost btn-sm" to={`/support/reports/${r.id}`}>
                    Review
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
