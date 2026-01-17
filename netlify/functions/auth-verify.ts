// =====================================================
// CheddaBoards OAuth Token Verifier
// Netlify Function: POST /.netlify/functions/auth-verify
// 
// Verifies Google/Apple OAuth tokens and creates sessions
// on the CheddaBoards canister using a trusted identity.
// See .env.example for required environment variables
// =====================================================

import { createRemoteJWKSet, jwtVerify } from "jose";
import { HttpAgent, Actor } from "@dfinity/agent";
import { Ed25519KeyIdentity } from "@dfinity/identity";
// @ts-ignore — generated DID file (Candid interface)
import { idlFactory } from "./_lib/cheddaboards_v2_backend.did.js";

// ==========================
// Environment variables
// ==========================
const GOOGLE_CLIENT_ID   = process.env.GOOGLE_CLIENT_ID!;
const APPLE_SERVICE_ID   = process.env.APPLE_SERVICE_ID!;
const APPLE_BUNDLE_ID    = process.env.APPLE_BUNDLE_ID!;  // NEW: for "Hide My Email"
const CHEDDA_CANISTER_ID = process.env.CHEDDA_CANISTER_ID!;
const DFX_HOST           = process.env.DFX_HOST || "https://icp-api.io";
const IDENTITY_JSON      = process.env.VERIFIER_IDENTITY_JSON!;

// ==========================
// Allowed Origins (CORS)
// ==========================
// Set ALLOWED_ORIGINS env var as comma-separated list, e.g.:
// "https://yourgame.com,https://anothergame.com,http://localhost:8888"
const ALLOWED_ORIGINS = new Set<string>(
  (process.env.ALLOWED_ORIGINS || "http://localhost:8888")
    .split(",")
    .map(s => s.trim())
    .filter(Boolean)
);

// ==========================
// Providers
// ==========================
const PROVIDERS = {
  google: {
    issuer: "https://accounts.google.com",
    jwks: "https://www.googleapis.com/oauth2/v3/certs",
    audiences: [GOOGLE_CLIENT_ID],  // Google only uses Service ID
  },
  apple: {
    issuer: "https://appleid.apple.com",
    jwks: "https://appleid.apple.com/auth/keys",
    // Apple can use EITHER Service ID OR Bundle ID depending on "Hide My Email"
    audiences: [
      APPLE_SERVICE_ID,
      APPLE_BUNDLE_ID,
      // Fallback patterns for safety
      APPLE_SERVICE_ID?.replace('.web', ''),
    ].filter(Boolean),  // Remove any undefined values
  },
} as const;

// ==========================
// Types
// ==========================
type AuthType = { google: null } | { apple: null };

type Session = {
  sessionId: string;
  email: string;
  nickname: string;
  authType: AuthType;
  created: number | bigint;
  expires: number | bigint;
  lastUsed: number | bigint;
};

type ResultOk<T> = { ok: T };
type ResultErr = { err: string };
type Result<T> = ResultOk<T> | ResultErr;

interface CanisterActor {
  createSessionForVerifiedUser(
    idp: AuthType,
    sub: string,
    emailOpt: [] | [string],
    nonce: string
  ): Promise<Result<Session>>;
}

// ==========================
// Helper functions
// ==========================
function assert(cond: any, msg = "Bad request") {
  if (!cond) throw new Error(msg);
}

function corsHeaders(origin: string | undefined) {
  const allowed = origin && ALLOWED_ORIGINS.has(origin)
    ? origin
    : Array.from(ALLOWED_ORIGINS)[0] || "*";

  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json",
  };
}

function getIdentity() {
  assert(IDENTITY_JSON, "Missing VERIFIER_IDENTITY_JSON");
  
  try {
    console.log("[Verifier] Identity JSON length:", IDENTITY_JSON.length);
    console.log("[Verifier] Identity JSON preview (first 100 chars):", IDENTITY_JSON.substring(0, 100));
    
    // Parse the JSON
    let parsed;
    try {
      parsed = JSON.parse(IDENTITY_JSON);
      console.log("[Verifier] JSON parsed successfully");
      console.log("[Verifier] Parsed type:", typeof parsed);
      console.log("[Verifier] Is array:", Array.isArray(parsed));
      if (typeof parsed === 'object') {
        console.log("[Verifier] Keys:", Object.keys(parsed));
      }
    } catch (parseErr: any) {
      console.error("[Verifier] JSON parse failed:", parseErr.message);
      throw new Error(`Malformed IDENTITY_JSON: ${parseErr.message}`);
    }
    
    // Try fromJSON first (standard method)
    if (typeof Ed25519KeyIdentity.fromJSON === 'function') {
      console.log("[Verifier] Attempting Ed25519KeyIdentity.fromJSON");
      try {
        const identity = Ed25519KeyIdentity.fromJSON(JSON.stringify(parsed));
        console.log("[Verifier] ✅ fromJSON succeeded");
        console.log("[Verifier] Identity principal:", identity.getPrincipal().toText());
        return identity;
      } catch (fromJsonErr: any) {
        console.error("[Verifier] fromJSON failed:", fromJsonErr.message);
        // Continue to next method
      }
    }
    
    // Try fromParsedJson
    if (typeof (Ed25519KeyIdentity as any).fromParsedJson === 'function') {
      console.log("[Verifier] Attempting Ed25519KeyIdentity.fromParsedJson");
      
      // fromParsedJson expects array format [publicKey, privateKey]
      let dataToUse = parsed;
      
      if (!Array.isArray(parsed)) {
        console.log("[Verifier] Converting object to array format");
        if (parsed.publicKey && parsed.privateKey) {
          dataToUse = [parsed.publicKey, parsed.privateKey];
        } else {
          throw new Error("Identity JSON must have publicKey and privateKey properties, or be an array [publicKey, privateKey]");
        }
      }
      
      try {
        const identity = (Ed25519KeyIdentity as any).fromParsedJson(dataToUse);
        console.log("[Verifier] ✅ fromParsedJson succeeded");
        console.log("[Verifier] Identity principal:", identity.getPrincipal().toText());
        return identity;
      } catch (fromParsedErr: any) {
        console.error("[Verifier] fromParsedJson failed:", fromParsedErr.message);
        throw fromParsedErr;
      }
    }
    
    throw new Error("No suitable Ed25519KeyIdentity method available (tried fromJSON and fromParsedJson)");
    
  } catch (e: any) {
    console.error("[Verifier] Identity error:", e.message);
    console.error("[Verifier] Stack:", e.stack);
    throw new Error(`Identity parsing failed: ${e.message}`);
  }
}

async function getActor() {
  const identity = getIdentity();
  const agent = new HttpAgent({ host: DFX_HOST, identity });
  
  console.log("[Verifier] Creating actor for canister:", CHEDDA_CANISTER_ID);
  console.log("[Verifier] Using host:", DFX_HOST);
  
  return Actor.createActor(idlFactory, { 
    agent, 
    canisterId: CHEDDA_CANISTER_ID 
  }) as unknown as CanisterActor;
}

async function verifyIdToken(
  provider: "google" | "apple",
  idToken: string,
  expectedNonce?: string
) {
  const cfg = PROVIDERS[provider];
  assert(cfg, "Unsupported provider");

  const JWKS = createRemoteJWKSet(new URL(cfg.jwks));
  
  // First, decode the token without verification to check the audience
  const tokenParts = idToken.split('.');
  assert(tokenParts.length === 3, "Invalid JWT format");
  
  const payloadJson = Buffer.from(tokenParts[1], 'base64url').toString('utf8');
  const decodedPayload = JSON.parse(payloadJson);
  
  console.log(`[Verifier] ${provider.toUpperCase()} token audience:`, decodedPayload.aud);
  console.log(`[Verifier] Expected audiences:`, cfg.audiences);
  
  // Check if the audience matches any of our valid audiences
  const audienceMatch = cfg.audiences.includes(decodedPayload.aud);
  
  if (!audienceMatch) {
    console.error(`[Verifier] Audience mismatch!`);
    console.error(`[Verifier] Token aud: "${decodedPayload.aud}"`);
    console.error(`[Verifier] Valid audiences: [${cfg.audiences.join(', ')}]`);
    
    // For Apple, provide helpful message about "Hide My Email"
    if (provider === "apple") {
      throw new Error(
        `Apple token audience mismatch. ` +
        `This may be due to "Hide My Email" selection. ` +
        `Expected: ${cfg.audiences[0]}, Got: ${decodedPayload.aud}. ` +
        `Please ensure APPLE_BUNDLE_ID is set in environment variables.`
      );
    }
    
    throw new Error(`Token audience mismatch: expected one of [${cfg.audiences.join(', ')}], got: ${decodedPayload.aud}`);
  }
  
  console.log(`[Verifier] ✅ Audience validated: ${decodedPayload.aud}`);
  
  // Now verify the token signature (skip audience check since we did it manually)
  const { payload } = await jwtVerify(idToken, JWKS, {
    issuer: cfg.issuer,
    // Don't check audience in jwtVerify since we already validated it above
    audience: undefined,
  });

  assert(payload.sub, "Missing sub");

  // Apple nonce validation - make it optional
  if (provider === "apple" && expectedNonce) {
    if (payload.nonce) {
      assert(payload.nonce === expectedNonce, "Nonce mismatch");
      console.log("[Verifier] ✅ Nonce validated");
    } else {
      console.warn("[Verifier] ⚠️ No nonce in Apple token (expected when using nonce)");
    }
  }

  // Extract email
  let email: string | null = null;
  let isPrivateRelay = false;
  
  if (typeof payload.email === "string") {
    email = payload.email;
    
    // Detect Apple Private Relay
    if (provider === "apple" && email.includes("@privaterelay.appleid.com")) {
      isPrivateRelay = true;
      console.log("[Verifier] 🔒 User selected 'Hide My Email'");
      console.log("[Verifier] Private relay address:", email);
    }
  } else if (provider === "apple" && typeof payload.sub === "string") {
    // Fallback for Apple if no email provided
    email = `apple:${payload.sub}@apple.local`;
    console.warn("[Verifier] No email in Apple token, using fallback");
  }

  console.log("[Verifier] Email extraction result:", {
    hasEmail: !!email,
    isPrivateRelay,
    emailDomain: email?.split('@')[1] || 'none'
  });

  return { 
    sub: String(payload.sub), 
    email,
    isPrivateRelay,
    audience: String(payload.aud)
  };
}

// ==========================
// Handler
// ==========================
export const handler = async (event: any) => {
  const origin = event?.headers?.origin as string | undefined;

  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 204, headers: corsHeaders(origin), body: "" };
  }

  try {
    assert(event.httpMethod === "POST", "Use POST");

    const body = JSON.parse(event.body || "{}");
    const provider = body.provider as "google" | "apple";
    const id_token = body.id_token as string;
    const nonce = body.nonce as string | undefined;

    assert(provider === "google" || provider === "apple", "Bad provider");
    assert(typeof id_token === "string" && id_token.length > 100, "Bad token");

    console.log("[Verifier] ========================================");
    console.log("[Verifier] Starting verification for provider:", provider);
    if (nonce) {
      console.log("[Verifier] Nonce provided:", nonce.substring(0, 10) + "...");
    } else {
      console.log("[Verifier] No nonce provided");
    }
    console.log("[Verifier] ========================================");

    // Step 1: Verify the token
    const { sub, email, isPrivateRelay, audience } = await verifyIdToken(
      provider, 
      id_token, 
      nonce
    );
    
    console.log("[Verifier] ✅ Token verified:", { 
      sub, 
      email: email || "none",
      isPrivateRelay,
      audience,
      provider 
    });

    // Step 2: Get actor
    const actorInstance = await getActor();
    console.log("[Verifier] ✅ Actor created successfully");

    // Step 3: Prepare parameters
    const idpVariant: AuthType = provider === "google" 
      ? { google: null } 
      : { apple: null };
    
    const emailOpt: [] | [string] = email ? [email] : [];
    
    console.log("[Verifier] Calling canister with:", {
      provider,
      sub,
      hasEmail: !!email,
      emailType: isPrivateRelay ? "private-relay" : "direct",
      nonce: nonce || "none"
    });

    // Step 4: Call canister
    const result = await actorInstance.createSessionForVerifiedUser(
      idpVariant,
      sub,
      emailOpt,
      nonce ?? ""
    );

    console.log("[Verifier] ✅ Canister call completed");

    // Step 5: Handle result
    if ("err" in result) {
      console.error("[Verifier] ❌ Canister returned error:", result.err);
      return {
        statusCode: 401,
        headers: corsHeaders(origin),
        body: JSON.stringify({ ok: false, error: result.err }),
      };
    }

    const session = result.ok;
    console.log("[Verifier] Session created, serializing...");

    // Step 6: Serialize session (handle bigints and variants)
    let authTypeString = "unknown";
    if (session.authType && typeof session.authType === "object") {
      if ("google" in session.authType) {
        authTypeString = "google";
      } else if ("apple" in session.authType) {
        authTypeString = "apple";
      }
    }

    const serializedSession = {
      sessionId: String(session.sessionId),
      email: String(session.email),
      nickname: String(session.nickname),
      authType: authTypeString,
      created: Number(session.created),
      expires: Number(session.expires),
      lastUsed: Number(session.lastUsed),
      isPrivateRelay,  // Include this info for the client
    };

    console.log("[Verifier] ✅ Success! SessionId:", serializedSession.sessionId);
    if (isPrivateRelay) {
      console.log("[Verifier] 🔒 Session uses Apple Private Relay");
    }
    console.log("[Verifier] ========================================");

    return {
      statusCode: 200,
      headers: corsHeaders(origin),
      body: JSON.stringify({ ok: true, session: serializedSession }),
    };
    
  } catch (e: any) {
    console.error("[Verifier] ❌ ERROR:", e.message);
    console.error("[Verifier] Stack:", e?.stack);
    
    return {
      statusCode: 401,
      headers: corsHeaders(origin),
      body: JSON.stringify({ 
        ok: false, 
        error: String(e?.message || e) 
      }),
    };
  }
};
