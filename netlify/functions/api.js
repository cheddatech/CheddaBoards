// =====================================================
// CheddaBoards HTTP API Proxy v1.5.2
// Per-Game OAuth Credentials + Time-Based Scoreboards + Archives
// + Play Session Time Validation + Batch Achievement Unlocks
// =====================================================
//
// Netlify Function: Proxies REST requests to the CheddaBoards canister
// See .env.example for required environment variables
//

import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory } from "./_lib/cheddaboards_v2_backend.did.js";

// =====================================================
// Configuration
// =====================================================
const CANISTER_ID = process.env.CANISTER_ID; // Required - your CheddaBoards canister ID
const ICP_HOST = process.env.ICP_HOST || "https://icp-api.io";
const API_VERSION = "1.5.2";

if (!CANISTER_ID) {
  throw new Error("CANISTER_ID environment variable is required");
}

// Fallback credentials for CheddaBoards-owned games (The Cheese Game, etc)
const FALLBACK_GOOGLE_CLIENT_IDS = (process.env.GOOGLE_CLIENT_IDS || "").split(",").filter(Boolean);
const FALLBACK_APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "";

// =====================================================
// Actor Creation
// =====================================================
let cachedAgent = null;
let cachedActor = null;
let lastActorCreation = 0;
const ACTOR_TTL = 5 * 60 * 1000;

async function getActor() {
  const now = Date.now();
  
  if (!cachedActor || (now - lastActorCreation) > ACTOR_TTL) {
    try {
      cachedAgent = new HttpAgent({ host: ICP_HOST });
      cachedActor = Actor.createActor(idlFactory, {
        agent: cachedAgent,
        canisterId: CANISTER_ID,
      });
      lastActorCreation = now;
      console.log("[CheddaAPI] Actor created/refreshed");
    } catch (err) {
      console.error("[CheddaAPI] Failed to create actor:", err);
      throw new Error("Backend connection failed");
    }
  }
  
  return cachedActor;
}

// =====================================================
// OAuth Config Cache (per game)
// =====================================================
const oauthConfigCache = new Map();
const OAUTH_CACHE_TTL = 5 * 60 * 1000;

async function getGameOAuthConfig(actor, gameId) {
  const now = Date.now();
  const cached = oauthConfigCache.get(gameId);
  
  if (cached && (now - cached.timestamp) < OAUTH_CACHE_TTL) {
    return cached.config;
  }
  
  try {
    const result = await actor.getGameOAuthConfig(gameId);
    
    if (result && result[0]) {
      const config = result[0];
      oauthConfigCache.set(gameId, { config, timestamp: now });
      return config;
    }
    
    oauthConfigCache.set(gameId, { config: null, timestamp: now });
    return null;
  } catch (e) {
    console.error("[OAuth] Failed to fetch config for game:", gameId, e);
    return null;
  }
}

// =====================================================
// Response Helpers
// =====================================================
const baseHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-API-Key, X-Game-ID, X-Session-Token, Authorization",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "X-API-Version": API_VERSION,
};

const respond = (statusCode, body, extraHeaders = {}) => ({
  statusCode,
  headers: { ...baseHeaders, ...extraHeaders },
  body: JSON.stringify(body),
});

const success = (data, extraHeaders = {}) => respond(200, { ok: true, data }, extraHeaders);
const error = (code, message, extraHeaders = {}) => respond(code, { ok: false, error: message }, extraHeaders);

// =====================================================
// JWT Utilities
// =====================================================

function base64UrlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) {
    str += '=';
  }
  return Buffer.from(str, 'base64').toString('utf8');
}

function decodeJwtPayload(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    return JSON.parse(base64UrlDecode(parts[1]));
  } catch (e) {
    return null;
  }
}

function decodeJwtHeader(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    return JSON.parse(base64UrlDecode(parts[0]));
  } catch (e) {
    return null;
  }
}

// =====================================================
// Google Token Verification
// =====================================================

async function verifyGoogleToken(idToken, allowedClientIds) {
  try {
    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
    );
    
    if (!response.ok) {
      console.error("[Google] Token verification failed:", response.status);
      return { valid: false, error: "Invalid Google token" };
    }
    
    const payload = await response.json();
    
    if (allowedClientIds.length > 0 && !allowedClientIds.includes(payload.aud)) {
      console.error("[Google] Client ID mismatch. Got:", payload.aud, "Expected one of:", allowedClientIds);
      return { 
        valid: false, 
        error: "Google client ID not registered for this game. Add your client ID in the CheddaBoards dashboard." 
      };
    }
    
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && parseInt(payload.exp) < now) {
      return { valid: false, error: "Google token expired" };
    }
    
    return {
      valid: true,
      user: {
        sub: payload.sub,
        email: payload.email,
        emailVerified: payload.email_verified === "true",
        name: payload.name || payload.email?.split("@")[0] || "Player",
        picture: payload.picture,
      }
    };
  } catch (e) {
    console.error("[Google] Verification error:", e);
    return { valid: false, error: "Failed to verify Google token" };
  }
}

// =====================================================
// Apple Token Verification
// =====================================================

let applePublicKeys = null;
let appleKeysLastFetch = 0;
const APPLE_KEYS_TTL = 24 * 60 * 60 * 1000;

async function getApplePublicKeys() {
  const now = Date.now();
  
  if (applePublicKeys && (now - appleKeysLastFetch) < APPLE_KEYS_TTL) {
    return applePublicKeys;
  }
  
  try {
    const response = await fetch("https://appleid.apple.com/auth/keys");
    if (!response.ok) throw new Error(`Failed: ${response.status}`);
    
    const data = await response.json();
    applePublicKeys = data.keys;
    appleKeysLastFetch = now;
    return applePublicKeys;
  } catch (e) {
    console.error("[Apple] Failed to fetch public keys:", e);
    return null;
  }
}

async function verifyAppleToken(identityToken, allowedBundleId) {
  try {
    const payload = decodeJwtPayload(identityToken);
    const header = decodeJwtHeader(identityToken);
    
    if (!payload || !header) {
      return { valid: false, error: "Invalid Apple token format" };
    }
    
    if (payload.iss !== "https://appleid.apple.com") {
      return { valid: false, error: "Invalid Apple token issuer" };
    }
    
    if (allowedBundleId && payload.aud !== allowedBundleId) {
      console.error("[Apple] Bundle ID mismatch. Got:", payload.aud, "Expected:", allowedBundleId);
      return { 
        valid: false, 
        error: "Apple bundle ID not registered for this game. Add your bundle ID in the CheddaBoards dashboard." 
      };
    }
    
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      return { valid: false, error: "Apple token expired" };
    }
    
    const keys = await getApplePublicKeys();
    if (keys) {
      const matchingKey = keys.find(k => k.kid === header.kid);
      if (!matchingKey) {
        return { valid: false, error: "Apple token signature key not found" };
      }
    }
    
    return {
      valid: true,
      user: {
        sub: payload.sub,
        email: payload.email,
        emailVerified: payload.email_verified === "true" || payload.email_verified === true,
        isPrivateEmail: payload.is_private_email === "true" || payload.is_private_email === true,
      }
    };
  } catch (e) {
    console.error("[Apple] Verification error:", e);
    return { valid: false, error: "Failed to verify Apple token" };
  }
}

// =====================================================
// Auth Handlers
// =====================================================

async function handleGoogleAuth(actor, body, gameId) {
  const { idToken, nickname } = body;
  
  if (!idToken) {
    return error(400, "Missing required field: idToken");
  }
  
  if (!gameId) {
    return error(400, "Missing game ID. Include X-Game-ID header or gameId in body.");
  }
  
  const oauthConfig = await getGameOAuthConfig(actor, gameId);
  
  let allowedClientIds = [];
  
  if (oauthConfig && oauthConfig.googleClientIds && oauthConfig.googleClientIds.length > 0) {
    allowedClientIds = oauthConfig.googleClientIds;
    console.log(`[Google] Using game credentials for ${gameId}:`, allowedClientIds.length, "client IDs");
  } else if (FALLBACK_GOOGLE_CLIENT_IDS.length > 0) {
    allowedClientIds = FALLBACK_GOOGLE_CLIENT_IDS;
    console.log(`[Google] Using fallback credentials for ${gameId}`);
  } else {
    return error(400, "Google Sign-In not configured for this game. Add your Google client IDs in the CheddaBoards dashboard.");
  }
  
  const verification = await verifyGoogleToken(idToken, allowedClientIds);
  
  if (!verification.valid) {
    return error(401, verification.error);
  }
  
  const googleUser = verification.user;
  
  if (!googleUser.email) {
    return error(400, "Google account has no email associated");
  }
  
  const userNickname = nickname || googleUser.name || googleUser.email.split("@")[0];
  
  try {
    const result = await actor.socialLoginAndGetProfile(
      googleUser.email,
      userNickname.substring(0, 12),
      "google",
      gameId
    );
    
    if (result?.ok) {
      const data = result.ok;
      return success({
        sessionId: data.sessionId,
        nickname: data.nickname,
        isNewUser: data.isNewUser,
        message: data.message,
        email: googleUser.email,
        gameProfile: data.gameProfile ? {
          score: Number(data.gameProfile.total_score),
          streak: Number(data.gameProfile.best_streak),
          achievements: data.gameProfile.achievements,
          playCount: Number(data.gameProfile.play_count),
        } : null
      });
    }
    
    return error(400, result?.err || "Authentication failed");
  } catch (e) {
    console.error("[Auth] Google login error:", e);
    return error(500, "Failed to complete Google sign-in");
  }
}

async function handleAppleAuth(actor, body, gameId) {
  const { identityToken, authorizationCode, user, nickname } = body;
  
  if (!identityToken) {
    return error(400, "Missing required field: identityToken");
  }
  
  if (!gameId) {
    return error(400, "Missing game ID. Include X-Game-ID header or gameId in body.");
  }
  
  const oauthConfig = await getGameOAuthConfig(actor, gameId);
  
  let allowedBundleId = null;
  
  if (oauthConfig && oauthConfig.appleBundleId) {
    allowedBundleId = oauthConfig.appleBundleId;
    console.log(`[Apple] Using game credentials for ${gameId}: ${allowedBundleId}`);
  } else if (FALLBACK_APPLE_BUNDLE_ID) {
    allowedBundleId = FALLBACK_APPLE_BUNDLE_ID;
    console.log(`[Apple] Using fallback credentials for ${gameId}`);
  } else {
    return error(400, "Apple Sign-In not configured for this game. Add your Apple bundle ID in the CheddaBoards dashboard.");
  }
  
  const verification = await verifyAppleToken(identityToken, allowedBundleId);
  
  if (!verification.valid) {
    return error(401, verification.error);
  }
  
  const appleUser = verification.user;
  
  let email = appleUser.email;
  if (!email && user?.email) {
    email = user.email;
  }
  if (!email) {
    email = `apple_${appleUser.sub}@privaterelay.appleid.com`;
  }
  
  let userNickname = nickname;
  if (!userNickname && user?.name) {
    userNickname = user.name.firstName || user.name.givenName || "Player";
  }
  if (!userNickname) {
    userNickname = "Player";
  }
  
  try {
    const result = await actor.socialLoginAndGetProfile(
      email,
      userNickname.substring(0, 12),
      "apple",
      gameId
    );
    
    if (result?.ok) {
      const data = result.ok;
      return success({
        sessionId: data.sessionId,
        nickname: data.nickname,
        isNewUser: data.isNewUser,
        message: data.message,
        gameProfile: data.gameProfile ? {
          score: Number(data.gameProfile.total_score),
          streak: Number(data.gameProfile.best_streak),
          achievements: data.gameProfile.achievements,
          playCount: Number(data.gameProfile.play_count),
        } : null
      });
    }
    
    return error(400, result?.err || "Authentication failed");
  } catch (e) {
    console.error("[Auth] Apple login error:", e);
    return error(500, "Failed to complete Apple sign-in");
  }
}

async function handleAnonymousAuth(actor, body, gameId) {
  const { deviceId, nickname } = body;
  
  if (!gameId) {
    return error(400, "Missing game ID. Include X-Game-ID header or gameId in body.");
  }
  
  const finalDeviceId = deviceId || `anon_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
  const finalNickname = nickname || `Player_${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
  
  try {
    const result = await actor.anonymousLoginAndGetProfile(
      finalDeviceId,
      finalNickname.substring(0, 12),
      gameId
    );
    
    if (result?.ok) {
      const data = result.ok;
      return success({
        sessionId: data.sessionId,
        playerId: finalDeviceId,
        nickname: data.nickname,
        isNewUser: data.isNewUser,
        message: data.message,
        gameProfile: data.gameProfile ? {
          score: Number(data.gameProfile.total_score),
          streak: Number(data.gameProfile.best_streak),
          achievements: data.gameProfile.achievements,
          playCount: Number(data.gameProfile.play_count),
        } : null
      });
    }
    
    return error(400, result?.err || "Authentication failed");
  } catch (e) {
    console.error("[Auth] Anonymous login error:", e);
    return error(500, "Failed to complete anonymous sign-in");
  }
}

async function handleValidateSession(actor, sessionId) {
  if (!sessionId) {
    return error(401, "Missing session token");
  }
  
  try {
    const result = await actor.validateSession(sessionId);
    
    if (result?.ok) {
      return success({
        valid: true,
        email: result.ok.email,
        nickname: result.ok.nickname,
      });
    }
    
    return error(401, result?.err || "Invalid session");
  } catch (e) {
    console.error("[Auth] Session validation error:", e);
    return error(500, "Failed to validate session");
  }
}

async function handleLogout(actor, sessionId) {
  if (!sessionId) {
    return error(400, "Missing session token");
  }
  
  try {
    await actor.destroySession(sessionId);
    return success({ message: "Logged out successfully" });
  } catch (e) {
    return success({ message: "Logged out" });
  }
}

async function handleGetProfile(actor, sessionId, gameId) {
  if (!sessionId) {
    return error(401, "Missing session token");
  }
  
  try {
    const result = await actor.getMyProfileBySession(sessionId);
    
    if (result?.ok) {
      const profile = result.ok;
      
      let gameProfile = null;
      if (gameId) {
        for (const [gId, gp] of profile.gameProfiles) {
          if (gId === gameId) {
            gameProfile = {
              score: Number(gp.total_score),
              streak: Number(gp.best_streak),
              achievements: gp.achievements,
              playCount: Number(gp.play_count),
              lastPlayed: Number(gp.last_played),
            };
            break;
          }
        }
      }
      
      return success({
        nickname: profile.nickname,
        authType: profile.authType,
        created: Number(profile.created),
        lastUpdated: Number(profile.last_updated),
        gameProfile: gameProfile,
        totalGames: profile.gameProfiles.length,
      });
    }
    
    return error(404, result?.err || "Profile not found");
  } catch (e) {
    console.error("[Auth] Get profile error:", e);
    return error(500, "Failed to fetch profile");
  }
}

// =====================================================
// PLAY SESSION HANDLERS (NEW v1.5.0)
// =====================================================

async function handleStartPlaySession(actor, apiKey, gameId, body, rateLimit) {
  const { playerId } = body;
  
  if (!playerId) {
    return error(400, "Missing required field: playerId");
  }
  
  if (typeof playerId !== "string" || playerId.length < 3 || playerId.length > 100) {
    return error(400, "playerId must be a string between 3-100 characters");
  }
  
  console.log(`[PlaySession] Starting session for game: ${gameId}, player: ${playerId}`);
  
  try {
    const result = await actor.startGameSessionByApiKey(apiKey, playerId, gameId);
    
    if (result?.ok) {
      console.log(`[PlaySession] Session started: ${result.ok.substring(0, 30)}...`);
      return success({ 
        ok: result.ok,
        message: "Play session started"
      }, { "X-RateLimit-Remaining": String(rateLimit?.hour || 0) });
    }
    
    if (result?.err) {
      console.log(`[PlaySession] Error: ${result.err}`);
      return error(400, result.err);
    }
    
    return error(500, "Unexpected response from backend");
  } catch (e) {
    console.error("[PlaySession] Start session error:", e);
    return error(500, "Failed to start play session: " + e.message);
  }
}

async function handleStartPlaySessionBySession(actor, sessionId, gameId) {
  if (!sessionId) {
    return error(401, "Missing session token");
  }
  
  console.log(`[PlaySession] Starting session (OAuth) for game: ${gameId}`);
  
  try {
    const result = await actor.startGameSessionBySession(sessionId, gameId);
    
    if (result?.ok) {
      console.log(`[PlaySession] Session started: ${result.ok.substring(0, 30)}...`);
      return success({ 
        ok: result.ok,
        message: "Play session started"
      });
    }
    
    if (result?.err) {
      console.log(`[PlaySession] Error: ${result.err}`);
      return error(400, result.err);
    }
    
    return error(500, "Unexpected response from backend");
  } catch (e) {
    console.error("[PlaySession] Start session error:", e);
    return error(500, "Failed to start play session: " + e.message);
  }
}

async function handleGetPlaySessionStatus(actor, sessionToken) {
  if (!sessionToken) {
    return error(400, "Missing session token parameter");
  }
  
  try {
    const result = await actor.getPlaySessionStatus(sessionToken);
    
    if (result?.ok) {
      const status = result.ok;
      return success({
        isValid: status.isValid,
        gameId: status.gameId,
        startedAt: Number(status.startedAt),
        expiresAt: Number(status.expiresAt),
        remainingSeconds: Number(status.remainingSeconds),
      });
    }
    
    if (result?.err) {
      return error(404, result.err);
    }
    
    return error(404, "Session not found");
  } catch (e) {
    console.error("[PlaySession] Get status error:", e);
    return error(500, "Failed to get play session status");
  }
}

// =====================================================
// Session-based game operations
// =====================================================

async function handleSessionSubmitScore(actor, sessionId, gameId, body) {
  const { score, streak, rounds, playSessionToken } = body;
  
  if (!sessionId) return error(401, "Missing session token");
  if (typeof score !== "number" || score < 0) return error(400, "score must be a non-negative number");
  
  try {
    const result = await actor.submitScore(
      "session", sessionId, gameId,
      Math.floor(score), Math.floor(streak || 0),
      rounds ? [Math.floor(rounds)] : [], 
      [],
      playSessionToken ? [playSessionToken] : []
    );
    
    if (result?.ok) return success({ message: result.ok });
    if (result?.err) return error(400, result.err);
    return success({ message: "Score submitted" });
  } catch (e) {
    console.error("[Session] Submit score error:", e);
    return error(500, "Failed to submit score");
  }
}

async function handleSessionUnlockAchievement(actor, sessionId, gameId, body) {
  const { achievementId } = body;
  
  if (!sessionId) return error(401, "Missing session token");
  if (!achievementId) return error(400, "Missing required field: achievementId");
  
  try {
    const result = await actor.unlockAchievement("session", sessionId, gameId, achievementId);
    
    if (result?.ok) return success({ message: result.ok });
    if (result?.err) return error(400, result.err);
    return success({ message: "Achievement unlocked" });
  } catch (e) {
    console.error("[Session] Achievement error:", e);
    return error(500, "Failed to unlock achievement");
  }
}

async function handleSessionChangeNickname(actor, sessionId, gameId, body) {
  const { nickname } = body;
  
  if (!sessionId) return error(401, "Missing session token");
  if (!nickname || nickname.length < 3 || nickname.length > 12) {
    return error(400, "nickname must be 3-12 characters");
  }
  
  try {
    const result = await actor.changeNicknameAndGetProfile("session", sessionId, nickname, gameId);
    
    if (result?.ok) {
      return success({
        message: result.ok.message,
        nickname: result.ok.nickname,
        gameProfile: result.ok.gameProfile ? {
          score: Number(result.ok.gameProfile.total_score),
          streak: Number(result.ok.gameProfile.best_streak),
        } : null
      });
    }
    if (result?.err) return error(400, result.err);
    return error(500, "Unexpected response");
  } catch (e) {
    console.error("[Session] Nickname change error:", e);
    return error(500, "Failed to change nickname");
  }
}

// =====================================================
// SCOREBOARD HANDLERS
// =====================================================

async function handleListScoreboards(actor, gameId) {
  try {
    const scoreboards = await actor.getScoreboardsForGame(gameId);
    
    return success({
      gameId: gameId,
      scoreboards: scoreboards.map(sb => ({
        scoreboardId: sb.scoreboardId,
        name: sb.name,
        description: sb.description,
        period: sb.period,
        sortBy: sb.sortBy,
        maxEntries: Number(sb.maxEntries),
        entryCount: Number(sb.entryCount),
        lastReset: Number(sb.lastReset),
        isActive: sb.isActive,
      }))
    });
  } catch (e) {
    console.error("[Scoreboard] List error:", e);
    return error(500, "Failed to fetch scoreboards");
  }
}

async function handleGetScoreboard(actor, gameId, scoreboardId, limit) {
  try {
    const result = await actor.getScoreboard(gameId, scoreboardId, limit);
    
    if (result?.ok) {
      const config = result.ok.config;
      const entries = result.ok.entries;
      
      return success({
        scoreboardId: scoreboardId,
        config: {
          name: config.name,
          description: config.description,
          period: config.period,
          sortBy: config.sortBy,
          lastReset: Number(config.lastReset),
        },
        entries: entries.map(e => ({
          rank: Number(e.rank),
          nickname: e.nickname,
          score: Number(e.score),
          streak: Number(e.streak),
          authType: e.authType,
          submittedAt: Number(e.submittedAt),
        })),
        totalEntries: entries.length,
      });
    }
    
    if (result?.err) {
      return error(404, result.err);
    }
    
    return error(404, "Scoreboard not found");
  } catch (e) {
    console.error("[Scoreboard] Get error:", e);
    return error(500, "Failed to fetch scoreboard");
  }
}

async function handleGetPlayerRank(actor, gameId, scoreboardId, sessionId) {
  try {
    const sessionResult = await actor.validateSession(sessionId);
    if (!sessionResult?.ok) {
      return error(401, "Invalid session");
    }
    
    const result = await actor.getScoreboard(gameId, scoreboardId, 1000);
    
    if (result?.ok) {
      const entries = result.ok.entries;
      const nickname = sessionResult.ok.nickname;
      
      const playerEntry = entries.find(e => e.nickname === nickname);
      
      if (playerEntry) {
        return success({
          found: true,
          rank: Number(playerEntry.rank),
          score: Number(playerEntry.score),
          streak: Number(playerEntry.streak),
          totalPlayers: entries.length,
        });
      }
      
      return success({
        found: false,
        message: "Player not on this scoreboard yet",
        totalPlayers: entries.length,
      });
    }
    
    return error(404, result?.err || "Scoreboard not found");
  } catch (e) {
    console.error("[Scoreboard] Get rank error:", e);
    return error(500, "Failed to fetch player rank");
  }
}

async function handleCreateScoreboard(actor, sessionId, gameId, body) {
  const { scoreboardId, name, description, period, sortBy, maxEntries } = body;
  
  if (!sessionId) return error(401, "Missing session token");
  if (!scoreboardId) return error(400, "Missing required field: scoreboardId");
  if (!name) return error(400, "Missing required field: name");
  
  const validPeriods = ["allTime", "daily", "weekly", "monthly", "custom"];
  if (period && !validPeriods.includes(period)) {
    return error(400, `Invalid period. Must be one of: ${validPeriods.join(", ")}`);
  }
  
  const validSortBy = ["score", "streak"];
  if (sortBy && !validSortBy.includes(sortBy)) {
    return error(400, `Invalid sortBy. Must be one of: ${validSortBy.join(", ")}`);
  }
  
  try {
    const result = await actor.createScoreboardBySession(
      sessionId,
      gameId,
      scoreboardId,
      name,
      description || "",
      period || "allTime",
      sortBy || "score",
      maxEntries ? [maxEntries] : []
    );
    
    if (result?.ok) return success({ message: result.ok, scoreboardId });
    if (result?.err) return error(400, result.err);
    return error(500, "Unexpected response");
  } catch (e) {
    console.error("[Scoreboard] Create error:", e);
    return error(500, "Failed to create scoreboard");
  }
}

async function handleResetScoreboard(actor, sessionId, gameId, scoreboardId) {
  if (!sessionId) return error(401, "Missing session token");
  
  try {
    const result = await actor.resetScoreboardBySession(sessionId, gameId, scoreboardId);
    
    if (result?.ok) return success({ message: result.ok });
    if (result?.err) return error(400, result.err);
    return error(500, "Unexpected response");
  } catch (e) {
    console.error("[Scoreboard] Reset error:", e);
    return error(500, "Failed to reset scoreboard");
  }
}

async function handleDeleteScoreboard(actor, sessionId, gameId, scoreboardId) {
  if (!sessionId) return error(401, "Missing session token");
  
  try {
    const result = await actor.deleteScoreboardBySession(sessionId, gameId, scoreboardId);
    
    if (result?.ok) return success({ message: result.ok });
    if (result?.err) return error(400, result.err);
    return error(500, "Unexpected response");
  } catch (e) {
    console.error("[Scoreboard] Delete error:", e);
    return error(500, "Failed to delete scoreboard");
  }
}

// =====================================================
// SCOREBOARD ARCHIVE HANDLERS (NEW v1.4.0)
// =====================================================

async function handleListArchives(actor, gameId, scoreboardId, query) {
  try {
    let archives;
    
    if (query.after && query.before) {
      archives = await actor.getArchivesInRange(
        gameId,
        scoreboardId,
        BigInt(query.after),
        BigInt(query.before)
      );
    } else {
      archives = await actor.getScoreboardArchives(gameId, scoreboardId);
    }
    
    return success({
      gameId: gameId,
      scoreboardId: scoreboardId,
      archives: archives.map(archive => ({
        archiveId: archive.archiveId,
        scoreboardId: archive.scoreboardId,
        periodStart: Number(archive.periodStart),
        periodEnd: Number(archive.periodEnd),
        entryCount: Number(archive.entryCount),
        topPlayer: archive.topPlayer[0] || null,
        topScore: Number(archive.topScore),
      }))
    });
  } catch (e) {
    console.error("[Archive] List error:", e);
    return error(500, "Failed to fetch archives");
  }
}

async function handleGetLastArchive(actor, gameId, scoreboardId, limit) {
  try {
    const result = await actor.getLastArchivedScoreboard(gameId, scoreboardId, limit);
    
    if (result?.err) {
      return error(404, result.err);
    }
    
    const archive = result.ok;
    
    return success({
      archiveId: archive.archiveId,
      config: {
        name: archive.config.name,
        period: archive.config.period,
        sortBy: archive.config.sortBy,
        periodStart: Number(archive.config.periodStart),
        periodEnd: Number(archive.config.periodEnd),
      },
      entries: archive.entries.map(e => ({
        rank: Number(e.rank),
        nickname: e.nickname,
        score: Number(e.score),
        streak: Number(e.streak),
        authType: e.authType,
        submittedAt: Number(e.submittedAt),
      })),
      totalEntries: archive.entries.length,
    });
  } catch (e) {
    console.error("[Archive] Get last error:", e);
    return error(500, "Failed to fetch last archive");
  }
}

async function handleGetArchive(actor, archiveId, limit) {
  try {
    const result = await actor.getArchivedScoreboard(archiveId, limit);
    
    if (result?.err) {
      return error(404, result.err);
    }
    
    const archive = result.ok;
    
    return success({
      archiveId: archiveId,
      config: {
        name: archive.config.name,
        period: archive.config.period,
        sortBy: archive.config.sortBy,
        periodStart: Number(archive.config.periodStart),
        periodEnd: Number(archive.config.periodEnd),
      },
      entries: archive.entries.map(e => ({
        rank: Number(e.rank),
        nickname: e.nickname,
        score: Number(e.score),
        streak: Number(e.streak),
        authType: e.authType,
        submittedAt: Number(e.submittedAt),
      })),
      totalEntries: archive.entries.length,
    });
  } catch (e) {
    console.error("[Archive] Get error:", e);
    return error(500, "Failed to fetch archive");
  }
}

async function handleGetArchiveStats(actor, gameId) {
  try {
    const stats = await actor.getArchiveStats(gameId);
    
    return success({
      gameId: gameId,
      totalArchives: Number(stats.totalArchives),
      byScoreboard: stats.byScoreboard.map(([scoreboardId, count]) => ({
        scoreboardId,
        count: Number(count),
      })),
    });
  } catch (e) {
    console.error("[Archive] Stats error:", e);
    return error(500, "Failed to fetch archive stats");
  }
}

// =====================================================
// API Key Handling
// =====================================================

const isDemoKey = (key) => key?.startsWith("demo_");
const rateLimitMap = new Map();

function getRateLimitForTier(tier) {
  switch (tier) {
    case "enterprise": return { perHour: Infinity, perMinute: Infinity };
    case "pro": return { perHour: 10000, perMinute: 200 };
    case "free": return { perHour: 1000, perMinute: 50 };
    case "demo": return { perHour: 100, perMinute: 10 };
    default: return { perHour: 100, perMinute: 10 };
  }
}

function checkRateLimit(apiKey, tier) {
  const limits = getRateLimitForTier(tier);
  const now = Date.now();
  const minuteAgo = now - 60000;
  const hourAgo = now - 3600000;
  
  let entry = rateLimitMap.get(apiKey);
  if (!entry) {
    entry = { requests: [] };
    rateLimitMap.set(apiKey, entry);
  }
  
  entry.requests = entry.requests.filter(t => t > hourAgo);
  
  const requestsLastMinute = entry.requests.filter(t => t > minuteAgo).length;
  const requestsLastHour = entry.requests.length;
  
  if (requestsLastMinute >= limits.perMinute) {
    return { allowed: false, error: "Rate limit exceeded (per minute)", retryAfter: 60 };
  }
  
  if (requestsLastHour >= limits.perHour) {
    return { allowed: false, error: "Rate limit exceeded (per hour)", retryAfter: 3600 };
  }
  
  entry.requests.push(now);
  
  return { allowed: true, remaining: { minute: limits.perMinute - requestsLastMinute - 1, hour: limits.perHour - requestsLastHour - 1 }};
}

async function validateApiKeyAsync(apiKey, actor, gameIdHeader = null) {
  if (!apiKey) return { valid: false, error: "Missing API key" };
  
  if (isDemoKey(apiKey)) {
    const extractedGameId = apiKey.replace("demo_", "");
    const rateCheck = checkRateLimit(apiKey, "demo");
    if (!rateCheck.allowed) return { valid: false, error: rateCheck.error, retryAfter: rateCheck.retryAfter };
    return { valid: true, gameId: gameIdHeader || extractedGameId, tier: "demo", rateLimit: rateCheck.remaining };
  }
  
  try {
    const result = await actor.validateApiKeyQuery(apiKey);
    
    if (result && result[0]) {
      const keyData = result[0];
      if (!keyData.isActive) return { valid: false, error: "API key has been revoked" };
      
      const rateCheck = checkRateLimit(apiKey, keyData.tier);
      if (!rateCheck.allowed) return { valid: false, error: rateCheck.error, retryAfter: rateCheck.retryAfter };
      
      return { valid: true, gameId: keyData.gameId, tier: keyData.tier, rateLimit: rateCheck.remaining };
    }
    
    return { valid: false, error: "Invalid API key" };
  } catch (e) {
    console.error("[CheddaAPI] Key validation error:", e);
    return { valid: false, error: "Failed to validate API key" };
  }
}

async function handleExternalSubmitScore(actor, apiKey, gameId, body, rateLimit) {
  const { playerId, score, streak, rounds, nickname, playSessionToken } = body;
  
  if (!playerId) return error(400, "Missing required field: playerId");
  if (typeof playerId !== "string" || playerId.length < 1 || playerId.length > 100) {
    return error(400, "playerId must be a string between 1-100 characters");
  }
  if (typeof score !== "number" || score < 0 || !Number.isFinite(score)) {
    return error(400, "score must be a non-negative number");
  }
  
  try {
    const result = await actor.submitScore(
      "external", playerId, gameId,
      Math.floor(score), Math.floor(streak || 0),
      rounds ? [Math.floor(rounds)] : [],
      nickname ? [nickname] : [],
      playSessionToken ? [playSessionToken] : []
    );
    
    if (result?.ok) return success({ message: result.ok }, { "X-RateLimit-Remaining": String(rateLimit?.hour || 0) });
    if (result?.err) return error(400, result.err);
    return success({ message: "Score submitted" });
  } catch (e) {
    console.error("[CheddaAPI] Submit score error:", e);
    return error(500, "Failed to submit score");
  }
}

async function handleExternalChangeNickname(actor, gameId, playerId, body, rateLimit) {
  const { nickname } = body;
  
  if (!nickname || nickname.length < 3 || nickname.length > 12) {
    return error(400, "nickname must be 3-12 characters");
  }
  
  try {
    const result = await actor.changeNicknameAndGetProfile(
      "external",
      playerId,
      nickname,
      gameId
    );
    
    if (result?.ok) {
      return success({
        message: result.ok.message,
        nickname: result.ok.nickname,
        gameProfile: result.ok.gameProfile ? {
          score: Number(result.ok.gameProfile.total_score),
          streak: Number(result.ok.gameProfile.best_streak),
        } : null
      }, { "X-RateLimit-Remaining": String(rateLimit?.hour || 0) });
    }
    if (result?.err) return error(400, result.err);
    return error(500, "Unexpected response");
  } catch (e) {
    console.error("[API] External nickname change error:", e);
    return error(500, "Failed to change nickname");
  }
}

async function handleGetLeaderboard(actor, gameId, query) {
  const sortBy = query.sort === "streak" ? { streak: null } : { score: null };
  const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
  
  try {
    const results = await actor.getLeaderboard(gameId, sortBy, limit);
    
    const leaderboard = results.map((entry, index) => ({
      rank: index + 1,
      nickname: entry[0],
      score: Number(entry[1]),
      streak: Number(entry[2]),
      authType: entry[3],
    }));
    
    return success({ leaderboard, total: leaderboard.length });
  } catch (e) {
    console.error("[CheddaAPI] Leaderboard error:", e);
    return error(500, "Failed to fetch leaderboard");
  }
}

async function handleGetGameInfo(actor, gameId) {
  try {
    const game = await actor.getGame(gameId);
    
    if (game && game[0]) {
      const g = game[0];
      
      const oauthConfig = await getGameOAuthConfig(actor, gameId);
      
      let scoreboards = [];
      try {
        const sbList = await actor.getScoreboardsForGame(gameId);
        scoreboards = sbList.map(sb => ({
          scoreboardId: sb.scoreboardId,
          name: sb.name,
          period: sb.period,
        }));
      } catch (e) {
        // Scoreboards not available, that's ok
      }
      
      return success({
        gameId: g.gameId,
        name: g.name,
        description: g.description,
        totalPlayers: Number(g.totalPlayers),
        totalPlays: Number(g.totalPlays),
        isActive: g.isActive,
        timeValidationEnabled: g.timeValidationEnabled || false,
        nativeAuth: {
          googleEnabled: oauthConfig?.googleClientIds?.length > 0 || FALLBACK_GOOGLE_CLIENT_IDS.length > 0,
          appleEnabled: !!oauthConfig?.appleBundleId || !!FALLBACK_APPLE_BUNDLE_ID,
        },
        scoreboards: scoreboards,
      });
    }
    return error(404, "Game not found");
  } catch (e) {
    return error(500, "Failed to fetch game info");
  }
}

// =====================================================
// Main Handler
// =====================================================
export async function handler(event) {
  if (event.httpMethod === "OPTIONS") {
    return respond(200, {});
  }
  
  const method = event.httpMethod;
  const path = event.path.replace("/.netlify/functions/api", "").replace("/api", "") || "/";
  const pathParts = path.split("/").filter(Boolean);
  const query = event.queryStringParameters || {};
  
  let body = {};
  if (event.body) {
    try {
      body = JSON.parse(event.body);
    } catch (e) {
      return error(400, "Invalid JSON body");
    }
  }
  
  const apiKey = event.headers["x-api-key"] || event.headers["X-API-Key"] || query.api_key;
  const sessionToken = event.headers["x-session-token"] || event.headers["X-Session-Token"] || 
                       event.headers["authorization"]?.replace("Bearer ", "") || query.session;
  const gameIdHeader = event.headers["x-game-id"] || event.headers["X-Game-ID"] || query.game_id;
  
  let actor;
  try {
    actor = await getActor();
  } catch (e) {
    return error(503, "Backend temporarily unavailable");
  }
  
  console.log(`[CheddaAPI] ${method} ${path}`);
  
  try {
    // =====================================================
    // AUTH ROUTES
    // =====================================================
    
    if (method === "POST" && pathParts[0] === "auth" && pathParts[1] === "google") {
      return await handleGoogleAuth(actor, body, gameIdHeader || body.gameId);
    }
    
    if (method === "POST" && pathParts[0] === "auth" && pathParts[1] === "apple") {
      return await handleAppleAuth(actor, body, gameIdHeader || body.gameId);
    }
    
    if (method === "POST" && pathParts[0] === "auth" && pathParts[1] === "anonymous") {
      return await handleAnonymousAuth(actor, body, gameIdHeader || body.gameId);
    }
    
    if (method === "GET" && pathParts[0] === "auth" && pathParts[1] === "session") {
      return await handleValidateSession(actor, sessionToken);
    }
    
    if (method === "POST" && pathParts[0] === "auth" && pathParts[1] === "logout") {
      return await handleLogout(actor, sessionToken);
    }
    
    if (method === "GET" && pathParts[0] === "auth" && pathParts[1] === "profile") {
      return await handleGetProfile(actor, sessionToken, gameIdHeader);
    }
    
    if (method === "GET" && pathParts[0] === "auth" && pathParts[1] === "config") {
      const gameId = pathParts[2] || gameIdHeader;
      if (!gameId) return error(400, "Missing game ID");
      
      const oauthConfig = await getGameOAuthConfig(actor, gameId);
      
      return success({
        gameId: gameId,
        google: {
          enabled: (oauthConfig?.googleClientIds?.length > 0) || FALLBACK_GOOGLE_CLIENT_IDS.length > 0,
          clientIdCount: oauthConfig?.googleClientIds?.length || 0,
        },
        apple: {
          enabled: !!oauthConfig?.appleBundleId || !!FALLBACK_APPLE_BUNDLE_ID,
          bundleId: oauthConfig?.appleBundleId ? "[configured]" : null,
        }
      });
    }
    
    // =====================================================
    // PLAY SESSION ROUTES (NEW v1.5.0)
    // =====================================================
    
    // POST /play-sessions/start - Start a play session (API key auth)
    if (method === "POST" && pathParts[0] === "play-sessions" && pathParts[1] === "start") {
      // Check for API key first
      if (apiKey) {
        const keyValidation = await validateApiKeyAsync(apiKey, actor, gameIdHeader);
        if (!keyValidation.valid) {
          const code = keyValidation.retryAfter ? 429 : 401;
          return error(code, keyValidation.error, keyValidation.retryAfter ? { "Retry-After": String(keyValidation.retryAfter) } : {});
        }
        return await handleStartPlaySession(actor, apiKey, keyValidation.gameId, body, keyValidation.rateLimit);
      }
      
      // Check for session token (OAuth users)
      if (sessionToken) {
        const gameId = gameIdHeader || body.gameId;
        if (!gameId) return error(400, "Missing game ID");
        return await handleStartPlaySessionBySession(actor, sessionToken, gameId);
      }
      
      return error(401, "API key or session token required");
    }
    
    // GET /play-sessions/:token/status - Check play session status
    if (method === "GET" && pathParts[0] === "play-sessions" && pathParts[2] === "status") {
      const token = pathParts[1];
      return await handleGetPlaySessionStatus(actor, token);
    }
    
    // =====================================================
    // SCOREBOARD ROUTES (Public)
    // =====================================================
    
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && !pathParts[3]) {
      const gameId = pathParts[1];
      return await handleListScoreboards(actor, gameId);
    }
    
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && pathParts[3] && 
        pathParts[4] !== "rank" && pathParts[4] !== "archives") {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
      return await handleGetScoreboard(actor, gameId, scoreboardId, limit);
    }
    
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && pathParts[3] && pathParts[4] === "rank") {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      
      if (!sessionToken) {
        return error(401, "Session required to get player rank");
      }
      
      return await handleGetPlayerRank(actor, gameId, scoreboardId, sessionToken);
    }
    
    // =====================================================
    // SCOREBOARD ARCHIVE ROUTES (NEW v1.4.0)
    // =====================================================
    
    // GET /games/:gameId/scoreboards/:scoreboardId/archives
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && 
        pathParts[3] && pathParts[4] === "archives" && !pathParts[5]) {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      return await handleListArchives(actor, gameId, scoreboardId, query);
    }
    
    // GET /games/:gameId/scoreboards/:scoreboardId/archives/latest
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && 
        pathParts[3] && pathParts[4] === "archives" && pathParts[5] === "latest") {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
      return await handleGetLastArchive(actor, gameId, scoreboardId, limit);
    }
    
    // GET /archives/:archiveId
    if (method === "GET" && pathParts[0] === "archives" && pathParts[1]) {
      const archiveId = decodeURIComponent(pathParts.slice(1).join("/"));
      const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
      return await handleGetArchive(actor, archiveId, limit);
    }
    
    // GET /games/:gameId/archives/stats
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "archives" && pathParts[3] === "stats") {
      const gameId = pathParts[1];
      return await handleGetArchiveStats(actor, gameId);
    }
    
    // =====================================================
    // SCOREBOARD ROUTES (Developer)
    // =====================================================
    
    if (method === "POST" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && !pathParts[3]) {
      const gameId = pathParts[1];
      return await handleCreateScoreboard(actor, sessionToken, gameId, body);
    }
    
    if (method === "POST" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && pathParts[3] && pathParts[4] === "reset") {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      return await handleResetScoreboard(actor, sessionToken, gameId, scoreboardId);
    }
    
    if (method === "DELETE" && pathParts[0] === "games" && pathParts[2] === "scoreboards" && pathParts[3]) {
      const gameId = pathParts[1];
      const scoreboardId = pathParts[3];
      return await handleDeleteScoreboard(actor, sessionToken, gameId, scoreboardId);
    }
    
    // =====================================================
    // SESSION-BASED ROUTES
    // =====================================================
    
    if (sessionToken && !apiKey) {
      const gameId = gameIdHeader || body.gameId;
      
      if (!gameId && !["auth", "games", "archives", "play-sessions"].includes(pathParts[0])) {
        return error(400, "Missing X-Game-ID header or gameId in body");
      }
      
      if (method === "POST" && pathParts[0] === "scores") {
        return await handleSessionSubmitScore(actor, sessionToken, gameId, body);
      }
      
      if (method === "POST" && pathParts[0] === "achievements") {
        return await handleSessionUnlockAchievement(actor, sessionToken, gameId, body);
      }
      
      if (method === "PUT" && pathParts[0] === "profile" && pathParts[1] === "nickname") {
        return await handleSessionChangeNickname(actor, sessionToken, gameId, body);
      }
      
      if (method === "GET" && pathParts[0] === "leaderboard") {
        return await handleGetLeaderboard(actor, gameId, query);
      }
      
      if (method === "GET" && pathParts[0] === "game" && !pathParts[1]) {
        return await handleGetGameInfo(actor, gameId);
      }
    }
    
    // =====================================================
    // API KEY ROUTES
    // =====================================================
    
    if (apiKey) {
      const keyValidation = await validateApiKeyAsync(apiKey, actor, gameIdHeader);
      if (!keyValidation.valid) {
        const code = keyValidation.retryAfter ? 429 : 401;
        return error(code, keyValidation.error, keyValidation.retryAfter ? { "Retry-After": String(keyValidation.retryAfter) } : {});
      }
      
      const gameId = keyValidation.gameId;
      const rateLimit = keyValidation.rateLimit;
      
      if (method === "POST" && pathParts[0] === "scores") {
        return await handleExternalSubmitScore(actor, apiKey, gameId, body, rateLimit);
      }
      
      // POST /achievements - Unlock achievement(s) - supports batch via achievementIds array
      if (method === "POST" && pathParts[0] === "achievements") {
        const { playerId, achievementId, achievementIds } = body;
        if (!playerId) return error(400, "Missing required field: playerId");
        
        // Support both single (achievementId) and batch (achievementIds)
        const idsToUnlock = achievementIds || (achievementId ? [achievementId] : []);
        if (idsToUnlock.length === 0) return error(400, "Missing required field: achievementId or achievementIds");
        
        try {
          const results = [];
          for (const achId of idsToUnlock) {
            try {
              const result = await actor.unlockAchievement("external", playerId, gameId, achId);
              results.push({ achievementId: achId, success: true, message: result?.ok || "unlocked" });
            } catch (e) {
              results.push({ achievementId: achId, success: false, error: e.message });
            }
          }
          
          const successCount = results.filter(r => r.success).length;
          return success({ 
            message: `${successCount}/${idsToUnlock.length} achievements unlocked`,
            unlocked: successCount,
            total: idsToUnlock.length,
            results 
          }, { "X-RateLimit-Remaining": String(rateLimit?.hour || 0) });
        } catch (e) {
          console.error("[API] Achievement unlock error:", e);
          return error(500, "Failed to unlock achievements");
        }
      }
      
      if (method === "PUT" && pathParts[0] === "players" && pathParts[2] === "nickname") {
        const playerId = pathParts[1];
        return await handleExternalChangeNickname(actor, gameId, playerId, body, rateLimit);
      }
      
      if (method === "GET" && pathParts[0] === "players" && pathParts[2] === "profile") {
        const playerId = pathParts[1];
        try {
          const result = await actor.getUserProfile("external", playerId);
          if (result?.ok) {
            const profile = result.ok;
            let gameProfile = null;
            for (const [gId, gp] of profile.gameProfiles) {
              if (gId === gameId) {
                gameProfile = {
                  score: Number(gp.total_score),
                  streak: Number(gp.best_streak),
                  achievements: gp.achievements,
                  playCount: Number(gp.play_count),
                  lastPlayed: Number(gp.last_played),
                };
                break;
              }
            }
            return success({
              nickname: profile.nickname,
              created: Number(profile.created),
              gameProfile: gameProfile,
            }, { "X-RateLimit-Remaining": String(rateLimit?.hour || 0) });
          }
          return error(404, result?.err || "Player not found");
        } catch (e) {
          console.error("[API] Get external profile error:", e);
          return error(500, "Failed to fetch player profile");
        }
      }
      
      if (method === "GET" && pathParts[0] === "leaderboard") {
        return await handleGetLeaderboard(actor, gameId, query);
      }
      
      if (method === "GET" && pathParts[0] === "game" && !pathParts[1]) {
        return await handleGetGameInfo(actor, gameId);
      }
      
      if (method === "GET" && pathParts[0] === "scoreboards" && !pathParts[1]) {
        return await handleListScoreboards(actor, gameId);
      }
      
      if (method === "GET" && pathParts[0] === "scoreboards" && pathParts[1] && pathParts[2] !== "archives") {
        const scoreboardId = pathParts[1];
        const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
        return await handleGetScoreboard(actor, gameId, scoreboardId, limit);
      }
      
      // API Key archive routes
      if (method === "GET" && pathParts[0] === "scoreboards" && pathParts[1] && pathParts[2] === "archives" && !pathParts[3]) {
        const scoreboardId = pathParts[1];
        return await handleListArchives(actor, gameId, scoreboardId, query);
      }
      
      if (method === "GET" && pathParts[0] === "scoreboards" && pathParts[1] && pathParts[2] === "archives" && pathParts[3] === "latest") {
        const scoreboardId = pathParts[1];
        const limit = Math.min(Math.max(parseInt(query.limit) || 100, 1), 1000);
        return await handleGetLastArchive(actor, gameId, scoreboardId, limit);
      }
      
      if (method === "GET" && pathParts[0] === "archives" && pathParts[1] === "stats") {
        return await handleGetArchiveStats(actor, gameId);
      }
      
      if (method === "GET" && (path === "/" || path === "/health")) {
        return success({ status: "healthy", version: API_VERSION, gameId, tier: keyValidation.tier, auth: "api_key" });
      }
    }
    
    // =====================================================
    // OAUTH MANAGEMENT ROUTES
    // =====================================================
    
    if (method === "POST" && pathParts[0] === "games" && pathParts[2] === "oauth" && pathParts[3] === "google") {
      const gameId = pathParts[1];
      const { clientIds } = body;
      
      if (!sessionToken) {
        return error(401, "Session required. Login first.");
      }
      
      if (!clientIds || !Array.isArray(clientIds)) {
        return error(400, "clientIds must be an array of Google OAuth client IDs");
      }
      
      for (const id of clientIds) {
        if (!id.endsWith(".apps.googleusercontent.com")) {
          return error(400, `Invalid client ID format: ${id}. Must end with .apps.googleusercontent.com`);
        }
      }
      
      try {
        const result = await actor.setGameGoogleCredentialsBySession(sessionToken, gameId, clientIds);
        
        if (result?.ok) {
          oauthConfigCache.delete(gameId);
          return success({ message: result.ok, clientIdCount: clientIds.length });
        }
        if (result?.err) {
          return error(400, result.err);
        }
        return error(500, "Unexpected response");
      } catch (e) {
        console.error("[OAuth] Set Google credentials error:", e);
        return error(500, "Failed to save Google credentials");
      }
    }
    
    if (method === "POST" && pathParts[0] === "games" && pathParts[2] === "oauth" && pathParts[3] === "apple") {
      const gameId = pathParts[1];
      const { bundleId, teamId } = body;
      
      if (!sessionToken) {
        return error(401, "Session required. Login first.");
      }
      
      if (!bundleId) {
        return error(400, "bundleId is required (e.g., com.company.appname)");
      }
      
      if (!bundleId.includes(".") || bundleId.length < 5) {
        return error(400, "Invalid bundle ID format. Expected: com.company.appname");
      }
      
      try {
        const result = await actor.setGameAppleCredentialsBySession(
          sessionToken, 
          gameId, 
          bundleId, 
          teamId ? [teamId] : []
        );
        
        if (result?.ok) {
          oauthConfigCache.delete(gameId);
          return success({ message: result.ok, bundleId });
        }
        if (result?.err) {
          return error(400, result.err);
        }
        return error(500, "Unexpected response");
      } catch (e) {
        console.error("[OAuth] Set Apple credentials error:", e);
        return error(500, "Failed to save Apple credentials");
      }
    }
    
    if (method === "GET" && pathParts[0] === "games" && pathParts[2] === "oauth" && !pathParts[3]) {
      const gameId = pathParts[1];
      
      if (!sessionToken) {
        return error(401, "Session required");
      }
      
      try {
        const result = await actor.getGameOAuthConfigBySession(sessionToken, gameId);
        
        if (result?.ok) {
          const config = result.ok;
          return success({
            google: {
              configured: config.googleConfigured,
              clientIds: config.googleClientIds,
            },
            apple: {
              configured: config.appleConfigured,
              bundleId: config.appleBundleId || null,
              teamId: config.appleTeamId || null,
            }
          });
        }
        if (result?.err) {
          return error(400, result.err);
        }
        return error(500, "Unexpected response");
      } catch (e) {
        console.error("[OAuth] Get config error:", e);
        return error(500, "Failed to fetch OAuth config");
      }
    }
    
    if (method === "DELETE" && pathParts[0] === "games" && pathParts[2] === "oauth" && pathParts[3] === "google") {
      const gameId = pathParts[1];
      
      if (!sessionToken) {
        return error(401, "Session required");
      }
      
      try {
        const result = await actor.clearGameOAuthCredentialsBySession(sessionToken, gameId, "google");
        
        if (result?.ok) {
          oauthConfigCache.delete(gameId);
          return success({ message: result.ok });
        }
        if (result?.err) {
          return error(400, result.err);
        }
        return error(500, "Unexpected response");
      } catch (e) {
        return error(500, "Failed to clear Google credentials");
      }
    }
    
    if (method === "DELETE" && pathParts[0] === "games" && pathParts[2] === "oauth" && pathParts[3] === "apple") {
      const gameId = pathParts[1];
      
      if (!sessionToken) {
        return error(401, "Session required");
      }
      
      try {
        const result = await actor.clearGameOAuthCredentialsBySession(sessionToken, gameId, "apple");
        
        if (result?.ok) {
          oauthConfigCache.delete(gameId);
          return success({ message: result.ok });
        }
        if (result?.err) {
          return error(400, result.err);
        }
        return error(500, "Unexpected response");
      } catch (e) {
        return error(500, "Failed to clear Apple credentials");
      }
    }
    
    // =====================================================
    // PUBLIC ROUTES
    // =====================================================
    
    if (method === "GET" && (path === "/" || path === "/health")) {
      return success({ status: "healthy", version: API_VERSION, auth: "none" });
    }
    
    if (method === "GET" && path === "/docs") {
      return success({
        version: API_VERSION,
        description: "CheddaBoards - Web3 Gaming Backend",
        baseUrl: "https://api.cheddaboards.com",
        
        authentication: {
          note: "Three auth methods available",
          methods: {
            session: "Use X-Session-Token header after OAuth login",
            apiKey: "Use X-API-Key header for server-to-server",
            gameId: "Use X-Game-ID header to specify game context",
          }
        },
        
        endpoints: {
          auth: {
            "POST /auth/google": "Sign in with Google",
            "POST /auth/apple": "Sign in with Apple",
            "POST /auth/anonymous": "Create anonymous player",
            "GET /auth/session": "Validate session",
            "POST /auth/logout": "Destroy session",
            "GET /auth/profile": "Get user profile",
            "GET /auth/config/:gameId": "Check available auth methods"
          },
          
          playSessions: {
            "POST /play-sessions/start": "Start a play session (for time validation)",
            "GET /play-sessions/:token/status": "Check play session status"
          },
          
          scoreboards: {
            "GET /games/:gameId/scoreboards": "List all scoreboards",
            "GET /games/:gameId/scoreboards/:id": "Get scoreboard entries",
            "GET /games/:gameId/scoreboards/:id/rank": "Get player rank (session)",
            "POST /games/:gameId/scoreboards": "Create scoreboard (dev)",
            "POST /games/:gameId/scoreboards/:id/reset": "Reset scoreboard (dev)",
            "DELETE /games/:gameId/scoreboards/:id": "Delete scoreboard (dev)"
          },
          
          archives: {
            "GET /games/:gameId/scoreboards/:id/archives": "List all archives",
            "GET /games/:gameId/scoreboards/:id/archives/latest": "Get last week's/month's results",
            "GET /archives/:archiveId": "Get specific archive",
            "GET /games/:gameId/archives/stats": "Get archive stats"
          },
          
          gameplay: {
            "POST /scores": "Submit score (include playSessionToken for time validation)",
            "POST /achievements": "Unlock achievement",
            "PUT /profile/nickname": "Change nickname",
            "GET /leaderboard": "Get legacy leaderboard"
          },
          
          apiKey: {
            "POST /play-sessions/start": "Start play session {playerId, gameId}",
            "POST /scores": "Submit score (external)",
            "POST /achievements": "Unlock achievement {playerId, achievementId}",
            "PUT /players/:id/nickname": "Change nickname",
            "GET /players/:id/profile": "Get player profile",
            "GET /scoreboards/:id/archives": "List archives",
            "GET /scoreboards/:id/archives/latest": "Get last archive"
          }
        },
        
        examples: {
          startSession: "POST /play-sessions/start {playerId: 'dev_123', gameId: 'my-game'}",
          submitWithSession: "POST /scores {playerId: 'dev_123', score: 1000, playSessionToken: 'ps_...'}",
          getWeekly: "GET /games/my-game/scoreboards/weekly?limit=10",
          getLastWeek: "GET /games/my-game/scoreboards/weekly/archives/latest",
          listArchives: "GET /games/my-game/scoreboards/weekly/archives"
        }
      });
    }
    
    return error(404, `Unknown endpoint: ${method} ${path}. See /docs`);
    
  } catch (e) {
    console.error("[CheddaAPI] Unhandled error:", e);
    return error(500, "Internal server error");
  }
}
