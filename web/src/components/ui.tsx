// Reusable presentational bits: status badges, spinners, error/empty states.

import type { ReactNode } from "react";

export function Badge({ children, tone = "neutral" }: { children: ReactNode; tone?: string }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export function Spinner({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="state" role="status">
      <div className="spinner" aria-hidden="true" />
      <p>{label}</p>
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="state state-error" role="alert">
      <p>{message}</p>
    </div>
  );
}

export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="state state-empty">{children}</div>;
}

/** Maps a listing/inquiry/report status string to a badge tone. */
export function statusTone(status: string): string {
  switch (status) {
    case "active":
    case "open":
      return "green";
    case "sold":
    case "resolved":
    case "closed":
      return "blue";
    case "removed":
    case "flagged":
    case "banned":
      return "red";
    default:
      return "neutral";
  }
}
