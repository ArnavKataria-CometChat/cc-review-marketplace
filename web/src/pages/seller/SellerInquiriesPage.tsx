import { useState } from "react";

import * as api from "../../api/endpoints";
import type { Inquiry } from "../../api/types";
import { InquiryCard } from "../../components/InquiryCard";
import { ReportDialog } from "../../components/ReportDialog";
import { EmptyState, ErrorState, Spinner } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";

export function SellerInquiriesPage() {
  const { data: inquiries, loading, error, reload } = useAsync(() => api.listInquiries(), []);
  const [disputeFor, setDisputeFor] = useState<Inquiry | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const toggle = async (inq: Inquiry) => {
    setActionError(null);
    try {
      await api.patchInquiry(inq.id, inq.status === "open" ? "closed" : "open");
      reload();
    } catch (err) {
      setActionError(errMessage(err));
    }
  };

  return (
    <div className="page">
      <div className="page-head">
        <h1>Inquiries inbox</h1>
      </div>
      {actionError && <div className="form-error">{actionError}</div>}

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && inquiries && inquiries.length === 0 && (
        <EmptyState>No buyer inquiries yet.</EmptyState>
      )}
      {!loading && !error && inquiries && (
        <div className="stack">
          {inquiries.map((inq) => (
            <InquiryCard
              key={inq.id}
              inquiry={inq}
              perspective="seller"
              actions={
                <>
                  <button className="btn btn-ghost btn-sm" onClick={() => toggle(inq)}>
                    {inq.status === "open" ? "Close" : "Reopen"}
                  </button>
                  <button className="btn btn-link btn-sm" onClick={() => setDisputeFor(inq)}>
                    Report
                  </button>
                </>
              }
            />
          ))}
        </div>
      )}

      {disputeFor && (
        <ReportDialog
          targetType="listing"
          targetId={disputeFor.listingId}
          inquiryId={disputeFor.id}
          onClose={() => setDisputeFor(null)}
          onSubmitted={() => {
            setDisputeFor(null);
            reload();
          }}
        />
      )}
    </div>
  );
}
