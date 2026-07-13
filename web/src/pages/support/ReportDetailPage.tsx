import { Link, useParams } from "react-router-dom";

import * as api from "../../api/endpoints";
import type { ReportStatus } from "../../api/types";
import { Badge, ErrorState, Spinner, statusTone } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";
import { formatDate, formatMoney } from "../../components/util";

// The transitions support/admin can drive a report through. Flagging a
// thread-linked report escalates the inquiry to a dispute; resolving closes it.
const TRANSITIONS: { label: string; value: ReportStatus; tone: string }[] = [
  { label: "Flag as dispute", value: "flagged", tone: "btn-danger" },
  { label: "Mark resolved", value: "resolved", tone: "btn-primary" },
  { label: "Reopen", value: "open", tone: "btn-ghost" },
];

export function ReportDetailPage() {
  const { id = "" } = useParams();
  const { data, loading, error, reload } = useAsync(() => api.getReport(id), [id]);

  if (loading) return <Spinner />;
  if (error) return <ErrorState message={error} />;
  if (!data) return <ErrorState message="Report not found." />;

  const { report, reporter, listing, inquiry, buyer, seller } = data;

  const setStatus = async (status: ReportStatus) => {
    try {
      await api.patchReport(report.id, status);
      reload();
    } catch (err) {
      alert(errMessage(err));
    }
  };

  return (
    <div className="page narrow">
      <Link to="/support/disputes" className="back-link">
        ← Dispute queue
      </Link>

      <div className="page-head">
        <h1>Report</h1>
        <Badge tone={statusTone(report.status)}>{report.status}</Badge>
      </div>

      <section className="card detail-block">
        <h2>Report</h2>
        <dl className="kv">
          <dt>Target</dt>
          <dd>
            <Badge tone="neutral">{report.targetType}</Badge> <code>{report.targetId}</code>
          </dd>
          <dt>Reason</dt>
          <dd>{report.reason}</dd>
          <dt>Reporter</dt>
          <dd>{reporter ? `${reporter.name} (${reporter.email})` : report.reporterId}</dd>
          <dt>Filed</dt>
          <dd>{formatDate(report.createdAt)}</dd>
        </dl>
      </section>

      {listing && (
        <section className="card detail-block">
          <h2>Disputed listing</h2>
          <p>
            <Link to={`/listings/${listing.id}`}>{listing.title}</Link> — {formatMoney(listing.priceCents)}{" "}
            <Badge tone={statusTone(listing.status)}>{listing.status}</Badge>
          </p>
          <p className="muted">{listing.description}</p>
        </section>
      )}

      {inquiry && (
        <section className="card detail-block">
          <h2>Thread context</h2>
          <p className="inquiry-message">“{inquiry.message}”</p>
          <dl className="kv">
            <dt>Buyer</dt>
            <dd>{buyer ? `${buyer.name} (${buyer.email})` : inquiry.buyerId}</dd>
            <dt>Seller</dt>
            <dd>{seller ? `${seller.name} (${seller.email})` : inquiry.sellerId}</dd>
            <dt>Thread status</dt>
            <dd>
              <Badge tone={statusTone(inquiry.status)}>{inquiry.status}</Badge>{" "}
              {inquiry.flagged && <Badge tone="red">flagged</Badge>}
            </dd>
          </dl>
          <p className="muted small">
            Phase B: a flagged thread becomes a buyer + seller + support group chat here.
          </p>
        </section>
      )}

      <section className="card detail-block">
        <h2>Actions</h2>
        <div className="row-actions">
          {TRANSITIONS.filter((t) => t.value !== report.status).map((t) => (
            <button key={t.value} className={`btn ${t.tone}`} onClick={() => setStatus(t.value)}>
              {t.label}
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}
