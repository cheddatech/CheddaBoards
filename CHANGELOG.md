# Changelog

This changelog starts on 2026-08-18. Earlier changes weren't tracked in this
repo, so the first entry below is a catch-up covering everything since the
previous public update. Per-release entries begin from here.

## v0.11.0 — 2026-09-30

### Removed
- The Files module has been removed: `files.mo`, the `stableFiles` stable field, the transient file list and its pre/postupgrade copies, and all 7 public file methods (including `uploadFile` and `deleteFile`). It was unused (0 files stored) and only added interface and attack surface.
- `getSystemInfo` no longer returns `fileCount`.

### Added
- `memStats` query: reports cycles balance, memory usage and internal map sizes, for capacity monitoring.
- `GET /metrics` on the raw domain, served directly by the canister: the same capacity figures as JSON, with warning flags when cycles fall under 5T or memory goes over 1.5 GB.

### Notes for self-hosters
- This release removes Candid methods, so dfx will prompt about a breaking interface change on upgrade. Expected; confirm it. Update any client that calls the file methods or reads `fileCount`.
- **Existing canisters need a two-step upgrade.** EOP will not implicitly drop a stable field (error M0169). First deploy tag `v0.11.0-migration`, which includes a one-shot `migration.mo` applied via `(with migration = Migration.run)` to drop `stableFiles`, then deploy `v0.11.0`, which retires the migration. Deploying `v0.11.0` directly onto a v0.10.0 canister will be rejected. Fresh installs can go straight to `v0.11.0`.
- Take a snapshot before upgrading. Each snapshot is a full copy of the heap, so keep one at a time (`dfx canister snapshot create --replace`) to avoid paying cycles for stale copies.

## v0.10.0 — 2026-09-26

### Security
- External (API-key) player writes are now accepted only from the verifier principal. Score submits, targeted board submits, achievement unlocks and nickname changes on the `external` path can no longer be made by calling the canister directly.
- Proxy-only entry points now require the verifier: `migrateAnonymousAccount`, `startGameSessionByApiKey`, `cancelPlaySession`.
- `getSessionInfo`, `trackEvent` and `validateApiKey` are now verifier-only.
- `getRecentEvents` is now admin-only; analytics events carry player identifiers and should never have been public.
- Session tokens, play-session tokens and API keys are now generated from `raw_rand` (IC randomness) instead of timestamps and counters. Existing sessions and keys remain valid.

### Fixed
- Sessions now survive canister upgrades. `postupgrade` was restoring sessions from a transient variable, so every upgrade signed out all signed-in players and developers.

### Notes for self-hosters
- **Your proxy must make every canister call signed as the verifier identity**, including external score submits. A proxy that calls anonymously for writes will get `Unauthorized` after this upgrade.
- New token formats: sessions are `session_` + 64 hex characters, play tokens `ps_<gameId>_` + 32 hex, API keys `cb_<gameId>_` + 32 hex. Anything that parses the old numeric formats should be updated.
- No Candid interface changes.

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

## v0.8.1 — 2026-08-29

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

## v0.8.0 — 2026-08-18

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