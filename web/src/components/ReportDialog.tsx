// Modal for filing a report/dispute. Used from the listing detail page and the
// buyer/seller inquiry views. When an inquiryId is supplied the report links to
// that thread, giving support the buyer/seller context (and, in Phase B,
// escalating the thread to a dispute group when flagged).

import { useState } from "react";

import * as api from "../api/endpoints";
import type { ReportTargetType } from "../api/types";
import { errMessage } from "./useAsync";

export function ReportDialog({
  targetType,
  targetId,
  inquiryId,
  onClose,
  onSubmitted,
}: {
  targetType: ReportTargetType;
  targetId: string;
  inquiryId?: string;
  onClose: () => void;
  onSubmitted: () => void;
}) {
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await api.createReport({ targetType, targetId, reason: reason.trim(), inquiryId });
      onSubmitted();
    } catch (err) {
      setError(errMessage(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal card" onClick={(e) => e.stopPropagation()}>
        <h2>Report {targetType}</h2>
        <form onSubmit={submit}>
          {error && <div className="form-error">{error}</div>}
          <label>
            Reason
            <textarea
              rows={4}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Describe the problem…"
              required
            />
          </label>
          <div className="row-actions">
            <button className="btn btn-primary" type="submit" disabled={submitting}>
              {submitting ? "Submitting…" : "Submit report"}
            </button>
            <button className="btn btn-ghost" type="button" onClick={onClose}>
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
