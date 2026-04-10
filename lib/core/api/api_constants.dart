class ApiConstants {
  ApiConstants._();

  // Auth
  static const String login        = '/api/Authentication/login';
  static const String refreshToken = '/api/Authentication/refresh-token';

  // Users
  static const String users = '/api/Users';
  static String userById(String id) => '/api/Users/$id';

  // Groups
  static const String groups = '/api/Groups';
  static String groupById(String id) => '/api/Groups/$id';
  static String groupsByAdmin(String adminId) =>
      '/api/Groups/admin/$adminId';
  static String groupsByFinanceiro(String finId) =>
      '/api/Groups/financeiro/$finId';

  // Players
  static const String playersMe = '/api/Players/mine';
  static String playerById(String id) => '/api/Players/$id';
  static String birthdayStatus(String groupId) =>
      '/api/Players/group/$groupId/birthday-status';
  static String visualStats(String groupId) =>
      '/api/TeamGeneration/visual-stats/$groupId';

  // Players (group admin)
  static const String playersCreate                = '/api/Players';
  static String groupPlayers(String groupId)       => '/api/Players/group/$groupId';
  static String playerOps(String id)               => '/api/Players/$id';
  static String playerLeaveGroup(String id)        => '/api/Players/$id/leave-group';

  // Group invites
  static const String groupInvites                 = '/api/GroupInvites';

  // Users – search (paginated)
  static String usersListSearch(String q, int pageSize) =>
      '/api/Users?search=${Uri.encodeComponent(q)}&pageSize=$pageSize';

  // Matches
  static String currentMatch(String groupId) =>
      '/api/matches/group/$groupId/current';
  static String matchDetails(String groupId, String matchId) =>
      '/api/Matches/group/$groupId/$matchId/details';
  static String playerRecentMatches(String groupId) =>
      '/api/Matches/group/$groupId/player-recent';
  static String matchHistory(String groupId) =>
      '/api/Matches/group/$groupId/history';

  // Payments – mensalidades
  static String monthlyGrid(String groupId, int year) =>
      '/api/groups/$groupId/payments/monthly/$year';
  static String upsertMonthly(String groupId) =>
      '/api/groups/$groupId/payments/monthly';
  static String monthlyProof(String groupId, String playerId, int year, int month) =>
      '/api/groups/$groupId/payments/monthly/$year/$month/$playerId/proof';
  static String myMonthlyRow(String groupId, int year) =>
      '/api/groups/$groupId/payments/monthly/$year/me';

  // Payments – cobranças extras
  static String extraCharges(String groupId) =>
      '/api/groups/$groupId/payments/extra-charges';
  static String extraChargeById(String groupId, String chargeId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId';
  static String extraChargeBulkDiscount(String groupId, String chargeId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/bulk-discount';
  static String extraChargePayment(String groupId, String chargeId, String playerId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/players/$playerId';
  static String extraChargeProof(String groupId, String chargeId, String playerId) =>
      '/api/groups/$groupId/payments/extra-charges/$chargeId/$playerId/proof';
  static String myExtraCharges(String groupId) =>
      '/api/groups/$groupId/payments/extra-charges/me';

  // Payments – resumo
  static String myPaymentSummary(String groupId) =>
      '/api/groups/$groupId/payments/my';

  // Calendar
  static String calendarEvents(String groupId, String start, String end) =>
      '/api/Calendar/group/$groupId?start=$start&end=$end';
  static String calendarEventById(String groupId, String id) =>
      '/api/Calendar/group/$groupId/events/$id';
  static String calendarEvents2(String groupId) =>
      '/api/Calendar/group/$groupId/events';
  static String calendarCategories(String groupId) =>
      '/api/Calendar/group/$groupId/categories';
  static String calendarCategoryById(String groupId, String id) =>
      '/api/Calendar/group/$groupId/categories/$id';

  // Users – mutations
  static String changePassword(String id) => '/api/Users/$id/change-password';
  static String deactivateUser(String id)  => '/api/Users/$id/deactivate';
  static String activateUser(String id)    => '/api/Users/$id/activate';

  // Group settings (separate resource from group detail)
  static String groupSettings(String groupId) => '/api/GroupSettings/group/$groupId';

  // Group members management
  static String groupAdmins(String id)                      => '/api/Groups/$id/admins';
  static String groupAdminById(String id, String uid)       => '/api/Groups/$id/admins/$uid';
  static String groupFinanceiros(String id)                 => '/api/Groups/$id/financeiros';
  static String groupFinanceiroById(String id, String uid)  => '/api/Groups/$id/financeiros/$uid';
  static String usersSearch(String q)                       => '/api/Users?search=${Uri.encodeComponent(q)}';

  // Polls
  static String polls(String groupId) =>
      '/api/Polls/group/$groupId';
  static String pollById(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId';
  static String createEventPoll(String groupId) =>
      '/api/Polls/group/$groupId/event';
  static String closePoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/close';
  static String reopenPoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/reopen';
  static String deletePoll(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId';
  static String pollOptions(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/options';
  static String pollOptionById(String groupId, String pollId, String optId) =>
      '/api/Polls/group/$groupId/$pollId/options/$optId';
  static String castVote(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/vote';
  static String adminVote(String groupId, String pollId) =>
      '/api/Polls/group/$groupId/$pollId/admin-vote';

  // Team Colors
  static String teamColors(String groupId) => '/api/TeamColor/group/$groupId';
  static String teamColorById(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id';
  static String teamColorActivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/activate';
  static String teamColorDeactivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/deactivate';

  // Matches – workflow completo
  static String matchCreate(String groupId)              => '/api/Matches/group/$groupId';
  static String matchHeader(String groupId, String id)   => '/api/Matches/group/$groupId/$id/header';
  static String matchAcceptation(String groupId, String id) => '/api/Matches/group/$groupId/$id/acceptation';
  static String matchMatchmaking(String groupId, String id) => '/api/Matches/group/$groupId/$id/matchmaking';
  static String matchPostgame(String groupId, String id)    => '/api/Matches/group/$groupId/$id/postgame';
  static String matchAccept(String groupId, String id)   => '/api/Matches/group/$groupId/$id/accept';
  static String matchReject(String groupId, String id)   => '/api/Matches/group/$groupId/$id/reject';
  static String matchColors(String groupId, String id)   => '/api/Matches/group/$groupId/$id/colors';
  static String matchStart(String groupId, String id)    => '/api/Matches/group/$groupId/$id/start';
  static String matchEnd(String groupId, String id)      => '/api/Matches/group/$groupId/$id/end';
  static String matchVote(String groupId, String id)     => '/api/Matches/group/$groupId/$id/vote';
  static String matchScore(String groupId, String id)    => '/api/Matches/group/$groupId/$id/score';
  static String matchGoals(String groupId, String id)    => '/api/Matches/group/$groupId/$id/goals';
  static String matchGoalById(String groupId, String id, String goalId) =>
      '/api/Matches/group/$groupId/$id/goals/$goalId';
  static String matchTeams(String groupId, String id)    => '/api/Matches/group/$groupId/$id/teams';
  static String matchSwap(String groupId, String id)     => '/api/Matches/group/$groupId/$id/swap';
  static String matchFinalize(String groupId, String id) => '/api/Matches/group/$groupId/$id/finalize';
  static String matchRewind(String groupId, String id)   => '/api/Matches/group/$groupId/$id/rewind';
  static String matchGoToMatchmaking(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/go-to-matchmaking';
  static String matchGoToPostGame(String groupId, String id) =>
      '/api/Matches/group/$groupId/$id/go-to-post-game';
  static String matchGuest(String groupId, String id)    => '/api/Matches/group/$groupId/$id/guest';
  static String matchPlayerRole(String groupId, String id, String mpId) =>
      '/api/Matches/group/$groupId/$id/players/$mpId/role';

  // Match invite — aceitar/rejeitar pelo token JWT (sem playerId)
  static String matchMyInviteAccept(String groupId, String matchId) =>
      '/api/matches/group/$groupId/$matchId/my-invite/accept';
  static String matchMyInviteReject(String groupId, String matchId) =>
      '/api/matches/group/$groupId/$matchId/my-invite/reject';

  // TeamGeneration
  static const String teamGenGenerate = '/api/TeamGeneration/generate';

  // Absences
  static const String absences     = '/api/absences';
  static const String absencesMine = '/api/absences/mine';
  static String absenceById(String id) => '/api/absences/$id';

  // Push Notifications
  static const String pushRegisterToken = '/api/push/register-token';
}
