# Changelog

This changelog starts on 2026-08-18. Earlier changes weren't tracked in this
repo, so the first entry below is a catch-up covering everything since the
previous public update. Per-release entries begin from here.

## 2026-08-18

### Security — self-hosters should upgrade

- `socialLoginAndGetProfile` is now gated on the verifier principal. Previously
  it could be called directly on the canister, bypassing OAuth token
  verification entirely. If you run your own instance, upgrade to this version
  and set `VERIFIER_PRINCIPAL` to your own verifier's signing principal (see
  README). Until you do, treat OAuth-based sessions on older deployments as
  untrusted.
- The verifier principal is now single-sourced (`VERIFIER_PRINCIPAL`) and
  force-reassigned in `postupgrade()`. This matters because the actor is
  `persistent`: top-level variables are implicitly stable and survive upgrades,
  so editing a literal alone does not change the running value. The same
  applies to `CONTROLLER` — set it before your first deploy.

### Added

- Moderation endpoints for game owners: view a board in admin mode, delete a
  single score entry, or wipe a player's scores across all of a game's boards
  (optionally including archives). Available in both session-auth and
  principal-auth variants.
- Deletion audit log (`getEntryDeletionLog`): capped, stable record of every
  moderation action. Player identifiers are stored as hashes, never raw
  emails or principals.
- Submission stats: `getSubmissionStats` and `getSystemInfo` now expose the
  running submission total; `getSystemInfo` game count now reflects active
  games only.

### Fixed

- Nickname validation unified to a single rule (3–16 characters, restricted
  charset) across registration and score-submission paths. Previously
  different entry points enforced different lengths. Existing out-of-range
  nicknames are grandfathered; the rule is enforced on write only.
- Deleted games no longer linger: soft-deleted games are now filtered from
  all owner-facing game lists, and expired soft-deletes are actually purged
  (cleanup previously never ran and left records behind, inflating counts).
- Score wipes reset the player's per-game profile (score, streak, play count)
  while leaving achievements intact, and touched boards bust their caches so
  clients see the change promptly.

### Changed

- Moderation read endpoints are query calls (faster, no consensus round).
- Unauthorized calls to gated auth methods return a plain error message.
