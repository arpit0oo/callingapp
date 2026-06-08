import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // Collection references

  static CollectionReference tenantsCol() =>
      _db.collection('tenants');

  static CollectionReference campaignsCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('campaigns');

  static CollectionReference leadsCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('leads');

  static CollectionReference usersCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('users');

  static CollectionReference callbacksCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('callbacks');

  static CollectionReference activityLogsCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('activity_logs');

  static CollectionReference suppressionCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('suppression_list');

  static CollectionReference formSchemaCol(String tenantId, String campaignId) =>
      campaignsCol(tenantId).doc(campaignId).collection('form_schema');

  static CollectionReference dispositionCol(String tenantId, String campaignId) =>
      campaignsCol(tenantId).doc(campaignId).collection('disposition_config');
}
