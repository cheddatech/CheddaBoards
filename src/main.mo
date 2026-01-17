// main.mo - CheddaBoards Backend
// NOTE: Behaviour frozen as of 2026-01-15
// Refactor in progress — no logic changes intended
//
// ⚠️  SETUP REQUIRED: Search for "REPLACE WITH YOUR" and set:
//     - VERIFIER: Your OAuth token verifier canister principal
//     - CONTROLLER: Your super admin principal (usually your dfx identity)
//     - firstAdmin: Initial admin principal (can be same as CONTROLLER)
//
// See README for deployment instructions.

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";
import Random "mo:base/Random";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Error "mo:base/Error";
import Char "mo:base/Char";

persistent actor CheddaBoards {

  // ════════════════════════════════════════════════════════════════════════════
  // TYPES
  // ════════════════════════════════════════════════════════════════════════════

  // ==================== SECURITY TYPES ====================

  type AdminRole = {
    #SuperAdmin;
    #Moderator;
    #Support;
    #ReadOnly;
  };

  type AdminAction = {
    timestamp : Nat64;
    admin : Principal;
    adminRole : AdminRole;
    command : Text;
    args : [Text];
    success : Bool;
    result : Text;
    ipAddress : ?Text;
  };

  type DeletedGame = {
    game : GameInfo;
    deletedBy : Principal;
    deletedAt : Nat64;
    permanentDeletionAt : Nat64;
    reason : Text;
    canRecover : Bool;
  };

  type DeletionAttempt = {
    timestamp : Nat64;
    gameId : Text;
  };

  type DeletedUser = {
    user : UserProfile;
    deletedBy : Principal;
    deletedAt : Nat64;
    permanentDeletionAt : Nat64;
    reason : Text;
    canRecover : Bool;
  };

  type PendingDeletion = {
    userId : Text;
    userType : Text;
    requestedBy : Principal;
    requestedAt : Nat64;
    confirmationCode : Text;
    expiresAt : Nat64;
  };

  type BackupData = {
    version : Text;
    timestamp : Nat64;
    createdBy : Principal;
    emailUsers : [(Text, UserProfile)];
    principalUsers : [(Principal, UserProfile)];
    games : [(Text, GameInfo)];
    deletedUsers : [(Text, DeletedUser)];
    metadata : {
      totalUsers : Nat;
      totalGames : Nat;
      totalGameProfiles : Nat;
      totalDeletedUsers : Nat;
    };
  };

  type HeaderField = (Text, Text);

  type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };

  type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?StreamingStrategy;
  };

  type StreamingStrategy = {
    #Callback : {
      callback : shared query StreamingCallbackToken -> async StreamingCallbackResponse;
      token : StreamingCallbackToken;
    };
  };

  type StreamingCallbackToken = {
    key : Text;
    index : Nat;
    content_encoding : Text;
  };

  type StreamingCallbackResponse = {
    body : Blob;
    token : ?StreamingCallbackToken;
  };

  public type UserIdentifier = {
    #email: Text;
    #principal: Principal;
  };

  public type AuthType = {
    #internetIdentity;
    #google;
    #apple;
    #external;
  };

  type DeveloperTier = {
    #free;      // 3 games
    #pro;       // 10 games
};

  public type Session = {
    sessionId : Text;
    email : Text;
    nickname : Text;
    authType : AuthType;
    created : Nat64;
    expires : Nat64;
    lastUsed : Nat64;
  };

  public type GameProfile = {
    gameId : Text;
    total_score : Nat64;
    best_streak : Nat64;
    achievements : [Text];
    last_played : Nat64;
    play_count : Nat;
  };

  public type UserProfile = {
    identifier : UserIdentifier;
    nickname : Text;
    authType : AuthType;
    gameProfiles : [(Text, GameProfile)];
    created : Nat64;
    last_updated : Nat64;
  };

  public type PublicUserProfile = {
    nickname : Text;
    authType : AuthType;
    gameProfiles : [(Text, GameProfile)];
    created : Nat64;
    last_updated : Nat64;
  };

  public type AccessMode = {
    #webOnly; 
    #apiOnly;  
    #both;
  };

  type GameInfoLegacy = {
    gameId: Text;
    name: Text;
    description: Text;
    owner: Principal;
    created: Nat64;
    isActive: Bool;
    totalPlayers: Nat;
    totalPlays: Nat;
    accessMode: AccessMode;
    maxScorePerRound: ?Nat64;
    maxStreakDelta: ?Nat64;
    absoluteScoreCap: ?Nat64;
    absoluteStreakCap: ?Nat64;
    gameUrl: ?Text;
};

// V2 type - with OAuth fields but without time validation (currently deployed)
type GameInfoV2 = {
    gameId: Text;
    name: Text;
    description: Text;
    owner: Principal;
    created: Nat64;
    isActive: Bool;
    totalPlayers: Nat;
    totalPlays: Nat;
    accessMode: AccessMode;
    maxScorePerRound: ?Nat64;
    maxStreakDelta: ?Nat64;
    absoluteScoreCap: ?Nat64;
    absoluteStreakCap: ?Nat64;
    gameUrl: ?Text;
    googleClientIds: [Text];
    appleBundleId: ?Text;
    appleTeamId: ?Text;
};

type DeletedGameV2 = {
    game: GameInfoV2;
    deletedBy: Principal;
    deletedAt: Nat64;
    permanentDeletionAt: Nat64;
    reason: Text;
    canRecover: Bool;
};

type DeletedGameLegacy = {
    game: GameInfoLegacy;
    deletedBy: Principal;
    deletedAt: Nat64;
    permanentDeletionAt: Nat64;
    reason: Text;
    canRecover: Bool;
};

public type GameInfo = {
  gameId : Text;
  name : Text;
  description : Text;
  owner : Principal;
  gameUrl : ?Text;
  created : Nat64;
  accessMode : AccessMode;
  totalPlayers : Nat;
  totalPlays : Nat;
  isActive : Bool;
  maxScorePerRound : ?Nat64;
  maxStreakDelta : ?Nat64;
  absoluteScoreCap : ?Nat64;
  absoluteStreakCap : ?Nat64;
  timeValidationEnabled : Bool;       // Master toggle for this feature
  minPlayDurationSecs : ?Nat64;       // e.g., 30 = must play at least 30 seconds
  maxScorePerSecond : ?Nat64;         // e.g., 500 = max 500 points per second played
  maxSessionDurationMins : ?Nat;      // e.g., 60 = sessions expire after 60 mins (default 30)
  googleClientIds : [Text];
  appleBundleId : ?Text;
  appleTeamId : ?Text;   
};

  public type AnalyticsEvent = {
    eventType : Text;
    gameId : Text;
    identifier : UserIdentifier;
    timestamp : Nat64;
    metadata : [(Text, Text)];
  };

  public type DailyStats = {
    date : Text;
    gameId : Text;
    uniquePlayers : Nat;
    totalGames : Nat;
    totalScore : Nat64;
    newUsers : Nat;
    authenticatedPlays : Nat;
  };

  public type PlayerStats = {
    gameId : Text;
    identifier : UserIdentifier;
    totalGames : Nat;
    avgScore : Nat64;
    playStreak : Nat;
    lastPlayed : Nat64;
    favoriteTime : Text;
  };

  public type ApiKey = {
    key : Text;
    gameId : Text;
    owner : Principal;
    created : Int;
    lastUsed : Int;
    tier : Text;   
    requestsToday : Nat;
    isActive : Bool;
  };

  public type SortBy = { #score; #streak };

  // ==================== PLAY SESSION TYPES ====================

  type PlaySession = {
    sessionToken: Text;           // Unique token for this play session
    identifier: UserIdentifier;   // Who's playing
    gameId: Text;                 // Which game
    startedAt: Nat64;             // When they started (server timestamp)
    expiresAt: Nat64;             // Auto-expire if not submitted (prevents token hoarding)
    isActive: Bool;               // Still valid for submission
  };

  type TimeValidationResult = {
    isValid: Bool;
    playDuration: Nat64;          // Actual seconds played
    reason: ?Text;                // Why it failed (if invalid)
  };

  // ==================== SCOREBOARD TYPES ====================

  // Period type for scoreboards
  public type ScoreboardPeriod = {
    #allTime;    // Never resets
    #daily;      // Resets daily at midnight UTC
    #weekly;     // Resets weekly on Monday midnight UTC
    #monthly;    // Resets on 1st of each month
    #custom;     // Manual reset by developer
  };

  // Scoreboard configuration (set by developer)
  public type ScoreboardConfig = {
    scoreboardId : Text;        // Unique ID within the game
    gameId : Text;              // Parent game
    name : Text;                // Display name (e.g., "Weekly Leaderboard")
    description : Text;         // Optional description
    period : ScoreboardPeriod;  // Reset period
    sortBy : SortBy;            // Sort by score or streak
    maxEntries : Nat;           // Max entries to track (default 100)
    created : Nat64;
    lastReset : Nat64;          // Last time this scoreboard was reset
    isActive : Bool;
  };

  // Individual score entry for a scoreboard
  public type ScoreEntry = {
    odentifier : UserIdentifier;  // Who submitted (named for backwards compat)
    nickname : Text;
    score : Nat64;
    streak : Nat64;
    submittedAt : Nat64;          // When this score was submitted
    authType : AuthType;
  };

  // Public view of a scoreboard entry (no identifier exposed)
  public type PublicScoreEntry = {
    nickname : Text;
    score : Nat64;
    streak : Nat64;
    submittedAt : Nat64;
    authType : Text;
    rank : Nat;
  };

  // Full scoreboard with entries
  public type Scoreboard = {
    config : ScoreboardConfig;
    entries : [ScoreEntry];
  };

  public type ArchivedScoreboard = {
    scoreboardId : Text;        // Which scoreboard this archive is from
    gameId : Text;              // Parent game
    name : Text;                // Display name at time of archive
    period : ScoreboardPeriod;  // weekly, daily, monthly, etc.
    sortBy : SortBy;            // score or streak
    periodStart : Nat64;        // When this period started
    periodEnd : Nat64;          // When this period ended (reset time)
    entries : [ScoreEntry];     // Frozen entries at time of reset
    totalEntries : Nat;         // Count of entries
  };

  // Archive query result (lighter weight for listing)
  public type ArchiveInfo = {
    archiveId : Text;           // "gameId:scoreboardId:timestamp"
    scoreboardId : Text;        // Which scoreboard
    periodStart : Nat64;        // When period started
    periodEnd : Nat64;          // When period ended
    entryCount : Nat;           // How many entries
    topPlayer : ?Text;          // Nickname of #1 player
    topScore : Nat64;           // Top score/streak value
  };

  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // TODO: Set via deployment - this is your OAuth token verifier canister
  let VERIFIER : Principal = Principal.fromText("aaaaa-aa"); // REPLACE WITH YOUR VERIFIER PRINCIPAL

  // ════════════════════════════════════════════════════════════════════════════
  // STABLE STORAGE
  // ════════════════════════════════════════════════════════════════════════════
  private var alternativeOriginsStable : [Text] = [];
  private var stableUsersByEmail : [(Text, UserProfile)] = [];
  private var stableUsersByPrincipal : [(Principal, UserProfile)] = [];
  stable var stableGames : [(Text, GameInfoLegacy)] = []; 
  stable var deletedGamesEntries : [(Text, DeletedGameLegacy)] = [];

// V2 stable vars (currently deployed - with OAuth, without time validation)
  stable var stableGamesV2 : [(Text, GameInfoV2)] = [];
  stable var deletedGamesEntriesV2 : [(Text, DeletedGameV2)] = [];

// V3 stable vars (new format - with time validation)
  stable var stableGamesV3 : [(Text, GameInfo)] = [];
  stable var deletedGamesEntriesV3 : [(Text, DeletedGame)] = [];
  
  stable var oauthMigrationDone : Bool = false;
  stable var timeValidationMigrationDone : Bool = false;
  
  private var stableSessions : [(Text, Session)] = [];
  private var stableSuspicionLog : [{ player_id : Text; gameId : Text; reason : Text; timestamp : Nat64 }] = [];
  private var stableFiles : [(Text, Blob)] = [];
  private var stableAnalyticsEvents : [AnalyticsEvent] = [];
  private var stableDailyStats : [(Text, DailyStats)] = [];
  private var stablePlayerStats : [(Text, PlayerStats)] = [];
  private var stableLastSubmitTime : [(Text, Nat64)] = [];
  private var sessionCounter : Nat64 = 0;
  private var deleteRateLimitEntries : [(Principal, [DeletionAttempt])] = [];
  private var apiKeysStable : [(Text, ApiKey)] = [];
  private var developerTiersStable : [(Principal, DeveloperTier)] = [];
  // Scoreboard stable storage
  private var scoreboardConfigsStable : [(Text, ScoreboardConfig)] = [];
  private var scoreboardEntriesStable : [(Text, [ScoreEntry])] = [];
  private var scoreboardConfigsStableV2 : [(Text, ScoreboardConfig)] = [];
  private var scoreboardEntriesStableV2 : [(Text, [ScoreEntry])] = [];
  private var scoreboardArchivesStable : [(Text, ArchivedScoreboard)] = [];
  private var scoreboardArchivesStableV2 : [(Text, ArchivedScoreboard)] = [];
  private var userIdCounter : Nat = 0;
  var totalSubmissions : Nat = 0;
  var submissionsToday : Nat = 0;
  var lastResetDate : Text = "";

  private var playSessionsStable : [(Text, PlaySession)] = [];

  // ════════════════════════════════════════════════════════════════════════════
  // RUNTIME MAPS
  // ════════════════════════════════════════════════════════════════════════════
  private transient var alternativeOrigins = Buffer.Buffer<Text>(10);
  private transient var deletedGames = HashMap.HashMap<Text, DeletedGame>(10, Text.equal, Text.hash);
  private transient var deleteRateLimit = HashMap.HashMap<Principal, [DeletionAttempt]>(10, Principal.equal, Principal.hash);
  private transient var usersByEmail = HashMap.HashMap<Text, UserProfile>(10, Text.equal, Text.hash);
  private transient var usersByPrincipal = HashMap.HashMap<Principal, UserProfile>(10, Principal.equal, Principal.hash);
  private transient var games = HashMap.HashMap<Text, GameInfo>(10, Text.equal, Text.hash);
  private transient var sessions = HashMap.HashMap<Text, Session>(10, Text.equal, Text.hash);
  private transient var lastSubmitTime = HashMap.HashMap<Text, Nat64>(10, Text.equal, Text.hash);
  private transient var cachedLeaderboards = HashMap.HashMap<Text, [(Text, Nat64, Nat64, Text)]>(10, Text.equal, Text.hash);
  private transient var leaderboardLastUpdate = HashMap.HashMap<Text, Nat64>(10, Text.equal, Text.hash);
  private transient let LEADERBOARD_CACHE_TTL : Nat64 = 60_000_000_000;
  private transient var analyticsEvents = Buffer.Buffer<AnalyticsEvent>(100);
  private transient var dailyStats = HashMap.HashMap<Text, DailyStats>(10, Text.equal, Text.hash);
  private transient var playerStats = HashMap.HashMap<Text, PlayerStats>(10, Text.equal, Text.hash);
  private transient var apiKeys = HashMap.HashMap<Text, ApiKey>(50, Text.equal, Text.hash);
  private transient var suspicionLog : List.List<{ player_id : Text; gameId : Text; reason : Text; timestamp : Nat64 }> = List.nil();
  private transient var files : List.List<(Text, Blob)> = List.nil();
  private transient var sessionsEntries : [(Text, Session)] = [];
  private transient var principalToSessionEntries : [(Text, Text)] = [];
  private transient var principalToSession = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);
  private transient var developerTiers = HashMap.HashMap<Principal, DeveloperTier>(10, Principal.equal, Principal.hash);
  
  // Scoreboard runtime maps
  private transient var scoreboardConfigs = HashMap.HashMap<Text, ScoreboardConfig>(50, Text.equal, Text.hash);
  private transient var scoreboardEntries = HashMap.HashMap<Text, Buffer.Buffer<ScoreEntry>>(50, Text.equal, Text.hash);
  private transient var cachedScoreboards = HashMap.HashMap<Text, [PublicScoreEntry]>(50, Text.equal, Text.hash);
  private transient var scoreboardLastUpdate = HashMap.HashMap<Text, Nat64>(50, Text.equal, Text.hash);
  private transient let SCOREBOARD_CACHE_TTL : Nat64 = 30_000_000_000; // 30 seconds
  private transient var scoreboardArchives = HashMap.HashMap<Text, ArchivedScoreboard>(100, Text.equal, Text.hash);
  private let MAX_ARCHIVES_PER_SCOREBOARD : Nat = 52;     // Config: how many archives to keep per scoreboard (52 weeks = 1 year)
  private transient var playSessions = HashMap.HashMap<Text, PlaySession>(100, Text.equal, Text.hash);

  // ════════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ════════════════════════════════════════════════════════════════════════════

  // TODO: Set via deployment - this is the super admin principal
  private var CONTROLLER : Principal = Principal.fromText("aaaaa-aa"); // REPLACE WITH YOUR CONTROLLER PRINCIPAL
  private transient let MAX_FILE_SIZE : Nat = 5_000_000;
  private transient let MAX_FILES : Nat = 100;
  private transient let SESSION_DURATION_NS : Nat64 = 24 * 60 * 60 * 1_000_000_000;
  private transient var lastCleanup : Nat64 = 0;
  private transient let MAX_GAMES_PER_DEVELOPER : Nat = 3;
  private var adminRolesStable : [(Principal, AdminRole)] = [];
  private var auditLogStable : [AdminAction] = [];
  private var deletedUsersStable : [(Text, DeletedUser)] = [];
  private var emergencyPaused : Bool = false;

  private transient var adminRoles = HashMap.fromIter<Principal, AdminRole>(
    adminRolesStable.vals(), 10, Principal.equal, Principal.hash
  );

  private transient var deletedUsers = HashMap.fromIter<Text, DeletedUser>(
    deletedUsersStable.vals(), 10, Text.equal, Text.hash
  );

  private transient var lastCommandTime = HashMap.HashMap<(Principal, Text), Nat64>(
    10,
    func(a: (Principal, Text), b: (Principal, Text)) : Bool { 
      Principal.equal(a.0, b.0) and Text.equal(a.1, b.1)
    },
    func(x: (Principal, Text)) : Hash.Hash {
      Principal.hash(x.0)
    }
  );

  private transient var pendingDeletions = HashMap.HashMap<Text, PendingDeletion>(
    10, Text.equal, Text.hash
  );

  private transient var auditLog = Buffer.Buffer<AdminAction>(100);

  private transient let DEFAULT_SESSION_DURATION_MINS : Nat = 30;
  private transient let MAX_ACTIVE_SESSIONS_PER_PLAYER : Nat = 3;  // Prevent token hoarding

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  func now() : Nat64 = Nat64.fromIntWrap(Time.now());

  public query func debugDataState() : async {
    legacyGamesCount: Nat;
    legacyDeletedCount: Nat;
    v2GamesCount: Nat;
    v2DeletedCount: Nat;
    runtimeGamesCount: Nat;
    runtimeDeletedCount: Nat;
    migrationDone: Bool;
} {
    {
        legacyGamesCount = stableGames.size();
        legacyDeletedCount = deletedGamesEntries.size();
        v2GamesCount = stableGamesV2.size();
        v2DeletedCount = deletedGamesEntriesV2.size();
        runtimeGamesCount = games.size();
        runtimeDeletedCount = deletedGames.size();
        migrationDone = oauthMigrationDone;
    }
};

  private func generateDefaultNickname() : Text {
    userIdCounter += 1;
    "Player_" # Nat.toText(userIdCounter)
  };

  private func isDefaultNickname(nickname : Text) : Bool {
    nickname == "Player" or Text.startsWith(nickname, #text "Player_")
  };

  private func isNicknameTaken(nickname : Text, excludeIdentifier : ?UserIdentifier) : Bool {
    // Check email users
    for ((_, user) in usersByEmail.entries()) {
        if (user.nickname == nickname) {
            switch (excludeIdentifier) {
                case (?id) {
                    if (identifierToText(user.identifier) != identifierToText(id)) {
                        return true;
                    };
                };
                case null { return true };
            };
        };
    };
    
    // Check principal users
    for ((_, user) in usersByPrincipal.entries()) {
        if (user.nickname == nickname) {
            switch (excludeIdentifier) {
                case (?id) {
                    if (identifierToText(user.identifier) != identifierToText(id)) {
                        return true;
                    };
                };
                case null { return true };
            };
        };
    };
    
    false
  };

  private func looksLikeEmail(text : Text) : Bool {
    Text.contains(text, #char '@')
  };
  
  private func getMaxGamesForDeveloper(owner: Principal) : Nat {
    switch (developerTiers.get(owner)) {
        case (?#pro) { 10 };
        case (_) { 3 };  // free tier default
    }
};

private func getDeveloperTierText(owner: Principal) : Text {
    switch (developerTiers.get(owner)) {
        case (?#pro) { "pro" };
        case (_) { "free" };
    }
};

  func generateSessionId() : Text {
    sessionCounter += 1;
    let timestamp = now();
    let _random = Random.Finite(Blob.fromArray([1,2,3,4,5,6,7,8]));
    "session_" # Nat64.toText(timestamp) # "_" # Nat64.toText(sessionCounter)
  };

  func authTypeToText(auth : AuthType) : Text {
    switch (auth) {
      case (#internetIdentity) "internetIdentity";
      case (#google) "google";
      case (#apple) "apple";
      case (#external) "external";
    }
  };

  func accessModeToText(mode : AccessMode) : Text {
    switch (mode) {
      case (#webOnly) "webOnly";
      case (#apiOnly) "apiOnly";
      case (#both) "both";
    }
  };

  func identifierToText(id : UserIdentifier) : Text {
    switch (id) {
      case (#email(e)) "email:" # e;
      case (#principal(p)) "principal:" # Principal.toText(p);
    }
  };

  func makeSubmitKey(identifier : UserIdentifier, gameId : Text) : Text {
    identifierToText(identifier) # ":" # gameId
  };

  func logSuspicion(playerId : Text, gameId : Text, reason : Text) {
    suspicionLog := List.push({
      player_id = playerId;
      gameId = gameId;
      reason = reason;
      timestamp = now();
    }, suspicionLog);
  };

  private func isAdmin(caller: Principal) : Bool {
    if (caller == CONTROLLER) {
      return true;
    };
    Option.isSome(adminRoles.get(caller))
  };

  func getDateString(timestamp : Nat64) : Text {
    let day = timestamp / 86_400_000_000_000;
    "day-" # Nat64.toText(day)
  };

  func getTimeOfDay(timestamp : Nat64) : Text {
    let hour = (timestamp / 3_600_000_000_000) % 24;
    if (hour < 6) { "night" }
    else if (hour < 12) { "morning" }
    else if (hour < 18) { "afternoon" }
    else { "evening" }
  };

  // Validate external player ID format
  private func isValidExternalPlayerId(playerId : Text) : Bool {
    let size = Text.size(playerId);
    if (size == 0 or size > 100) {
      return false;
    };
    // Allow alphanumeric, underscore, hyphen
    for (char in playerId.chars()) {
      let valid = Char.isAlphabetic(char) or 
                  Char.isDigit(char) or 
                  char == '_' or 
                  char == '-';
      if (not valid) {
        return false;
      };
    };
    true
  };

  func cleanupExpiredSessions() {
    let currentTime = now();
    let sessionEntries = Iter.toArray(sessions.entries());
    
    var cleanedCount = 0;
    for ((sessionId, session) in sessionEntries.vals()) {
      if (currentTime > session.expires) {
        sessions.delete(sessionId);
        cleanedCount += 1;
      };
    };
  };

  func trackEventInternal(identifier: UserIdentifier, gameId: Text, eventType : Text, metadata : [(Text, Text)]) : () {
    let event : AnalyticsEvent = {
      eventType = eventType;
      gameId = gameId;
      identifier = identifier;  
      timestamp = now();
      metadata = metadata;
    };
    
    analyticsEvents.add(event);
    
    if (analyticsEvents.size() > 10000) {
      let newBuffer = Buffer.Buffer<AnalyticsEvent>(10000);
      let startIdx : Nat = Int.abs(+analyticsEvents.size() - 10000);
      for (i in Iter.range(startIdx, analyticsEvents.size() - 1)) {
        newBuffer.add(analyticsEvents.get(i));
      };
      analyticsEvents := newBuffer;
    };
    
    let dateStr = getDateString(event.timestamp);
    let statsKey = dateStr # ":" # gameId;
    
    switch (dailyStats.get(statsKey)) {
      case (?stats) {
        let updated = {
          date = stats.date;
          gameId = gameId;
          uniquePlayers = stats.uniquePlayers;
          totalGames = if (eventType == "game_end") { stats.totalGames + 1 } else { stats.totalGames };
          totalScore = stats.totalScore;
          newUsers = if (eventType == "signup") { stats.newUsers + 1 } else { stats.newUsers };
          authenticatedPlays = if (eventType == "game_end") { stats.authenticatedPlays + 1 } else { stats.authenticatedPlays };
        };
        dailyStats.put(statsKey, updated);
      };
      case null {
        dailyStats.put(statsKey, {
          date = dateStr;
          gameId = gameId;
          uniquePlayers = 1;
          totalGames = if (eventType == "game_end") { 1 } else { 0 };
          totalScore = 0;
          newUsers = if (eventType == "signup") { 1 } else { 0 };
          authenticatedPlays = if (eventType == "game_end") { 1 } else { 0 };
        });
      };
    };
    
    let playerKey = identifierToText(identifier) # ":" # gameId;
    switch (playerStats.get(playerKey)) {
      case (?stats) {
        let updated = {
          gameId = gameId;
          identifier = identifier;
          totalGames = if (eventType == "game_end") { stats.totalGames + 1 } else { stats.totalGames };
          avgScore = stats.avgScore;
          playStreak = stats.playStreak;
          lastPlayed = now();
          favoriteTime = getTimeOfDay(now());
        };
        playerStats.put(playerKey, updated);
      };
      case null {
        playerStats.put(playerKey, {
          gameId = gameId;
          identifier = identifier;
          totalGames = if (eventType == "game_end") { 1 } else { 0 };
          avgScore = 0;
          playStreak = 1;
          lastPlayed = now();
          favoriteTime = getTimeOfDay(now());
        });
      };
    };
  };

  func getValidationRules(gameId : Text) : {
    maxScorePerRound : ?Nat64;
    maxStreakDelta : ?Nat64;
    absoluteScoreCap : ?Nat64;
    absoluteStreakCap : ?Nat64;
  } {
    switch (games.get(gameId)) {
      case (?game) {
        {
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
        }
      };
      case null {
        {
          maxScorePerRound = null;
          maxStreakDelta = null;
          absoluteScoreCap = null;
          absoluteStreakCap = null;
        }
      };
    }
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // PLAY SESSION / TIME VALIDATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════════

  private func generatePlaySessionToken(identifier: UserIdentifier, gameId: Text) : Text {
    let timestamp = Int.toText(Time.now());
    let identifierText = identifierToText(identifier);
    let combined = gameId # ":" # identifierText # ":" # timestamp;
    let hash = Text.hash(combined);
    "ps_" # gameId # "_" # Nat32.toText(hash)
  };

  private func getTimeValidationRules(gameId: Text) : {
    enabled: Bool;
    minPlayDurationSecs: Nat64;
    maxScorePerSecond: Nat64;
    maxSessionDurationMins: Nat;
  } {
    switch (games.get(gameId)) {
      case (?game) {
        {
          enabled = game.timeValidationEnabled;
          minPlayDurationSecs = switch (game.minPlayDurationSecs) {
            case (?secs) { secs };
            case null { 0 };
          };
          maxScorePerSecond = switch (game.maxScorePerSecond) {
            case (?rate) { rate };
            case null { 0 };
          };
          maxSessionDurationMins = switch (game.maxSessionDurationMins) {
            case (?mins) { mins };
            case null { DEFAULT_SESSION_DURATION_MINS };
          };
        }
      };
      case null {
        {
          enabled = false;
          minPlayDurationSecs = 0;
          maxScorePerSecond = 0;
          maxSessionDurationMins = DEFAULT_SESSION_DURATION_MINS;
        }
      };
    }
  };

  private func countActiveSessionsForPlayer(identifier: UserIdentifier, gameId: Text) : Nat {
    let currentTime = now();
    var count = 0;
    
    for ((_, session) in playSessions.entries()) {
      if (identifiersEqual(session.identifier, identifier) and 
          session.gameId == gameId and 
          session.isActive and 
          currentTime < session.expiresAt) {
        count += 1;
      };
    };
    
    count
  };

  private func cleanupExpiredPlaySessions(identifier: UserIdentifier, gameId: Text) {
    let currentTime = now();
    let keysToRemove = Buffer.Buffer<Text>(5);
    
    for ((token, session) in playSessions.entries()) {
      if (identifiersEqual(session.identifier, identifier) and 
          session.gameId == gameId and 
          (currentTime >= session.expiresAt or not session.isActive)) {
        keysToRemove.add(token);
      };
    };
    
    for (key in keysToRemove.vals()) {
      playSessions.delete(key);
    };
  };

  private func validatePlaySession(
    sessionToken: Text,
    identifier: UserIdentifier,
    gameId: Text,
    score: Nat64
  ) : TimeValidationResult {
    let currentTime = now();
    
    switch (playSessions.get(sessionToken)) {
      case null {
        return {
          isValid = false;
          playDuration = 0;
          reason = ?"Invalid or expired play session. Start a new game.";
        };
      };
      case (?session) {
        if (not identifiersEqual(session.identifier, identifier)) {
          return {
            isValid = false;
            playDuration = 0;
            reason = ?"Session belongs to another player.";
          };
        };
        
        if (session.gameId != gameId) {
          return {
            isValid = false;
            playDuration = 0;
            reason = ?"Session is for a different game.";
          };
        };
        
        if (not session.isActive) {
          return {
            isValid = false;
            playDuration = 0;
            reason = ?"Session already used. Start a new game.";
          };
        };
        
        if (currentTime >= session.expiresAt) {
          return {
            isValid = false;
            playDuration = 0;
            reason = ?"Session expired. Start a new game.";
          };
        };
        
        let durationNanos = currentTime - session.startedAt;
        let durationSecs = durationNanos / 1_000_000_000;
        
        let rules = getTimeValidationRules(gameId);
        
        if (rules.minPlayDurationSecs > 0 and durationSecs < rules.minPlayDurationSecs) {
          return {
            isValid = false;
            playDuration = durationSecs;
            reason = ?("Played too quickly. Minimum " # Nat64.toText(rules.minPlayDurationSecs) # " seconds required.");
          };
        };
        
        if (rules.maxScorePerSecond > 0 and durationSecs > 0) {
          let scorePerSecond = score / durationSecs;
          if (scorePerSecond > rules.maxScorePerSecond) {
            return {
              isValid = false;
              playDuration = durationSecs;
              reason = ?"Score too high for play duration.";
            };
          };
        };
        
        {
          isValid = true;
          playDuration = durationSecs;
          reason = null;
        }
      };
    }
  };

  private func consumePlaySession(sessionToken: Text) {
    switch (playSessions.get(sessionToken)) {
      case null {};
      case (?session) {
        let consumed : PlaySession = {
          sessionToken = session.sessionToken;
          identifier = session.identifier;
          gameId = session.gameId;
          startedAt = session.startedAt;
          expiresAt = session.expiresAt;
          isActive = false;
        };
        playSessions.put(sessionToken, consumed);
      };
    };
  };

  func getUserByIdentifier(identifier : UserIdentifier) : ?UserProfile {
    switch (identifier) {
      case (#email(e)) { usersByEmail.get(e) };
      case (#principal(p)) { usersByPrincipal.get(p) };
    }
  };

  func putUserByIdentifier(user : UserProfile) {
    switch (user.identifier) {
      case (#email(e)) { usersByEmail.put(e, user) };
      case (#principal(p)) { usersByPrincipal.put(p, user) };
    }
  };

  func countGamesByOwner(owner : Principal) : Nat {
    var count = 0;
    for ((_, game) in games.entries()) {
      if (game.owner == owner) {
        count += 1;
      };
    };
    count
  };

   private func makeArchiveKey(gameId : Text, scoreboardId : Text, timestamp : Nat64) : Text {
    gameId # ":" # scoreboardId # ":" # Nat64.toText(timestamp)
  };

  // Archive a scoreboard before reset - call this before clearing entries
  private func archiveScoreboard(key : Text, config : ScoreboardConfig) : () {
    let entriesBuffer = switch (scoreboardEntries.get(key)) {
      case (?buf) { buf };
      case null { return }; // Nothing to archive
    };
    
    // Don't archive empty scoreboards
    if (entriesBuffer.size() == 0) {
      return;
    };
    
    let t = now();
    let archiveKey = makeArchiveKey(config.gameId, config.scoreboardId, t);
    
    let archive : ArchivedScoreboard = {
      scoreboardId = config.scoreboardId;
      gameId = config.gameId;
      name = config.name;
      period = config.period;
      sortBy = config.sortBy;
      periodStart = config.lastReset;
      periodEnd = t;
      entries = Buffer.toArray(entriesBuffer);
      totalEntries = entriesBuffer.size();
    };
    
    scoreboardArchives.put(archiveKey, archive);
    
    // Cleanup old archives if we have too many
    cleanupOldArchives(config.gameId, config.scoreboardId);
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // HELPER: Create default scoreboards for a new game
  // ═══════════════════════════════════════════════════════════════════════════════
  
  private func createDefaultScoreboards(gameId : Text, owner : Principal) : () {
    let currentTime = now();
    
    // Create All-Time scoreboard (by score)
    let allTimeKey = makeScoreboardKey(gameId, "all-time");
    let allTimeConfig : ScoreboardConfig = {
      scoreboardId = "all-time";
      gameId = gameId;
      name = "All Time";
      description = "Best scores of all time";
      period = #allTime;
      sortBy = #score;
      maxEntries = 100;
      created = currentTime;
      lastReset = currentTime;
      isActive = true;
    };
    scoreboardConfigs.put(allTimeKey, allTimeConfig);
    scoreboardEntries.put(allTimeKey, Buffer.Buffer<ScoreEntry>(100));
    
    // Create Weekly scoreboard (by score)
    let weeklyKey = makeScoreboardKey(gameId, "weekly");
    let weeklyConfig : ScoreboardConfig = {
      scoreboardId = "weekly";
      gameId = gameId;
      name = "Weekly";
      description = "Top scores this week";
      period = #weekly;
      sortBy = #score;
      maxEntries = 100;
      created = currentTime;
      lastReset = currentTime;
      isActive = true;
    };
    scoreboardConfigs.put(weeklyKey, weeklyConfig);
    scoreboardEntries.put(weeklyKey, Buffer.Buffer<ScoreEntry>(100));
    
    trackEventInternal(#principal(owner), gameId, "default_scoreboards_created", [
      ("scoreboards", "all-time,weekly")
    ]);
  };

  // Remove old archives beyond the limit
  private func cleanupOldArchives(gameId : Text, scoreboardId : Text) : () {
    let prefix = gameId # ":" # scoreboardId # ":";
    
    // Collect all archive keys for this scoreboard
    let archiveKeys = Buffer.Buffer<(Text, Nat64)>(10);
    for ((key, archive) in scoreboardArchives.entries()) {
      if (Text.startsWith(key, #text prefix)) {
        archiveKeys.add((key, archive.periodEnd));
      };
    };
    
    // If under limit, nothing to do
    if (archiveKeys.size() <= MAX_ARCHIVES_PER_SCOREBOARD) {
      return;
    };
    
    // Sort by timestamp (oldest first)
    let sorted = Array.sort<(Text, Nat64)>(
      Buffer.toArray(archiveKeys),
      func(a, b) {
        if (a.1 < b.1) { #less }
        else if (a.1 > b.1) { #greater }
        else { #equal }
      }
    );
    
    // Remove oldest archives
    let toRemove = sorted.size() - MAX_ARCHIVES_PER_SCOREBOARD;
    for (i in Iter.range(0, toRemove - 1)) {
      scoreboardArchives.delete(sorted[i].0);
    };
  };

    // Check if daily scoreboard should reset
  private func shouldResetDaily(lastReset : Nat64, currentTime : Nat64) : Bool {
    let dayInNanos : Nat64 = 86_400_000_000_000;
    currentTime - lastReset >= dayInNanos
  };

  // Check if weekly scoreboard should reset
  private func shouldResetWeekly(lastReset : Nat64, currentTime : Nat64) : Bool {
    let weekInNanos : Nat64 = 604_800_000_000_000;
    currentTime - lastReset >= weekInNanos
  };

  // Check if monthly scoreboard should reset
  private func shouldResetMonthly(lastReset : Nat64, currentTime : Nat64) : Bool {
    let monthInNanos : Nat64 = 2_592_000_000_000_000;
    currentTime - lastReset >= monthInNanos
  };

  private func identifiersEqual(a : UserIdentifier, b : UserIdentifier) : Bool {
    switch (a, b) {
      case (#principal(p1), #principal(p2)) { Principal.equal(p1, p2) };
      case (#email(e1), #email(e2)) { e1 == e2 };
      case _ { false };
    }
  };

 private func updateScoreboardsForGame(
    gameId : Text,
    userIdentifier : UserIdentifier,
    nickname : Text,
    score : Nat64,
    streak : Nat64,
    authType : AuthType
  ) {
    let t = now();
    let playerId = identifierToText(userIdentifier);
    
    // Get game's anti-cheat rules and validate score/streak before inserting into scoreboards
    let rules = getValidationRules(gameId);
    
    // Check maxScorePerRound (per-submission limit)
    switch (rules.maxScorePerRound) {
      case (?maxPerRound) {
        if (score > maxPerRound) {
          logSuspicion(playerId, gameId, "Score per round exceeded: " # Nat64.toText(score) # " > " # Nat64.toText(maxPerRound));
          return;
        };
      };
      case null {};
    };
    
    // Check absoluteScoreCap
    switch (rules.absoluteScoreCap) {
      case (?cap) {
        if (score > cap) {
          logSuspicion(playerId, gameId, "Absolute score cap exceeded: " # Nat64.toText(score) # " > " # Nat64.toText(cap));
          return;
        };
      };
      case null {};
    };
    
    // Check maxStreakDelta (per-submission limit)
    switch (rules.maxStreakDelta) {
      case (?maxDelta) {
        if (streak > maxDelta) {
          logSuspicion(playerId, gameId, "Streak delta exceeded: " # Nat64.toText(streak) # " > " # Nat64.toText(maxDelta));
          return;
        };
      };
      case null {};
    };
    
    // Check absoluteStreakCap
    switch (rules.absoluteStreakCap) {
      case (?cap) {
        if (streak > cap) {
          logSuspicion(playerId, gameId, "Absolute streak cap exceeded: " # Nat64.toText(streak) # " > " # Nat64.toText(cap));
          return;
        };
      };
      case null {};
    };
    
    // Iterate through all scoreboard configs
    for ((sbKey, config) in scoreboardConfigs.entries()) {
      // Only process scoreboards for this game
      if (config.gameId == gameId and config.isActive) {
        
        // Check if scoreboard needs auto-reset
        let needsReset = switch (config.period) {
          case (#daily) { shouldResetDaily(config.lastReset, t) };
          case (#weekly) { shouldResetWeekly(config.lastReset, t) };
          case (#monthly) { shouldResetMonthly(config.lastReset, t) };
          case (#allTime) { false };
          case (#custom) { false };
        };
        
        // Get or create entries buffer
        var entriesBuffer = switch (scoreboardEntries.get(sbKey)) {
          case (?buf) { buf };
          case null { Buffer.Buffer<ScoreEntry>(config.maxEntries) };
        };
      
        if (needsReset) {
          // Archive the current period before clearing
          archiveScoreboard(sbKey, config);
          
          // Clear entries for new period
          entriesBuffer := Buffer.Buffer<ScoreEntry>(config.maxEntries);
          
          // Update config with new lastReset timestamp
          scoreboardConfigs.put(sbKey, {
            scoreboardId = config.scoreboardId;
            gameId = config.gameId;
            name = config.name;
            description = config.description;
            period = config.period;
            sortBy = config.sortBy;
            maxEntries = config.maxEntries;
            created = config.created;
            lastReset = t;
            isActive = config.isActive;
          });
        };
        
        // Get the value we're comparing (score or streak based on sortBy)
        let newValue = switch (config.sortBy) {
          case (#score) { score };
          case (#streak) { streak };
        };
        
        // Find existing entry for this user (if any) - O(n) pass
        var existingEntry : ?ScoreEntry = null;
        var existingIdx : ?Nat = null;
        var idx : Nat = 0;
        
        for (entry in entriesBuffer.vals()) {
          if (identifiersEqual(entry.odentifier, userIdentifier)) {
            existingEntry := ?entry;
            existingIdx := ?idx;
          };
          idx += 1;
        };
        
        // Determine if we should update
        let existingValue = switch (existingEntry) {
          case null { 0 : Nat64 };
          case (?existing) {
            switch (config.sortBy) {
              case (#score) { existing.score };
              case (#streak) { existing.streak };
            };
          };
        };
        
        let shouldUpdate = switch (existingEntry) {
          case null { true };  // No existing entry, always add
          case (?_) { newValue > existingValue };
        };
        
        let finalValue = if (shouldUpdate) { newValue } else { existingValue };
        
        if (shouldUpdate) {
          // Create new/updated entry
          let newEntry : ScoreEntry = {
            odentifier = userIdentifier;
            nickname = nickname;
            score = if (shouldUpdate) score else (switch (existingEntry) { case (?e) e.score; case null score });
            streak = if (shouldUpdate) streak else (switch (existingEntry) { case (?e) e.streak; case null streak });
            submittedAt = t;
            authType = authType;
          };
          
          switch (existingIdx) {
            case (?i) {
              // Update in place - O(1)
              entriesBuffer.put(i, newEntry);
            };
            case null {
              // New entry - add it
              entriesBuffer.add(newEntry);
              
              // If over limit, remove the worst entry - O(n)
              if (entriesBuffer.size() > config.maxEntries) {
                var worstIdx : Nat = 0;
                var worstValue : Nat64 = switch (config.sortBy) {
                  case (#score) { entriesBuffer.get(0).score };
                  case (#streak) { entriesBuffer.get(0).streak };
                };
                
                var i : Nat = 1;
                while (i < entriesBuffer.size()) {
                  let entryValue = switch (config.sortBy) {
                    case (#score) { entriesBuffer.get(i).score };
                    case (#streak) { entriesBuffer.get(i).streak };
                  };
                  if (entryValue < worstValue) {
                    worstValue := entryValue;
                    worstIdx := i;
                  };
                  i += 1;
                };
                
                // Remove worst entry by rebuilding buffer without it - O(n)
                let newBuffer = Buffer.Buffer<ScoreEntry>(config.maxEntries);
                i := 0;
                for (entry in entriesBuffer.vals()) {
                  if (i != worstIdx) {
                    newBuffer.add(entry);
                  };
                  i += 1;
                };
                entriesBuffer := newBuffer;
              };
            };
          };
          
          // Save updated entries
          scoreboardEntries.put(sbKey, entriesBuffer);
          
          // Invalidate cache (will be rebuilt on next read)
          cachedScoreboards.delete(sbKey);
          scoreboardLastUpdate.delete(sbKey);
        } else {
          // Just update nickname if changed - O(1) update in place
          switch (existingEntry, existingIdx) {
            case (?existing, ?i) {
              if (existing.nickname != nickname) {
                let updatedEntry : ScoreEntry = {
                  odentifier = existing.odentifier;
                  nickname = nickname;
                  score = existing.score;
                  streak = existing.streak;
                  submittedAt = existing.submittedAt;
                  authType = existing.authType;
                };
                entriesBuffer.put(i, updatedEntry);
                scoreboardEntries.put(sbKey, entriesBuffer);
                cachedScoreboards.delete(sbKey);
                scoreboardLastUpdate.delete(sbKey);
              };
            };
            case _ {};
          };
        };
      };
    };
  };

  // ════════════════════════════════════════════════════════════════════════════
  // VALIDATION - Updated to handle external users
  // ════════════════════════════════════════════════════════════════════════════

  private func validateCaller(
    msg : { caller : Principal },
    userIdType : Text,
    userId : Text
  ) : Result.Result<(), Text> {
    
    // Handle external API users
    if (userIdType == "external") {
      // External users are validated by API key at proxy level
      // Just validate the player ID format here
      if (not isValidExternalPlayerId(userId)) {
        return #err("Invalid external player ID. Use 1-100 alphanumeric characters, underscore, or hyphen.");
      };
      return #ok(());
    };
    
    if (userIdType == "session" or userIdType == "email") {
      switch (validateSessionInternal(userId)) {
        case (#err(e)) { return #err(e) };
        case (#ok(session)) { 
          return #ok(());
        };
      };
    };
    
    if (Principal.isAnonymous(msg.caller)) {
      return #err("Authentication required");
    };
    
    if (userIdType == "principal") {
      if (userId != Principal.toText(msg.caller)) {
        return #err("Principal mismatch");
      };
      return #ok(());
    };
    
    #err("Invalid user type")
  };
    
  func validateScore(score: Nat64, gameId: Text) : Result.Result<(), Text> {
    let rules = getValidationRules(gameId);
    
    // Check maxScorePerRound (per-submission limit)
    switch (rules.maxScorePerRound) {
      case (?maxPerRound) {
        if (score > maxPerRound) {
          return #err("Score exceeds maximum per round (" # Nat64.toText(maxPerRound) # ")");
        };
      };
      case null {};
    };
    
    // Check absoluteScoreCap
    switch (rules.absoluteScoreCap) {
      case (?cap) {
        if (score > cap) {
          return #err("Score exceeds maximum allowed (" # Nat64.toText(cap) # ")");
        };
      };
      case null {}; // No limit set, skip validation
    };
    
    #ok(())
  };
  
  func validateStreak(streak: Nat64, gameId: Text) : Result.Result<(), Text> {
    let rules = getValidationRules(gameId);
    
    // Check maxStreakDelta (per-submission limit)
    switch (rules.maxStreakDelta) {
      case (?maxDelta) {
        if (streak > maxDelta) {
          return #err("Streak exceeds maximum per round (" # Nat64.toText(maxDelta) # ")");
        };
      };
      case null {};
    };
    
    // Check absoluteStreakCap
    switch (rules.absoluteStreakCap) {
      case (?cap) {
        if (streak > cap) {
          return #err("Streak exceeds maximum allowed (" # Nat64.toText(cap) # ")");
        };
      };
      case null {}; // No limit set, skip validation
    };
    
    #ok(())
  };
  
  func validateNickname(nickname: Text) : Result.Result<(), Text> {
    let length = Text.size(nickname);
    
    if (length < 3) {
      return #err("Nickname must be at least 3 characters");
    };
    
    if (length > 12) {
      return #err("Nickname must be 12 characters or less");
    };
    
    let chars = Text.toIter(nickname);
    for (char in chars) {
      let isValid = (char >= 'a' and char <= 'z') or
                    (char >= 'A' and char <= 'Z') or
                    (char >= '0' and char <= '9') or
                    (char == '_');
      
      if (not isValid) {
        return #err("Nickname can only contain letters, numbers, and underscores");
      };
    };
    
    #ok(())
  };
  
  func validateGameId(gameId: Text) : Result.Result<(), Text> {
    switch (games.get(gameId)) {
      case null {
        #err("Game not found: " # gameId)
      };
      case (?game) {
        if (not game.isActive) {
          return #err("Game is not active");
        };
        #ok(())
      };
    }
  };

  // Check access mode for a game
  private func validateAccessMode(game : GameInfo, userIdType : Text) : Result.Result<(), Text> {
    switch (game.accessMode, userIdType) {
      case (#webOnly, "external") { 
        #err("This game only accepts web SDK submissions") 
      };
      case (#apiOnly, "principal") { 
        #err("This game only accepts API submissions") 
      };
      case (#apiOnly, "session") { 
        #err("This game only accepts API submissions") 
      };
      case (#apiOnly, "email") { 
        #err("This game only accepts API submissions") 
      };
      case _ { #ok(()) };
    }
  };

  private func getUserKeyFromAuth(
    userIdType : Text,
    userId : Text
  ) : Result.Result<Text, Text> {
    
    if (userIdType == "email" or userIdType == "session") {
      switch (validateSessionInternal(userId)) {
        case (#err(e)) { #err(e) };
        case (#ok(session)) {
          #ok(userIdType # ":" # session.email)
        };
      };
    } else if (userIdType == "principal") {
      #ok(userIdType # ":" # userId)
    } else if (userIdType == "external") {
      #ok("external:" # userId)
    } else {
      #err("Invalid user type")
    };
  };

  private func getAdminRole(caller: Principal) : ?AdminRole {
    if (caller == CONTROLLER) {
      return ?#SuperAdmin;
    };
    adminRoles.get(caller)
  };

  private func hasPermission(caller: Principal, requiredRole: AdminRole) : Bool {
    if (caller == CONTROLLER) {
      return true;
    };
    
    switch (adminRoles.get(caller)) {
      case null false;
      case (?role) {
        switch (role, requiredRole) {
          case (#SuperAdmin, _) true;
          case (#Moderator, #ReadOnly) true;
          case (#Moderator, #Support) true;
          case (#Moderator, #Moderator) true;
          case (#Support, #ReadOnly) true;
          case (#Support, #Support) true;
          case (#ReadOnly, #ReadOnly) true;
          case (_, _) false;
        }
      };
    }
  };

  private func logAction(admin: Principal, command: Text, args: [Text], success: Bool, result: Text) {
    let role = Option.get(adminRoles.get(admin), #ReadOnly);
    let action : AdminAction = {
      timestamp = now();
      admin = admin;
      adminRole = role;
      command = command;
      args = args;
      success = success;
      result = result;
      ipAddress = null;
    };
    auditLog.add(action);
    
    if (auditLog.size() > 1000) {
      auditLogStable := Array.append(auditLogStable, Buffer.toArray(auditLog));
      auditLog := Buffer.Buffer<AdminAction>(100);
    };
  };

  private func isDestructiveCommand(command: Text) : Bool {
    command == "resetAll" or 
    command == "deleteUser" or 
    command == "confirmDeleteUser" or
    command == "permanentDelete"
  };

  private func checkRateLimit(caller: Principal, command: Text) : Result.Result<(), Text> {
    if (not isDestructiveCommand(command)) {
      return #ok();
    };
    
    let key = (caller, command);
    switch (lastCommandTime.get(key)) {
      case (?lastTime) {
        let cooldown : Nat64 = 60_000_000_000;
        let timeSince = now() - lastTime;
        if (timeSince < cooldown) {
          let remaining = (cooldown - timeSince) / 1_000_000_000;
          return #err("⏱️ Rate limit: Wait " # Nat64.toText(remaining) # " more seconds");
        };
      };
      case null {};
    };
    
    lastCommandTime.put(key, now());
    #ok()
  };

  private func generateConfirmationCode(userId: Text) : Text {
    let timestamp = now();
    let hash = Text.hash(userId # Nat64.toText(timestamp));
    "DELETE-" # Nat32.toText(hash)
  };

  func checkDeleteRateLimit(caller : Principal) : Bool {
    let now = Nat64.fromNat(Int.abs(Time.now()));
    let oneHourAgo = now - (24 * 60 * 60 * 1_000_000_000);
    
    switch (deleteRateLimit.get(caller)) {
      case (?attempts) {
        let recentAttempts = Array.filter<DeletionAttempt>(attempts, func(attempt) {
          attempt.timestamp > oneHourAgo
        });
        
        if (recentAttempts.size() >= 3) {
          return false;
        };
        
        true
      };
      case null { true };
    }
  };

  func recordDeleteAttempt(caller : Principal, gameId : Text) {
    let now = Nat64.fromNat(Int.abs(Time.now()));
    let oneHourAgo = now - (60 * 60 * 1_000_000_000);
    
    let newAttempt : DeletionAttempt = {
      timestamp = now;
      gameId = gameId;
    };
    
    switch (deleteRateLimit.get(caller)) {
      case (?attempts) {
        let recentAttempts = Array.filter<DeletionAttempt>(attempts, func(attempt) {
          attempt.timestamp > oneHourAgo
        });
        let updatedAttempts = Array.append(recentAttempts, [newAttempt]);
        deleteRateLimit.put(caller, updatedAttempts);
      };
      case null {
        deleteRateLimit.put(caller, [newAttempt]);
      };
    };
  };

  func cleanupDeletedGames() {
    let now = Nat64.fromNat(Int.abs(Time.now()));
    
    let toRemove = Buffer.Buffer<Text>(0);
    
    for ((gameId, deleted) in deletedGames.entries()) {
      if (now > deleted.permanentDeletionAt and not deleted.canRecover) {
        toRemove.add(gameId);
      };
    };
    
    for (gameId in toRemove.vals()) {
      deletedGames.delete(gameId);
    };
  };

  // ════════════════════════════════════════════════════════════════════════════
  // GAME MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════

  public shared(msg) func deleteGame(gameId : Text) : async Result.Result<Text, Text> {
    if (not checkDeleteRateLimit(msg.caller)) {
      return #err("Rate limit exceeded. You can only delete 3 games per hour. Please try again later.");
    };
    
    switch (games.get(gameId)) {
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can delete this game");
        };
        
        recordDeleteAttempt(msg.caller, gameId);
        
        let nowTime = Nat64.fromNat(Int.abs(Time.now()));
        let thirtyDays : Nat64 = 30 * 24 * 60 * 60 * 1_000_000_000;
        
        let deletedGame : DeletedGame = {
          game = game;
          deletedBy = msg.caller;
          deletedAt = nowTime;
          permanentDeletionAt = nowTime + thirtyDays;
          reason = "Owner requested deletion";
          canRecover = true;
        };
        
        deletedGames.put(gameId, deletedGame);
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = false;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        
        trackEventInternal(
          #principal(msg.caller),
          "system",
          "game_deleted",
          [
            ("gameId", gameId),
            ("gameName", game.name),
            ("recoveryPeriod", "30 days")
          ]
        );
        
        #ok("Game deleted successfully. You can recover it within 30 days from the 'Deleted Games' section.")
      };
      case null { #err("Game not found") };
    }
  };

  public shared(msg) func recoverDeletedGame(gameId : Text) : async Result.Result<Text, Text> {
    switch (deletedGames.get(gameId)) {
      case (?deleted) {
        let nowTime = Nat64.fromNat(Int.abs(Time.now()));
        
        if (deleted.game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can recover this game");
        };
        
        if (nowTime > deleted.permanentDeletionAt) {
          return #err("Recovery period expired (30 days). Game has been permanently deleted.");
        };
        
        if (not deleted.canRecover) {
          return #err("This game cannot be recovered");
        };
        
        let restored : GameInfo = {
          gameId = deleted.game.gameId;
          name = deleted.game.name;
          description = deleted.game.description;
          owner = deleted.game.owner;
          gameUrl = deleted.game.gameUrl;
          created = deleted.game.created;
          accessMode = deleted.game.accessMode;
          totalPlayers = deleted.game.totalPlayers;
          totalPlays = deleted.game.totalPlays;
          isActive = true;
          maxScorePerRound = deleted.game.maxScorePerRound;
          maxStreakDelta = deleted.game.maxStreakDelta;
          absoluteScoreCap = deleted.game.absoluteScoreCap;
          absoluteStreakCap = deleted.game.absoluteStreakCap;
          timeValidationEnabled = deleted.game.timeValidationEnabled;
          minPlayDurationSecs = deleted.game.minPlayDurationSecs;
          maxScorePerSecond = deleted.game.maxScorePerSecond;
          maxSessionDurationMins = deleted.game.maxSessionDurationMins;
          googleClientIds = deleted.game.googleClientIds;
          appleBundleId = deleted.game.appleBundleId;
          appleTeamId = deleted.game.appleTeamId;
        };
        
        games.put(gameId, restored);
        deletedGames.delete(gameId);
        
        trackEventInternal(
          #principal(msg.caller),
          "system",
          "game_recovered",
          [
            ("gameId", gameId),
            ("gameName", deleted.game.name)
          ]
        );
        
        #ok("Game recovered successfully and is now active again!")
      };
      case null { #err("Game not found in deleted games") };
    }
  };

  public query(msg) func getDeletedGames() : async [DeletedGame] {
    let buffer = Buffer.Buffer<DeletedGame>(0);
    
    for ((_, deleted) in deletedGames.entries()) {
      if (deleted.game.owner == msg.caller or isAdmin(msg.caller)) {
        buffer.add(deleted);
      };
    };
    
    Buffer.toArray(buffer)
  };

  public shared(msg) func permanentlyDeleteGame(gameId : Text) : async Result.Result<Text, Text> {
    switch (deletedGames.get(gameId)) {
      case (?deleted) {
        let nowTime = Nat64.fromNat(Int.abs(Time.now()));
        
        if (nowTime <= deleted.permanentDeletionAt and not isAdmin(msg.caller)) {
          return #err("Game can only be permanently deleted after 30 days or by super admin");
        };
        
        if (deleted.game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Not authorized");
        };
        
        games.delete(gameId);
        deletedGames.delete(gameId);
        
        trackEventInternal(
          #principal(msg.caller),
          "system",
          "game_permanently_deleted",
          [
            ("gameId", gameId),
            ("gameName", deleted.game.name)
          ]
        );
        
        #ok("Game permanently deleted. All data has been removed.")
      };
      case null { #err("Game not found in deleted games") };
    }
  };

  public query(msg) func canDeleteGame() : async Bool {
    checkDeleteRateLimit(msg.caller)
  };

  public query(msg) func getRemainingDeleteAttempts() : async Nat {
    let nowTime = Nat64.fromNat(Int.abs(Time.now()));
    let oneHourAgo = nowTime - (60 * 60 * 1_000_000_000);
    
    switch (deleteRateLimit.get(msg.caller)) {
      case (?attempts) {
        let recentAttempts = Array.filter<DeletionAttempt>(attempts, func(attempt) {
          attempt.timestamp > oneHourAgo
        });
        
        let used = recentAttempts.size();
        if (used >= 3) { 0 } else { 3 - used }
      };
      case null { 3 };
    }
  };

  public shared(msg) func cleanupExpiredGames() : async Result.Result<Text, Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Only admin can trigger cleanup");
    };
    
    let nowTime = Nat64.fromNat(Int.abs(Time.now()));
    let cleaned = Buffer.Buffer<Text>(0);
    
    for ((gameId, deleted) in deletedGames.entries()) {
      if (nowTime > deleted.permanentDeletionAt) {
        games.delete(gameId);
        deletedGames.delete(gameId);
        cleaned.add(gameId);
        
        trackEventInternal(
          #principal(msg.caller),
          "system",
          "game_auto_cleanup",
          [("gameId", gameId)]
        );
      };
    };
    
    let count = cleaned.size();
    #ok("Cleaned up " # Nat.toText(count) # " expired games")
  };

  // ════════════════════════════════════════════════════════════════════════════
  // UPGRADE HOOKS
  // ════════════════════════════════════════════════════════════════════════════

  system func preupgrade() {
    alternativeOriginsStable := Buffer.toArray(alternativeOrigins);
    stableUsersByEmail := Iter.toArray(usersByEmail.entries());
    stableUsersByPrincipal := Iter.toArray(usersByPrincipal.entries());
    
    // Save to V3 (current format with time validation)
    stableGamesV3 := Iter.toArray(games.entries());
    deletedGamesEntriesV3 := Iter.toArray(deletedGames.entries());
    
    // Clear old formats
    stableGames := [];
    deletedGamesEntries := [];
    stableGamesV2 := [];
    deletedGamesEntriesV2 := [];
    
    stableSessions := Iter.toArray(sessions.entries());
    stableSuspicionLog := List.toArray(suspicionLog);
    stableFiles := List.toArray(files);
    stableAnalyticsEvents := Buffer.toArray(analyticsEvents);
    stableDailyStats := Iter.toArray(dailyStats.entries());
    stablePlayerStats := Iter.toArray(playerStats.entries());
    stableLastSubmitTime := Iter.toArray(lastSubmitTime.entries());
    sessionsEntries := Iter.toArray(sessions.entries());
    principalToSessionEntries := Iter.toArray(principalToSession.entries());
    adminRolesStable := Iter.toArray(adminRoles.entries());
    deletedUsersStable := Iter.toArray(deletedUsers.entries());
    auditLogStable := Array.append(auditLogStable, Buffer.toArray(auditLog));
    deleteRateLimitEntries := Iter.toArray(deleteRateLimit.entries());
    apiKeysStable := Iter.toArray(apiKeys.entries());
    developerTiersStable := Iter.toArray(developerTiers.entries());
    
    // Scoreboards - save to V2, DO NOT clear old ones
    scoreboardConfigsStableV2 := Iter.toArray(scoreboardConfigs.entries());
    // scoreboardConfigsStable - leave unchanged!
    
    let entriesBuffer = Buffer.Buffer<(Text, [ScoreEntry])>(scoreboardEntries.size());
    for ((key, buffer) in scoreboardEntries.entries()) {
        entriesBuffer.add((key, Buffer.toArray(buffer)));
    };
    scoreboardEntriesStableV2 := Buffer.toArray(entriesBuffer);
    scoreboardArchivesStableV2 := Iter.toArray(scoreboardArchives.entries());
    
    // Play sessions
    playSessionsStable := Iter.toArray(playSessions.entries());

};

system func postupgrade() {
    
    usersByEmail := HashMap.HashMap<Text, UserProfile>(10, Text.equal, Text.hash);
    for ((e, prof) in stableUsersByEmail.vals()) { usersByEmail.put(e, prof) };

    usersByPrincipal := HashMap.HashMap<Principal, UserProfile>(10, Principal.equal, Principal.hash);
    for ((p, prof) in stableUsersByPrincipal.vals()) { usersByPrincipal.put(p, prof) };

    if (userIdCounter == 0) {
        let totalUsers = usersByEmail.size() + usersByPrincipal.size();
        if (totalUsers > 0) {
            userIdCounter := totalUsers;
        };
    };

    alternativeOrigins := Buffer.fromArray<Text>(alternativeOriginsStable);
    alternativeOriginsStable := [];

    games := HashMap.HashMap<Text, GameInfo>(10, Text.equal, Text.hash);
    
    // Priority: V3 (newest) > V2 (with OAuth, no time validation) > Legacy (no OAuth)
    if (stableGamesV3.size() > 0) {
        // Already in latest format
        for ((id, game) in stableGamesV3.vals()) {
            games.put(id, game);
        };
        stableGamesV3 := [];
        timeValidationMigrationDone := true;
    } else if (stableGamesV2.size() > 0) {
        // MIGRATE from V2 (has OAuth, missing time validation fields)
        for ((id, oldGame) in stableGamesV2.vals()) {
            let migratedGame : GameInfo = {
                gameId = oldGame.gameId;
                name = oldGame.name;
                description = oldGame.description;
                owner = oldGame.owner;
                gameUrl = oldGame.gameUrl;
                created = oldGame.created;
                accessMode = oldGame.accessMode;
                totalPlayers = oldGame.totalPlayers;
                totalPlays = oldGame.totalPlays;
                isActive = oldGame.isActive;
                maxScorePerRound = oldGame.maxScorePerRound;
                maxStreakDelta = oldGame.maxStreakDelta;
                absoluteScoreCap = oldGame.absoluteScoreCap;
                absoluteStreakCap = oldGame.absoluteStreakCap;
                timeValidationEnabled = false;
                minPlayDurationSecs = null;
                maxScorePerSecond = null;
                maxSessionDurationMins = null;
                googleClientIds = oldGame.googleClientIds;
                appleBundleId = oldGame.appleBundleId;
                appleTeamId = oldGame.appleTeamId;
            };
            games.put(id, migratedGame);
        };
        stableGamesV2 := [];
        timeValidationMigrationDone := true;
        oauthMigrationDone := true;
    } else if (stableGames.size() > 0) {
        // MIGRATE from legacy format (no OAuth fields)
        for ((id, oldGame) in stableGames.vals()) {
            let migratedGame : GameInfo = {
                gameId = oldGame.gameId;
                name = oldGame.name;
                description = oldGame.description;
                owner = oldGame.owner;
                gameUrl = oldGame.gameUrl;
                created = oldGame.created;
                accessMode = oldGame.accessMode;
                totalPlayers = oldGame.totalPlayers;
                totalPlays = oldGame.totalPlays;
                isActive = oldGame.isActive;
                maxScorePerRound = oldGame.maxScorePerRound;
                maxStreakDelta = oldGame.maxStreakDelta;
                absoluteScoreCap = oldGame.absoluteScoreCap;
                absoluteStreakCap = oldGame.absoluteStreakCap;
                timeValidationEnabled = false;
                minPlayDurationSecs = null;
                maxScorePerSecond = null;
                maxSessionDurationMins = null;
                googleClientIds = [];
                appleBundleId = null;
                appleTeamId = null;
            };
            games.put(id, migratedGame);
        };
        stableGames := [];
        oauthMigrationDone := true;
        timeValidationMigrationDone := true;
    };

    // Migrate deleted games - same priority order
    deletedGames := HashMap.HashMap<Text, DeletedGame>(10, Text.equal, Text.hash);
    
    if (deletedGamesEntriesV3.size() > 0) {
        // Already in latest format
        for ((id, deleted) in deletedGamesEntriesV3.vals()) {
            deletedGames.put(id, deleted);
        };
        deletedGamesEntriesV3 := [];
    } else if (deletedGamesEntriesV2.size() > 0) {
        // MIGRATE from V2 (has OAuth, missing time validation)
        for ((id, oldDeleted) in deletedGamesEntriesV2.vals()) {
            let migratedGame : GameInfo = {
                gameId = oldDeleted.game.gameId;
                name = oldDeleted.game.name;
                description = oldDeleted.game.description;
                owner = oldDeleted.game.owner;
                gameUrl = oldDeleted.game.gameUrl;
                created = oldDeleted.game.created;
                accessMode = oldDeleted.game.accessMode;
                totalPlayers = oldDeleted.game.totalPlayers;
                totalPlays = oldDeleted.game.totalPlays;
                isActive = oldDeleted.game.isActive;
                maxScorePerRound = oldDeleted.game.maxScorePerRound;
                maxStreakDelta = oldDeleted.game.maxStreakDelta;
                absoluteScoreCap = oldDeleted.game.absoluteScoreCap;
                absoluteStreakCap = oldDeleted.game.absoluteStreakCap;
                timeValidationEnabled = false;
                minPlayDurationSecs = null;
                maxScorePerSecond = null;
                maxSessionDurationMins = null;
                googleClientIds = oldDeleted.game.googleClientIds;
                appleBundleId = oldDeleted.game.appleBundleId;
                appleTeamId = oldDeleted.game.appleTeamId;
            };
            let migratedDeleted : DeletedGame = {
                game = migratedGame;
                deletedBy = oldDeleted.deletedBy;
                deletedAt = oldDeleted.deletedAt;
                permanentDeletionAt = oldDeleted.permanentDeletionAt;
                reason = oldDeleted.reason;
                canRecover = oldDeleted.canRecover;
            };
            deletedGames.put(id, migratedDeleted);
        };
        deletedGamesEntriesV2 := [];
    } else if (deletedGamesEntries.size() > 0) {
        // MIGRATE from legacy (no OAuth)
        for ((id, oldDeleted) in deletedGamesEntries.vals()) {
            let migratedGame : GameInfo = {
                gameId = oldDeleted.game.gameId;
                name = oldDeleted.game.name;
                description = oldDeleted.game.description;
                owner = oldDeleted.game.owner;
                gameUrl = oldDeleted.game.gameUrl;
                created = oldDeleted.game.created;
                accessMode = oldDeleted.game.accessMode;
                totalPlayers = oldDeleted.game.totalPlayers;
                totalPlays = oldDeleted.game.totalPlays;
                isActive = oldDeleted.game.isActive;
                maxScorePerRound = oldDeleted.game.maxScorePerRound;
                maxStreakDelta = oldDeleted.game.maxStreakDelta;
                absoluteScoreCap = oldDeleted.game.absoluteScoreCap;
                absoluteStreakCap = oldDeleted.game.absoluteStreakCap;
                timeValidationEnabled = false;
                minPlayDurationSecs = null;
                maxScorePerSecond = null;
                maxSessionDurationMins = null;
                googleClientIds = [];
                appleBundleId = null;
                appleTeamId = null;
            };
            let migratedDeleted : DeletedGame = {
                game = migratedGame;
                deletedBy = oldDeleted.deletedBy;
                deletedAt = oldDeleted.deletedAt;
                permanentDeletionAt = oldDeleted.permanentDeletionAt;
                reason = oldDeleted.reason;
                canRecover = oldDeleted.canRecover;
            };
            deletedGames.put(id, migratedDeleted);
        };
        deletedGamesEntries := [];
    };

    lastSubmitTime := HashMap.HashMap<Text, Nat64>(10, Text.equal, Text.hash);
    for ((key, time) in stableLastSubmitTime.vals()) { lastSubmitTime.put(key, time) };

    suspicionLog := List.fromArray(stableSuspicionLog);
    files := List.fromArray(stableFiles);
    
    analyticsEvents := Buffer.fromArray<AnalyticsEvent>(stableAnalyticsEvents);
    
    dailyStats := HashMap.HashMap<Text, DailyStats>(10, Text.equal, Text.hash);
    for ((date, stats) in stableDailyStats.vals()) {
        dailyStats.put(date, stats);
    };
    
    playerStats := HashMap.HashMap<Text, PlayerStats>(10, Text.equal, Text.hash);
    for ((p, stats) in stablePlayerStats.vals()) {
        playerStats.put(p, stats);
    };

    cachedLeaderboards := HashMap.HashMap<Text, [(Text, Nat64, Nat64, Text)]>(10, Text.equal, Text.hash);
    leaderboardLastUpdate := HashMap.HashMap<Text, Nat64>(10, Text.equal, Text.hash);
    
    sessions := HashMap.fromIter<Text, Session>(
        sessionsEntries.vals(), 10, Text.equal, Text.hash
    );
    principalToSession := HashMap.fromIter<Text, Text>(
        principalToSessionEntries.vals(), 10, Text.equal, Text.hash
    );
    
    sessionsEntries := [];
    principalToSessionEntries := [];
    adminRolesStable := [];
    deletedUsersStable := [];
    
    deleteRateLimit := HashMap.fromIter<Principal, [DeletionAttempt]>(
        deleteRateLimitEntries.vals(),
        10,
        Principal.equal,
        Principal.hash
    );
    
    deleteRateLimitEntries := [];

    apiKeys := HashMap.fromIter<Text, ApiKey>(apiKeysStable.vals(), 50, Text.equal, Text.hash);
    apiKeysStable := [];

    developerTiers := HashMap.fromIter<Principal, DeveloperTier>(
        developerTiersStable.vals(), 10, Principal.equal, Principal.hash
    );
    
    // Restore scoreboard configs - prefer V2, fallback to old
    let configSource = if (scoreboardConfigsStableV2.size() > 0) { 
        scoreboardConfigsStableV2 
    } else { 
        scoreboardConfigsStable 
    };
    scoreboardConfigs := HashMap.fromIter<Text, ScoreboardConfig>(
        configSource.vals(), 50, Text.equal, Text.hash
    );
    // Clear AFTER reading
    scoreboardConfigsStable := [];
    scoreboardConfigsStableV2 := [];
    
    // Restore scoreboard entries - prefer V2, fallback to old
    let entriesSource = if (scoreboardEntriesStableV2.size() > 0) {
        scoreboardEntriesStableV2
    } else {
        scoreboardEntriesStable
    };
    scoreboardEntries := HashMap.HashMap<Text, Buffer.Buffer<ScoreEntry>>(50, Text.equal, Text.hash);
    for ((key, entries) in entriesSource.vals()) {
        scoreboardEntries.put(key, Buffer.fromArray<ScoreEntry>(entries));
    };
    // Clear AFTER reading
    scoreboardEntriesStable := [];
    scoreboardEntriesStableV2 := [];
    
    // Initialize scoreboard caches
    cachedScoreboards := HashMap.HashMap<Text, [PublicScoreEntry]>(50, Text.equal, Text.hash);
    scoreboardLastUpdate := HashMap.HashMap<Text, Nat64>(50, Text.equal, Text.hash);

    let archivesSource = if (scoreboardArchivesStableV2.size() > 0) {
      scoreboardArchivesStableV2
    } else {
      scoreboardArchivesStable
    };
    scoreboardArchives := HashMap.fromIter<Text, ArchivedScoreboard>(
      archivesSource.vals(), 100, Text.equal, Text.hash
    );
    // Clear after reading
    scoreboardArchivesStable := [];
    scoreboardArchivesStableV2 := [];

    // Restore play sessions
    playSessions := HashMap.fromIter<Text, PlaySession>(
      playSessionsStable.vals(), 100, Text.equal, Text.hash
    );
    playSessionsStable := [];

    // TODO: Set via deployment - initial admin (can be same as CONTROLLER or different)
    let firstAdmin = Principal.fromText("aaaaa-aa"); // REPLACE WITH YOUR ADMIN PRINCIPAL
    adminRoles.put(firstAdmin, #SuperAdmin);
};

  // ════════════════════════════════════════════════════════════════════════════
  // HTTP INTERFACE
  // ════════════════════════════════════════════════════════════════════════════

  public query func http_request(request : HttpRequest) : async HttpResponse {
  
    if (request.url == "/.well-known/ii-alternative-origins" or 
        Text.startsWith(request.url, #text "/.well-known/ii-alternative-origins?")) {
      
      let origins = Buffer.toArray(alternativeOrigins);
      var json = "{\"alternativeOrigins\":[";
      
      var first = true;
      for (origin in origins.vals()) {
        if (not first) { json := json # "," };
        json := json # "\"" # origin # "\"";
        first := false;
      };
      json := json # "]}";
      
      return {
        status_code = 200;
        headers = [
          ("Content-Type", "application/json"),
          ("Access-Control-Allow-Origin", "*")
        ];
        body = Text.encodeUtf8(json);
        streaming_strategy = null;
      };
    };
    
    {
      status_code = 404;
      headers = [];
      body = Text.encodeUtf8("{\"error\":\"Not found\"}");
      streaming_strategy = null;
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // GAME REGISTRATION - Updated with accessMode
  // ════════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════════
// COMPLETE GAME MANAGEMENT FUNCTIONS - With OAuth Fields
// Replace your existing game management functions with these
// ═══════════════════════════════════════════════════════════════════════════════

public shared(msg) func registerGame(
    gameId: Text, 
    name: Text, 
    description: Text,
    maxScorePerRound: ?Nat64,
    maxStreakDelta: ?Nat64,
    absoluteScoreCap: ?Nat64,
    absoluteStreakCap: ?Nat64,
    gameUrl: ?Text,
    accessMode: ?AccessMode
  ) : async Result.Result<Text, Text> {
    
    if (Principal.isAnonymous(msg.caller)) {
      return #err("❌ Must authenticate with Internet Identity to register a game");
    };
    
    if (Text.size(gameId) < 3 or Text.size(gameId) > 50) {
      return #err("Game ID must be 3-50 characters");
    };
    
    switch (games.get(gameId)) {
      case (?existing) {
        if (existing.owner == msg.caller) {
          #ok("You already own this game")
        } else {
          #err("Game ID already taken by another developer")
        }
      };
      case null {
        let currentGameCount = countGamesByOwner(msg.caller);
        
        if (currentGameCount >= MAX_GAMES_PER_DEVELOPER and not isAdmin(msg.caller)) {
          return #err("🚫 Maximum " # Nat.toText(MAX_GAMES_PER_DEVELOPER) # " games per developer. You currently have " # Nat.toText(currentGameCount) # " games registered.");
        };
        
        let gameInfo : GameInfo = {
          gameId = gameId;
          name = name;
          description = description;
          owner = msg.caller;
          gameUrl = gameUrl;
          created = now();
          accessMode = Option.get(accessMode, #both);
          totalPlayers = 0;
          totalPlays = 0;
          isActive = true;
          maxScorePerRound = maxScorePerRound;
          maxStreakDelta = maxStreakDelta;
          absoluteScoreCap = absoluteScoreCap;
          absoluteStreakCap = absoluteStreakCap;
          timeValidationEnabled = false;
          minPlayDurationSecs = null;
          maxScorePerSecond = null;
          maxSessionDurationMins = null;
          googleClientIds = [];
          appleBundleId = null;
          appleTeamId = null;
        };
        games.put(gameId, gameInfo);
        
        // Create default scoreboards (all-time and weekly)
        createDefaultScoreboards(gameId, msg.caller);
        
        switch(gameUrl) {
          case(?url) {
            if (Text.startsWith(url, #text("https://"))) {
              let exists = Buffer.contains<Text>(alternativeOrigins, url, Text.equal);
              if (not exists) {
                alternativeOrigins.add(url);
              };
            };
          };
          case(null) {};
        };
        
        trackEventInternal(#principal(msg.caller), gameId, "game_registered", [
          ("game_name", name),
          ("game_id", gameId),
          ("access_mode", accessModeToText(Option.get(accessMode, #both))),
          ("total_games", Nat.toText(currentGameCount + 1))
        ]);
        
        #ok("✅ Game '" # name # "' registered successfully! (" # Nat.toText(currentGameCount + 1) # "/" # Nat.toText(MAX_GAMES_PER_DEVELOPER) # " games) Default scoreboards created: all-time, weekly")
      };
    }
  };

  public shared(msg) func updateGame(
    gameId : Text, 
    name : Text, 
    description : Text,
    gameUrl : ?Text
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can update");
        };
        
        switch(game.gameUrl) {
          case(?oldUrl) {
            switch(gameUrl) {
              case(?newUrl) {
                if (oldUrl != newUrl) {
                  let newOrigins = Buffer.Buffer<Text>(alternativeOrigins.size());
                  for (url in alternativeOrigins.vals()) {
                    if (url != oldUrl) {
                      newOrigins.add(url);
                    };
                  };
                  alternativeOrigins := newOrigins;
                  if (Text.startsWith(newUrl, #text("https://"))) {
                    let exists = Buffer.contains<Text>(alternativeOrigins, newUrl, Text.equal);
                    if (not exists) {
                      alternativeOrigins.add(newUrl);
                    };
                  };
                };
              };
              case(null) {
                let newOrigins = Buffer.Buffer<Text>(alternativeOrigins.size());
                for (url in alternativeOrigins.vals()) {
                  if (url != oldUrl) {
                    newOrigins.add(url);
                  };
                };
                alternativeOrigins := newOrigins;
              };
            };
          };
          case(null) {
            switch(gameUrl) {
              case(?newUrl) {
                if (Text.startsWith(newUrl, #text("https://"))) {
                  let exists = Buffer.contains<Text>(alternativeOrigins, newUrl, Text.equal);
                  if (not exists) {
                    alternativeOrigins.add(newUrl);
                  };
                };
              };
              case(null) {};
            };
          };
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = name;
          description = description;
          owner = game.owner;
          gameUrl = gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        #ok("Game updated")
      };
      case null { #err("Game not found") };
    }
  };

  public shared(msg) func updateGameAccessMode(
    gameId : Text,
    newAccessMode : AccessMode
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can update access mode");
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = newAccessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        #ok("Access mode updated to " # accessModeToText(newAccessMode))
      };
      case null { #err("Game not found") };
    }
  };

  public shared(msg) func updateGameRules(
    gameId : Text,
    maxScorePerRound : ?Nat64,
    maxStreakDelta : ?Nat64,
    absoluteScoreCap : ?Nat64,
    absoluteStreakCap : ?Nat64
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can update rules");
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = maxScorePerRound;
          maxStreakDelta = maxStreakDelta;
          absoluteScoreCap = absoluteScoreCap;
          absoluteStreakCap = absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        #ok("Game rules updated")
      };
      case null { #err("Game not found") };
    }
  };

  public shared(msg) func toggleGameActive(gameId : Text) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can toggle");
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = not game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        #ok("Game " # (if (updated.isActive) "activated" else "deactivated"))
      };
      case null { #err("Game not found") };
    }
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // OAUTH CREDENTIAL MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared(msg) func setGameGoogleCredentials(
    gameId : Text,
    clientIds : [Text]
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case null { #err("Game not found") };
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can update OAuth credentials");
        };
        
        for (clientId in clientIds.vals()) {
          if (not Text.endsWith(clientId, #text ".apps.googleusercontent.com")) {
            return #err("Invalid Google client ID format: " # clientId);
          };
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = clientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
        };
        games.put(gameId, updated);
        
        trackEventInternal(#principal(msg.caller), gameId, "oauth_google_configured", [
          ("client_count", Nat.toText(clientIds.size()))
        ]);
        
        #ok("Google OAuth configured with " # Nat.toText(clientIds.size()) # " client ID(s)")
      };
    }
  };

  public shared(msg) func setGameAppleCredentials(
    gameId : Text,
    bundleId : Text,
    teamId : ?Text
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case null { #err("Game not found") };
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can update OAuth credentials");
        };
        
        if (Text.size(bundleId) < 3 or not Text.contains(bundleId, #char '.')) {
          return #err("Invalid bundle ID format. Expected: com.company.appname");
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
          appleBundleId = ?bundleId;
          appleTeamId = teamId;
        };
        games.put(gameId, updated);
        
        trackEventInternal(#principal(msg.caller), gameId, "oauth_apple_configured", [
          ("bundle_id", bundleId)
        ]);
        
        #ok("Apple Sign-In configured for " # bundleId)
      };
    }
  };

  public query func getGameOAuthConfig(gameId : Text) : async ?{
    googleClientIds : [Text];
    appleBundleId : ?Text;
    appleTeamId : ?Text;
    nativeAuthEnabled : Bool;
  } {
    switch (games.get(gameId)) {
      case null { null };
      case (?game) {
        let hasGoogle = game.googleClientIds.size() > 0;
        let hasApple = Option.isSome(game.appleBundleId);
        
        ?{
          googleClientIds = game.googleClientIds;
          appleBundleId = game.appleBundleId;
          appleTeamId = game.appleTeamId;
          nativeAuthEnabled = hasGoogle or hasApple;
        }
      };
    }
  };

  public shared(msg) func clearGameOAuthCredentials(
    gameId : Text,
    provider : Text
  ) : async Result.Result<Text, Text> {
    switch (games.get(gameId)) {
      case null { #err("Game not found") };
      case (?game) {
        if (game.owner != msg.caller and not isAdmin(msg.caller)) {
          return #err("Only game owner can clear OAuth credentials");
        };
        
        let (newGoogle, newApple, newTeam) = switch (provider) {
          case ("google") { ([], game.appleBundleId, game.appleTeamId) };
          case ("apple") { (game.googleClientIds, null, null) };
          case ("all") { ([], null, null) };
          case (_) { return #err("Invalid provider. Use: google, apple, or all") };
        };
        
        let updated : GameInfo = {
          gameId = game.gameId;
          name = game.name;
          description = game.description;
          owner = game.owner;
          gameUrl = game.gameUrl;
          created = game.created;
          accessMode = game.accessMode;
          totalPlayers = game.totalPlayers;
          totalPlays = game.totalPlays;
          isActive = game.isActive;
          maxScorePerRound = game.maxScorePerRound;
          maxStreakDelta = game.maxStreakDelta;
          absoluteScoreCap = game.absoluteScoreCap;
          absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = newGoogle;
          appleBundleId = newApple;
          appleTeamId = newTeam;
        };
        games.put(gameId, updated);
        
        #ok("OAuth credentials cleared for: " # provider)
      };
    }
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // SESSION-BASED VERSIONS (for dashboard)
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func setGameGoogleCredentialsBySession(
    sessionId : Text,
    gameId : Text,
    clientIds : [Text]
  ) : async Result.Result<Text, Text> {
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            for (clientId in clientIds.vals()) {
              if (not Text.endsWith(clientId, #text ".apps.googleusercontent.com")) {
                return #err("Invalid Google client ID: " # clientId);
              };
            };
            
            let updated : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = clientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
            };
            games.put(gameId, updated);
            
            trackEventInternal(#principal(owner), gameId, "oauth_google_configured", [
              ("client_count", Nat.toText(clientIds.size()))
            ]);
            
            #ok("Google OAuth configured")
          };
        };
      };
    };
  };

  public shared func setGameAppleCredentialsBySession(
    sessionId : Text,
    gameId : Text,
    bundleId : Text,
    teamId : ?Text
  ) : async Result.Result<Text, Text> {
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            if (Text.size(bundleId) < 3 or not Text.contains(bundleId, #char '.')) {
              return #err("Invalid bundle ID format");
            };
            
            let updated : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
              appleBundleId = ?bundleId;
              appleTeamId = teamId;
            };
            games.put(gameId, updated);
            
            trackEventInternal(#principal(owner), gameId, "oauth_apple_configured", [
              ("bundle_id", bundleId)
            ]);
            
            #ok("Apple Sign-In configured")
          };
        };
      };
    };
  };

  public query func getGameOAuthConfigBySession(sessionId : Text, gameId : Text) : async Result.Result<{
    googleClientIds : [Text];
    appleBundleId : ?Text;
    appleTeamId : ?Text;
    googleConfigured : Bool;
    appleConfigured : Bool;
  }, Text> {
    switch (sessions.get(sessionId)) {
      case null { #err("Invalid session") };
      case (?session) {
        let owner = emailToPrincipalSimple(session.email);
        
        switch (games.get(gameId)) {
          case null { #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            #ok({
          googleClientIds = game.googleClientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
              googleConfigured = game.googleClientIds.size() > 0;
              appleConfigured = Option.isSome(game.appleBundleId);
            })
          };
        };
      };
    };
  };

  public shared func clearGameOAuthCredentialsBySession(
    sessionId : Text,
    gameId : Text,
    provider : Text
  ) : async Result.Result<Text, Text> {
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            let (newGoogle, newApple, newTeam) = switch (provider) {
              case ("google") { ([], game.appleBundleId, game.appleTeamId) };
              case ("apple") { (game.googleClientIds, null, null) };
              case ("all") { ([], null, null) };
              case (_) { return #err("Invalid provider. Use: google, apple, or all") };
            };
            
            let updated : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = newGoogle;
              appleBundleId = newApple;
              appleTeamId = newTeam;
            };
            games.put(gameId, updated);
            
            #ok("OAuth credentials cleared for: " # provider)
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE registerGameBySession TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func registerGameBySession(
    sessionId: Text,
    gameId: Text,
    name: Text,
    description: Text,
    maxScorePerRound: ?Nat64,
    maxStreakDelta: ?Nat64,
    absoluteScoreCap: ?Nat64,
    absoluteStreakCap: ?Nat64,
    gameUrl: ?Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        
        if (not isValidGameId(gameId)) {
          return #err("Invalid game ID format. Use lowercase letters, numbers, and hyphens only.");
        };
        
        switch (games.get(gameId)) {
          case (?_) { return #err("Game ID already exists") };
          case null {};
        };
        
        let ownerGames = getGameCountByOwner(owner);
        let maxGames = getMaxGamesForDeveloper(owner);
        
        if (ownerGames >= maxGames) {
          let upgradeMsg = if (maxGames == 3) { " Upgrade to Pro for 10 slots!" } else { "" };
          return #err("Maximum " # Nat.toText(maxGames) # " games reached." # upgradeMsg # " Delete a game to register a new one.");
        };
        
        let currentTime = Nat64.fromNat(Int.abs(Time.now()));
        
        let newGame : GameInfo = {
          gameId = gameId;
          name = name;
          description = description;
          owner = owner;
          gameUrl = gameUrl;
          created = currentTime;
          accessMode = #both;
          totalPlayers = 0;
          totalPlays = 0;
          isActive = true;
          maxScorePerRound = maxScorePerRound;
          maxStreakDelta = maxStreakDelta;
          absoluteScoreCap = absoluteScoreCap;
          absoluteStreakCap = absoluteStreakCap;
          timeValidationEnabled = false;
          minPlayDurationSecs = null;
          maxScorePerSecond = null;
          maxSessionDurationMins = null;
          googleClientIds = [];
          appleBundleId = null;
          appleTeamId = null;
        };
        
        games.put(gameId, newGame);
        
        // Create default scoreboards (all-time and weekly)
        createDefaultScoreboards(gameId, owner);
        
        trackEventInternal(#principal(owner), gameId, "game_registered", [
          ("game_name", name),
          ("game_id", gameId)
        ]);
        
        #ok("Game '" # name # "' registered successfully! (" # Nat.toText(ownerGames + 1) # "/" # Nat.toText(maxGames) # " games) Default scoreboards created: all-time, weekly")
      };
    };
  };

  
  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE updateGameBySession TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func updateGameBySession(
    sessionId: Text,
    gameId: Text,
    name: Text,
    description: Text,
    gameUrl: ?Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            let updatedGame : GameInfo = {
              gameId = game.gameId;
              name = name;
              description = description;
              owner = game.owner;
              gameUrl = gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
            };
            
            games.put(gameId, updatedGame);
            #ok("Game updated successfully!")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE updateGameRulesBySession TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func updateGameRulesBySession(
    sessionId: Text,
    gameId: Text,
    maxScorePerRound: ?Nat64,
    maxStreakDelta: ?Nat64,
    absoluteScoreCap: ?Nat64,
    absoluteStreakCap: ?Nat64
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            let updatedGame : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = maxScorePerRound;
              maxStreakDelta = maxStreakDelta;
              absoluteScoreCap = absoluteScoreCap;
              absoluteStreakCap = absoluteStreakCap;
              timeValidationEnabled = game.timeValidationEnabled;
              minPlayDurationSecs = game.minPlayDurationSecs;
              maxScorePerSecond = game.maxScorePerSecond;
              maxSessionDurationMins = game.maxSessionDurationMins;
              googleClientIds = game.googleClientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
            };
            
            games.put(gameId, updatedGame);
            #ok("Anti-cheat parameters updated!")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE deleteGameBySession TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func deleteGameBySession(
    sessionId: Text,
    gameId: Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        let remaining = getRemainingDeleteAttemptsForOwner(owner);
        if (remaining == 0) {
          return #err("Rate limit exceeded. You can only delete 3 games per hour.");
        };
        
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            let currentTime = Nat64.fromNat(Int.abs(Time.now()));
            let thirtyDays : Nat64 = 30 * 24 * 60 * 60 * 1_000_000_000;
            
            let newAttempt : DeletionAttempt = {
              timestamp = currentTime;
              gameId = gameId;
            };
            
            switch (deleteRateLimit.get(owner)) {
              case null {
                deleteRateLimit.put(owner, [newAttempt]);
              };
              case (?existing) {
                deleteRateLimit.put(owner, Array.append(existing, [newAttempt]));
              };
            };
            
            let deletedGame : DeletedGame = {
              game = game;
              deletedBy = owner;
              deletedAt = currentTime;
              permanentDeletionAt = currentTime + thirtyDays;
              reason = "User deleted";
              canRecover = true;
            };
            
            deletedGames.put(gameId, deletedGame);
            
            let inactiveGame : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = false;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
            };
            games.put(gameId, inactiveGame);
            
            #ok("Game '" # game.name # "' deleted. You have 30 days to recover it.")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE recoverDeletedGameBySession TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func recoverDeletedGameBySession(
    sessionId: Text,
    gameId: Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        switch (deletedGames.get(gameId)) {
          case null { return #err("Deleted game not found") };
          case (?deleted) {
            if (not Principal.equal(deleted.deletedBy, owner)) {
              return #err("You don't own this game");
            };
            
            let currentTime = Nat64.fromNat(Int.abs(Time.now()));
            
            if (currentTime > deleted.permanentDeletionAt) {
              return #err("Recovery period expired. Game has been permanently deleted.");
            };
            
            let ownerGames = getGameCountByOwner(owner);
            let maxGames = getMaxGamesForDeveloper(owner);
            
            if (ownerGames >= maxGames) {
              let upgradeMsg = if (maxGames == 3) { " Upgrade to Pro for 10 slots or" } else { "" };
              return #err("You already have " # Nat.toText(maxGames) # " active games." # upgradeMsg # " Delete one to recover this game.");
            };
            
            let restoredGame : GameInfo = {
              gameId = deleted.game.gameId;
              name = deleted.game.name;
              description = deleted.game.description;
              owner = deleted.game.owner;
              gameUrl = deleted.game.gameUrl;
              created = deleted.game.created;
              accessMode = deleted.game.accessMode;
              totalPlayers = deleted.game.totalPlayers;
              totalPlays = deleted.game.totalPlays;
              isActive = true;
              maxScorePerRound = deleted.game.maxScorePerRound;
              maxStreakDelta = deleted.game.maxStreakDelta;
              absoluteScoreCap = deleted.game.absoluteScoreCap;
              absoluteStreakCap = deleted.game.absoluteStreakCap;
          timeValidationEnabled = deleted.game.timeValidationEnabled;
          minPlayDurationSecs = deleted.game.minPlayDurationSecs;
          maxScorePerSecond = deleted.game.maxScorePerSecond;
          maxSessionDurationMins = deleted.game.maxSessionDurationMins;
          googleClientIds = deleted.game.googleClientIds;
              appleBundleId = deleted.game.appleBundleId;
              appleTeamId = deleted.game.appleTeamId;
            };
            
            games.put(gameId, restoredGame);
            deletedGames.delete(gameId);
            
            #ok("Game '" # deleted.game.name # "' recovered successfully!")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE updateGameStats HELPER TO INCLUDE OAUTH FIELDS
  // ═══════════════════════════════════════════════════════════════════════════════

  func updateGameStats(game : GameInfo, newPlayers : Nat, newPlays : Nat) : GameInfo {
    {
      gameId = game.gameId;
      name = game.name;
      description = game.description;
      owner = game.owner;
      gameUrl = game.gameUrl;
      created = game.created;
      accessMode = game.accessMode;
      totalPlayers = game.totalPlayers + newPlayers;
      totalPlays = game.totalPlays + newPlays;
      isActive = game.isActive;
      maxScorePerRound = game.maxScorePerRound;
      maxStreakDelta = game.maxStreakDelta;
      absoluteScoreCap = game.absoluteScoreCap;
      absoluteStreakCap = game.absoluteStreakCap;
      timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
      appleBundleId = game.appleBundleId;
      appleTeamId = game.appleTeamId;
    }
  };



  public query(msg) func getMyGameCount() : async Nat {
    countGamesByOwner(msg.caller)
  };


  public query func getGame(gameId : Text) : async ?GameInfo {
    games.get(gameId)
  };

  public query func listGames() : async [GameInfo] {
    Iter.toArray(games.vals())
  };

  public query func getActiveGames() : async [GameInfo] {
    Iter.toArray(
      Iter.filter(games.vals(), func (g : GameInfo) : Bool { g.isActive })
    )
  };

  public query func getGamesByOwner(owner : Principal) : async [GameInfo] {
    Iter.toArray(
      Iter.filter(games.vals(), func (g : GameInfo) : Bool { g.owner == owner })
    )
  };

  public query func getGameAccessMode(gameId : Text) : async ?AccessMode {
    switch (games.get(gameId)) {
      case null { null };
      case (?game) { ?game.accessMode };
    }
  };

  public query func getDeveloperTierBySession(sessionId: Text) : async {tier: Text; maxGames: Nat; currentGames: Nat} {
    switch (sessions.get(sessionId)) {
        case null { {tier = "free"; maxGames = 3; currentGames = 0} };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            let maxGames = getMaxGamesForDeveloper(owner);
            let currentGames = getGameCountByOwner(owner);
            let tier = getDeveloperTierText(owner);
            {tier = tier; maxGames = maxGames; currentGames = currentGames}
        };
    };
};

// Also add for II users:
public query func getDeveloperTier() : async {tier: Text; maxGames: Nat; currentGames: Nat} {
    let owner = Principal.fromActor(CheddaBoards); // This won't work - need msg.caller
    {tier = "free"; maxGames = 3; currentGames = 0}
};

// Better version using shared query:
public shared query(msg) func getMyDeveloperTier() : async {tier: Text; maxGames: Nat; currentGames: Nat} {
    let owner = msg.caller;
    let maxGames = getMaxGamesForDeveloper(owner);
    let currentGames = getGameCountByOwner(owner);
    let tier = getDeveloperTierText(owner);
    {tier = tier; maxGames = maxGames; currentGames = currentGames}
};

public query func getScoreboardArchives(
    gameId : Text,
    scoreboardId : Text
  ) : async [ArchiveInfo] {
    let prefix = gameId # ":" # scoreboardId # ":";
    let results = Buffer.Buffer<ArchiveInfo>(10);
    
    for ((key, archive) in scoreboardArchives.entries()) {
      if (Text.startsWith(key, #text prefix)) {
        let topPlayer : ?Text = if (archive.entries.size() > 0) {
          ?archive.entries[0].nickname
        } else { null };
        
        let topScore : Nat64 = if (archive.entries.size() > 0) {
          switch (archive.sortBy) {
            case (#score) { archive.entries[0].score };
            case (#streak) { archive.entries[0].streak };
          }
        } else { 0 };
        
        results.add({
          archiveId = key;
          scoreboardId = archive.scoreboardId;
          periodStart = archive.periodStart;
          periodEnd = archive.periodEnd;
          entryCount = archive.totalEntries;
          topPlayer = topPlayer;
          topScore = topScore;
        });
      };
    };
    
    // Sort by periodEnd descending (newest first)
    let sorted = Array.sort<ArchiveInfo>(
      Buffer.toArray(results),
      func(a, b) {
        if (a.periodEnd > b.periodEnd) { #less }
        else if (a.periodEnd < b.periodEnd) { #greater }
        else { #equal }
      }
    );
    
    sorted
  };

 public query func getArchivedScoreboard(
    archiveId : Text,
    limit : Nat
  ) : async Result.Result<{
    config : {
      name : Text;
      period : Text;
      sortBy : Text;
      periodStart : Nat64;
      periodEnd : Nat64;
    };
    entries : [PublicScoreEntry];
  }, Text> {
    switch (scoreboardArchives.get(archiveId)) {
      case null { #err("Archive not found") };
      case (?archive) {
        let cap = if (limit == 0 or limit > archive.entries.size()) { 
          archive.entries.size() 
        } else { limit };
        
        let publicEntries = Buffer.Buffer<PublicScoreEntry>(cap);
        var rank : Nat = 1;
        
        for (entry in archive.entries.vals()) {
          if (rank <= cap) {
            publicEntries.add({
              nickname = entry.nickname;
              score = entry.score;
              streak = entry.streak;
              submittedAt = entry.submittedAt;
              authType = authTypeToText(entry.authType);
              rank = rank;
            });
            rank += 1;
          };
        };
        
        #ok({
          config = {
            name = archive.name;
            period = periodToText(archive.period);
            sortBy = switch (archive.sortBy) { case (#score) "score"; case (#streak) "streak" };
            periodStart = archive.periodStart;
            periodEnd = archive.periodEnd;
          };
          entries = Buffer.toArray(publicEntries);
        })
      };
    };
  };

  public query func getLastArchivedScoreboard(
    gameId : Text,
    scoreboardId : Text,
    limit : Nat
  ) : async Result.Result<{
    archiveId : Text;
    config : {
      name : Text;
      period : Text;
      sortBy : Text;
      periodStart : Nat64;
      periodEnd : Nat64;
    };
    entries : [PublicScoreEntry];
  }, Text> {
    let prefix = gameId # ":" # scoreboardId # ":";
    var latestKey : ?Text = null;
    var latestTime : Nat64 = 0;
    
    for ((key, archive) in scoreboardArchives.entries()) {
      if (Text.startsWith(key, #text prefix)) {
        if (archive.periodEnd > latestTime) {
          latestTime := archive.periodEnd;
          latestKey := ?key;
        };
      };
    };
    
    switch (latestKey) {
      case null { #err("No archives found for this scoreboard") };
      case (?key) {
        switch (scoreboardArchives.get(key)) {
          case null { #err("Archive not found") };
          case (?archive) {
            let cap = if (limit == 0 or limit > archive.entries.size()) { 
              archive.entries.size() 
            } else { limit };
            
            let publicEntries = Buffer.Buffer<PublicScoreEntry>(cap);
            var rank : Nat = 1;
            
            for (entry in archive.entries.vals()) {
              if (rank <= cap) {
                publicEntries.add({
                  nickname = entry.nickname;
                  score = entry.score;
                  streak = entry.streak;
                  submittedAt = entry.submittedAt;
                  authType = authTypeToText(entry.authType);
                  rank = rank;
                });
                rank += 1;
              };
            };
            
            #ok({
              archiveId = key;
              config = {
                name = archive.name;
                period = periodToText(archive.period);
                sortBy = switch (archive.sortBy) { case (#score) "score"; case (#streak) "streak" };
                periodStart = archive.periodStart;
                periodEnd = archive.periodEnd;
              };
              entries = Buffer.toArray(publicEntries);
            })
          };
        };
      };
    };
  };

   public query func getArchivesInRange(
    gameId : Text,
    scoreboardId : Text,
    afterTimestamp : Nat64,
    beforeTimestamp : Nat64
  ) : async [ArchiveInfo] {
    let prefix = gameId # ":" # scoreboardId # ":";
    let results = Buffer.Buffer<ArchiveInfo>(10);
    
    for ((key, archive) in scoreboardArchives.entries()) {
      if (Text.startsWith(key, #text prefix)) {
        // Check if archive falls within range
        if (archive.periodEnd >= afterTimestamp and archive.periodEnd <= beforeTimestamp) {
          let topPlayer : ?Text = if (archive.entries.size() > 0) {
            ?archive.entries[0].nickname
          } else { null };
          
          let topScore : Nat64 = if (archive.entries.size() > 0) {
            switch (archive.sortBy) {
              case (#score) { archive.entries[0].score };
              case (#streak) { archive.entries[0].streak };
            }
          } else { 0 };
          
          results.add({
            archiveId = key;
            scoreboardId = archive.scoreboardId;
            periodStart = archive.periodStart;
            periodEnd = archive.periodEnd;
            entryCount = archive.totalEntries;
            topPlayer = topPlayer;
            topScore = topScore;
          });
        };
      };
    };
    
    // Sort by periodEnd descending (newest first)
    let sorted = Array.sort<ArchiveInfo>(
      Buffer.toArray(results),
      func(a, b) {
        if (a.periodEnd > b.periodEnd) { #less }
        else if (a.periodEnd < b.periodEnd) { #greater }
        else { #equal }
      }
    );
    
    sorted
  };

   public query func getArchiveStats(gameId : Text) : async {
    totalArchives : Nat;
    byScoreboard : [(Text, Nat)];
  } {
    let counts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
    var total : Nat = 0;
    
    for ((key, archive) in scoreboardArchives.entries()) {
      if (archive.gameId == gameId) {
        total += 1;
        switch (counts.get(archive.scoreboardId)) {
          case (?c) { counts.put(archive.scoreboardId, c + 1) };
          case null { counts.put(archive.scoreboardId, 1) };
        };
      };
    };
    
    {
      totalArchives = total;
      byScoreboard = Iter.toArray(counts.entries());
    }
  };
// ─────────────────────────────────────────────────────────────────────────────
// 10. UPDATE getRemainingGameSlotsBySession to use dynamic max:
// ─────────────────────────────────────────────────────────────────────────────

public query func getRemainingGameSlotsBySession(sessionId: Text) : async Nat {
    switch (sessions.get(sessionId)) {
        case null { return 0 };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            let maxGames = getMaxGamesForDeveloper(owner);
            let count = getGameCountByOwner(owner);
            if (count >= maxGames) { 0 } else { maxGames - count }
        };
    };
};

// And for II users:
public shared query(msg) func getRemainingGameSlots() : async Nat {
    let owner = msg.caller;
    let maxGames = getMaxGamesForDeveloper(owner);
    let count = getGameCountByOwner(owner);
    if (count >= maxGames) { 0 } else { maxGames - count }
};

  // ════════════════════════════════════════════════════════════════════════════
  // API KEY MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════

  // Generate API key for a game (owner only)
  public shared(msg) func generateApiKey(gameId : Text) : async Result.Result<Text, Text> {
    let game = switch (games.get(gameId)) {
      case null { return #err("Game not found"); };
      case (?g) { g };
    };
    
    if (game.owner != msg.caller) {
      return #err("Only the game owner can generate API keys");
    };
    
    // Check if active key already exists
    for ((key, apiKey) in apiKeys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return #err("Active API key exists. Revoke it first to generate a new one.");
      };
    };
    
    let timestamp = Time.now();
    let hash = Text.hash(gameId # Int.toText(timestamp) # Principal.toText(msg.caller));
    let key = "cb_" # gameId # "_" # Nat32.toText(hash);
    
    let apiKey : ApiKey = {
      key = key;
      gameId = gameId;
      owner = msg.caller;
      created = timestamp;
      lastUsed = timestamp;
      tier = "free";
      requestsToday = 0;
      isActive = true;
    };
    
    apiKeys.put(key, apiKey);
    
    trackEventInternal(#principal(msg.caller), gameId, "api_key_generated", [
      ("gameId", gameId)
    ]);
    
    #ok(key)
  };

  // Get API key for a game (owner only)
  public shared(msg) func getApiKey(gameId : Text) : async Result.Result<Text, Text> {
    let game = switch (games.get(gameId)) {
      case null { return #err("Game not found"); };
      case (?g) { g };
    };
    
    if (game.owner != msg.caller) {
      return #err("Only the game owner can view API keys");
    };
    
    for ((key, apiKey) in apiKeys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        return #ok(key);
      };
    };
    
    #err("No API key found. Generate one first.")
  };

 // Check if game has API key
  public query func hasApiKey(gameId : Text) : async Bool {
      for ((_, apiKey) in apiKeys.entries()) {
          if (apiKey.gameId == gameId and apiKey.isActive) {
              return true;
          };
      };
      false
  };

  // Validate API key (called by proxy) - query for efficiency
  public query func validateApiKeyQuery(key : Text) : async ?{
    gameId : Text;
    tier : Text;
    isActive : Bool;
  } {
    switch (apiKeys.get(key)) {
      case null { null };
      case (?apiKey) {
        if (apiKey.isActive) {
          ?{ gameId = apiKey.gameId; tier = apiKey.tier; isActive = true }
        } else { null }
      };
    }
  };

  // Full API key validation (update call to track usage)
  public shared func validateApiKey(key : Text) : async ?ApiKey {
    switch (apiKeys.get(key)) {
      case null { null };
      case (?apiKey) {
        if (apiKey.isActive) {
          // Update last used time
          let updated : ApiKey = {
            key = apiKey.key;
            gameId = apiKey.gameId;
            owner = apiKey.owner;
            created = apiKey.created;
            lastUsed = Time.now();
            tier = apiKey.tier;
            requestsToday = apiKey.requestsToday + 1;
            isActive = apiKey.isActive;
          };
          apiKeys.put(key, updated);
          ?updated
        } else { null }
      };
    }
  };

  // Revoke API key
  public shared(msg) func revokeApiKey(gameId : Text) : async Result.Result<Text, Text> {
    let game = switch (games.get(gameId)) {
      case null { return #err("Game not found"); };
      case (?g) { g };
    };
    
    if (game.owner != msg.caller and not isAdmin(msg.caller)) {
      return #err("Only the game owner can revoke API keys");
    };
    
    for ((key, apiKey) in apiKeys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        let updated : ApiKey = {
          key = apiKey.key;
          gameId = apiKey.gameId;
          owner = apiKey.owner;
          created = apiKey.created;
          lastUsed = apiKey.lastUsed;
          tier = apiKey.tier;
          requestsToday = apiKey.requestsToday;
          isActive = false;
        };
        apiKeys.put(key, updated);
        
        trackEventInternal(#principal(msg.caller), gameId, "api_key_revoked", [
          ("gameId", gameId)
        ]);
        
        return #ok("API key revoked");
      };
    };
    
    #err("No active API key found")
  };

  // Update API key tier (owner or admin)
  public shared(msg) func updateApiKeyTier(gameId : Text, newTier : Text) : async Result.Result<Text, Text> {
    let game = switch (games.get(gameId)) {
      case null { return #err("Game not found"); };
      case (?g) { g };
    };
    
    if (game.owner != msg.caller and not isAdmin(msg.caller)) {
      return #err("Only the game owner can update API key tier");
    };
    
    // Validate tier
    if (newTier != "free" and newTier != "indie" and newTier != "pro") {
      return #err("Invalid tier. Use: free, indie, or pro");
    };
    
    for ((key, apiKey) in apiKeys.entries()) {
      if (apiKey.gameId == gameId and apiKey.isActive) {
        let updated : ApiKey = {
          key = apiKey.key;
          gameId = apiKey.gameId;
          owner = apiKey.owner;
          created = apiKey.created;
          lastUsed = Time.now();
          tier = newTier;
          requestsToday = apiKey.requestsToday;
          isActive = apiKey.isActive;
        };
        apiKeys.put(key, updated);
        return #ok("Tier updated to " # newTier);
      };
    };
    
    #err("No active API key found")
  };

  // ════════════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ════════════════════════════════════════════════════════════════════════════

  func validateSessionInternal(sessionId : Text) : Result.Result<Session, Text> {
    switch (sessions.get(sessionId)) {
      case null {
        #err("Invalid session: not found")
      };
      case (?session) {
        let currentTime = now();
        
        if (currentTime > session.expires) {
          sessions.delete(sessionId);
          return #err("Session expired");
        };
        
        #ok(session)
      };
    }
  };

  public shared func validateSession(sessionId : Text) : async Result.Result<{ email: Text; nickname: Text; valid: Bool }, Text> {
    switch (sessions.get(sessionId)) {
      case (?session) {
        if (session.expires < now()) {
          sessions.delete(sessionId);
          #err("Session expired")
        } else {
          let updated = {
            sessionId = session.sessionId;
            email = session.email;
            nickname = session.nickname;
            authType = session.authType;
            created = session.created;
            expires = session.expires;
            lastUsed = now();
          };
          sessions.put(sessionId, updated);
          
          #ok({
            email = session.email;
            nickname = session.nickname;
            valid = true;
          })
        }
      };
      case null { #err("Invalid session") };
    }
  };

  public shared func destroySession(sessionId : Text) : async Result.Result<Text, Text> {
    switch (sessions.remove(sessionId)) {
      case (?_) { #ok("Session destroyed") };
      case null { #err("Session not found") };
    }
  };

  public shared(msg) func iiLoginAndGetProfile(
    nickname : Text,
    gameId : Text
  ) : async Result.Result<{
    message : Text;
    isNewUser : Bool;
    nickname : Text;
    gameProfile : ?{
      total_score : Nat64;
      best_streak : Nat64;
      achievements : [Text];
      last_played : Nat64;
      play_count : Nat;
    };
  }, Text> {
    
    let caller = msg.caller;
    
    if (Text.size(nickname) < 2 or Text.size(nickname) > 12) {
      return #err("Nickname must be 2-12 characters");
    };
    
    if (Principal.isAnonymous(caller)) {
      return #err("Internet Identity required");
    };
    
    let (user, isNewUser) = switch (usersByPrincipal.get(caller)) {
      case (?existingUser) {
        (existingUser, false)
      };
      case null {
        let newUser : UserProfile = {
          identifier = #principal(caller);
          nickname = nickname;
          authType = #internetIdentity;
          gameProfiles = [];
          created = now();
          last_updated = now();
        };
        usersByPrincipal.put(caller, newUser);
        
        trackEventInternal(#principal(caller), "default", "signup", [
          ("provider", "internetIdentity"),
          ("nickname", nickname)
        ]);
        
        (newUser, true)
      };
    };
    
    var gameProfile : ?{
      total_score : Nat64;
      best_streak : Nat64;
      achievements : [Text];
      last_played : Nat64;
      play_count : Nat;
    } = null;
    
    for ((gId, gp) in user.gameProfiles.vals()) {
      if (gId == gameId) {
        gameProfile := ?{
          total_score = gp.total_score;
          best_streak = gp.best_streak;
          achievements = gp.achievements;
          last_played = gp.last_played;
          play_count = gp.play_count;
        };
      };
    };
    
    let message = if (isNewUser) {
      "Account created for " # user.nickname
    } else {
      "Welcome back, " # user.nickname
    };
    
    #ok({
      message = message;
      isNewUser = isNewUser;
      nickname = user.nickname;
      gameProfile = gameProfile;
    })
  };

  public shared(msg) func socialLoginAndGetProfile(
    email : Text,
    nickname : Text,
    provider : Text,
    gameId : Text
  ) : async Result.Result<{
    message : Text;
    isNewUser : Bool;
    nickname : Text;
    sessionId : Text;
    gameProfile : ?{
      total_score : Nat64;
      best_streak : Nat64;
      achievements : [Text];
      last_played : Nat64;
      play_count : Nat;
    };
  }, Text> {
    
    if (Text.size(nickname) < 2 or Text.size(nickname) > 12) {
      return #err("Nickname must be 2-12 characters");
    };
    
    let authType = if (provider == "google") { #google } else { #apple };
    
    let (user, isNewUser) = switch (usersByEmail.get(email)) {
      case (?existingUser) {
        (existingUser, false)
      };
      case null {
        let newUser : UserProfile = {
          identifier = #email(email);
          nickname = nickname;
          authType = authType;
          gameProfiles = [];
          created = now();
          last_updated = now();
        };
        usersByEmail.put(email, newUser);
        
        trackEventInternal(#email(email), "default", "signup", [
          ("provider", provider),
          ("nickname", nickname)
        ]);
        
        (newUser, true)
      };
    };
    
    let sessionId = generateSessionId();
    let session : Session = {
      sessionId = sessionId;
      email = email;
      nickname = user.nickname;
      authType = authType;
      created = now();
      expires = now() + SESSION_DURATION_NS;
      lastUsed = now();
    };
    sessions.put(sessionId, session);
    principalToSession.put(Principal.toText(msg.caller), sessionId);

    var gameProfile : ?{
      total_score : Nat64;
      best_streak : Nat64;
      achievements : [Text];
      last_played : Nat64;
      play_count : Nat;
    } = null;
    
    for ((gId, gp) in user.gameProfiles.vals()) {
      if (gId == gameId) {
        gameProfile := ?{
          total_score = gp.total_score;
          best_streak = gp.best_streak;
          achievements = gp.achievements;
          last_played = gp.last_played;
          play_count = gp.play_count;
        };
      };
    };
    
    let message = if (isNewUser) {
      "Account created for " # user.nickname
    } else {
      "Welcome back, " # user.nickname
    };
    
    #ok({
      message = message;
      isNewUser = isNewUser;
      nickname = user.nickname;
      sessionId = sessionId;
      gameProfile = gameProfile;
    })
  };

  public shared ({ caller }) func createSessionForVerifiedUser(
    idp   : AuthType,
    sub   : Text,
    email : ?Text,
    nonce : Text
  ) : async Result.Result<Session, Text> {

    if (caller != VERIFIER) {
      return #err("Unauthorized: caller is not verifier");
    };

    let userEmail : Text = switch (email) {
      case (null) { return #err("Email required"); };
      case (?e) { e };
    };

    let defaultNickname : Text = generateDefaultNickname();

    let tNow = now();
    let userIdentifier : UserIdentifier = #email(userEmail);

    let actualNickname : Text = switch (usersByEmail.get(userEmail)) {
      case (null) {
        let profile : UserProfile = {
          identifier   = userIdentifier;
          nickname     = defaultNickname;
          authType     = idp;
          gameProfiles = [];
          created      = tNow;
          last_updated = tNow;
        };
        usersByEmail.put(userEmail, profile);
        defaultNickname
      };

      case (?existing) {
        let updated : UserProfile = {
          identifier   = existing.identifier;
          nickname     = existing.nickname;
          authType     = idp;
          gameProfiles = existing.gameProfiles;
          created      = existing.created;
          last_updated = tNow;
        };
        usersByEmail.put(userEmail, updated);
        existing.nickname
      };
    };

    let sessionToken : Text = generateSessionId();
    let session : Session = {
      sessionId = sessionToken;
      email     = userEmail;
      nickname  = actualNickname;
      authType  = idp;
      created   = tNow;
      expires   = tNow + SESSION_DURATION_NS;
      lastUsed  = tNow;
    };
    sessions.put(sessionToken, session);

    return #ok(session);
  };

  public shared(msg) func suggestNickname() : async Result.Result<Text, Text> {
    let suggestion = generateDefaultNickname();
    #ok(suggestion)
  };

  public shared(msg) func getNicknameBySession(sessionId : Text) : async Result.Result<Text, Text> {
    switch (validateSessionInternal(sessionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(session)) { #ok(session.nickname) };
    };
  };

  public shared(msg) func changeNicknameAndGetProfile(
    userIdType : Text,
    userId : Text,
    newNickname : Text,
    gameId : Text
  ) : async Result.Result<{
    message : Text;
    nickname : Text;
    gameProfile : ?{
      total_score : Nat64;
      best_streak : Nat64;
      achievements : [Text];
      last_played : Nat64;
      play_count : Nat;
    };
  }, Text> {
    
    switch (validateCaller(msg, userIdType, userId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };
    
    switch (validateNickname(newNickname)) {
      case (#err(e)) { return #err(e) };
      case (#ok()) {};
    };
    
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { 
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("session") {
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(msg.caller) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };
    
    // Check AFTER identifier is defined
    if (isNicknameTaken(newNickname, ?identifier)) {
      return #err("Nickname already taken");
    };
    
    let user = getUserByIdentifier(identifier);
    
    switch (user) {
      case null { #err("User not found") };
      case (?u) {
        let updatedUser : UserProfile = {
          identifier = u.identifier;
          nickname = newNickname;
          authType = u.authType;
          gameProfiles = u.gameProfiles;
          created = u.created;
          last_updated = now();
        };
        
        putUserByIdentifier(updatedUser);
        
        trackEventInternal(u.identifier, "default", "nickname_changed", [
          ("old_nickname", u.nickname),
          ("new_nickname", newNickname)
        ]);
        
        var gameProfile : ?{
          total_score : Nat64;
          best_streak : Nat64;
          achievements : [Text];
          last_played : Nat64;
          play_count : Nat;
        } = null;
        
        for ((gId, gp) in updatedUser.gameProfiles.vals()) {
          if (gId == gameId) {
            gameProfile := ?{
              total_score = gp.total_score;
              best_streak = gp.best_streak;
              achievements = gp.achievements;
              last_played = gp.last_played;
              play_count = gp.play_count;
            };
          };
        };
        
        #ok({
          message = "Nickname changed to " # newNickname;
          nickname = newNickname;
          gameProfile = gameProfile;
        })
      };
    };
  };

  // ════════════════════════════════════════════════════════════════════════════
  // SCORE SUBMISSION - Updated for external users
  // ════════════════════════════════════════════════════════════════════════════

  public query func getDetailedStats(gameId : Text) : async {
    submissions: {
      total: Nat;
      today: Nat;
    };
    game: ?{
      totalPlayers: Nat;
      totalGames: Nat;
      isActive: Bool;
    };
  } {
    let gameInfo = switch (games.get(gameId)) {
      case (?g) {
        ?{
          totalPlayers = g.totalPlayers;
          totalGames = g.totalPlays;
          isActive = g.isActive;
        }
      };
      case null { null };
    };
    
    {
      submissions = {
        total = totalSubmissions;
        today = submissionsToday;
      };
      game = gameInfo;
    }
  };

  public query func getSubmissionStats() : async {
    total: Nat;
    today: Nat;
    date: Text;
  } {
    {
      total = totalSubmissions;
      today = submissionsToday;
      date = lastResetDate;
    }
  };

  public shared(msg) func submitScore(
    userIdType : Text,
    userId : Text,
    gameId : Text,
    scoreNat : Nat,
    streakNat : Nat,
    roundsPlayed : ?Nat,
    nickname : ?Text,
    playSessionToken : ?Text
  ) : async Result.Result<Text, Text> {
    
    totalSubmissions += 1;
    let t = now();
    let currentDate = getDateString(t);
    if (currentDate != lastResetDate) {
      submissionsToday := 0;
      lastResetDate := currentDate;
    };
    submissionsToday += 1;
    
    let rounds : Nat = switch (roundsPlayed) {
      case (?r) { r };
      case null { 1 };
    };
    
    // Validate caller
    switch (validateCaller(msg, userIdType, userId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };
    
    // Build identifier based on user type
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { 
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("session") {
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(msg.caller) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };
    
    let score = Nat64.fromNat(scoreNat);
    let streak = Nat64.fromNat(streakNat);
    let rules = getValidationRules(gameId);

    // Validate game exists and is active
    let game = switch (games.get(gameId)) {
      case null { 
        return #err("Game not found. Please register the game first.");
      };
      case (?g) {
        if (not g.isActive) {
          return #err("Game is not active");
        };
        g
      };
    };

    // Check access mode
    switch (validateAccessMode(game, userIdType)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };

    // Validate score and streak
    switch (validateScore(score, gameId)) {
      case (#err(e)) { 
        logSuspicion(userId # "/" # userIdType, gameId, "Invalid score: " # e);
        return #err(e);
      };
      case (#ok()) {};
    };

    switch (validateStreak(streak, gameId)) {
      case (#err(e)) {
        logSuspicion(userId # "/" # userIdType, gameId, "Invalid streak: " # e);
        return #err(e);
      };
      case (#ok()) {};
    };

    // Get or create user
    var user = getUserByIdentifier(identifier);
    
    // Auto-create external users if they don't exist
    if (Option.isNull(user) and userIdType == "external") {
      userIdCounter += 1;
      
      // Use provided nickname or generate default
      let playerNickname = switch (nickname) {
        case (?n) { 
          if (Text.size(n) >= 2 and Text.size(n) <= 20 and not isNicknameTaken(n, null)) { n } 
          else { "Player_" # Nat.toText(userIdCounter) }
        };
        case null { "Player_" # Nat.toText(userIdCounter) };
      };
      
      let newUser : UserProfile = {
        identifier = identifier;
        nickname = playerNickname;
        authType = #external;
        gameProfiles = [];
        created = t;
        last_updated = t;
      };
      usersByEmail.put("ext:" # userId, newUser);
      user := ?newUser;
      
      trackEventInternal(identifier, gameId, "external_user_created", [
        ("playerId", userId),
        ("nickname", playerNickname)
      ]);
    };
    
    // Track if nickname changed
    var nicknameChanged = false;
    var updatedNickname = "";
    
    switch (user, nickname) {
      case (?u, ?n) {
        if (n != u.nickname and Text.size(n) >= 2 and Text.size(n) <= 20 and not isNicknameTaken(n, ?u.identifier)) {
          let updatedWithNickname : UserProfile = {
            identifier = u.identifier;
            nickname = n;
            authType = u.authType;
            gameProfiles = u.gameProfiles;
            created = u.created;
            last_updated = t;
          };
          putUserByIdentifier(updatedWithNickname);
          user := ?updatedWithNickname;
          nicknameChanged := true;
          updatedNickname := n;
        };
      };
      case _ {};
    };
        
    switch (user) {
      case (?u) {
        let submitKey = makeSubmitKey(u.identifier, gameId);
        switch (lastSubmitTime.get(submitKey)) {
          case (?prev) {
            if (t - prev < 2_000_000_000) {
              return #err("Please wait 2 seconds between submissions.");
            };
          };
          case null {};
        };
        lastSubmitTime.put(submitKey, t);

        // Time validation check (if enabled for this game)
        let timeRules = getTimeValidationRules(gameId);
        if (timeRules.enabled) {
          switch (playSessionToken) {
            case null {
              return #err("This game requires starting a session before submitting. Call startGameSession first.");
            };
            case (?token) {
              let validation = validatePlaySession(token, u.identifier, gameId, score);
              if (not validation.isValid) {
                switch (validation.reason) {
                  case (?reason) {
                    logSuspicion(identifierToText(u.identifier), gameId, "Time validation failed: " # reason);
                    return #err(reason);
                  };
                  case null {
                    return #err("Play session validation failed.");
                  };
                };
              };
              // Valid session - consume it so it can't be reused
              consumePlaySession(token);
            };
          };
        };

        var gameProfiles = Buffer.Buffer<(Text, GameProfile)>(u.gameProfiles.size());
        var found = false;
        var scoreImproved = false;
        var streakImproved = false;
        var existingScore : Nat64 = 0;
        var existingStreak : Nat64 = 0;

        for ((gId, gProfile) in u.gameProfiles.vals()) {
          if (gId == gameId) {
            found := true;
            existingScore := gProfile.total_score;
            existingStreak := gProfile.best_streak;
            
            var updatedScore = gProfile.total_score;
            var updatedStreak = gProfile.best_streak;
            
            if (score > gProfile.total_score) {
              // Only check delta if developer set a limit
              switch (rules.maxScorePerRound) {
                case (?maxDelta) {
                  if (score - gProfile.total_score > maxDelta) {
                    logSuspicion(identifierToText(u.identifier), gameId, "Score delta too high");
                    return #err("Score increase too large.");
                  };
                };
                case null {}; // No limit set, skip check
              };
              updatedScore := score;
              scoreImproved := true;
            };

            if (streak > gProfile.best_streak) {
              // Only check delta if developer set a limit
              switch (rules.maxStreakDelta) {
                case (?maxDelta) {
                  if (streak - gProfile.best_streak > maxDelta) {
                    logSuspicion(identifierToText(u.identifier), gameId, "Streak delta too high");
                    return #err("Streak increase too large.");
                  };
                };
                case null {}; // No limit set, skip check
              };
              updatedStreak := streak;
              streakImproved := true;
            };
            
            let updated : GameProfile = {
              gameId = gameId;
              total_score = updatedScore;
              best_streak = updatedStreak;
              achievements = gProfile.achievements;
              last_played = t;
              play_count = gProfile.play_count + 1;
            };
            gameProfiles.add((gId, updated));
          } else {
            gameProfiles.add((gId, gProfile));
          };
        };

        if (not found) {
          let newGameProfile : GameProfile = {
            gameId = gameId;
            total_score = score;
            best_streak = streak;
            achievements = [];
            last_played = t;
            play_count = 1;
          };
          gameProfiles.add((gameId, newGameProfile));
          scoreImproved := true;
          streakImproved := true;
          
          switch (games.get(gameId)) {
            case (?gameInfo) {
              games.put(gameId, updateGameStats(gameInfo, 1, rounds));
            };
            case null {};
          };
        } else {
          switch (games.get(gameId)) {
            case (?gameInfo) {
              games.put(gameId, updateGameStats(gameInfo, 0, rounds));
            };
            case null {};
          };
        };

        let updatedUser : UserProfile = {
          identifier = u.identifier;
          nickname = u.nickname;
          authType = u.authType;
          gameProfiles = Buffer.toArray(gameProfiles);
          created = u.created;
          last_updated = t;
        };
        
        putUserByIdentifier(updatedUser);
        
        if (scoreImproved) {
          cachedLeaderboards.delete(gameId # ":score");
        };
        if (streakImproved) {
          cachedLeaderboards.delete(gameId # ":streak");
        };

        if (scoreImproved or streakImproved) {
          let dateStr = getDateString(t);
          let statsKey = dateStr # ":" # gameId;
          switch (dailyStats.get(statsKey)) {
            case (?stats) {
              dailyStats.put(statsKey, {
                date = stats.date;
                gameId = stats.gameId;
                uniquePlayers = stats.uniquePlayers;
                totalGames = stats.totalGames + 1;
                totalScore = stats.totalScore + score;
                newUsers = stats.newUsers;
                authenticatedPlays = stats.authenticatedPlays + 1;
              });
            };
            case null {
              dailyStats.put(statsKey, {
                date = dateStr;
                gameId = gameId;
                uniquePlayers = 1;
                totalGames = 1;
                totalScore = score;
                newUsers = if (not found) 1 else 0;
                authenticatedPlays = 1;
              });
            };
          };
        };
        
        // ALWAYS update scoreboards - let updateScoreboardsForGame handle per-board logic
        // This ensures periodic boards (weekly/daily) get updated even when it's not an all-time best
        updateScoreboardsForGame(gameId, u.identifier, u.nickname, score, streak, u.authType);
        
        // Track analytics only for all-time improvements
        if (scoreImproved or streakImproved) {
          trackEventInternal(u.identifier, gameId, "high_score", [
            ("score", Nat64.toText(score)),
            ("streak", Nat64.toText(streak)),
            ("score_improved", if (scoreImproved) "true" else "false"),
            ("streak_improved", if (streakImproved) "true" else "false"),
            ("rounds", Nat.toText(rounds)),
            ("auth_type", authTypeToText(u.authType))
          ]);
        };
        
        let message = if (scoreImproved and streakImproved) {
          "🎉 New high score and streak!"
        } else if (scoreImproved) {
          "🏆 New high score!"
        } else if (streakImproved) {
          "🔥 New best streak!"
        } else if (nicknameChanged) {
          "✅ Nickname updated"
        } else {
          "✅ Score submitted"
        };
        
        #ok(message # " Score: " # Nat64.toText(score) # ", Streak: " # Nat64.toText(streak))
      };
      case null {
        #err("User not found. Please login first.")
      };
    };
  };


  // ════════════════════════════════════════════════════════════════════════════
  // PLAY SESSION ENDPOINTS (Time Validation)
  // ════════════════════════════════════════════════════════════════════════════

  // Start a game session - Internet Identity users
  public shared(msg) func startGameSession(gameId: Text) : async Result.Result<Text, Text> {
    let caller = msg.caller;
    
    if (Principal.isAnonymous(caller)) {
      return #err("Authentication required");
    };
    
    switch (games.get(gameId)) {
      case null { return #err("Game not found") };
      case (?game) {
        if (not game.isActive) {
          return #err("Game is not active");
        };
        if (not game.timeValidationEnabled) {
          return #err("Time validation not enabled for this game");
        };
      };
    };
    
    let identifier : UserIdentifier = #principal(caller);
    
    cleanupExpiredPlaySessions(identifier, gameId);
    
    let activeCount = countActiveSessionsForPlayer(identifier, gameId);
    if (activeCount >= MAX_ACTIVE_SESSIONS_PER_PLAYER) {
      return #err("Too many active sessions. Finish or wait for current sessions to expire.");
    };
    
    let currentTime = now();
    let rules = getTimeValidationRules(gameId);
    let sessionDurationNanos = Nat64.fromNat(rules.maxSessionDurationMins * 60) * 1_000_000_000;
    
    let token = generatePlaySessionToken(identifier, gameId);
    
    let session : PlaySession = {
      sessionToken = token;
      identifier = identifier;
      gameId = gameId;
      startedAt = currentTime;
      expiresAt = currentTime + sessionDurationNanos;
      isActive = true;
    };
    
    playSessions.put(token, session);
    
    #ok(token)
  };

  // Start a game session - Session-based users (Google/Apple)
  public shared func startGameSessionBySession(
    sessionId: Text,
    gameId: Text
  ) : async Result.Result<Text, Text> {
    
    let identifier : UserIdentifier = switch (validateSessionInternal(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(session)) { #email(session.email) };
    };
    
    switch (games.get(gameId)) {
      case null { return #err("Game not found") };
      case (?game) {
        if (not game.isActive) {
          return #err("Game is not active");
        };
        if (not game.timeValidationEnabled) {
          return #err("Time validation not enabled for this game");
        };
      };
    };
    
    cleanupExpiredPlaySessions(identifier, gameId);
    
    let activeCount = countActiveSessionsForPlayer(identifier, gameId);
    if (activeCount >= MAX_ACTIVE_SESSIONS_PER_PLAYER) {
      return #err("Too many active sessions. Finish or wait for current sessions to expire.");
    };
    
    let currentTime = now();
    let rules = getTimeValidationRules(gameId);
    let sessionDurationNanos = Nat64.fromNat(rules.maxSessionDurationMins * 60) * 1_000_000_000;
    
    let token = generatePlaySessionToken(identifier, gameId);
    
    let session : PlaySession = {
      sessionToken = token;
      identifier = identifier;
      gameId = gameId;
      startedAt = currentTime;
      expiresAt = currentTime + sessionDurationNanos;
      isActive = true;
    };
    
    playSessions.put(token, session);
    
    #ok(token)
  };

  // Start a game session - API key based users (anonymous/device ID)
  public shared func startGameSessionByApiKey(
    apiKeyValue: Text,
    playerId: Text,
    gameId: Text
  ) : async Result.Result<Text, Text> {
    
    // Validate API key
    switch (apiKeys.get(apiKeyValue)) {
      case null { return #err("Invalid API key") };
      case (?key) {
        if (not key.isActive) {
          return #err("API key is inactive");
        };
        if (key.gameId != gameId) {
          return #err("API key not valid for this game");
        };
      };
    };
    
    // Validate playerId
    if (Text.size(playerId) < 3 or Text.size(playerId) > 100) {
      return #err("Invalid player ID");
    };
    
    switch (games.get(gameId)) {
      case null { return #err("Game not found") };
      case (?game) {
        if (not game.isActive) {
          return #err("Game is not active");
        };
        if (not game.timeValidationEnabled) {
          // If time validation not enabled, return a placeholder token
          // The score submission will skip validation
          return #ok("skip_validation_" # gameId # "_" # Nat64.toText(now()));
        };
      };
    };
    
    // Use the same identifier format as submitScore for "external" users
    let identifier : UserIdentifier = #email("ext:" # playerId);
    
    cleanupExpiredPlaySessions(identifier, gameId);
    
    let activeCount = countActiveSessionsForPlayer(identifier, gameId);
    if (activeCount >= MAX_ACTIVE_SESSIONS_PER_PLAYER) {
      return #err("Too many active sessions. Finish or wait for current sessions to expire.");
    };
    
    let currentTime = now();
    let rules = getTimeValidationRules(gameId);
    let sessionDurationNanos = Nat64.fromNat(rules.maxSessionDurationMins * 60) * 1_000_000_000;
    
    let token = generatePlaySessionToken(identifier, gameId);
    
    let session : PlaySession = {
      sessionToken = token;
      identifier = identifier;
      gameId = gameId;
      startedAt = currentTime;
      expiresAt = currentTime + sessionDurationNanos;
      isActive = true;
    };
    
    playSessions.put(token, session);
    
    #ok(token)
  };

  // Query play session status
  public query func getPlaySessionStatus(sessionToken: Text) : async ?{
    gameId: Text;
    startedAt: Nat64;
    expiresAt: Nat64;
    isActive: Bool;
    elapsedSeconds: Nat64;
    remainingSeconds: Nat64;
  } {
    switch (playSessions.get(sessionToken)) {
      case null { null };
      case (?session) {
        let currentTime = now();
        let elapsed = (currentTime - session.startedAt) / 1_000_000_000;
        let remaining : Nat64 = if (currentTime < session.expiresAt) {
          (session.expiresAt - currentTime) / 1_000_000_000
        } else { 0 };
        
        ?{
          gameId = session.gameId;
          startedAt = session.startedAt;
          expiresAt = session.expiresAt;
          isActive = session.isActive and currentTime < session.expiresAt;
          elapsedSeconds = elapsed;
          remainingSeconds = remaining;
        }
      };
    }
  };

  // Cancel a play session (if player quits without submitting)
  public shared(msg) func cancelPlaySession(sessionToken: Text) : async Result.Result<Text, Text> {
    switch (playSessions.get(sessionToken)) {
      case null { #err("Session not found") };
      case (?session) {
        // Verify ownership - check both principal and email-based identifiers
        let callerIdentifier : UserIdentifier = #principal(msg.caller);
        if (not identifiersEqual(session.identifier, callerIdentifier)) {
          // For session-based users, we can't directly verify ownership here
          // So we'll just allow cancellation if the token exists
          // This is safe because cancellation only removes their own session
        };
        
        playSessions.delete(sessionToken);
        #ok("Session cancelled")
      };
    }
  };

  // Update time validation settings for a game
  public shared func updateTimeValidationBySession(
    sessionId: Text,
    gameId: Text,
    timeValidationEnabled: Bool,
    minPlayDurationSecs: ?Nat64,
    maxScorePerSecond: ?Nat64,
    maxSessionDurationMins: ?Nat
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
            
            let updatedGame : GameInfo = {
              gameId = game.gameId;
              name = game.name;
              description = game.description;
              owner = game.owner;
              gameUrl = game.gameUrl;
              created = game.created;
              accessMode = game.accessMode;
              totalPlayers = game.totalPlayers;
              totalPlays = game.totalPlays;
              isActive = game.isActive;
              maxScorePerRound = game.maxScorePerRound;
              maxStreakDelta = game.maxStreakDelta;
              absoluteScoreCap = game.absoluteScoreCap;
              absoluteStreakCap = game.absoluteStreakCap;
          timeValidationEnabled = timeValidationEnabled;
          minPlayDurationSecs = minPlayDurationSecs;
          maxScorePerSecond = maxScorePerSecond;
          maxSessionDurationMins = maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
              appleBundleId = game.appleBundleId;
              appleTeamId = game.appleTeamId;
            };
            
            games.put(gameId, updatedGame);
            
            let status = if (timeValidationEnabled) { "enabled" } else { "disabled" };
            #ok("Time validation " # status # " for " # game.name)
          };
        };
      };
    };
  };

  // Query time validation rules for a game
  public query func getGameTimeValidationRules(gameId: Text) : async {
    enabled: Bool;
    minPlayDurationSecs: Nat64;
    maxScorePerSecond: Nat64;
    maxSessionDurationMins: Nat;
  } {
    getTimeValidationRules(gameId)
  };

  // Admin: Cleanup all expired play sessions
  public shared(msg) func cleanupAllExpiredPlaySessions() : async Result.Result<Nat, Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Only admin can trigger cleanup");
    };
    
    let currentTime = now();
    let keysToRemove = Buffer.Buffer<Text>(50);
    
    for ((token, session) in playSessions.entries()) {
      if (currentTime >= session.expiresAt or not session.isActive) {
        keysToRemove.add(token);
      };
    };
    
    for (key in keysToRemove.vals()) {
      playSessions.delete(key);
    };
    
    #ok(keysToRemove.size())
  };

  // ════════════════════════════════════════════════════════════════════════════
  // SESSION QUERIES
  // ════════════════════════════════════════════════════════════════════════════
  
  public query func getSessionInfo(sessionId : Text) : async ?{
    email: Text;
    nickname: Text;
    authType: Text;
    created: Nat64;
    expires: Nat64;
    lastUsed: Nat64;
  } {
    switch (sessions.get(sessionId)) {
      case (?session) {
        ?{
          email = session.email;
          nickname = session.nickname;
          authType = authTypeToText(session.authType);
          created = session.created;
          expires = session.expires;
          lastUsed = session.lastUsed;
        }
      };
      case null { null };
    }
  };

  public query func getActiveSessions() : async Nat {
    sessions.size()
  };

  // ════════════════════════════════════════════════════════════════════════════
  // ACHIEVEMENTS - Updated for external users
  // ════════════════════════════════════════════════════════════════════════════

  public shared(msg) func unlockAchievement(
    userIdType : Text,
    userId : Text,
    gameId : Text,
    achievementId : Text
  ) : async Result.Result<Text, Text> {

    switch (validateCaller(msg, userIdType, userId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };
      
    // Validate game and check access mode
    let game = switch (games.get(gameId)) {
      case null { return #err("Game not found: " # gameId) };
      case (?g) {
        if (not g.isActive) {
          return #err("Game is not active");
        };
        g
      };
    };

    switch (validateAccessMode(game, userIdType)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };
    
    if (Text.size(achievementId) == 0) {
      return #err("Achievement ID cannot be empty");
    };
    
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { 
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("session") {
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(msg.caller) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };

    let user = getUserByIdentifier(identifier);

    switch (user) {
      case null { #err("User not found") };
      case (?u) {
        var gameProfiles = Buffer.Buffer<(Text, GameProfile)>(u.gameProfiles.size());
        var found = false;
        
        for ((gId, gProfile) in u.gameProfiles.vals()) {
          if (gId == gameId) {
            found := true;
            
            for (existingId in gProfile.achievements.vals()) {
              if (existingId == achievementId) {
                return #ok("Achievement already unlocked.");
              };
            };
            
            let updated : GameProfile = {
              gameId = gameId;
              total_score = gProfile.total_score;
              best_streak = gProfile.best_streak;
              achievements = Array.append(gProfile.achievements, [achievementId]);
              last_played = gProfile.last_played;
              play_count = gProfile.play_count;
            };
            gameProfiles.add((gId, updated));
          } else {
            gameProfiles.add((gId, gProfile));
          };
        };
        
        if (not found) {
          return #err("No profile for this game. Play first!");
        };
        
        let updatedUser : UserProfile = {
          identifier = u.identifier;
          nickname = u.nickname;
          authType = u.authType;
          gameProfiles = Buffer.toArray(gameProfiles);
          created = u.created;
          last_updated = now();
        };
        
        putUserByIdentifier(updatedUser);
        
        trackEventInternal(u.identifier, gameId, "achievement_unlocked", [
          ("achievement_id", achievementId)
        ]);
        
        #ok("Achievement unlocked: " # achievementId)
      };
    };
  };

  public query func getAchievements(userIdType : Text, userId : Text, gameId : Text) : async [Text] {
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return [] };
    };

    switch (getUserByIdentifier(identifier)) {
      case (?user) {
        for ((gId, gProfile) in user.gameProfiles.vals()) {
          if (gId == gameId) {
            return gProfile.achievements;
          };
        };
        []
      };
      case null { [] };
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // LEADERBOARD
  // ════════════════════════════════════════════════════════════════════════════

  public query func getLeaderboard(gameId : Text, sortBy : SortBy, limit : Nat) : async [(Text, Nat64, Nat64, Text)] {
    let cacheKey = gameId # ":" # (switch(sortBy) { case (#score) "score"; case (#streak) "streak" });
    
    switch (cachedLeaderboards.get(cacheKey)) {
      case (?cached) {
        switch (leaderboardLastUpdate.get(cacheKey)) {
          case (?lastUpdate) {
            if (now() - lastUpdate < LEADERBOARD_CACHE_TTL) {
              let cap = if (limit == 0 or limit > 1000) 1000 else limit;
              if (cached.size() <= cap) return cached else return Array.subArray(cached, 0, cap);
            };
          };
          case null {};
        };
      };
      case null {};
    };
    
    var allScores = Buffer.Buffer<(Text, Nat64, Nat64, Text)>(100);
    
    for ((email, user) in usersByEmail.entries()) {
      for ((gId, gProfile) in user.gameProfiles.vals()) {
        if (gId == gameId) {
          allScores.add((
            user.nickname, 
            gProfile.total_score, 
            gProfile.best_streak,
            authTypeToText(user.authType)
          ));
        };
      };
    };
    
    for ((principal, user) in usersByPrincipal.entries()) {
      for ((gId, gProfile) in user.gameProfiles.vals()) {
        if (gId == gameId) {
          allScores.add((
            user.nickname, 
            gProfile.total_score, 
            gProfile.best_streak,
            authTypeToText(user.authType)
          ));
        };
      };
    };
    
    let sorted = Array.sort<(Text, Nat64, Nat64, Text)>(
      Buffer.toArray(allScores),
      func(a, b) {
        switch (sortBy) {
          case (#score) {
            if (a.1 > b.1) #less
            else if (a.1 < b.1) #greater
            else #equal
          };
          case (#streak) {
            if (a.2 > b.2) #less
            else if (a.2 < b.2) #greater
            else #equal
          };
        }
      }
    );
    
    cachedLeaderboards.put(cacheKey, sorted);
    leaderboardLastUpdate.put(cacheKey, now());
    
    let cap = if (limit == 0 or limit > 1000) 1000 else limit;
    if (sorted.size() <= cap) sorted else Array.subArray(sorted, 0, cap)
  };

  public query func getLeaderboardByAuth(gameId : Text, authType : AuthType, sortBy : SortBy, limit : Nat) : async [(Text, Nat64, Nat64, Text)] {
    var filteredScores = Buffer.Buffer<(Text, Nat64, Nat64, Text)>(100);
    
    for ((email, user) in usersByEmail.entries()) {
      if (user.authType == authType) {
        for ((gId, gProfile) in user.gameProfiles.vals()) {
          if (gId == gameId) {
            filteredScores.add((
              user.nickname, 
              gProfile.total_score, 
              gProfile.best_streak,
              authTypeToText(user.authType)
            ));
          };
        };
      };
    };
    
    for ((principal, user) in usersByPrincipal.entries()) {
      if (user.authType == authType) {
        for ((gId, gProfile) in user.gameProfiles.vals()) {
          if (gId == gameId) {
            filteredScores.add((
              user.nickname, 
              gProfile.total_score, 
              gProfile.best_streak,
              authTypeToText(user.authType)
            ));
          };
        };
      };
    };
    
    let sorted = Array.sort<(Text, Nat64, Nat64, Text)>(
      Buffer.toArray(filteredScores),
      func(a, b) {
        switch (sortBy) {
          case (#score) {
            if (a.1 > b.1) #less
            else if (a.1 < b.1) #greater
            else #equal
          };
          case (#streak) {
            if (a.2 > b.2) #less
            else if (a.2 < b.2) #greater
            else #equal
          };
        }
      }
    );
    
    let cap = if (limit == 0 or limit > 1000) 1000 else limit;
    if (sorted.size() <= cap) sorted else Array.subArray(sorted, 0, cap)
  };

  // ════════════════════════════════════════════════════════════════════════════
  // SCOREBOARDS - Developer-configured time-based leaderboards
  // ════════════════════════════════════════════════════════════════════════════

  // Helper: Generate scoreboard key
  private func makeScoreboardKey(gameId : Text, scoreboardId : Text) : Text {
    gameId # ":" # scoreboardId
  };

  // Helper: Check if a scoreboard needs reset based on its period
  private func scoreboardNeedsReset(config : ScoreboardConfig) : Bool {
    let currentTime = now();
    let lastReset = config.lastReset;
    
    switch (config.period) {
      case (#allTime) { false };
      case (#custom) { false };  // Manual reset only
      case (#daily) {
        // Reset if we're on a different day (86400 seconds = 1 day in nanoseconds)
        let daysSinceReset = (currentTime - lastReset) / 86_400_000_000_000;
        daysSinceReset >= 1
      };
      case (#weekly) {
        // Reset if 7+ days have passed
        let daysSinceReset = (currentTime - lastReset) / 86_400_000_000_000;
        daysSinceReset >= 7
      };
      case (#monthly) {
        // Reset if 30+ days have passed (simplified)
        let daysSinceReset = (currentTime - lastReset) / 86_400_000_000_000;
        daysSinceReset >= 30
      };
    }
  };

  // Helper: Reset a scoreboard
  private func resetScoreboard(key : Text, config : ScoreboardConfig) : () {

    archiveScoreboard(key, config);
    
    let newConfig : ScoreboardConfig = {
      scoreboardId = config.scoreboardId;
      gameId = config.gameId;
      name = config.name;
      description = config.description;
      period = config.period;
      sortBy = config.sortBy;
      maxEntries = config.maxEntries;
      created = config.created;
      lastReset = now();
      isActive = config.isActive;
    };
    scoreboardConfigs.put(key, newConfig);
    scoreboardEntries.put(key, Buffer.Buffer<ScoreEntry>(100));
    cachedScoreboards.delete(key);
  };

  // Helper: Convert period to text
  private func periodToText(period : ScoreboardPeriod) : Text {
    switch (period) {
      case (#allTime) { "allTime" };
      case (#daily) { "daily" };
      case (#weekly) { "weekly" };
      case (#monthly) { "monthly" };
      case (#custom) { "custom" };
    }
  };

  // Helper: Text to period
  private func textToPeriod(text : Text) : ?ScoreboardPeriod {
    switch (text) {
      case ("allTime") { ?#allTime };
      case ("daily") { ?#daily };
      case ("weekly") { ?#weekly };
      case ("monthly") { ?#monthly };
      case ("custom") { ?#custom };
      case (_) { null };
    }
  };


  // ═══════════════════════════════════════════════════════════════════════════════
  // CREATE SCOREBOARD (Developer function)
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func createScoreboardBySession(
    sessionId : Text,
    gameId : Text,
    scoreboardId : Text,
    name : Text,
    description : Text,
    periodText : Text,
    sortByText : Text,
    maxEntries : ?Nat
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        // Verify game ownership
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
          };
        };

        // Validate scoreboard ID
        if (Text.size(scoreboardId) < 2 or Text.size(scoreboardId) > 30) {
          return #err("Scoreboard ID must be 2-30 characters");
        };

        let key = makeScoreboardKey(gameId, scoreboardId);
        
        // Check if scoreboard already exists
        switch (scoreboardConfigs.get(key)) {
          case (?_) { return #err("Scoreboard ID already exists for this game") };
          case null {};
        };

        // Parse period
        let period = switch (textToPeriod(periodText)) {
          case null { return #err("Invalid period. Use: allTime, daily, weekly, monthly, custom") };
          case (?p) { p };
        };

        // Parse sortBy
        let sortBy : SortBy = switch (sortByText) {
          case ("score") { #score };
          case ("streak") { #streak };
          case (_) { return #err("Invalid sortBy. Use: score or streak") };
        };

        let maxEntriesVal = switch (maxEntries) {
          case (?n) { if (n > 1000) 1000 else if (n < 10) 10 else n };
          case null { 100 };
        };

        let currentTime = now();
        
        let config : ScoreboardConfig = {
          scoreboardId = scoreboardId;
          gameId = gameId;
          name = name;
          description = description;
          period = period;
          sortBy = sortBy;
          maxEntries = maxEntriesVal;
          created = currentTime;
          lastReset = currentTime;
          isActive = true;
        };

        scoreboardConfigs.put(key, config);
        scoreboardEntries.put(key, Buffer.Buffer<ScoreEntry>(100));

        trackEventInternal(#principal(owner), gameId, "scoreboard_created", [
          ("scoreboardId", scoreboardId),
          ("period", periodText),
          ("sortBy", sortByText)
        ]);

        #ok("Scoreboard '" # name # "' created successfully!")
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // GET SCOREBOARDS FOR GAME
  // ═══════════════════════════════════════════════════════════════════════════════

  public query func getScoreboardsForGame(gameId : Text) : async [{
    scoreboardId : Text;
    name : Text;
    description : Text;
    period : Text;
    sortBy : Text;
    maxEntries : Nat;
    lastReset : Nat64;
    entryCount : Nat;
    isActive : Bool;
  }] {
    let results = Buffer.Buffer<{
      scoreboardId : Text;
      name : Text;
      description : Text;
      period : Text;
      sortBy : Text;
      maxEntries : Nat;
      lastReset : Nat64;
      entryCount : Nat;
      isActive : Bool;
    }>(10);

    for ((key, config) in scoreboardConfigs.entries()) {
      if (config.gameId == gameId and config.isActive) {
        let entryCount = switch (scoreboardEntries.get(key)) {
          case (?buffer) { buffer.size() };
          case null { 0 };
        };

        results.add({
          scoreboardId = config.scoreboardId;
          name = config.name;
          description = config.description;
          period = periodToText(config.period);
          sortBy = switch (config.sortBy) { case (#score) "score"; case (#streak) "streak" };
          maxEntries = config.maxEntries;
          lastReset = config.lastReset;
          entryCount = entryCount;
          isActive = config.isActive;
        });
      };
    };

    Buffer.toArray(results)
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // GET SCOREBOARD ENTRIES
  // ═══════════════════════════════════════════════════════════════════════════════

  public query func getScoreboard(
    gameId : Text,
    scoreboardId : Text,
    limit : Nat
  ) : async Result.Result<{
    config : {
      name : Text;
      description : Text;
      period : Text;
      sortBy : Text;
      lastReset : Nat64;
    };
    entries : [PublicScoreEntry];
  }, Text> {
    let key = makeScoreboardKey(gameId, scoreboardId);
    
    switch (scoreboardConfigs.get(key)) {
      case null { return #err("Scoreboard not found") };
      case (?config) {
        if (not config.isActive) {
          return #err("Scoreboard is not active");
        };

        // Check cache first
        switch (cachedScoreboards.get(key)) {
          case (?cached) {
            switch (scoreboardLastUpdate.get(key)) {
              case (?lastUpdate) {
                if (now() - lastUpdate < SCOREBOARD_CACHE_TTL) {
                  let cap = if (limit == 0 or limit > config.maxEntries) config.maxEntries else limit;
                  let entries = if (cached.size() <= cap) cached else Array.subArray(cached, 0, cap);
                  return #ok({
                    config = {
                      name = config.name;
                      description = config.description;
                      period = periodToText(config.period);
                      sortBy = switch (config.sortBy) { case (#score) "score"; case (#streak) "streak" };
                      lastReset = config.lastReset;
                    };
                    entries = entries;
                  });
                };
              };
              case null {};
            };
          };
          case null {};
        };

        // Build fresh leaderboard
        let buffer = switch (scoreboardEntries.get(key)) {
          case null { Buffer.Buffer<ScoreEntry>(0) };
          case (?b) { b };
        };

        // Sort entries
        let entriesArray = Buffer.toArray(buffer);
        let sorted = Array.sort<ScoreEntry>(entriesArray, func(a, b) {
          switch (config.sortBy) {
            case (#score) {
              if (a.score > b.score) #less
              else if (a.score < b.score) #greater
              else #equal
            };
            case (#streak) {
              if (a.streak > b.streak) #less
              else if (a.streak < b.streak) #greater
              else #equal
            };
          }
        });

        // Convert to public entries with rank
        let publicEntries = Buffer.Buffer<PublicScoreEntry>(sorted.size());
        var rank : Nat = 1;
        for (entry in sorted.vals()) {
          publicEntries.add({
            nickname = entry.nickname;
            score = entry.score;
            streak = entry.streak;
            submittedAt = entry.submittedAt;
            authType = authTypeToText(entry.authType);
            rank = rank;
          });
          rank += 1;
        };

        let publicArray = Buffer.toArray(publicEntries);
        
        // Cache the result
        cachedScoreboards.put(key, publicArray);
        scoreboardLastUpdate.put(key, now());

        let cap = if (limit == 0 or limit > config.maxEntries) config.maxEntries else limit;
        let entries = if (publicArray.size() <= cap) publicArray else Array.subArray(publicArray, 0, cap);

        #ok({
          config = {
            name = config.name;
            description = config.description;
            period = periodToText(config.period);
            sortBy = switch (config.sortBy) { case (#score) "score"; case (#streak) "streak" };
            lastReset = config.lastReset;
          };
          entries = entries;
        })
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // SUBMIT SCORE TO SCOREBOARD
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared(msg) func submitScoreToScoreboard(
    userIdType : Text,
    userId : Text,
    gameId : Text,
    scoreboardId : Text,
    scoreNat : Nat,
    streakNat : Nat,
    nickname : ?Text
  ) : async Result.Result<{ rank : Nat; isNewBest : Bool }, Text> {
    
    let key = makeScoreboardKey(gameId, scoreboardId);
    
    // Validate caller
    switch (validateCaller(msg, userIdType, userId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };

    // Build identifier
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { 
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("session") {
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(msg.caller) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };

    // Get scoreboard config
    switch (scoreboardConfigs.get(key)) {
      case null { return #err("Scoreboard not found") };
      case (?config) {
        if (not config.isActive) {
          return #err("Scoreboard is not active");
        };

        // Check if scoreboard needs reset
        if (scoreboardNeedsReset(config)) {
          resetScoreboard(key, config);
        };

        // Validate game exists
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not game.isActive) {
              return #err("Game is not active");
            };
          };
        };

        let score = Nat64.fromNat(scoreNat);
        let streak = Nat64.fromNat(streakNat);
        let playerId = identifierToText(identifier);

        // Validate score and streak
        switch (validateScore(score, gameId)) {
          case (#err(e)) { 
            logSuspicion(playerId, gameId, "Invalid score submission: " # e);
            return #err(e);
          };
          case (#ok()) {};
        };

        switch (validateStreak(streak, gameId)) {
          case (#err(e)) { 
            logSuspicion(playerId, gameId, "Invalid streak submission: " # e);
            return #err(e);
          };
          case (#ok()) {};
        };

        // Get user info
        let user = getUserByIdentifier(identifier);
        let playerNickname = switch (user) {
          case (?u) { u.nickname };
          case null {
            switch (nickname) {
              case (?n) { n };
              case null { "Player" };
            };
          };
        };

        let authType = switch (user) {
          case (?u) { u.authType };
          case null { #external };
        };

        // Get or create entries buffer
        let buffer = switch (scoreboardEntries.get(key)) {
          case null { 
            let newBuffer = Buffer.Buffer<ScoreEntry>(100);
            scoreboardEntries.put(key, newBuffer);
            newBuffer
          };
          case (?b) { b };
        };

        let currentTime = now();
        
        // Get the value we're comparing based on sortBy
        let newValue = switch (config.sortBy) {
          case (#score) { score };
          case (#streak) { streak };
        };

        // Single O(n) pass: find existing entry AND count better scores
        var existingIdx : ?Nat = null;
        var existingEntry : ?ScoreEntry = null;
        var betterCount : Nat = 0;
        var idx : Nat = 0;
        
        for (entry in buffer.vals()) {
          let entryValue = switch (config.sortBy) {
            case (#score) { entry.score };
            case (#streak) { entry.streak };
          };
          
          if (identifierToText(entry.odentifier) == identifierToText(identifier)) {
            existingIdx := ?idx;
            existingEntry := ?entry;
          } else {
            // Count entries with better scores (for rank calculation)
            if (entryValue > newValue) {
              betterCount += 1;
            };
          };
          idx += 1;
        };

        var isNewBest = false;
        var finalValue = newValue;

        switch (existingEntry) {
          case (?existing) {
            let existingValue = switch (config.sortBy) {
              case (#score) { existing.score };
              case (#streak) { existing.streak };
            };
            
            // Update if better score
            if (newValue > existingValue) {
              let updated : ScoreEntry = {
                odentifier = identifier;
                nickname = playerNickname;
                score = score;
                streak = streak;
                submittedAt = currentTime;
                authType = authType;
              };
              
              switch (existingIdx) {
                case (?i) { buffer.put(i, updated) };
                case null {};
              };
              isNewBest := true;
              finalValue := newValue;
            } else {
              // Keep existing value for rank calculation
              finalValue := existingValue;
            };
          };
          case null {
            // New entry
            let newEntry : ScoreEntry = {
              odentifier = identifier;
              nickname = playerNickname;
              score = score;
              streak = streak;
              submittedAt = currentTime;
              authType = authType;
            };
            buffer.add(newEntry);
            isNewBest := true;

            // If over max entries, remove the worst - O(n)
            if (buffer.size() > config.maxEntries) {
              var worstIdx : Nat = 0;
              var worstValue : Nat64 = switch (config.sortBy) {
                case (#score) { buffer.get(0).score };
                case (#streak) { buffer.get(0).streak };
              };
              
              var i : Nat = 1;
              while (i < buffer.size()) {
                let entryValue = switch (config.sortBy) {
                  case (#score) { buffer.get(i).score };
                  case (#streak) { buffer.get(i).streak };
                };
                if (entryValue < worstValue) {
                  worstValue := entryValue;
                  worstIdx := i;
                };
                i += 1;
              };
              
              // If we're removing ourselves (we're the worst), adjust rank
              let newBuffer = Buffer.Buffer<ScoreEntry>(config.maxEntries);
              i := 0;
              for (entry in buffer.vals()) {
                if (i != worstIdx) {
                  newBuffer.add(entry);
                };
                i += 1;
              };
              scoreboardEntries.put(key, newBuffer);
              
              // If the worst entry was our new entry, we're not on the board
              if (worstValue == newValue) {
                return #ok({ rank = config.maxEntries + 1; isNewBest = false });
              };
            };
          };
        };

        // Invalidate cache
        cachedScoreboards.delete(key);

        // Rank = count of entries better than us + 1
        // For existing entries, recount with final value
        if (Option.isSome(existingEntry) and not isNewBest) {
          // Recount with existing value
          betterCount := 0;
          for (entry in buffer.vals()) {
            if (identifierToText(entry.odentifier) != identifierToText(identifier)) {
              let entryValue = switch (config.sortBy) {
                case (#score) { entry.score };
                case (#streak) { entry.streak };
              };
              if (entryValue > finalValue) {
                betterCount += 1;
              };
            };
          };
        };
        
        let rank = betterCount + 1;

        #ok({ rank = rank; isNewBest = isNewBest })
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // RESET SCOREBOARD (Developer function)
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func resetScoreboardBySession(
    sessionId : Text,
    gameId : Text,
    scoreboardId : Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        // Verify game ownership
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
          };
        };

        let key = makeScoreboardKey(gameId, scoreboardId);
        
        switch (scoreboardConfigs.get(key)) {
          case null { return #err("Scoreboard not found") };
          case (?config) {
            resetScoreboard(key, config);
            
            trackEventInternal(#principal(owner), gameId, "scoreboard_reset", [
              ("scoreboardId", scoreboardId)
            ]);

            #ok("Scoreboard '" # config.name # "' has been reset")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // DELETE SCOREBOARD (Developer function)
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func deleteScoreboardBySession(
    sessionId : Text,
    gameId : Text,
    scoreboardId : Text
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        // Verify game ownership
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
          };
        };

        let key = makeScoreboardKey(gameId, scoreboardId);
        
        switch (scoreboardConfigs.get(key)) {
          case null { return #err("Scoreboard not found") };
          case (?config) {
            // Soft delete - mark as inactive
            let updated : ScoreboardConfig = {
              scoreboardId = config.scoreboardId;
              gameId = config.gameId;
              name = config.name;
              description = config.description;
              period = config.period;
              sortBy = config.sortBy;
              maxEntries = config.maxEntries;
              created = config.created;
              lastReset = config.lastReset;
              isActive = false;
            };
            scoreboardConfigs.put(key, updated);
            
            // Clear entries
            scoreboardEntries.delete(key);
            cachedScoreboards.delete(key);
            
            trackEventInternal(#principal(owner), gameId, "scoreboard_deleted", [
              ("scoreboardId", scoreboardId)
            ]);

            #ok("Scoreboard '" # config.name # "' has been deleted")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // UPDATE SCOREBOARD CONFIG (Developer function)
  // ═══════════════════════════════════════════════════════════════════════════════

  public shared func updateScoreboardBySession(
    sessionId : Text,
    gameId : Text,
    scoreboardId : Text,
    name : ?Text,
    description : ?Text,
    maxEntries : ?Nat
  ) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(owner)) {
        // Verify game ownership
        switch (games.get(gameId)) {
          case null { return #err("Game not found") };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) {
              return #err("You don't own this game");
            };
          };
        };

        let key = makeScoreboardKey(gameId, scoreboardId);
        
        switch (scoreboardConfigs.get(key)) {
          case null { return #err("Scoreboard not found") };
          case (?config) {
            let newName = switch (name) { case (?n) n; case null config.name };
            let newDesc = switch (description) { case (?d) d; case null config.description };
            let newMax = switch (maxEntries) { 
              case (?n) { if (n > 1000) 1000 else if (n < 10) 10 else n }; 
              case null config.maxEntries 
            };

            let updated : ScoreboardConfig = {
              scoreboardId = config.scoreboardId;
              gameId = config.gameId;
              name = newName;
              description = newDesc;
              period = config.period;
              sortBy = config.sortBy;
              maxEntries = newMax;
              created = config.created;
              lastReset = config.lastReset;
              isActive = config.isActive;
            };
            scoreboardConfigs.put(key, updated);
            
            #ok("Scoreboard updated successfully")
          };
        };
      };
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════════
  // GET PLAYER RANK ON SCOREBOARD
  // ═══════════════════════════════════════════════════════════════════════════════

  public query func getPlayerScoreboardRank(
    gameId : Text,
    scoreboardId : Text,
    userIdType : Text,
    userId : Text
  ) : async ?{
    rank : Nat;
    score : Nat64;
    streak : Nat64;
    totalPlayers : Nat;
  } {
    let key = makeScoreboardKey(gameId, scoreboardId);
    
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("session") { 
        switch (sessions.get(userId)) {
          case (?session) { #email(session.email) };
          case null { return null };
        };
      };
      case ("principal") { 
        switch (Principal.fromText(userId)) {
          case p { #principal(p) };
        };
      };
      case ("external") { #email("ext:" # userId) };
      case (_) { return null };
    };

    switch (scoreboardConfigs.get(key)) {
      case null { return null };
      case (?config) {
        let buffer = switch (scoreboardEntries.get(key)) {
          case null { return null };
          case (?b) { b };
        };

        let entriesArray = Buffer.toArray(buffer);
        let sorted = Array.sort<ScoreEntry>(entriesArray, func(a, b) {
          switch (config.sortBy) {
            case (#score) {
              if (a.score > b.score) #less
              else if (a.score < b.score) #greater
              else #equal
            };
            case (#streak) {
              if (a.streak > b.streak) #less
              else if (a.streak < b.streak) #greater
              else #equal
            };
          }
        });

        var rank : Nat = 1;
        for (entry in sorted.vals()) {
          if (identifierToText(entry.odentifier) == identifierToText(identifier)) {
            return ?{
              rank = rank;
              score = entry.score;
              streak = entry.streak;
              totalPlayers = sorted.size();
            };
          };
          rank += 1;
        };

        null
      };
    };
  };
  
  public query func getPlayerRank(
    gameId : Text,
    sortBy : SortBy,
    userIdType : Text,
    userId : Text
  ) : async ?{
    rank : Nat;
    score : Nat64;
    streak : Nat64;
    totalPlayers : Nat;
  } {
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return null };
    };
    
    switch (getUserByIdentifier(identifier)) {
      case null { null };
      case (?user) {
        var userScore : Nat64 = 0;
        var userStreak : Nat64 = 0;
        var found = false;
        
        for ((gId, gProfile) in user.gameProfiles.vals()) {
          if (gId == gameId) {
            userScore := gProfile.total_score;
            userStreak := gProfile.best_streak;
            found := true;
          };
        };
        
        if (not found) return null;
        
        var betterCount = 0;
        var totalCount = 0;
        
        for ((_, otherUser) in usersByEmail.entries()) {
          for ((gId, gProfile) in otherUser.gameProfiles.vals()) {
            if (gId == gameId) {
              totalCount += 1;
              let isBetter = switch (sortBy) {
                case (#score) { gProfile.total_score > userScore };
                case (#streak) { gProfile.best_streak > userStreak };
              };
              if (isBetter) betterCount += 1;
            };
          };
        };
        
        for ((_, otherUser) in usersByPrincipal.entries()) {
          for ((gId, gProfile) in otherUser.gameProfiles.vals()) {
            if (gId == gameId) {
              totalCount += 1;
              let isBetter = switch (sortBy) {
                case (#score) { gProfile.total_score > userScore };
                case (#streak) { gProfile.best_streak > userStreak };
              };
              if (isBetter) betterCount += 1;
            };
          };
        };
        
        ?{
          rank = betterCount + 1;
          score = userScore;
          streak = userStreak;
          totalPlayers = totalCount;
        }
      };
    }
  };

  public query func getGameAuthStats(gameId : Text) : async {
    internetIdentity : Nat;
    google : Nat;
    apple : Nat;
    external : Nat;
    total : Nat;
  } {
    var iiCount = 0;
    var googleCount = 0;
    var appleCount = 0;
    var externalCount = 0;
    var totalCount = 0;
    
    for ((_, user) in usersByEmail.entries()) {
      for ((gId, _) in user.gameProfiles.vals()) {
        if (gId == gameId) {
          totalCount += 1;
          switch (user.authType) {
            case (#google) googleCount += 1;
            case (#apple) appleCount += 1;
            case (#external) externalCount += 1;
            case (_) {};
          };
        };
      };
    };
    
    for ((_, user) in usersByPrincipal.entries()) {
      for ((gId, _) in user.gameProfiles.vals()) {
        if (gId == gameId) {
          totalCount += 1;
          switch (user.authType) {
            case (#internetIdentity) iiCount += 1;
            case (_) {};
          };
        };
      };
    };
    
    {
      internetIdentity = iiCount;
      google = googleCount;
      apple = appleCount;
      external = externalCount;
      total = totalCount;
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // PROFILE QUERIES - Updated for external users
  // ════════════════════════════════════════════════════════════════════════════

  public query func getUserProfile(userIdType : Text, userId : Text) : async Result.Result<PublicUserProfile, Text> {
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("session") { 
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };
    
    switch (getUserByIdentifier(identifier)) {
      case (?profile) { 
        #ok({
          nickname = profile.nickname;
          authType = profile.authType;
          gameProfiles = profile.gameProfiles;
          created = profile.created;
          last_updated = profile.last_updated;
        })
      };
      case null { #err("User not found") };
    };
  };

  public query func getGameProfile(
    userIdType : Text, 
    userId : Text, 
    gameId : Text
  ) : async Result.Result<GameProfile, Text> {
    
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("session") {
        switch (validateSessionInternal(userId)) {
          case (#err(e)) { return #err(e) };
          case (#ok(session)) { #email(session.email) };
        };
      };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return #err("Invalid user type") };
    };

    switch (getUserByIdentifier(identifier)) {
      case (?user) {
        for ((gId, gProfile) in user.gameProfiles.vals()) {
          if (gId == gameId) {
            return #ok(gProfile);
          };
        };
        #err("Game profile not found")
      };
      case null { #err("User not found") };
    }
  };

  public shared(msg) func getMyProfile() : async Result.Result<UserProfile, Text> {
    let caller = msg.caller;
    
    if (Principal.isAnonymous(caller)) {
      return #err("Authentication required");
    };
    
    switch (usersByPrincipal.get(caller)) {
      case (?profile) { 
        #ok(profile)
      };
      case null { 
        #err("Profile not found") 
      };
    };
  };

  public shared(msg) func getMyProfileBySession(sessionId : Text) : async Result.Result<UserProfile, Text> {
    switch (validateSessionInternal(sessionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(session)) {
        switch (usersByEmail.get(session.email)) {
          case (?profile) { #ok(profile) };
          case null { #err("User not found") };
        };
      };
    };
  };

  public shared(msg) func getProfileBySession(sessionId : Text) : async Result.Result<UserProfile, Text> {
    switch (validateSessionInternal(sessionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(session)) {
        switch (usersByEmail.get(session.email)) {
          case (?user) { #ok(user) };
          case null { #err("User profile not found for session") };
        };
      };
    };
  };

  // ════════════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ════════════════════════════════════════════════════════════════════════════

  public shared func trackEvent(
    userIdType : Text,
    userId : Text,
    eventType : Text,
    gameId : Text,
    metadata : [(Text, Text)]
  ) : async () {
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return };
    };
    
    trackEventInternal(identifier, gameId, eventType, metadata);
  };

  public query func getDailyStats(date : Text, gameId : Text) : async ?DailyStats {
    dailyStats.get(date # ":" # gameId)
  };

  public query func getPlayerAnalytics(userIdType : Text, userId : Text, gameId : Text) : async ?PlayerStats {
    let identifier : UserIdentifier = switch (userIdType) {
      case ("email") { #email(userId) };
      case ("principal") { #principal(Principal.fromText(userId)) };
      case ("external") { #email("ext:" # userId) };
      case (_) { return null };
    };
    
    let playerKey = identifierToText(identifier) # ":" # gameId;
    playerStats.get(playerKey)
  };

  public query func getAnalyticsSummary() : async {
    totalEvents : Nat;
    uniquePlayers : Nat;
    totalGames : Nat;
    totalDays : Nat;
    mostActiveDay : Text;
    recentEvents : Nat;
  } {
    var mostGames = 0;
    var mostActiveDay = "";
    
    for ((_, stats) in dailyStats.entries()) {
      if (stats.totalGames > mostGames) {
        mostGames := stats.totalGames;
        mostActiveDay := stats.date;
      };
    };
    
    let recentCount = if (analyticsEvents.size() > 100) { 100 } else { analyticsEvents.size() };
    
    {
      totalEvents = analyticsEvents.size();
      uniquePlayers = usersByEmail.size() + usersByPrincipal.size();
      totalGames = games.size();
      totalDays = dailyStats.size();
      mostActiveDay = mostActiveDay;
      recentEvents = recentCount;
    }
  };

  public query func getRecentEvents(limit : Nat) : async [AnalyticsEvent] {
    let cap = if (limit > 100) { 100 } else { limit };
    let size = analyticsEvents.size();
    
    if (size == 0) { return [] };
    
    let startIdx = if (size > cap) { size - cap } else { 0 };
    
    var events = Buffer.Buffer<AnalyticsEvent>(cap);
    for (i in Iter.range(startIdx, size - 1)) {
      events.add(analyticsEvents.get(i));
    };
    
    Buffer.toArray(events)
  };

  // ════════════════════════════════════════════════════════════════════════════
  // FILE MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════

  public shared func uploadFile(filename : Text, data : Blob) : async Result.Result<Text, Text> {
    if (Blob.toArray(data).size() > MAX_FILE_SIZE) {
      return #err("File too large. Max size: 5MB");
    };
    
    if (List.size(files) >= MAX_FILES) {
      return #err("File limit reached. Max files: " # Nat.toText(MAX_FILES));
    };
    
    var found = false;
    let newFiles = List.map<(Text, Blob), (Text, Blob)>(
      files,
      func (f : (Text, Blob)) : (Text, Blob) {
        if (f.0 == filename) {
          found := true;
          (filename, data)
        } else {
          f
        }
      }
    );
    
    if (found) {
      files := newFiles;
      #ok("File updated: " # filename)
    } else {
      files := List.push((filename, data), files);
      #ok("File uploaded: " # filename)
    }
  };

  public shared func deleteFile(filename : Text) : async Result.Result<Text, Text> {
    let newFiles = List.filter<(Text, Blob)>(
      files,
      func (f : (Text, Blob)) : Bool { f.0 != filename }
    );
    
    if (List.size(newFiles) == List.size(files)) {
      #err("File not found: " # filename)
    } else {
      files := newFiles;
      #ok("File deleted: " # filename)
    }
  };

  public query func listFiles() : async [Text] {
    List.toArray(
      List.map<(Text, Blob), Text>(
        files,
        func(tup : (Text, Blob)) : Text { tup.0 }
      )
    )
  };

  public query func getFile(filename : Text) : async ?Blob {
    let found = List.find<(Text, Blob)>(
      files,
      func(tup : (Text, Blob)) : Bool { tup.0 == filename }
    );
    switch (found) {
      case null null;
      case (?(_, blob)) ?blob;
    }
  };

  public query func getFileInfo(filename : Text) : async ?{ name: Text; size: Nat } {
    let found = List.find<(Text, Blob)>(
      files,
      func(tup : (Text, Blob)) : Bool { tup.0 == filename }
    );
    switch (found) {
      case null null;
      case (?(name, blob)) ?{ name = name; size = Blob.toArray(blob).size() };
    }
  };

  // ════════════════════════════════════════════════════════════════════════════
  // SYSTEM INFO
  // ════════════════════════════════════════════════════════════════════════════

  public query func getSystemInfo() : async {
    emailUserCount : Nat;
    principalUserCount : Nat;
    gameCount : Nat;
    totalEvents : Nat;
    activeDays : Nat;
    fileCount : Nat;
    suspicionLogSize : Nat;
    apiKeyCount : Nat;
  } {
    {
      emailUserCount = usersByEmail.size();
      principalUserCount = usersByPrincipal.size();
      gameCount = games.size();
      totalEvents = analyticsEvents.size();
      activeDays = dailyStats.size();
      fileCount = List.size(files);
      suspicionLogSize = List.size(suspicionLog);
      apiKeyCount = apiKeys.size();
    }
  };

  public shared(msg) func adminCleanupSessions() : async Text {
    if (not isAdmin(msg.caller)) {
      throw Error.reject("Admin only");
    };
    
    let before = sessions.size();
    cleanupExpiredSessions();
    let after = sessions.size();
    
    "Cleaned " # Nat.toText(before - after) # " expired sessions"
  };

  // ════════════════════════════════════════════════════════════════════════════
  // ADMIN
  // ════════════════════════════════════════════════════════════════════════════

  public shared(msg) func adminGate(command : Text, args : [Text]) : async Result.Result<Text, Text> {
    if (emergencyPaused and command != "emergencyUnpause") {
      logAction(msg.caller, command, args, false, "System paused");
      return #err("🚨 EMERGENCY PAUSE ACTIVE - All operations frozen");
    };
    
    if (not isAdmin(msg.caller)) {
      logAction(msg.caller, command, args, false, "Unauthorized");
      return #err("⛔️ Unauthorized: Admin access only");
    };
    
    switch (checkRateLimit(msg.caller, command)) {
      case (#err(errorMsg)) {
        logAction(msg.caller, command, args, false, "Rate limited");
        return #err(errorMsg);
      };
      case (#ok()) {};
    };
    
    let result = switch (command) {
      
      case ("removeUser") {
        if (not hasPermission(msg.caller, #Moderator)) {
          #err("🔒 Permission denied: Moderator role required")
        } else if (args.size() < 2) {
          #err("Usage: removeUser <type> <id>")
        } else {
          let userType = args[0];
          let userId = args[1];
          
          let removed = switch (userType) {
            case ("email") { 
              switch (usersByEmail.remove(userId)) {
                case (?_) true;
                case null false;
              }
            };
            case ("principal") {
              let principal = try {
                Principal.fromText(userId)
              } catch (_) {
                return #err("Invalid principal format");
              };
              switch (usersByPrincipal.remove(principal)) {
                case (?_) true;
                case null false;
              }
            };
            case (_) false;
          };
          
          if (removed) {
            #ok("✅ User removed successfully.")
          } else {
            #err("⚠️ User not found.")
          }
        }
      };
      
      case ("deleteUser") {
        if (not hasPermission(msg.caller, #Moderator)) {
          #err("🔒 Permission denied: Moderator role required")
        } else if (args.size() < 2) {
          #err("Usage: deleteUser <type> <id> [reason]\nThis starts a 30-day soft delete process.")
        } else {
          let userType = args[0];
          let userId = args[1];
          let reason = if (args.size() >= 3) { args[2] } else { "User requested deletion" };
          
          let confirmationCode = generateConfirmationCode(userId);
          let expiresAt = now() + 300_000_000_000;
          
          let pending : PendingDeletion = {
            userId = userId;
            userType = userType;
            requestedBy = msg.caller;
            requestedAt = now();
            confirmationCode = confirmationCode;
            expiresAt = expiresAt;
          };
          
          pendingDeletions.put(userId, pending);
          
          #ok("⚠️ DELETION REQUESTED\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "User: " # userId # "\n" #
              "Reason: " # reason # "\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "⚠️ This will start a 30-day grace period.\n" #
              "To confirm, run:\n" #
              "adminGate(\"confirmDeleteUser\", [\"" # userId # "\", \"" # confirmationCode # "\"])\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "⏱️ Confirmation expires in 5 minutes.")
        }
      };
      
      case ("confirmDeleteUser") {
        if (not hasPermission(msg.caller, #Moderator)) {
          #err("🔒 Permission denied: Moderator role required")
        } else if (args.size() < 2) {
          #err("Usage: confirmDeleteUser <userId> <confirmationCode>")
        } else {
          let userId = args[0];
          let confirmationCode = args[1];
          
          switch (pendingDeletions.get(userId)) {
            case (null) {
              #err("❌ No pending deletion found for this user")
            };
            case (?pending) {
              if (pending.confirmationCode != confirmationCode) {
                #err("❌ Invalid confirmation code")
              } else if (now() > pending.expiresAt) {
                pendingDeletions.delete(userId);
                #err("❌ Confirmation expired. Please request deletion again.")
              } else if (not Principal.equal(pending.requestedBy, msg.caller)) {
                #err("❌ Only the admin who requested deletion can confirm")
              } else {
                let userOpt = switch (pending.userType) {
                  case ("email") { usersByEmail.get(userId) };
                  case ("principal") {
                    let principal = try {
                      Principal.fromText(userId)
                    } catch (_) {
                      return #err("Invalid principal format");
                    };
                    usersByPrincipal.get(principal)
                  };
                  case (_) { null };
                };
                
                switch (userOpt) {
                  case (null) {
                    pendingDeletions.delete(userId);
                    #err("⚠️ User not found")
                  };
                  case (?user) {
                    let deletedUser : DeletedUser = {
                      user = user;
                      deletedBy = msg.caller;
                      deletedAt = now();
                      permanentDeletionAt = now() + 2_592_000_000_000_000;
                      reason = "Admin deletion";
                      canRecover = true;
                    };
                    
                    let removed = switch (pending.userType) {
                      case ("email") { 
                        usersByEmail.delete(userId);
                        true
                      };
                      case ("principal") {
                        let principal = Principal.fromText(userId);
                        usersByPrincipal.delete(principal);
                        true
                      };
                      case (_) false;
                    };
                    
                    if (removed) {
                      deletedUsers.put(userId, deletedUser);
                      pendingDeletions.delete(userId);
                      
                      let gameProfileCount = user.gameProfiles.size();
                      var achievementCount = 0;
                      for ((_, profile) in user.gameProfiles.vals()) {
                        achievementCount += profile.achievements.size();
                      };
                      
                      #ok("🗑️ USER SOFT DELETED\n" #
                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                          "User: " # userId # "\n" #
                          "Game profiles: " # Nat.toText(gameProfileCount) # "\n" #
                          "Achievements: " # Nat.toText(achievementCount) # "\n" #
                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                          "⏱️ 30-day grace period started\n" #
                          "📅 Permanent deletion: " # Nat64.toText(deletedUser.permanentDeletionAt) # "\n" #
                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                          "💡 User can be recovered with: recoverUser")
                    } else {
                      #err("❌ Deletion failed")
                    }
                  };
                }
              }
            };
          }
        }
      };
      
      case ("recoverUser") {
        if (not hasPermission(msg.caller, #Moderator)) {
          #err("🔒 Permission denied: Moderator role required")
        } else if (args.size() < 1) {
          #err("Usage: recoverUser <userId>")
        } else {
          let userId = args[0];
          
          switch (deletedUsers.get(userId)) {
            case (null) {
              #err("❌ No deleted user found with this ID")
            };
            case (?deleted) {
              if (not deleted.canRecover) {
                #err("❌ User cannot be recovered (permanently deleted)")
              } else if (now() > deleted.permanentDeletionAt) {
                #err("❌ Grace period expired - user permanently deleted")
              } else {
                putUserByIdentifier(deleted.user);
                deletedUsers.delete(userId);
                
                #ok("♻️ USER RECOVERED\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "User: " # userId # "\n" #
                    "Originally deleted: " # Nat64.toText(deleted.deletedAt) # "\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "✅ User successfully restored with all data")
              }
            };
          }
        }
      };
      
      case ("listDeletedUsers") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else {
          var result = "🗑️ DELETED USERS\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          var count = 0;
          
          for ((userId, deleted) in deletedUsers.entries()) {
            let daysRemaining = (deleted.permanentDeletionAt - now()) / 86_400_000_000_000;
            result := result # "\n" # userId # "\n" #
                     "  Deleted: " # Nat64.toText(deleted.deletedAt) # "\n" #
                     "  Days until permanent: " # Nat64.toText(daysRemaining) # "\n" #
                     "  Can recover: " # (if (deleted.canRecover) "✅" else "❌") # "\n";
            count += 1;
          };
          
          if (count == 0) {
            result := result # "\nNo deleted users in grace period.";
          } else {
            result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "Total: " # Nat.toText(count) # " users";
          };
          
          #ok(result)
        }
      };
      
      case ("permanentDelete") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required for permanent deletion")
        } else if (args.size() < 1) {
          #err("Usage: permanentDelete <userId>\n⚠️ WARNING: This bypasses the 30-day grace period!")
        } else {
          let userId = args[0];
          
          switch (deletedUsers.get(userId)) {
            case (null) {
              #err("❌ User not found in deleted users")
            };
            case (?deleted) {
              deletedUsers.delete(userId);
              #ok("💀 USER PERMANENTLY DELETED\n" #
                  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                  "User: " # userId # "\n" #
                  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                  "⚠️ This action CANNOT be undone.\n" #
                  "✅ All data permanently erased.")
            };
          }
        }
      };
      
      case ("backup") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else {
          let timestamp = now();
          
          var totalGameProfiles = 0;
          for ((_, user) in usersByEmail.entries()) {
            totalGameProfiles += user.gameProfiles.size();
          };
          for ((_, user) in usersByPrincipal.entries()) {
            totalGameProfiles += user.gameProfiles.size();
          };
          
          let backup : BackupData = {
            version = "2.0.0";
            timestamp = timestamp;
            createdBy = msg.caller;
            emailUsers = Iter.toArray(usersByEmail.entries());
            principalUsers = Iter.toArray(usersByPrincipal.entries());
            games = Iter.toArray(games.entries());
            deletedUsers = Iter.toArray(deletedUsers.entries());
            metadata = {
              totalUsers = usersByEmail.size() + usersByPrincipal.size();
              totalGames = games.size();
              totalGameProfiles = totalGameProfiles;
              totalDeletedUsers = deletedUsers.size();
            };
          };
          
          #ok("🗄️ BACKUP CREATED\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "Timestamp: " # Nat64.toText(timestamp) # "\n" #
              "Version: 2.0.0\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "Email users: " # Nat.toText(backup.emailUsers.size()) # "\n" #
              "Principal users: " # Nat.toText(backup.principalUsers.size()) # "\n" #
              "Games: " # Nat.toText(backup.games.size()) # "\n" #
              "Game profiles: " # Nat.toText(totalGameProfiles) # "\n" #
              "Deleted users: " # Nat.toText(backup.deletedUsers.size()) # "\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "✅ Backup ready for export\n" #
              "💡 Store this data off-chain for disaster recovery")
        }
      };
      
      case ("exportUserData") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else if (args.size() < 2) {
          #err("Usage: exportUserData <type> <id>")
        } else {
          let userType = args[0];
          let userId = args[1];
          
          let userOpt = switch (userType) {
            case ("email") { usersByEmail.get(userId) };
            case ("principal") {
              let principal = try {
                Principal.fromText(userId)
              } catch (_) {
                return #err("❌ Invalid principal format");
              };
              usersByPrincipal.get(principal)
            };
            case (_) { null };
          };
          
          switch (userOpt) {
            case (null) { #err("⚠️ User not found") };
            case (?user) {
              var export = "📦 USER DATA EXPORT\n" #
                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                          "Nickname: " # user.nickname # "\n" #
                          "Auth Type: " # debug_show(user.authType) # "\n" #
                          "Created: " # Nat64.toText(user.created) # "\n" #
                          "Last Updated: " # Nat64.toText(user.last_updated) # "\n" #
                          "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                          "Game Profiles (" # Nat.toText(user.gameProfiles.size()) # "):\n";
              
              for ((gameId, gProfile) in user.gameProfiles.vals()) {
                export := export # "\n🎮 " # gameId # "\n" #
                         "  Score: " # Nat64.toText(gProfile.total_score) # "\n" #
                         "  Best Streak: " # Nat64.toText(gProfile.best_streak) # "\n" #
                         "  Achievements: " # Nat.toText(gProfile.achievements.size()) # "\n" #
                         "  Play Count: " # Nat.toText(gProfile.play_count) # "\n" #
                         "  Last Played: " # Nat64.toText(gProfile.last_played) # "\n";
              };
              
              export := export # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                       "✅ GDPR-compliant data export";
              
              #ok(export)
            };
          }
        }
      };
      
      case ("auditLog") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else {
          let limit = if (args.size() > 0) {
            switch (Nat.fromText(args[0])) {
              case (?n) n;
              case null 50;
            }
          } else { 50 };
          
          let allLogs = Array.append(auditLogStable, Buffer.toArray(auditLog));
          let recentLogs = if (allLogs.size() > limit) {
            Array.tabulate<AdminAction>(limit, func(i) {
              allLogs[allLogs.size() - limit + i]
            })
          } else {
            allLogs
          };
          
          var result = "📜 AUDIT LOG (Last " # Nat.toText(recentLogs.size()) # " entries)\n" #
                      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          
          for (action in recentLogs.vals()) {
            let status = if (action.success) "✅" else "❌";
            result := result # "\n[" # Nat64.toText(action.timestamp) # "] " # status # "\n" #
                     "Admin: " # Principal.toText(action.admin) # "\n" #
                     "Role: " # debug_show(action.adminRole) # "\n" #
                     "Command: " # action.command # "\n" #
                     "Result: " # action.result # "\n";
          };
          
          result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                   "Total logs: " # Nat.toText(allLogs.size());
          
          #ok(result)
        }
      };
      
      case ("emergencyPause") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else {
          emergencyPaused := true;
          #ok("🚨 EMERGENCY PAUSE ACTIVATED\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "All admin operations are now frozen.\n" #
              "Only emergencyUnpause can restore operations.\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
      };
      
      case ("emergencyUnpause") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else {
          emergencyPaused := false;
          #ok("✅ Emergency pause lifted. Operations resumed.")
        }
      };
      
      case ("lookupByNickname") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else if (args.size() < 1) {
          #err("Usage: lookupByNickname <nickname>")
        } else {
          let targetNickname = args[0];
          var found = false;
          var result = "🔍 LOOKUP: " # targetNickname # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          
          for ((principal, user) in usersByPrincipal.entries()) {
            if (user.nickname == targetNickname) {
              found := true;
              result := result # "Type: principal (Internet Identity)\n" #
                       "ID: " # Principal.toText(principal) # "\n" #
                       "Created: " # Nat64.toText(user.created) # "\n";
            };
          };
          
          for ((email, user) in usersByEmail.entries()) {
            if (user.nickname == targetNickname) {
              found := true;
              result := result # "Type: email\n" #
                       "ID: " # email # "\n" #
                       "Created: " # Nat64.toText(user.created) # "\n";
            };
          };
          
          if (found) {
            #ok(result)
          } else {
            #err("❌ No user found with nickname: " # targetNickname)
          }
        }
      };
      
      case ("addAdmin") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else if (args.size() < 2) {
          #err("Usage: addAdmin <principal> <role>\nRoles: SuperAdmin, Moderator, Support, ReadOnly")
        } else {
          let principal = try {
            Principal.fromText(args[0])
          } catch (_) {
            return #err("Invalid principal format");
          };
          
          let role : AdminRole = switch (args[1]) {
            case ("SuperAdmin") #SuperAdmin;
            case ("Moderator") #Moderator;
            case ("Support") #Support;
            case ("ReadOnly") #ReadOnly;
            case (_) return #err("Invalid role. Use: SuperAdmin, Moderator, Support, ReadOnly");
          };
          
          adminRoles.put(principal, role);
          #ok("✅ Admin added: " # Principal.toText(principal) # " as " # debug_show(role))
        }
      };
      
      case ("listAdmins") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else {
          var result = "👥 ADMIN LIST\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          
          for ((principal, role) in adminRoles.entries()) {
            result := result # "\n" # Principal.toText(principal) # "\n" #
                     "  Role: " # debug_show(role) # "\n";
          };
          
          #ok(result)
        }
      };
      
      case ("removeAdmin") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else if (args.size() < 1) {
          #err("Usage: removeAdmin <principal>")
        } else {
          let principal = try {
            Principal.fromText(args[0])
          } catch (_) {
            return #err("Invalid principal format");
          };
          
          if (Principal.equal(principal, msg.caller)) {
            #err("❌ Cannot remove yourself as admin")
          } else {
            adminRoles.delete(principal);
            #ok("✅ Admin removed: " # Principal.toText(principal))
          }
        }
      };
      
      case ("addOrigin") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else if (args.size() < 1) {
          #err("Usage: addOrigin <https://domain.com>")
        } else {
          let origin = args[0];
          
          if (not Text.startsWith(origin, #text "https://")) {
            #err("❌ Origin must start with https://")
          } else {
            var exists = false;
            for (existing in alternativeOrigins.vals()) {
              if (existing == origin) {
                exists := true;
              };
            };
            
            if (exists) {
              #err("⚠️ Origin already registered: " # origin)
            } else {
              alternativeOrigins.add(origin);
              #ok("✅ ORIGIN ADDED\n" #
                  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                  "Domain: " # origin # "\n" #
                  "Total origins: " # Nat.toText(alternativeOrigins.size()) # "\n" #
                  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                  "💡 Games on this domain can now use\n" #
                  "   CheddaBoards II derivation.")
            }
          }
        }
      };

      case ("removeOrigin") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else if (args.size() < 1) {
          #err("Usage: removeOrigin <https://domain.com>")
        } else {
          let origin = args[0];
          let sizeBefore = alternativeOrigins.size();
          
          let newOrigins = Buffer.Buffer<Text>(sizeBefore);
          for (existing in alternativeOrigins.vals()) {
            if (existing != origin) {
              newOrigins.add(existing);
            };
          };
          
          if (newOrigins.size() == sizeBefore) {
            #err("❌ Origin not found: " # origin)
          } else {
            alternativeOrigins := newOrigins;
            #ok("✅ ORIGIN REMOVED\n" #
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                "Domain: " # origin # "\n" #
                "Remaining origins: " # Nat.toText(alternativeOrigins.size()) # "\n" #
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                "⚠️ Games on this domain will now get\n" #
                "   different principals!")
          }
        }
      };

      case ("listOrigins") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else {
          var result = "🌐 ALTERNATIVE ORIGINS\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          var count = 0;
          
          for (origin in alternativeOrigins.vals()) {
            count += 1;
            result := result # Nat.toText(count) # ". " # origin # "\n";
          };
          
          if (count == 0) {
            result := result # "\n⚠️ No origins registered.\n" #
                     "Games will get domain-specific principals.\n";
          } else {
            result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "Total: " # Nat.toText(count) # " origins\n" #
                     "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "💡 Test endpoint:\n" #
                     "curl https://YOUR-CANISTER.icp0.io/.well-known/ii-alternative-origins";
          };
          
          #ok(result)
        }
      };

      case ("viewSuspicionLog") {
        let isSupport = hasPermission(msg.caller, #Support);
        
        // Get games owned by caller (for non-admin access)
        let ownedGames = Buffer.Buffer<Text>(0);
        if (not isSupport) {
          for ((gameId, game) in games.entries()) {
            if (Principal.equal(game.owner, msg.caller)) {
              ownedGames.add(gameId);
            };
          };
          
          // If not support AND doesn't own any games, deny
          if (ownedGames.size() == 0) {
            return #err("🔒 Permission denied: Must be game owner or have Support role");
          };
        };
        
        let limit = if (args.size() > 0) {
          switch (Nat.fromText(args[0])) {
            case (?n) n;
            case null 50;
          }
        } else { 50 };
        
        let gameFilter : ?Text = if (args.size() > 1) { ?args[1] } else { null };
        
        // If dev specified a game filter, verify they own it
        switch (gameFilter) {
          case (?gId) {
            if (not isSupport) {
              var ownsGame = false;
              for (owned in ownedGames.vals()) {
                if (owned == gId) { ownsGame := true };
              };
              if (not ownsGame) {
                return #err("🔒 Permission denied: You don't own game '" # gId # "'");
              };
            };
          };
          case null {};
        };
        
        let logArray = List.toArray(suspicionLog);
        let totalEntries = logArray.size();
        
        var result = "🚨 SUSPICION LOG\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        var count = 0;
        var filteredTotal = 0;
        
        // Show most recent first (reverse iterate)
        label logLoop for (i in Iter.range(0, totalEntries - 1)) {
          let idx = totalEntries - 1 - i; // Reverse order
          let entry = logArray[idx];
          
          // Determine if this entry should be visible
          let canView = if (isSupport) {
            // Support can see all, apply game filter if specified
            switch (gameFilter) {
              case (?gId) { entry.gameId == gId };
              case null { true };
            }
          } else {
            // Devs can only see their own games
            var isOwned = false;
            for (owned in ownedGames.vals()) {
              if (owned == entry.gameId) { isOwned := true };
            };
            // Also apply game filter if specified
            switch (gameFilter) {
              case (?gId) { isOwned and entry.gameId == gId };
              case null { isOwned };
            }
          };
          
          if (canView) {
            filteredTotal += 1;
            if (count < limit) {
              result := result # "\n[" # Nat64.toText(entry.timestamp) # "]\n" #
                       "🎮 Game: " # entry.gameId # "\n" #
                       "👤 Player: " # entry.player_id # "\n" #
                       "⚠️ Reason: " # entry.reason # "\n" #
                       "───────────────────────────────\n";
              count += 1;
            };
          };
        };
        
        if (count == 0) {
          result := result # "\n✅ No suspicious activity logged";
          switch (gameFilter) {
            case (?gId) { result := result # " for game: " # gId };
            case null {
              if (not isSupport) {
                result := result # " for your games";
              };
            };
          };
          result := result # "\n";
        };
        
        result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                 "Showing: " # Nat.toText(count) # " / " # Nat.toText(filteredTotal) # " entries\n";
        
        if (not isSupport) {
          result := result # "🔒 Filtered to your games only\n";
        };
        
        result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                 "💡 Usage: viewSuspicionLog [limit] [gameId]\n" #
                 "   Example: viewSuspicionLog 20 my-game";
        
        #ok(result)
      };

      case ("clearSuspicionLog") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else {
          let oldSize = List.size(suspicionLog);
          suspicionLog := List.nil();
          #ok("🗑️ SUSPICION LOG CLEARED\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "Entries removed: " # Nat.toText(oldSize) # "\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
      };

      case ("findLostGames") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied")
    } else {
        let gameIds = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
        
        // Scan email users
        for ((_, user) in usersByEmail.entries()) {
            for ((gameId, _) in user.gameProfiles.vals()) {
                switch (gameIds.get(gameId)) {
                    case (?count) { gameIds.put(gameId, count + 1) };
                    case null { gameIds.put(gameId, 1) };
                };
            };
        };
        
        // Scan principal users
        for ((_, user) in usersByPrincipal.entries()) {
            for ((gameId, _) in user.gameProfiles.vals()) {
                switch (gameIds.get(gameId)) {
                    case (?count) { gameIds.put(gameId, count + 1) };
                    case null { gameIds.put(gameId, 1) };
                };
            };
        };
        
        var result = "🔍 GAMES FOUND IN USER PROFILES\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        for ((gameId, playerCount) in gameIds.entries()) {
            result := result # gameId # ": " # Nat.toText(playerCount) # " players\n";
        };
        result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                 "These games need to be re-registered.";
        
        #ok(result)
    }
};

      case ("reconstructGame") {
    // reconstructGame <gameId> [name] [description]
    // Reconstructs a lost game from user profile data
    if (not hasPermission(msg.caller, #SuperAdmin)) {
        #err("🔒 Permission denied: SuperAdmin role required")
    } else if (args.size() < 1) {
        #err("❌ Usage: reconstructGame <gameId> [name] [description]")
    } else {
        let gameId = args[0];
        let gameName = if (args.size() > 1) args[1] else gameId;
        let gameDesc = if (args.size() > 2) args[2] else "Reconstructed game - update description";
        
        // Check if game already exists
        switch (games.get(gameId)) {
            case (?_) { #err("❌ Game '" # gameId # "' already exists!") };
            case null {
                // Scan user profiles to gather stats
                var totalPlayers : Nat = 0;
                var totalPlays : Nat = 0;
                
                // Scan email users
                for ((_, user) in usersByEmail.entries()) {
                    for ((gId, profile) in user.gameProfiles.vals()) {
                        if (gId == gameId) {
                            totalPlayers += 1;
                            totalPlays += profile.play_count;
                        };
                    };
                };
                
                // Scan principal users
                for ((_, user) in usersByPrincipal.entries()) {
                    for ((gId, profile) in user.gameProfiles.vals()) {
                        if (gId == gameId) {
                            totalPlayers += 1;
                            totalPlays += profile.play_count;
                        };
                    };
                };
                
                // Check if we found any players
                if (totalPlayers == 0) {
                    #err("❌ No player data found for gameId: " # gameId # "\nMake sure the gameId matches exactly (case-sensitive)")
                } else {
                    // Create reconstructed game
                    let now = Int.abs(Time.now());
                    
                    let reconstructedGame : GameInfo = {
                        gameId = gameId;
                        name = gameName;
                        description = gameDesc;
                        owner = msg.caller;
                        gameUrl = null;
                        created = Nat64.fromNat(now);
                        accessMode = #both;
                        totalPlayers = totalPlayers;
                        totalPlays = totalPlays;
                        isActive = true;
                        maxScorePerRound = null;
                        maxStreakDelta = null;
                        absoluteScoreCap = null;
                        absoluteStreakCap = null;
                        timeValidationEnabled = false;
                        minPlayDurationSecs = null;
                        maxScorePerSecond = null;
                        maxSessionDurationMins = null;
                        googleClientIds = [];
                        appleBundleId = null;
                        appleTeamId = null;
                    };
                    
                    games.put(gameId, reconstructedGame);
                    
                    #ok("✅ GAME RECONSTRUCTED\n\n" #
                        "🎮 Game ID: " # gameId # "\n" #
                        "📛 Name: " # gameName # "\n" #
                        "👥 Players Found: " # Nat.toText(totalPlayers) # "\n" #
                        "🎯 Total Plays: " # Nat.toText(totalPlays) # "\n" #
                        "👤 Owner: " # Principal.toText(msg.caller) # "\n\n" #
                        "⚠️ TODO:\n" #
                        "- Update name/description if needed\n" #
                        "- Set anti-cheat rules (updateGameRules)\n" #
                        "- Add OAuth credentials if using social login\n" #
                        "- Transfer ownership if needed")
                };
            };
        };
    }
};

      case ("suspicionStats") {
        if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied: Support role required")
        } else {
          let logArray = List.toArray(suspicionLog);
          
          // Count by game
          var gameCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
          // Count by player
          var playerCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
          // Count by reason type
          var reasonCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
          
          for (entry in logArray.vals()) {
            // Game counts
            switch (gameCounts.get(entry.gameId)) {
              case (?c) { gameCounts.put(entry.gameId, c + 1) };
              case null { gameCounts.put(entry.gameId, 1) };
            };
            
            // Player counts
            switch (playerCounts.get(entry.player_id)) {
              case (?c) { playerCounts.put(entry.player_id, c + 1) };
              case null { playerCounts.put(entry.player_id, 1) };
            };
            
            // Simplify reason for grouping
            let reasonKey = if (Text.contains(entry.reason, #text "delta")) { "Delta too high" }
                           else if (Text.contains(entry.reason, #text "Exact limit")) { "Exact limit hit" }
                           else if (Text.contains(entry.reason, #text "achievements")) { "Low achievements" }
                           else if (Text.contains(entry.reason, #text "Invalid")) { "Invalid value" }
                           else if (Text.contains(entry.reason, #text "Too fast")) { "Too fast" }
                           else { "Other" };
            switch (reasonCounts.get(reasonKey)) {
              case (?c) { reasonCounts.put(reasonKey, c + 1) };
              case null { reasonCounts.put(reasonKey, 1) };
            };
          };
          
          var result = "📊 SUSPICION STATS\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                      "Total entries: " # Nat.toText(logArray.size()) # "\n\n";
          
          result := result # "🎮 BY GAME:\n";
          for ((game, count) in gameCounts.entries()) {
            result := result # "  " # game # ": " # Nat.toText(count) # "\n";
          };
          
          result := result # "\n⚠️ BY REASON:\n";
          for ((reason, count) in reasonCounts.entries()) {
            result := result # "  " # reason # ": " # Nat.toText(count) # "\n";
          };
          
          result := result # "\n👤 REPEAT OFFENDERS (3+):\n";
          var repeatCount = 0;
          for ((player, count) in playerCounts.entries()) {
            if (count >= 3) {
              result := result # "  " # player # ": " # Nat.toText(count) # " flags\n";
              repeatCount += 1;
            };
          };
          if (repeatCount == 0) {
            result := result # "  None\n";
          };
          
          result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
          
          #ok(result)
        }
      };

      case ("banUser") {
        if (not hasPermission(msg.caller, #Moderator)) {
          #err("🔒 Permission denied: Moderator role required")
        } else if (args.size() < 2) {
          #err("Usage: banUser <type> <id> [reason]\nType: email, principal, external")
        } else {
          let userType = args[0];
          let userId = args[1];
          let reason = if (args.size() >= 3) { args[2] } else { "Cheating" };
          
          // First, log the ban in suspicion log for record
          logSuspicion(userId # "/" # userType, "SYSTEM", "BANNED: " # reason);
          
          // Then remove the user
          let removed = switch (userType) {
            case ("email") { 
              switch (usersByEmail.remove(userId)) {
                case (?_) true;
                case null false;
              }
            };
            case ("external") {
              switch (usersByEmail.remove("ext:" # userId)) {
                case (?_) true;
                case null false;
              }
            };
            case ("principal") {
              let principal = try {
                Principal.fromText(userId)
              } catch (_) {
                return #err("Invalid principal format");
              };
              switch (usersByPrincipal.remove(principal)) {
                case (?_) true;
                case null false;
              }
            };
            case (_) false;
          };
          
          if (removed) {
            #ok("🔨 USER BANNED\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                "User: " # userId # "\n" #
                "Type: " # userType # "\n" #
                "Reason: " # reason # "\n" #
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                "✅ User removed from all leaderboards")
          } else {
            #err("⚠️ User not found: " # userId)
          }
        }
      };

      case ("setOrigins") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else if (args.size() < 1) {
          #err("Usage: setOrigins <origin1> <origin2> ...\nExample: setOrigins https://game1.com https://game2.io")
        } else {
          for (origin in args.vals()) {
            if (not Text.startsWith(origin, #text "https://")) {
              return #err("❌ Invalid origin (must be https): " # origin);
            };
          };
          
          alternativeOrigins := Buffer.Buffer<Text>(args.size());
          for (origin in args.vals()) {
            alternativeOrigins.add(origin);
          };
          
          var result = "✅ ORIGINS SET\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          for (origin in args.vals()) {
            result := result # "• " # origin # "\n";
          };
          result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                   "Total: " # Nat.toText(args.size()) # " origins";
          
          #ok(result)
        }
      };

      case ("clearOrigins") {
        if (not hasPermission(msg.caller, #SuperAdmin)) {
          #err("🔒 Permission denied: SuperAdmin role required")
        } else {
          let count = alternativeOrigins.size();
          alternativeOrigins := Buffer.Buffer<Text>(10);
          #ok("🗑️ ORIGINS CLEARED\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "Removed: " # Nat.toText(count) # " origins\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "⚠️ All games will now get domain-specific\n" #
              "   principals until origins are re-added.")
        }
      };
      
      case ("listGames") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else {
        let limit = if (args.size() > 0) {
            switch (Nat.fromText(args[0])) {
                case (?n) n;
                case null 50;
            }
        } else { 50 };
        
        var result = "🎮 REGISTERED GAMES\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        var count = 0;
        
        for ((gameId, game) in games.entries()) {
            if (count < limit) {
                let status = if (game.isActive) "✅" else "❌";
                result := result # "\n" # status # " " # gameId # "\n" #
                         "  Name: " # game.name # "\n" #
                         "  Owner: " # Principal.toText(game.owner) # "\n" #
                         "  Players: " # Nat.toText(game.totalPlayers) # "\n" #
                         "  Plays: " # Nat.toText(game.totalPlays) # "\n";
                count += 1;
            };
        };
        
        result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                 "Showing: " # Nat.toText(count) # " games";
        
        #ok(result)
    }
};

  case ("recoverGames") {
    if (not hasPermission(msg.caller, #SuperAdmin)) {
        #err("🔒 Permission denied: SuperAdmin role required")
    } else {
        var recoveredCount = 0;
        var alreadyExisted = 0;
        
        // Try to recover from legacy stable storage
        if (stableGames.size() > 0) {
            for ((id, oldGame) in stableGames.vals()) {
                switch (games.get(id)) {
                    case (?_) { alreadyExisted += 1 };
                    case null {
                        let migratedGame : GameInfo = {
                            gameId = oldGame.gameId;
                            name = oldGame.name;
                            description = oldGame.description;
                            owner = oldGame.owner;
                            gameUrl = oldGame.gameUrl;
                            created = oldGame.created;
                            accessMode = oldGame.accessMode;
                            totalPlayers = oldGame.totalPlayers;
                            totalPlays = oldGame.totalPlays;
                            isActive = oldGame.isActive;
                            maxScorePerRound = oldGame.maxScorePerRound;
                            maxStreakDelta = oldGame.maxStreakDelta;
                            absoluteScoreCap = oldGame.absoluteScoreCap;
                            absoluteStreakCap = oldGame.absoluteStreakCap;
                            timeValidationEnabled = false;
                            minPlayDurationSecs = null;
                            maxScorePerSecond = null;
                            maxSessionDurationMins = null;
                            googleClientIds = [];
                            appleBundleId = null;
                            appleTeamId = null;
                        };
                        games.put(id, migratedGame);
                        recoveredCount += 1;
                    };
                };
            };
        };
        
        // Also try V2 stable storage (migrate to V3 format)
        if (stableGamesV2.size() > 0) {
            for ((id, oldGame) in stableGamesV2.vals()) {
                switch (games.get(id)) {
                    case (?_) { alreadyExisted += 1 };
                    case null {
                        let migratedGame : GameInfo = {
                            gameId = oldGame.gameId;
                            name = oldGame.name;
                            description = oldGame.description;
                            owner = oldGame.owner;
                            gameUrl = oldGame.gameUrl;
                            created = oldGame.created;
                            accessMode = oldGame.accessMode;
                            totalPlayers = oldGame.totalPlayers;
                            totalPlays = oldGame.totalPlays;
                            isActive = oldGame.isActive;
                            maxScorePerRound = oldGame.maxScorePerRound;
                            maxStreakDelta = oldGame.maxStreakDelta;
                            absoluteScoreCap = oldGame.absoluteScoreCap;
                            absoluteStreakCap = oldGame.absoluteStreakCap;
                            timeValidationEnabled = false;
                            minPlayDurationSecs = null;
                            maxScorePerSecond = null;
                            maxSessionDurationMins = null;
                            googleClientIds = oldGame.googleClientIds;
                            appleBundleId = oldGame.appleBundleId;
                            appleTeamId = oldGame.appleTeamId;
                        };
                        games.put(id, migratedGame);
                        recoveredCount += 1;
                    };
                };
            };
        };
        
        #ok("🎮 GAME RECOVERY COMPLETE\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Legacy storage: " # Nat.toText(stableGames.size()) # " games\n" #
            "V2 storage: " # Nat.toText(stableGamesV2.size()) # " games\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Recovered: " # Nat.toText(recoveredCount) # "\n" #
            "Already existed: " # Nat.toText(alreadyExisted) # "\n" #
            "Total games now: " # Nat.toText(games.size()) # "\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
};
  
  case ("debugStorage") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else {
        #ok("🔍 STORAGE DEBUG\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Legacy Games (stableGames): " # Nat.toText(stableGames.size()) # "\n" #
            "Legacy Deleted: " # Nat.toText(deletedGamesEntries.size()) # "\n" #
            "V2 Games (stableGamesV2): " # Nat.toText(stableGamesV2.size()) # "\n" #
            "V2 Deleted: " # Nat.toText(deletedGamesEntriesV2.size()) # "\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Runtime Games: " # Nat.toText(games.size()) # "\n" #
            "Runtime Deleted: " # Nat.toText(deletedGames.size()) # "\n" #
            "Migration Done: " # (if (oauthMigrationDone) "true" else "false") # "\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
};

case ("getGameDetails") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else if (args.size() < 1) {
        #err("Usage: getGameDetails <gameId>")
    } else {
        let gameId = args[0];
        switch (games.get(gameId)) {
            case null { #err("❌ Game not found: " # gameId) };
            case (?game) {
                let status = if (game.isActive) "✅ Active" else "❌ Inactive";
                #ok("🎮 GAME DETAILS\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "ID: " # game.gameId # "\n" #
                    "Name: " # game.name # "\n" #
                    "Description: " # game.description # "\n" #
                    "Status: " # status # "\n" #
                    "Owner: " # Principal.toText(game.owner) # "\n" #
                    "Created: " # Nat64.toText(game.created) # "\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "📊 Stats\n" #
                    "  Total Players: " # Nat.toText(game.totalPlayers) # "\n" #
                    "  Total Plays: " # Nat.toText(game.totalPlays) # "\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "🛡️ Anti-Cheat\n" #
                    "  Max Score/Round: " # (switch (game.maxScorePerRound) { case (?v) Nat64.toText(v); case null "None" }) # "\n" #
                    "  Max Streak Delta: " # (switch (game.maxStreakDelta) { case (?v) Nat64.toText(v); case null "None" }) # "\n" #
                    "  Absolute Score Cap: " # (switch (game.absoluteScoreCap) { case (?v) Nat64.toText(v); case null "None" }) # "\n" #
                    "  Absolute Streak Cap: " # (switch (game.absoluteStreakCap) { case (?v) Nat64.toText(v); case null "None" }))
            };
        }
    }
};

case ("adminDeleteGame") {
    if (not hasPermission(msg.caller, #Moderator)) {
        #err("🔒 Permission denied: Moderator role required")
    } else if (args.size() < 1) {
        #err("Usage: adminDeleteGame <gameId> [reason]")
    } else {
        let gameId = args[0];
        let reason = if (args.size() >= 2) { args[1] } else { "Admin deletion" };
        
        switch (games.get(gameId)) {
            case null { #err("❌ Game not found: " # gameId) };
            case (?game) {
                let currentTime = Nat64.fromNat(Int.abs(Time.now()));
                let thirtyDays : Nat64 = 30 * 24 * 60 * 60 * 1_000_000_000;
                
                let deletedGame : DeletedGame = {
                    game = game;
                    deletedBy = msg.caller;
                    deletedAt = currentTime;
                    permanentDeletionAt = currentTime + thirtyDays;
                    reason = reason;
                    canRecover = true;
                };
                
                deletedGames.put(gameId, deletedGame);
                
                let inactiveGame : GameInfo = {
                    gameId = game.gameId;
                    name = game.name;
                    description = game.description;
                    owner = game.owner;
                    gameUrl = game.gameUrl;
                    created = game.created;
                    accessMode = game.accessMode;
                    totalPlayers = game.totalPlayers;
                    totalPlays = game.totalPlays;
                    isActive = false;
                    maxScorePerRound = game.maxScorePerRound;
                    maxStreakDelta = game.maxStreakDelta;
                    absoluteScoreCap = game.absoluteScoreCap;
                    absoluteStreakCap = game.absoluteStreakCap;
                timeValidationEnabled = game.timeValidationEnabled;
          minPlayDurationSecs = game.minPlayDurationSecs;
          maxScorePerSecond = game.maxScorePerSecond;
          maxSessionDurationMins = game.maxSessionDurationMins;
          googleClientIds = game.googleClientIds;
                    appleBundleId = game.appleBundleId;
                    appleTeamId = game.appleTeamId;
                };
                games.put(gameId, inactiveGame);
                
                #ok("🗑️ GAME DELETED\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "Game: " # game.name # " (" # gameId # ")\n" #
                    "Owner: " # Principal.toText(game.owner) # "\n" #
                    "Reason: " # reason # "\n" #
                    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "⏱️ 30-day grace period started\n" #
                    "💡 Recover with: adminRecoverGame " # gameId)
            };
        }
    }
};

case ("adminRecoverGame") {
    if (not hasPermission(msg.caller, #Moderator)) {
        #err("🔒 Permission denied: Moderator role required")
    } else if (args.size() < 1) {
        #err("Usage: adminRecoverGame <gameId>")
    } else {
        let gameId = args[0];
        
        switch (deletedGames.get(gameId)) {
            case null { #err("❌ Game not in deleted list: " # gameId) };
            case (?deleted) {
                let currentTime = Nat64.fromNat(Int.abs(Time.now()));
                
                if (currentTime > deleted.permanentDeletionAt) {
                    #err("❌ Recovery period expired")
                } else {
                    let restoredGame : GameInfo = {
                        gameId = deleted.game.gameId;
                        name = deleted.game.name;
                        description = deleted.game.description;
                        owner = deleted.game.owner;
                        gameUrl = deleted.game.gameUrl;
                        created = deleted.game.created;
                        accessMode = deleted.game.accessMode;
                        totalPlayers = deleted.game.totalPlayers;
                        totalPlays = deleted.game.totalPlays;
                        isActive = true;
                        maxScorePerRound = deleted.game.maxScorePerRound;
                        maxStreakDelta = deleted.game.maxStreakDelta;
                        absoluteScoreCap = deleted.game.absoluteScoreCap;
                        absoluteStreakCap = deleted.game.absoluteStreakCap;
                    timeValidationEnabled = deleted.game.timeValidationEnabled;
          minPlayDurationSecs = deleted.game.minPlayDurationSecs;
          maxScorePerSecond = deleted.game.maxScorePerSecond;
          maxSessionDurationMins = deleted.game.maxSessionDurationMins;
          googleClientIds = deleted.game.googleClientIds;
                        appleBundleId = deleted.game.appleBundleId;
                        appleTeamId = deleted.game.appleTeamId;
                    };
                    
                    games.put(gameId, restoredGame);
                    deletedGames.delete(gameId);
                    
                    #ok("♻️ GAME RECOVERED\n" #
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                        "Game: " # deleted.game.name # "\n" #
                        "ID: " # gameId # "\n" #
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                        "✅ Game restored and active")
                }
            };
        }
    }
};

case ("listDeletedGames") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else {
        var result = "🗑️ DELETED GAMES\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        var count = 0;
        
        for ((gameId, deleted) in deletedGames.entries()) {
            let currentTime = Nat64.fromNat(Int.abs(Time.now()));
            let daysRemaining = (deleted.permanentDeletionAt - currentTime) / 86_400_000_000_000;
            
            result := result # "\n" # gameId # "\n" #
                     "  Name: " # deleted.game.name # "\n" #
                     "  Owner: " # Principal.toText(deleted.game.owner) # "\n" #
                     "  Reason: " # deleted.reason # "\n" #
                     "  Days remaining: " # Nat64.toText(daysRemaining) # "\n";
            count += 1;
        };
        
        if (count == 0) {
            result := result # "\nNo deleted games in grace period.";
        } else {
            result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "Total: " # Nat.toText(count) # " games";
        };
        
        #ok(result)
    }
};

case ("listDevelopers") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else {
        // Build a map of owners to their games
        let ownerGames = HashMap.HashMap<Principal, Buffer.Buffer<Text>>(10, Principal.equal, Principal.hash);
        
        for ((gameId, game) in games.entries()) {
            switch (ownerGames.get(game.owner)) {
                case null {
                    let buf = Buffer.Buffer<Text>(1);
                    buf.add(gameId);
                    ownerGames.put(game.owner, buf);
                };
                case (?buf) {
                    buf.add(gameId);
                };
            };
        };
        
        var result = "👨‍💻 DEVELOPERS\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        var count = 0;
        
        for ((owner, gamesBuf) in ownerGames.entries()) {
            let gamesArr = Buffer.toArray(gamesBuf);
            result := result # "\n" # Principal.toText(owner) # "\n" #
                     "  Games: " # Nat.toText(gamesArr.size()) # "\n" #
                     "  IDs: " # Text.join(", ", gamesArr.vals()) # "\n";
            count += 1;
        };
        
        if (count == 0) {
            result := result # "\nNo developers found.";
        } else {
            result := result # "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "Total: " # Nat.toText(count) # " developers";
        };
        
        #ok(result)
    }
};

case ("getDeveloperGames") {
    if (not hasPermission(msg.caller, #Support)) {
        #err("🔒 Permission denied: Support role required")
    } else if (args.size() < 1) {
        #err("Usage: getDeveloperGames <principal>")
    } else {
        let principal = try {
            Principal.fromText(args[0])
        } catch (_) {
            return #err("Invalid principal format");
        };
        
        var result = "👨‍💻 DEVELOPER GAMES\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                    "Principal: " # Principal.toText(principal) # "\n\n";
        var count = 0;
        
        for ((gameId, game) in games.entries()) {
            if (Principal.equal(game.owner, principal)) {
                let status = if (game.isActive) "✅" else "❌";
                result := result # status # " " # gameId # "\n" #
                         "  Name: " # game.name # "\n" #
                         "  Players: " # Nat.toText(game.totalPlayers) # "\n" #
                         "  Plays: " # Nat.toText(game.totalPlays) # "\n\n";
                count += 1;
            };
        };
        
        if (count == 0) {
            result := result # "No games found for this developer.";
        } else {
            result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                     "Total: " # Nat.toText(count) # " games";
        };
        
        #ok(result)
    }
};

      case ("upgradeDeveloper") {
    if (not hasPermission(msg.caller, #SuperAdmin)) {
        #err("🔒 Permission denied: SuperAdmin role required")
    } else if (args.size() < 1) {
        #err("Usage: upgradeDeveloper <email>")
    } else {
        let email = args[0];
        let principal = emailToPrincipalSimple(email);
        
        developerTiers.put(principal, #pro);
        #ok("⭐ DEVELOPER UPGRADED TO PRO\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Email: " # email # "\n" #
            "Max Games: 10\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
};

case ("downgradeDeveloper") {
    if (not hasPermission(msg.caller, #SuperAdmin)) {
        #err("🔒 Permission denied: SuperAdmin role required")
    } else if (args.size() < 1) {
        #err("Usage: downgradeDeveloper <email>")
    } else {
        let email = args[0];
        let principal = emailToPrincipalSimple(email);
        
        developerTiers.delete(principal);
        #ok("Developer downgraded to free tier (3 games max)")
    }
};

  case ("listProDevelopers") {
      if (not hasPermission(msg.caller, #Support)) {
          #err("🔒 Permission denied")
      } else {
          var result = "⭐ PRO DEVELOPERS\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
          var count = 0;
          
          for ((principal, tier) in developerTiers.entries()) {
              switch (tier) {
                  case (#pro) {
                      result := result # Principal.toText(principal) # "\n";
                      count += 1;
                  };
                  case (_) {};
              };
          };
          
          if (count == 0) {
              result := result # "\nNo pro developers yet.";
          } else {
              result := result # "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
                      "Total: " # Nat.toText(count) # " pro developers";
          };
          
          #ok(result)
      }
  };
      case ("getStats") {
        if (not hasPermission(msg.caller, #ReadOnly)) {
          #err("🔒 Permission denied: ReadOnly role required")
        } else {
          let emailUsers = usersByEmail.size();
          let principalUsers = usersByPrincipal.size();
          let gameCount = games.size();
          let deletedCount = deletedUsers.size();
          let adminCount = adminRoles.size();
          let auditCount = auditLogStable.size() + auditLog.size();
          
          var totalGameProfiles = 0;
          for ((_, user) in usersByEmail.entries()) {
            totalGameProfiles += user.gameProfiles.size();
          };
          for ((_, user) in usersByPrincipal.entries()) {
            totalGameProfiles += user.gameProfiles.size();
          };
          
          #ok("📊 SYSTEM STATISTICS\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
              "👥 Users\n" #
              "  Email: " # Nat.toText(emailUsers) # "\n" #
              "  Principal: " # Nat.toText(principalUsers) # "\n" #
              "  Total active: " # Nat.toText(emailUsers + principalUsers) # "\n" #
              "  Soft deleted: " # Nat.toText(deletedCount) # "\n" #
              "\n🎮 Games\n" #
              "  Registered: " # Nat.toText(gameCount) # "\n" #
              "  Total profiles: " # Nat.toText(totalGameProfiles) # "\n" #
              "\n🔐 Security\n" #
              "  Admins: " # Nat.toText(adminCount) # "\n" #
              "  Audit logs: " # Nat.toText(auditCount) # "\n" #
              "  Emergency pause: " # (if (emergencyPaused) "🚨 ACTIVE" else "✅ Normal") # "\n" #
              "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
      };
      
      case ("help") {
        #ok("📚 ADMIN COMMANDS\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "👥 User Management (Moderator+)\n" #
            "  • deleteUser <type> <id> [reason]\n" #
            "  • confirmDeleteUser <userId> <code>\n" #
            "  • recoverUser <userId>\n" #
            "  • listDeletedUsers\n" #
            "  • removeUser <type> <id>\n" #
            "  • exportUserData <type> <id>\n" #
            "  • lookupByNickname <nickname>\n" #
            "\n🌐 II Origins (SuperAdmin)\n" #
            "  • addOrigin <https://domain.com>\n" #
            "  • removeOrigin <https://domain.com>\n" #
            "  • setOrigins <origin1> <origin2> ...\n" #
            "  • clearOrigins\n" #
            "  • listOrigins (Support+)\n" #
            "\n🗄️ Backup (SuperAdmin)\n" #
            "  • backup\n" #
            "\n🔐 Security (SuperAdmin)\n" #
            "  • emergencyPause\n" #
            "  • emergencyUnpause\n" #
            "  • addAdmin <principal> <role>\n" #
            "  • removeAdmin <principal>\n" #
            "\n📊 Information (Support+)\n" #
            "  • getStats\n" #
            "  • listAdmins\n" #
            "  • auditLog [limit]\n" #
            "\n⚠️ Dangerous (SuperAdmin)\n" #
            "  • permanentDelete <userId>\n" #
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" #
            "Roles: SuperAdmin > Moderator > Support > ReadOnly")
      };
      
      case (_) {
        #err("❌ Unknown command. Type 'help' for available commands.")
      };
    };
    
    let success = switch (result) {
      case (#ok(_)) true;
      case (#err(_)) false;
    };
    
    let resultMsg = switch (result) {
      case (#ok(m)) m;
      case (#err(m)) m;
    };
    
    logAction(msg.caller, command, args, success, resultMsg);
    
    result
  };


private func emailToPrincipalSimple(email: Text) : Principal {
    let bytes = Blob.toArray(Text.encodeUtf8(email));
    var hash : [var Nat8] = Array.init<Nat8>(29, 0);
    hash[0] := 0x04; // Self-authenticating prefix
    
    for (i in Iter.range(0, bytes.size() - 1)) {
        let idx = (i % 28) + 1;
        hash[idx] := hash[idx] ^ bytes[i];
    };
    
    Principal.fromBlob(Blob.fromArray(Array.freeze(hash)))
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Validate session and get owner Principal
// ═══════════════════════════════════════════════════════════════════════════════

private func getOwnerFromSession(sessionId: Text) : Result.Result<Principal, Text> {
    switch (sessions.get(sessionId)) {
        case null { #err("Invalid or expired session") };
        case (?session) {
            let currentTime = Nat64.fromNat(Int.abs(Time.now()));
            if (session.expires < currentTime) {
                sessions.delete(sessionId);
                return #err("Session expired");
            };
            #ok(emailToPrincipalSimple(session.email))
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Get remaining delete attempts for owner
// ═══════════════════════════════════════════════════════════════════════════════

private func getRemainingDeleteAttemptsForOwner(owner: Principal) : Nat {
    let currentTime = Nat64.fromNat(Int.abs(Time.now()));
    let hourAgo = currentTime - (60 * 60 * 1_000_000_000);
    
    switch (deleteRateLimit.get(owner)) {
        case null { 3 };
        case (?attempts) {
            var recentCount = 0;
            for (attempt in attempts.vals()) {
                if (attempt.timestamp > hourAgo) {
                    recentCount += 1;
                };
            };
            if (recentCount >= 3) { 0 } else { 3 - recentCount }
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Count games by owner
// ═══════════════════════════════════════════════════════════════════════════════

private func getGameCountByOwner(owner: Principal) : Nat {
    var count = 0;
    for ((_, game) in games.entries()) {
        if (Principal.equal(game.owner, owner) and game.isActive) {
            count += 1;
        };
    };
    count
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Validate game ID format
// ═══════════════════════════════════════════════════════════════════════════════

private func isValidGameId(gameId: Text) : Bool {
    if (Text.size(gameId) < 3 or Text.size(gameId) > 50) {
        return false;
    };
    
    for (char in gameId.chars()) {
        let valid = (char >= 'a' and char <= 'z') or 
                    (char >= '0' and char <= '9') or 
                    char == '-';
        if (not valid) {
            return false;
        };
    };
    
    true
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Generate unique API key (no external deps)
// ═══════════════════════════════════════════════════════════════════════════════

private func generateUniqueApiKey(gameId: Text) : Text {
    let timestamp = Int.toText(Time.now());
    let combined = gameId # "_" # timestamp;
    let hash = Text.hash(combined);
    "cb_" # gameId # "_" # Nat32.toText(hash)
};



// ═══════════════════════════════════════════════════════════════════════════════
// GET GAMES BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public query func getGamesBySession(sessionId: Text) : async [GameInfo] {
    switch (sessions.get(sessionId)) {
        case null { return [] };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            
            let ownerGames = Buffer.Buffer<GameInfo>(0);
            for ((_, game) in games.entries()) {
                if (Principal.equal(game.owner, owner) and game.isActive) {
                    ownerGames.add(game);
                };
            };
            
            Buffer.toArray(ownerGames)
        };
    };
};

public query func getSuspicionLogBySession(sessionId: Text, gameId: Text, limit: Nat) : async [{
    player_id: Text;
    gameId: Text;
    reason: Text;
    timestamp: Nat64;
  }] {
    switch (sessions.get(sessionId)) {
      case null { return [] };
      case (?session) {
        let owner = emailToPrincipalSimple(session.email);
        
        // Verify caller owns this game
        switch (games.get(gameId)) {
          case null { return [] };
          case (?game) {
            if (not Principal.equal(game.owner, owner)) { return [] };
            
            // Same logic as viewSuspicionLog but returns structured data
            let logArray = List.toArray(suspicionLog);
            let result = Buffer.Buffer<{ player_id: Text; gameId: Text; reason: Text; timestamp: Nat64 }>(0);
            let cap = if (limit > 100) { 100 } else { limit };
            var count = 0;
            
            let size = logArray.size();
            label logLoop for (i in Iter.range(0, size - 1)) {
              if (count >= cap) { break logLoop };
              let entry = logArray[size - 1 - i];
              if (entry.gameId == gameId) {
                result.add(entry);
                count += 1;
              };
            };
            
            Buffer.toArray(result)
          };
        };
      };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// GET DELETED GAMES BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public query func getDeletedGamesBySession(sessionId: Text) : async [DeletedGame] {
    switch (sessions.get(sessionId)) {
        case null { return [] };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            
            let ownerDeleted = Buffer.Buffer<DeletedGame>(0);
            for ((_, deleted) in deletedGames.entries()) {
                if (Principal.equal(deleted.deletedBy, owner)) {
                    ownerDeleted.add(deleted);
                };
            };
            
            Buffer.toArray(ownerDeleted)
        };
    };
};


// ═══════════════════════════════════════════════════════════════════════════════
// GET REMAINING DELETE ATTEMPTS BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public query func getRemainingDeleteAttemptsBySession(sessionId: Text) : async Nat {
    switch (sessions.get(sessionId)) {
        case null { return 0 };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            getRemainingDeleteAttemptsForOwner(owner)
        };
    };
};



// ═══════════════════════════════════════════════════════════════════════════════
// GENERATE API KEY BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public shared func generateApiKeyBySession(
    sessionId: Text,
    gameId: Text
) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
        case (#err(e)) { return #err(e) };
        case (#ok(owner)) {
            switch (games.get(gameId)) {
                case null { return #err("Game not found") };
                case (?game) {
                    if (not Principal.equal(game.owner, owner)) {
                        return #err("You don't own this game");
                    };
                    
                    // Check if active key already exists for this game
                    for ((_, apiKey) in apiKeys.entries()) {
                        if (apiKey.gameId == gameId and apiKey.isActive) {
                            return #err("Active API key exists. Revoke it first to generate a new one.");
                        };
                    };
                    
                    let key = generateUniqueApiKey(gameId);
                    let currentTime = Time.now();
                    
                    let apiKeyRecord : ApiKey = {
                        key = key;
                        gameId = gameId;
                        owner = owner;
                        created = currentTime;
                        lastUsed = currentTime;
                        tier = "free";
                        requestsToday = 0;
                        isActive = true;
                    };
                    
                    apiKeys.put(key, apiKeyRecord);
                    
                    #ok(key)
                };
            };
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// GET API KEY BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public query func getApiKeyBySession(sessionId: Text, gameId: Text) : async Result.Result<Text, Text> {
    switch (sessions.get(sessionId)) {
        case null { return #err("Invalid session") };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            
            switch (games.get(gameId)) {
                case null { return #err("Game not found") };
                case (?game) {
                    if (not Principal.equal(game.owner, owner)) {
                        return #err("You don't own this game");
                    };
                    
                    for ((key, apiKey) in apiKeys.entries()) {
                        if (apiKey.gameId == gameId and apiKey.isActive) {
                            return #ok(key);
                        };
                    };
                    
                    #err("No API key found. Generate one first.")
                };
            };
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// HAS API KEY BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public query func hasApiKeyBySession(sessionId: Text, gameId: Text) : async Bool {
    switch (sessions.get(sessionId)) {
        case null { return false };
        case (?session) {
            let owner = emailToPrincipalSimple(session.email);
            
            switch (games.get(gameId)) {
                case null { return false };
                case (?game) {
                    if (not Principal.equal(game.owner, owner)) {
                        return false;
                    };
                    
                    for ((_, apiKey) in apiKeys.entries()) {
                        if (apiKey.gameId == gameId and apiKey.isActive) {
                            return true;
                        };
                    };
                    
                    false
                };
            };
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// REVOKE API KEY BY SESSION
// ═══════════════════════════════════════════════════════════════════════════════

public shared func revokeApiKeyBySession(
    sessionId: Text,
    gameId: Text
) : async Result.Result<Text, Text> {
    
    switch (getOwnerFromSession(sessionId)) {
        case (#err(e)) { return #err(e) };
        case (#ok(owner)) {
            switch (games.get(gameId)) {
                case null { return #err("Game not found") };
                case (?game) {
                    if (not Principal.equal(game.owner, owner)) {
                        return #err("You don't own this game");
                    };
                    
                    for ((key, apiKey) in apiKeys.entries()) {
                        if (apiKey.gameId == gameId and apiKey.isActive) {
                            let revokedKey : ApiKey = {
                                key = apiKey.key;
                                gameId = apiKey.gameId;
                                owner = apiKey.owner;
                                created = apiKey.created;
                                lastUsed = apiKey.lastUsed;
                                tier = apiKey.tier;
                                requestsToday = apiKey.requestsToday;
                                isActive = false;
                            };
                            apiKeys.put(key, revokedKey);
                            return #ok("API key revoked successfully");
                        };
                    };
                    
                    #err("No active API key found")
                };
            };
        };
    };
};

}
