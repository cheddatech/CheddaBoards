# CheddaBoards 🧀

**Post-Infrastructure gaming backend for indie developers. Zero DevOps.**

Permanent, serverless leaderboards, achievements, and player profiles — powered by the Internet Computer.

[![Live Demo](https://img.shields.io/badge/demo-Chedz%20vs%20the%20Graters-yellow)](https://cheddagames.com/chedzvsthegraters)
[![Website](https://img.shields.io/badge/website-cheddaboards.com-blue)](https://cheddaboards.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## What's in this repo?

This is the **backend** for CheddaBoards:

| Component | Description |
|-----------|-------------|
| `src/main.mo` | Motoko canister — all game logic, leaderboards, auth, achievements |
| `netlify/functions/api.js` | REST API proxy — HTTP interface to the canister |
| `netlify/functions/auth-verify.ts` | OAuth verifier — validates Google/Apple tokens |

**Looking for SDKs?**
- [cheddaboards-godot](https://github.com/cheddatech/cheddaboards-godot) — Godot 4 plugin
- cheddaboards-js — Web SDK (coming soon)

---

## Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Your Game     │──────│  Netlify Edge   │──────│   ICP Canister  │
│  (Godot/Web)    │      │  (api.js)       │      │   (main.mo)     │
└─────────────────┘      └─────────────────┘      └─────────────────┘
                                │
                         ┌──────┴──────┐
                         │ auth-verify │
                         │ (OAuth JWT) │
                         └─────────────┘
```

- **Note:** REST API currently runs on Netlify. HTTP canister planned for future release.

- **Canister**: Stores all data permanently on ICP. No database to manage.
- **API Proxy**: Translates REST to canister calls. Handles OAuth verification.
- **Auth Verifier**: Validates Google/Apple JWTs, creates sessions via trusted identity.

---

## Self-Hosting

### Prerequisites

- [dfx](https://internetcomputer.org/docs/current/developer-docs/setup/install/) (IC SDK)
- [Node.js](https://nodejs.org/) 18+
- [Netlify CLI](https://docs.netlify.com/cli/get-started/) (optional, for functions)

### 1. Clone & Install

```bash
git clone https://github.com/cheddatech/cheddaboards.git
cd cheddaboards
npm install
```

### 2. Configure Principals

Edit `src/main.mo` and replace the placeholder principals:

```motoko
// Line ~414 - OAuth token verifier identity
let VERIFIER : Principal = Principal.fromText("your-verifier-principal");

// Line ~501 - Super admin (your dfx identity)  
private var CONTROLLER : Principal = Principal.fromText("your-controller-principal");

// Line ~2263 - Initial admin (can be same as controller)
let firstAdmin = Principal.fromText("your-admin-principal");
```

Get your principal: `dfx identity get-principal`

### 3. Deploy Canister

```bash
# Local testing
dfx start --background
dfx deploy

# Production (mainnet)
dfx deploy --network ic
```

### 4. Generate Candid Interface

```bash
dfx generate cheddaboards
cp .dfx/local/canisters/cheddaboards/cheddaboards.did.js netlify/functions/_lib/
```

### 5. Configure Netlify Functions

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Required variables:
- `CANISTER_ID` — Your deployed canister ID
- `VERIFIER_IDENTITY_JSON` — Ed25519 identity JSON (must match VERIFIER principal)
- `GOOGLE_CLIENT_ID` — From Google Cloud Console
- `APPLE_SERVICE_ID` / `APPLE_BUNDLE_ID` — From Apple Developer Portal
- `ALLOWED_ORIGINS` — Your game domains (comma-separated)

### 6. Deploy Functions

```bash
netlify deploy --prod
```

Or connect your repo to Netlify for automatic deploys.

---

## Using the Hosted Version

Don't want to self-host? Use our hosted infrastructure:

```javascript
// Web SDK
const chedda = await CheddaBoards.init(null, { gameId: 'your-game' });
```

```gdscript
# Godot
var chedda = CheddaBoards.new()
chedda.init("your-game-id")
```

**Free tier**: 3 games, unlimited players.

---

## Features

- **Multi-Auth**: Google, Apple, Internet Identity, Anonymous
- **Leaderboards**: Real-time, server-validated scores
- **Scoreboards**: Daily/weekly/monthly with automatic archives
- **Achievements**: Unlock tracking with timestamps
- **Anti-Cheat**: Rate limiting, score validation, play session verification
- **Cross-Game Profiles**: Players keep one identity across all CheddaBoards games

---

## API Endpoints

See `/api/docs` for full documentation. Key endpoints:

```
POST /api/auth/google          # Sign in with Google
POST /api/auth/apple           # Sign in with Apple
POST /api/scores               # Submit score
GET  /api/games/:id/scoreboards/:id  # Get leaderboard
POST /api/achievements         # Unlock achievement
```

---

## Contributing

Contributions welcome! This is open source because gaming infrastructure should be transparent and community-owned.

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Submit a PR

---

## Links

- **Website**: [cheddaboards.com](https://cheddaboards.com)
- **Demo**: [Chedz vs the Graters](https://cheddagames.com/chedzvsthegraters)
- **Company**: [cheddatech.com](https://cheddatech.com)
- **Twitter**: [@cheddatech](https://twitter.com/cheddatech)
---

## License

MIT — see [LICENSE](LICENSE)

---

**Built by [CheddaTech Ltd](https://cheddatech.com) on the Internet Computer.**
