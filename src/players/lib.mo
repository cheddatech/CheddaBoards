// ════════════════════════════════════════════════════════════════════════════════
// CheddaBoards Players Module
// Player identity, nickname validation, and profile helpers
// ════════════════════════════════════════════════════════════════════════════════

import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Result "mo:base/Result";

import Types "../types";

module {

  // ════════════════════════════════════════════════════════════════════════════
  // TYPES
  // ════════════════════════════════════════════════════════════════════════════

  public type UserIdentifier = Types.UserIdentifier;
  public type UserProfile = Types.UserProfile;
  public type GameProfile = Types.GameProfile;

  // ════════════════════════════════════════════════════════════════════════════
  // IDENTIFIER HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Convert a UserIdentifier to a unique text key
  public func identifierToText(id : UserIdentifier) : Text {
    switch (id) {
      case (#email(e)) "email:" # e;
      case (#principal(p)) "principal:" # Principal.toText(p);
    }
  };

  /// Create a key for tracking submissions (identifier + gameId)
  public func makeSubmitKey(identifier : UserIdentifier, gameId : Text) : Text {
    identifierToText(identifier) # ":" # gameId
  };

  /// Check if text looks like an email address
  public func looksLikeEmail(text : Text) : Bool {
    Text.contains(text, #char '@')
  };

  // ════════════════════════════════════════════════════════════════════════════
  // NICKNAME VALIDATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Validate a nickname format (length and allowed characters)
  public func validateNickname(nickname : Text) : Result.Result<(), Text> {
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

  /// Check if a nickname is the default generated format (Player_123)
  public func isDefaultNickname(nickname : Text) : Bool {
    nickname == "Player" or Text.startsWith(nickname, #text "Player_")
  };

  /// Generate a default nickname from a counter
  public func generateDefaultNickname(counter : Nat) : Text {
    "Player_" # Nat.toText(counter)
  };

  /// Check if a nickname is taken (pass in user iterators)
  /// excludeIdentifier allows checking "taken by someone else" when changing your own nickname
  public func isNicknameTaken(
    nickname : Text,
    excludeIdentifier : ?UserIdentifier,
    emailUsers : Iter.Iter<(Text, UserProfile)>,
    principalUsers : Iter.Iter<(Principal, UserProfile)>
  ) : Bool {
    // Check email users
    for ((_, user) in emailUsers) {
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
    for ((_, user) in principalUsers) {
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

  // ════════════════════════════════════════════════════════════════════════════
  // EXTERNAL PLAYER ID VALIDATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Validate an external player ID format (for API key users)
  public func isValidExternalPlayerId(playerId : Text) : Bool {
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

  // ════════════════════════════════════════════════════════════════════════════
  // GAME PROFILE HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get a specific game profile from a user's profile
  public func getGameProfile(user : UserProfile, gameId : Text) : ?GameProfile {
    for ((gId, profile) in user.gameProfiles.vals()) {
      if (gId == gameId) {
        return ?profile;
      };
    };
    null
  };

  /// Create an empty game profile
  public func emptyGameProfile(gameId : Text, timestamp : Nat64) : GameProfile {
    {
      gameId = gameId;
      total_score = 0;
      best_streak = 0;
      achievements = [];
      last_played = timestamp;
      play_count = 0;
    }
  };

  /// Update a game profile within a user's profile list
  /// Returns the new gameProfiles array
  public func updateGameProfile(
    existingProfiles : [(Text, GameProfile)],
    gameId : Text,
    updatedProfile : GameProfile
  ) : [(Text, GameProfile)] {
    var found = false;
    let updated = Array.map<(Text, GameProfile), (Text, GameProfile)>(
      existingProfiles,
      func(entry : (Text, GameProfile)) : (Text, GameProfile) {
        if (entry.0 == gameId) {
          found := true;
          (gameId, updatedProfile)
        } else {
          entry
        }
      }
    );
    
    if (found) {
      updated
    } else {
      // Add new profile
      Array.append(existingProfiles, [(gameId, updatedProfile)])
    }
  };

}
