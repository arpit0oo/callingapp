class AppSession {
  static String tenantId = "xperttutor";
  static String userId = "test_user";
  static String role = AppRoles.companyAdmin;
  static String campaignId = "";
}

class AppRoles {
  static const superAdmin = "super_admin";
  static const companyAdmin = "company_admin";
  static const manager = "manager";
  static const coldCaller = "cold";
  static const warmCaller = "warm";
}
