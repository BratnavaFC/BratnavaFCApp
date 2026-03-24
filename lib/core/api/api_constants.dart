class ApiConstants {
  ApiConstants._();

  // Auth
  static const String login        = '/api/Authentication/login';
  static const String refreshToken = '/api/Authentication/refresh-token';

  // Users
  static const String users = '/api/Users';

  // Groups
  static const String groups = '/api/Groups';
  static String groupsByAdmin(String adminId) =>
      '/api/Groups/admin/$adminId';
  static String groupsByFinanceiro(String finId) =>
      '/api/Groups/financeiro/$finId';

  // Players
  static const String playersMe = '/api/Players/mine';
  static String playerById(String id) => '/api/Players/$id';

  // Players (group admin)
  static String groupPlayers(String groupId) => '/api/Players/group/$groupId';
  static String playerOps(String id) => '/api/Players/$id';

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

  // Team Colors
  static String teamColors(String groupId) => '/api/TeamColor/group/$groupId';
  static String teamColorById(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id';
  static String teamColorActivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/activate';
  static String teamColorDeactivate(String groupId, String id) =>
      '/api/TeamColor/group/$groupId/$id/deactivate';
}
