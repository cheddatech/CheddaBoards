// ════════════════════════════════════════════════════════════════════════════════
// CheddaBoards ApiKeys Module
// API key generation, validation, and management
// ════════════════════════════════════════════════════════════════════════════════

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Result "mo:base/Result";

import Types "../types";

module {

  // ════════════════════════════════════════════════════════════════════════════
  // TYPES
  // ════════════════════════════════════════════════════════════════════════════

  public type ApiKey = Types.ApiKey;
  public type ApiKeyMap = HashMap.HashMap<Text, ApiKey>;

  /// Validation result for quick lookups
  public type ValidationInfo = {
    gameId : Text;
    tier : Text;
    isActive : Bool;
  };

  /// Result type for operations that modify state
  public type KeyResult = {
    keys : [(Text, ApiKey)];  // Updated entries to put
    result : Result.Result<Text, Text>;
  };

  // ════════════════════════════════════════════════════════════════════════════
  // KEY GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Generate a unique API key string
  public func generateKeyString(gameId : Text) : Text {
    let timestamp = Int.toText(Time.now());
    let combined = gameId # "_" # timestamp;
    let hash = Text.hash(combined);
    "cb_" # gameId # "_" # Nat32.toText(hash)
  };

  /// Create a new API key record
  public func createKey(gameId : Text, owner : Principal) : ApiKey {
    let currentTime = Time.now();
    {
      key = generateKeyString(gameId);
      gameId = gameId;
      owner = owner;
      created = currentTime;
      lastUsed = currentTime;
      tier = "free";
      requestsToday = 0;
      isActive = true;
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // LOOKUP FUNCTIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Check if a game already has an active API key
  public func hasActiveKey(keys : ApiKeyMap, gameId : Text) : Bool {
    for ((_, apiKey) in keys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return true;
      };
    };
    false
  };

  /// Get the active API key for a game (returns the key string)
  public func getActiveKey(keys : ApiKeyMap, gameId : Text) : ?Text {
    for ((key, apiKey) in keys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return ?key;
      };
    };
    null
  };

  /// Validate an API key (query - no state changes)
  public func validate(keys : ApiKeyMap, key : Text) : ?ValidationInfo {
    switch (keys.get(key)) {
      case null { null };
      case (?apiKey) {
        if (apiKey.isActive) {
          ?{ gameId = apiKey.gameId; tier = apiKey.tier; isActive = true }
        } else { null }
      };
    }
  };

  /// Validate and get full API key record
  public func validateFull(keys : ApiKeyMap, key : Text) : ?ApiKey {
    switch (keys.get(key)) {
      case null { null };
      case (?apiKey) {
        if (apiKey.isActive) { ?apiKey } else { null }
      };
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // MUTATION FUNCTIONS (return updated records)
  // ════════════════════════════════════════════════════════════════════════════

  /// Update lastUsed timestamp and increment request count
  /// Returns the updated ApiKey to be stored
  public func recordUsage(apiKey : ApiKey) : ApiKey {
    {
      key = apiKey.key;
      gameId = apiKey.gameId;
      owner = apiKey.owner;
      created = apiKey.created;
      lastUsed = Time.now();
      tier = apiKey.tier;
      requestsToday = apiKey.requestsToday + 1;
      isActive = apiKey.isActive;
    }
  };

  /// Revoke an API key (set isActive = false)
  /// Returns the revoked key to be stored
  public func revoke(apiKey : ApiKey) : ApiKey {
    {
      key = apiKey.key;
      gameId = apiKey.gameId;
      owner = apiKey.owner;
      created = apiKey.created;
      lastUsed = apiKey.lastUsed;
      tier = apiKey.tier;
      requestsToday = apiKey.requestsToday;
      isActive = false;
    }
  };

  /// Update the tier of an API key
  /// Returns the updated key to be stored
  public func updateTier(apiKey : ApiKey, newTier : Text) : ApiKey {
    {
      key = apiKey.key;
      gameId = apiKey.gameId;
      owner = apiKey.owner;
      created = apiKey.created;
      lastUsed = Time.now();
      tier = newTier;
      requestsToday = apiKey.requestsToday;
      isActive = apiKey.isActive;
    }
  };

  /// Find and revoke the active key for a game
  /// Returns the key string and revoked record if found
  public func revokeForGame(keys : ApiKeyMap, gameId : Text) : ?(Text, ApiKey) {
    for ((key, apiKey) in keys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return ?(key, revoke(apiKey));
      };
    };
    null
  };

  /// Find and update tier for a game's active key
  /// Returns the key string and updated record if found
  public func updateTierForGame(keys : ApiKeyMap, gameId : Text, newTier : Text) : ?(Text, ApiKey) {
    for ((key, apiKey) in keys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return ?(key, updateTier(apiKey, newTier));
      };
    };
    null
  };

  // ════════════════════════════════════════════════════════════════════════════
  // VALIDATION HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Check if a tier string is valid
  public func isValidTier(tier : Text) : Bool {
    tier == "free" or tier == "indie" or tier == "pro" or tier == "enterprise"
  };

  /// Get rate limits for a tier
  public func getRateLimits(tier : Text) : { perMinute : Nat; perHour : Nat } {
    switch (tier) {
      case "enterprise" { { perMinute = 1000; perHour = 100000 } };
      case "pro" { { perMinute = 200; perHour = 10000 } };
      case "indie" { { perMinute = 100; perHour = 5000 } };
      case _ { { perMinute = 50; perHour = 1000 } };  // free tier
    }
  };

}
