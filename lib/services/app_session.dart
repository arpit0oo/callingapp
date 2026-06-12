import 'package:flutter/material.dart';

class AppSession {
  static String tenantId = "xperttutor";
  static String userId = "test_user";
  static String name = "";
  static String role = AppRoles.companyAdmin;
  static String campaignId   = "";
  static String campaignName = "";

  /// Disposition colors pre-fetched at login, keyed by lowercase label.
  /// Used by Home, Performance, and Workspace for chip rendering.
  /// Empty map = fall back to each screen's default gray chips.
  static Map<String, Color> dispositionColors = {};
}

class AppRoles {
  static const superAdmin = "super_admin";
  static const companyAdmin = "company_admin";
  static const manager = "manager";
  static const coldCaller = "cold";
  static const warmCaller = "warm";
}
