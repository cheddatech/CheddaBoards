# Changelog

This changelog starts on 2026-08-18. Earlier changes weren't tracked in this
repo, so the first entry below is a catch-up covering everything since the
previous public update. Per-release entries begin from here.

## v0.9.0 — 2026-09-24

### Security
- Verifier gate collapsed to a single verifier principal; the previous key is no longer accepted.

### Changed
- Moved from legacy persistence to enhanced orthogonal persistence (EOP).
  **Self-hosters upgrading an existing canister:** this is a one-way switch. Take a snapshot first; dfx.json now builds with `--enhanced-orthogonal-persistence`.
- Game ID validation on the principal registration path; name/description length caps; stats fixes for category-board submits; play-count de-duplication.

### Added
- HTTP board reads served directly by the canister: `GET /games/{gameId}/scoreboards/{boardId}?limit=N` on the raw domain, same JSON as the API, CORS-open.
- Deleted board IDs can be reused; the recreated board starts with a clean archive history.
- Expired soft-deleted games are now swept on dashboard deletes too.

## 2026-08-29 (v0.8.1)

Sync of the public repo to production. From this release the public repo is
updated via a git-tracked mirror of the private source, one commit per release.

### Changed

- Sessions now last 30 days with sliding renewal on every validated use,
  replacing the fixed 24-hour TTL. Linked players were silently dropping off
  boards a day after signing in because expired sessions rejected submits
  server-side while clients still showed them as logged in.
- Game name capped at 50 characters and description at 200; over-length values
  are clamped on write, not rejected, so existing games keep working.
- `registerGame` (principal path) now enforces the same game-ID rule as
  `registerGameBySession`: lowercase letters, digits, hyphens, 3–50 characters.
  Existing IDs that predate the rule are grandfathered.
- `dfx.json` now published as used for real builds, including
  `--legacy-persistence`: the live canister still runs classical persistence.
  Migration to enhanced orthogonal persistence is planned.

### Fixed

- Gate error on `socialLoginAndGetProfile` no longer echoes the expected
  verifier principal.

### Security

- Score, streak, and play-time validation failures now return a generic
  "rejected by game validation rules" message to clients. Previously the
  error echoed the configured cap or minimum duration, which let anyone
  binary-search a game's limits. Full detail, including actual play duration,
  is still logged owner-side in the suspicion log.

### Added

- `unlockAchievementBatch`: unlock many achievements for a player in a single
  update call, returning per-ID outcomes. Replaces per-achievement calls that
  timed out on large batches.

### Docs

- README: device-code login is implemented in the proxy layer, not the
  canister. Removed reference to `anonymousLoginAndGetProfile`; documented the
  account-linking migration functions.

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
