export const idlFactory = ({ IDL }) => {
  const Result_1 = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const Result_14 = IDL.Variant({
    'ok' : IDL.Record({
      'nickname' : IDL.Text,
      'message' : IDL.Text,
      'gameProfile' : IDL.Opt(
        IDL.Record({
          'total_score' : IDL.Nat64,
          'best_streak' : IDL.Nat64,
          'achievements' : IDL.Vec(IDL.Text),
          'last_played' : IDL.Nat64,
          'play_count' : IDL.Nat,
        })
      ),
    }),
    'err' : IDL.Text,
  });
  const Result_13 = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  const AuthType = IDL.Variant({
    'internetIdentity' : IDL.Null,
    'apple' : IDL.Null,
    'google' : IDL.Null,
    'external' : IDL.Null,
  });
  const Session = IDL.Record({
    'created' : IDL.Nat64,
    'nickname' : IDL.Text,
    'expires' : IDL.Nat64,
    'authType' : AuthType,
    'email' : IDL.Text,
    'sessionId' : IDL.Text,
    'lastUsed' : IDL.Nat64,
  });
  const Result_12 = IDL.Variant({ 'ok' : Session, 'err' : IDL.Text });
  const AccessMode = IDL.Variant({
    'apiOnly' : IDL.Null,
    'both' : IDL.Null,
    'webOnly' : IDL.Null,
  });
  const GameInfo = IDL.Record({
    'created' : IDL.Nat64,
    'absoluteScoreCap' : IDL.Opt(IDL.Nat64),
    'totalPlayers' : IDL.Nat,
    'owner' : IDL.Principal,
    'absoluteStreakCap' : IDL.Opt(IDL.Nat64),
    'name' : IDL.Text,
    'gameId' : IDL.Text,
    'accessMode' : AccessMode,
    'description' : IDL.Text,
    'maxSessionDurationMins' : IDL.Opt(IDL.Nat),
    'isActive' : IDL.Bool,
    'maxStreakDelta' : IDL.Opt(IDL.Nat64),
    'appleBundleId' : IDL.Opt(IDL.Text),
    'maxScorePerSecond' : IDL.Opt(IDL.Nat64),
    'gameUrl' : IDL.Opt(IDL.Text),
    'minPlayDurationSecs' : IDL.Opt(IDL.Nat64),
    'maxScorePerRound' : IDL.Opt(IDL.Nat64),
    'googleClientIds' : IDL.Vec(IDL.Text),
    'appleTeamId' : IDL.Opt(IDL.Text),
    'totalPlays' : IDL.Nat,
    'timeValidationEnabled' : IDL.Bool,
  });
  const PublicScoreEntry = IDL.Record({
    'streak' : IDL.Nat64,
    'nickname' : IDL.Text,
    'authType' : IDL.Text,
    'rank' : IDL.Nat,
    'submittedAt' : IDL.Nat64,
    'score' : IDL.Nat64,
  });
  const Result_11 = IDL.Variant({
    'ok' : IDL.Record({
      'entries' : IDL.Vec(PublicScoreEntry),
      'config' : IDL.Record({
        'sortBy' : IDL.Text,
        'period' : IDL.Text,
        'name' : IDL.Text,
        'periodEnd' : IDL.Nat64,
        'periodStart' : IDL.Nat64,
      }),
    }),
    'err' : IDL.Text,
  });
  const ArchiveInfo = IDL.Record({
    'entryCount' : IDL.Nat,
    'periodEnd' : IDL.Nat64,
    'scoreboardId' : IDL.Text,
    'periodStart' : IDL.Nat64,
    'topScore' : IDL.Nat64,
    'archiveId' : IDL.Text,
    'topPlayer' : IDL.Opt(IDL.Text),
  });
  const DailyStats = IDL.Record({
    'uniquePlayers' : IDL.Nat,
    'date' : IDL.Text,
    'gameId' : IDL.Text,
    'totalScore' : IDL.Nat64,
    'totalGames' : IDL.Nat,
    'newUsers' : IDL.Nat,
    'authenticatedPlays' : IDL.Nat,
  });
  const DeletedGame = IDL.Record({
    'game' : GameInfo,
    'permanentDeletionAt' : IDL.Nat64,
    'canRecover' : IDL.Bool,
    'deletedAt' : IDL.Nat64,
    'deletedBy' : IDL.Principal,
    'reason' : IDL.Text,
  });
  const Result_10 = IDL.Variant({
    'ok' : IDL.Record({
      'appleConfigured' : IDL.Bool,
      'googleConfigured' : IDL.Bool,
      'appleBundleId' : IDL.Opt(IDL.Text),
      'googleClientIds' : IDL.Vec(IDL.Text),
      'appleTeamId' : IDL.Opt(IDL.Text),
    }),
    'err' : IDL.Text,
  });
  const GameProfile = IDL.Record({
    'total_score' : IDL.Nat64,
    'gameId' : IDL.Text,
    'best_streak' : IDL.Nat64,
    'achievements' : IDL.Vec(IDL.Text),
    'last_played' : IDL.Nat64,
    'play_count' : IDL.Nat,
  });
  const Result_9 = IDL.Variant({ 'ok' : GameProfile, 'err' : IDL.Text });
  const Result_8 = IDL.Variant({
    'ok' : IDL.Record({
      'entries' : IDL.Vec(PublicScoreEntry),
      'config' : IDL.Record({
        'sortBy' : IDL.Text,
        'period' : IDL.Text,
        'name' : IDL.Text,
        'periodEnd' : IDL.Nat64,
        'periodStart' : IDL.Nat64,
      }),
      'archiveId' : IDL.Text,
    }),
    'err' : IDL.Text,
  });
  const SortBy = IDL.Variant({ 'streak' : IDL.Null, 'score' : IDL.Null });
  const UserIdentifier = IDL.Variant({
    'principal' : IDL.Principal,
    'email' : IDL.Text,
  });
  const UserProfile = IDL.Record({
    'created' : IDL.Nat64,
    'nickname' : IDL.Text,
    'gameProfiles' : IDL.Vec(IDL.Tuple(IDL.Text, GameProfile)),
    'authType' : AuthType,
    'last_updated' : IDL.Nat64,
    'identifier' : UserIdentifier,
  });
  const Result_7 = IDL.Variant({ 'ok' : UserProfile, 'err' : IDL.Text });
  const PlayerStats = IDL.Record({
    'lastPlayed' : IDL.Nat64,
    'avgScore' : IDL.Nat64,
    'gameId' : IDL.Text,
    'favoriteTime' : IDL.Text,
    'totalGames' : IDL.Nat,
    'playStreak' : IDL.Nat,
    'identifier' : UserIdentifier,
  });
  const AnalyticsEvent = IDL.Record({
    'metadata' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
    'gameId' : IDL.Text,
    'timestamp' : IDL.Nat64,
    'identifier' : UserIdentifier,
    'eventType' : IDL.Text,
  });
  const Result_6 = IDL.Variant({
    'ok' : IDL.Record({
      'entries' : IDL.Vec(PublicScoreEntry),
      'config' : IDL.Record({
        'sortBy' : IDL.Text,
        'lastReset' : IDL.Nat64,
        'period' : IDL.Text,
        'name' : IDL.Text,
        'description' : IDL.Text,
      }),
    }),
    'err' : IDL.Text,
  });
  const PublicUserProfile = IDL.Record({
    'created' : IDL.Nat64,
    'nickname' : IDL.Text,
    'gameProfiles' : IDL.Vec(IDL.Tuple(IDL.Text, GameProfile)),
    'authType' : AuthType,
    'last_updated' : IDL.Nat64,
  });
  const Result_5 = IDL.Variant({ 'ok' : PublicUserProfile, 'err' : IDL.Text });
  const HeaderField = IDL.Tuple(IDL.Text, IDL.Text);
  const HttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
  });
  const StreamingCallbackToken = IDL.Record({
    'key' : IDL.Text,
    'index' : IDL.Nat,
    'content_encoding' : IDL.Text,
  });
  const StreamingCallbackResponse = IDL.Record({
    'token' : IDL.Opt(StreamingCallbackToken),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const StreamingStrategy = IDL.Variant({
    'Callback' : IDL.Record({
      'token' : StreamingCallbackToken,
      'callback' : IDL.Func(
          [StreamingCallbackToken],
          [StreamingCallbackResponse],
          ['query'],
        ),
    }),
  });
  const HttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const Result_4 = IDL.Variant({
    'ok' : IDL.Record({
      'isNewUser' : IDL.Bool,
      'nickname' : IDL.Text,
      'message' : IDL.Text,
      'gameProfile' : IDL.Opt(
        IDL.Record({
          'total_score' : IDL.Nat64,
          'best_streak' : IDL.Nat64,
          'achievements' : IDL.Vec(IDL.Text),
          'last_played' : IDL.Nat64,
          'play_count' : IDL.Nat,
        })
      ),
    }),
    'err' : IDL.Text,
  });
  const Result_3 = IDL.Variant({
    'ok' : IDL.Record({
      'isNewUser' : IDL.Bool,
      'nickname' : IDL.Text,
      'message' : IDL.Text,
      'sessionId' : IDL.Text,
      'gameProfile' : IDL.Opt(
        IDL.Record({
          'total_score' : IDL.Nat64,
          'best_streak' : IDL.Nat64,
          'achievements' : IDL.Vec(IDL.Text),
          'last_played' : IDL.Nat64,
          'play_count' : IDL.Nat,
        })
      ),
    }),
    'err' : IDL.Text,
  });
  const Result_2 = IDL.Variant({
    'ok' : IDL.Record({ 'rank' : IDL.Nat, 'isNewBest' : IDL.Bool }),
    'err' : IDL.Text,
  });
  const ApiKey = IDL.Record({
    'key' : IDL.Text,
    'created' : IDL.Int,
    'requestsToday' : IDL.Nat,
    'owner' : IDL.Principal,
    'tier' : IDL.Text,
    'gameId' : IDL.Text,
    'isActive' : IDL.Bool,
    'lastUsed' : IDL.Int,
  });
  const Result = IDL.Variant({
    'ok' : IDL.Record({
      'nickname' : IDL.Text,
      'valid' : IDL.Bool,
      'email' : IDL.Text,
    }),
    'err' : IDL.Text,
  });
  return IDL.Service({
    'adminCleanupSessions' : IDL.Func([], [IDL.Text], []),
    'adminGate' : IDL.Func([IDL.Text, IDL.Vec(IDL.Text)], [Result_1], []),
    'canDeleteGame' : IDL.Func([], [IDL.Bool], ['query']),
    'cancelPlaySession' : IDL.Func([IDL.Text], [Result_1], []),
    'changeNicknameAndGetProfile' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Text],
        [Result_14],
        [],
      ),
    'cleanupAllExpiredPlaySessions' : IDL.Func([], [Result_13], []),
    'cleanupExpiredGames' : IDL.Func([], [Result_1], []),
    'clearGameOAuthCredentials' : IDL.Func(
        [IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'clearGameOAuthCredentialsBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'createScoreboardBySession' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Opt(IDL.Nat),
        ],
        [Result_1],
        [],
      ),
    'createSessionForVerifiedUser' : IDL.Func(
        [AuthType, IDL.Text, IDL.Opt(IDL.Text), IDL.Text],
        [Result_12],
        [],
      ),
    'debugDataState' : IDL.Func(
        [],
        [
          IDL.Record({
            'legacyDeletedCount' : IDL.Nat,
            'v2DeletedCount' : IDL.Nat,
            'v2GamesCount' : IDL.Nat,
            'runtimeDeletedCount' : IDL.Nat,
            'legacyGamesCount' : IDL.Nat,
            'runtimeGamesCount' : IDL.Nat,
            'migrationDone' : IDL.Bool,
          }),
        ],
        ['query'],
      ),
    'deleteFile' : IDL.Func([IDL.Text], [Result_1], []),
    'deleteGame' : IDL.Func([IDL.Text], [Result_1], []),
    'deleteGameBySession' : IDL.Func([IDL.Text, IDL.Text], [Result_1], []),
    'deleteScoreboardBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'destroySession' : IDL.Func([IDL.Text], [Result_1], []),
    'generateApiKey' : IDL.Func([IDL.Text], [Result_1], []),
    'generateApiKeyBySession' : IDL.Func([IDL.Text, IDL.Text], [Result_1], []),
    'getAchievements' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [IDL.Vec(IDL.Text)],
        ['query'],
      ),
    'getActiveGames' : IDL.Func([], [IDL.Vec(GameInfo)], ['query']),
    'getActiveSessions' : IDL.Func([], [IDL.Nat], ['query']),
    'getAnalyticsSummary' : IDL.Func(
        [],
        [
          IDL.Record({
            'uniquePlayers' : IDL.Nat,
            'totalEvents' : IDL.Nat,
            'totalDays' : IDL.Nat,
            'totalGames' : IDL.Nat,
            'recentEvents' : IDL.Nat,
            'mostActiveDay' : IDL.Text,
          }),
        ],
        ['query'],
      ),
    'getApiKey' : IDL.Func([IDL.Text], [Result_1], []),
    'getApiKeyBySession' : IDL.Func(
        [IDL.Text, IDL.Text],
        [Result_1],
        ['query'],
      ),
    'getArchiveStats' : IDL.Func(
        [IDL.Text],
        [
          IDL.Record({
            'totalArchives' : IDL.Nat,
            'byScoreboard' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat)),
          }),
        ],
        ['query'],
      ),
    'getArchivedScoreboard' : IDL.Func(
        [IDL.Text, IDL.Nat],
        [Result_11],
        ['query'],
      ),
    'getArchivesInRange' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Nat64, IDL.Nat64],
        [IDL.Vec(ArchiveInfo)],
        ['query'],
      ),
    'getDailyStats' : IDL.Func(
        [IDL.Text, IDL.Text],
        [IDL.Opt(DailyStats)],
        ['query'],
      ),
    'getDeletedGames' : IDL.Func([], [IDL.Vec(DeletedGame)], ['query']),
    'getDeletedGamesBySession' : IDL.Func(
        [IDL.Text],
        [IDL.Vec(DeletedGame)],
        ['query'],
      ),
    'getDetailedStats' : IDL.Func(
        [IDL.Text],
        [
          IDL.Record({
            'game' : IDL.Opt(
              IDL.Record({
                'totalPlayers' : IDL.Nat,
                'isActive' : IDL.Bool,
                'totalGames' : IDL.Nat,
              })
            ),
            'submissions' : IDL.Record({
              'today' : IDL.Nat,
              'total' : IDL.Nat,
            }),
          }),
        ],
        ['query'],
      ),
    'getDeveloperTier' : IDL.Func(
        [],
        [
          IDL.Record({
            'maxGames' : IDL.Nat,
            'tier' : IDL.Text,
            'currentGames' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'getDeveloperTierBySession' : IDL.Func(
        [IDL.Text],
        [
          IDL.Record({
            'maxGames' : IDL.Nat,
            'tier' : IDL.Text,
            'currentGames' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'getFile' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Vec(IDL.Nat8))], ['query']),
    'getFileInfo' : IDL.Func(
        [IDL.Text],
        [IDL.Opt(IDL.Record({ 'name' : IDL.Text, 'size' : IDL.Nat }))],
        ['query'],
      ),
    'getGame' : IDL.Func([IDL.Text], [IDL.Opt(GameInfo)], ['query']),
    'getGameAccessMode' : IDL.Func(
        [IDL.Text],
        [IDL.Opt(AccessMode)],
        ['query'],
      ),
    'getGameAuthStats' : IDL.Func(
        [IDL.Text],
        [
          IDL.Record({
            'total' : IDL.Nat,
            'internetIdentity' : IDL.Nat,
            'apple' : IDL.Nat,
            'google' : IDL.Nat,
            'external' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'getGameOAuthConfig' : IDL.Func(
        [IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'appleBundleId' : IDL.Opt(IDL.Text),
              'googleClientIds' : IDL.Vec(IDL.Text),
              'appleTeamId' : IDL.Opt(IDL.Text),
              'nativeAuthEnabled' : IDL.Bool,
            })
          ),
        ],
        ['query'],
      ),
    'getGameOAuthConfigBySession' : IDL.Func(
        [IDL.Text, IDL.Text],
        [Result_10],
        ['query'],
      ),
    'getGameProfile' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [Result_9],
        ['query'],
      ),
    'getGameTimeValidationRules' : IDL.Func(
        [IDL.Text],
        [
          IDL.Record({
            'maxSessionDurationMins' : IDL.Nat,
            'enabled' : IDL.Bool,
            'maxScorePerSecond' : IDL.Nat64,
            'minPlayDurationSecs' : IDL.Nat64,
          }),
        ],
        ['query'],
      ),
    'getGamesByOwner' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(GameInfo)],
        ['query'],
      ),
    'getGamesBySession' : IDL.Func([IDL.Text], [IDL.Vec(GameInfo)], ['query']),
    'getLastArchivedScoreboard' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Nat],
        [Result_8],
        ['query'],
      ),
    'getLeaderboard' : IDL.Func(
        [IDL.Text, SortBy, IDL.Nat],
        [IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat64, IDL.Nat64, IDL.Text))],
        ['query'],
      ),
    'getLeaderboardByAuth' : IDL.Func(
        [IDL.Text, AuthType, SortBy, IDL.Nat],
        [IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat64, IDL.Nat64, IDL.Text))],
        ['query'],
      ),
    'getMyDeveloperTier' : IDL.Func(
        [],
        [
          IDL.Record({
            'maxGames' : IDL.Nat,
            'tier' : IDL.Text,
            'currentGames' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'getMyGameCount' : IDL.Func([], [IDL.Nat], ['query']),
    'getMyProfile' : IDL.Func([], [Result_7], []),
    'getMyProfileBySession' : IDL.Func([IDL.Text], [Result_7], []),
    'getNicknameBySession' : IDL.Func([IDL.Text], [Result_1], []),
    'getPlaySessionStatus' : IDL.Func(
        [IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'startedAt' : IDL.Nat64,
              'expiresAt' : IDL.Nat64,
              'gameId' : IDL.Text,
              'isActive' : IDL.Bool,
              'elapsedSeconds' : IDL.Nat64,
              'remainingSeconds' : IDL.Nat64,
            })
          ),
        ],
        ['query'],
      ),
    'getPlayerAnalytics' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [IDL.Opt(PlayerStats)],
        ['query'],
      ),
    'getPlayerRank' : IDL.Func(
        [IDL.Text, SortBy, IDL.Text, IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'streak' : IDL.Nat64,
              'totalPlayers' : IDL.Nat,
              'rank' : IDL.Nat,
              'score' : IDL.Nat64,
            })
          ),
        ],
        ['query'],
      ),
    'getPlayerScoreboardRank' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'streak' : IDL.Nat64,
              'totalPlayers' : IDL.Nat,
              'rank' : IDL.Nat,
              'score' : IDL.Nat64,
            })
          ),
        ],
        ['query'],
      ),
    'getProfileBySession' : IDL.Func([IDL.Text], [Result_7], []),
    'getRecentEvents' : IDL.Func(
        [IDL.Nat],
        [IDL.Vec(AnalyticsEvent)],
        ['query'],
      ),
    'getRemainingDeleteAttempts' : IDL.Func([], [IDL.Nat], ['query']),
    'getRemainingDeleteAttemptsBySession' : IDL.Func(
        [IDL.Text],
        [IDL.Nat],
        ['query'],
      ),
    'getRemainingGameSlots' : IDL.Func([], [IDL.Nat], ['query']),
    'getRemainingGameSlotsBySession' : IDL.Func(
        [IDL.Text],
        [IDL.Nat],
        ['query'],
      ),
    'getScoreboard' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Nat],
        [Result_6],
        ['query'],
      ),
    'getScoreboardArchives' : IDL.Func(
        [IDL.Text, IDL.Text],
        [IDL.Vec(ArchiveInfo)],
        ['query'],
      ),
    'getScoreboardsForGame' : IDL.Func(
        [IDL.Text],
        [
          IDL.Vec(
            IDL.Record({
              'entryCount' : IDL.Nat,
              'sortBy' : IDL.Text,
              'lastReset' : IDL.Nat64,
              'period' : IDL.Text,
              'name' : IDL.Text,
              'description' : IDL.Text,
              'isActive' : IDL.Bool,
              'scoreboardId' : IDL.Text,
              'maxEntries' : IDL.Nat,
            })
          ),
        ],
        ['query'],
      ),
    'getSessionInfo' : IDL.Func(
        [IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'created' : IDL.Nat64,
              'nickname' : IDL.Text,
              'expires' : IDL.Nat64,
              'authType' : IDL.Text,
              'email' : IDL.Text,
              'lastUsed' : IDL.Nat64,
            })
          ),
        ],
        ['query'],
      ),
    'getSubmissionStats' : IDL.Func(
        [],
        [
          IDL.Record({
            'today' : IDL.Nat,
            'total' : IDL.Nat,
            'date' : IDL.Text,
          }),
        ],
        ['query'],
      ),
    'getSystemInfo' : IDL.Func(
        [],
        [
          IDL.Record({
            'principalUserCount' : IDL.Nat,
            'fileCount' : IDL.Nat,
            'totalEvents' : IDL.Nat,
            'gameCount' : IDL.Nat,
            'suspicionLogSize' : IDL.Nat,
            'apiKeyCount' : IDL.Nat,
            'activeDays' : IDL.Nat,
            'emailUserCount' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'getUserProfile' : IDL.Func([IDL.Text, IDL.Text], [Result_5], ['query']),
    'hasApiKey' : IDL.Func([IDL.Text], [IDL.Bool], ['query']),
    'hasApiKeyBySession' : IDL.Func(
        [IDL.Text, IDL.Text],
        [IDL.Bool],
        ['query'],
      ),
    'http_request' : IDL.Func([HttpRequest], [HttpResponse], ['query']),
    'iiLoginAndGetProfile' : IDL.Func([IDL.Text, IDL.Text], [Result_4], []),
    'listFiles' : IDL.Func([], [IDL.Vec(IDL.Text)], ['query']),
    'listGames' : IDL.Func([], [IDL.Vec(GameInfo)], ['query']),
    'permanentlyDeleteGame' : IDL.Func([IDL.Text], [Result_1], []),
    'recoverDeletedGame' : IDL.Func([IDL.Text], [Result_1], []),
    'recoverDeletedGameBySession' : IDL.Func(
        [IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'registerGame' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Text),
          IDL.Opt(AccessMode),
        ],
        [Result_1],
        [],
      ),
    'registerGameBySession' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Text),
        ],
        [Result_1],
        [],
      ),
    'resetScoreboardBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'revokeApiKey' : IDL.Func([IDL.Text], [Result_1], []),
    'revokeApiKeyBySession' : IDL.Func([IDL.Text, IDL.Text], [Result_1], []),
    'setGameAppleCredentials' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Opt(IDL.Text)],
        [Result_1],
        [],
      ),
    'setGameAppleCredentialsBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Opt(IDL.Text)],
        [Result_1],
        [],
      ),
    'setGameGoogleCredentials' : IDL.Func(
        [IDL.Text, IDL.Vec(IDL.Text)],
        [Result_1],
        [],
      ),
    'setGameGoogleCredentialsBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Vec(IDL.Text)],
        [Result_1],
        [],
      ),
    'socialLoginAndGetProfile' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Text],
        [Result_3],
        [],
      ),
    'startGameSession' : IDL.Func([IDL.Text], [Result_1], []),
    'startGameSessionByApiKey' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'startGameSessionBySession' : IDL.Func(
        [IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'submitScore' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Nat,
          IDL.Nat,
          IDL.Opt(IDL.Nat),
          IDL.Opt(IDL.Text),
          IDL.Opt(IDL.Text),
        ],
        [Result_1],
        [],
      ),
    'submitScoreToScoreboard' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Nat,
          IDL.Nat,
          IDL.Opt(IDL.Text),
        ],
        [Result_2],
        [],
      ),
    'suggestNickname' : IDL.Func([], [Result_1], []),
    'toggleGameActive' : IDL.Func([IDL.Text], [Result_1], []),
    'trackEvent' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
        ],
        [],
        [],
      ),
    'unlockAchievement' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'updateApiKeyTier' : IDL.Func([IDL.Text, IDL.Text], [Result_1], []),
    'updateGame' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Opt(IDL.Text)],
        [Result_1],
        [],
      ),
    'updateGameAccessMode' : IDL.Func([IDL.Text, AccessMode], [Result_1], []),
    'updateGameBySession' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Text, IDL.Text, IDL.Opt(IDL.Text)],
        [Result_1],
        [],
      ),
    'updateGameRules' : IDL.Func(
        [
          IDL.Text,
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
        ],
        [Result_1],
        [],
      ),
    'updateGameRulesBySession' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
        ],
        [Result_1],
        [],
      ),
    'updateScoreboardBySession' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          IDL.Opt(IDL.Text),
          IDL.Opt(IDL.Text),
          IDL.Opt(IDL.Nat),
        ],
        [Result_1],
        [],
      ),
    'updateTimeValidationBySession' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Bool,
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat64),
          IDL.Opt(IDL.Nat),
        ],
        [Result_1],
        [],
      ),
    'uploadFile' : IDL.Func([IDL.Text, IDL.Vec(IDL.Nat8)], [Result_1], []),
    'validateApiKey' : IDL.Func([IDL.Text], [IDL.Opt(ApiKey)], []),
    'validateApiKeyQuery' : IDL.Func(
        [IDL.Text],
        [
          IDL.Opt(
            IDL.Record({
              'tier' : IDL.Text,
              'gameId' : IDL.Text,
              'isActive' : IDL.Bool,
            })
          ),
        ],
        ['query'],
      ),
    'validateSession' : IDL.Func([IDL.Text], [Result], []),
  });
};
export const init = ({ IDL }) => { return []; };
