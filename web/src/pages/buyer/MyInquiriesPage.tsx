import { useState } from "react";
import { useLocation } from "react-router-dom";

import * as api from "../../api/endpoints";
import type { Inquiry } from "../../api/types";
import { InquiryCard } from "../../components/InquiryCard";
import { ReportDialog } from "../../components/ReportDialog";
import { EmptyState, ErrorState, Spinner } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";

export function MyInquiriesPage() {
  const location = useLocation();
  const highlightId = (location.state as { highlight?: string } | null)?.highlight;

  const { data: inquiries, loading, error, reload } = useAsync(() => api.listInquiries(), []);
  const [disputeFor, setDisputeFor] = useState<Inquiry | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const closeThread = async (inq: Inquiry) => {
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
        <h1>My inquiries</h1>
      </div>
      {actionError && <div className="form-error">{actionError}</div>}

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && inquiries && inquiries.length === 0 && (
        <EmptyState>You haven't contacted any sellers yet. Browse a listing and hit “Contact seller”.</EmptyState>
      )}
      {!loading && !error && inquiries && (
        <div className="stack">
          {inquiries.map((inq) => (
            <InquiryCard
              key={inq.id}
              inquiry={inq}
              perspective="buyer"
              highlight={inq.id === highlightId}
              actions={
                <>
                  <button className="btn btn-ghost btn-sm" onClick={() => closeThread(inq)}>
                    {inq.status === "open" ? "Close" : "Reopen"}
                  </button>
                  <button className="btn btn-link btn-sm" onClick={() => setDisputeFor(inq)}>
                    Open dispute
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
