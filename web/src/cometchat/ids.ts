// Deterministic CometChat identifiers, mirroring the backend so both sides
// resolve the same conversation without a round-trip.
//
// - A CometChat user's UID is the app user's id (the backend syncs users 1:1
//   and mints the auth token for that same uid).
// - A dispute group's GUID is derived from the inquiry id — the backend uses
//   the identical rule in internal/cometchat.DisputeGUID.

export const disputeGuid = (inquiryId: string): string => `dispute-${inquiryId}`;
