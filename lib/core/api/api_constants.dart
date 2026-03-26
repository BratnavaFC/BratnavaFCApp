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

  // Payments
  static String myPaymentSummary(String groupId) =>
      '/api/groups/$groupId/payments/my';
  static String monthlyGrid(String groupId, int year) =>
      '/api/groups/$groupId/payments/monthly/$year';
  static String extraCharges(String groupId) =>
      '/api/groups/$groupId/payments/extra-charges';

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

  // Team Colors
  static String teamColors(String groupId) => '/api/TeamColor/group/$groupId';
  static String teamColorById(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id';
  static String teamColorActivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/activate';
  static String teamColorDeactivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/deactivate';
}
