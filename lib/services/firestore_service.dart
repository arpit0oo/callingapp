import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── Top-level collections ────────────────────────────────────────────────

  static CollectionReference tenantsCol() =>
      _db.collection('tenants');

  static CollectionReference campaignsCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('campaigns');

  static CollectionReference usersCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('users');

  static CollectionReference activityLogsCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('activity_logs');

  static CollectionReference suppressionCol(String tenantId) =>
      tenantsCol().doc(tenantId).collection('suppression_list');

  // ── Campaign subcollections ──────────────────────────────────────────────

  static CollectionReference formSchemaCol(String tenantId, String campaignId) =>
      campaignsCol(tenantId).doc(campaignId).collection('form_schema');

  static CollectionReference dispositionCol(String tenantId, String campaignId) =>
      campaignsCol(tenantId).doc(campaignId).collection('disposition_config');

  /// Leads are now stored under the campaign; phone number is the document ID.
  static CollectionReference leadsCol(String tenantId, String campaignId) =>
      campaignsCol(tenantId).doc(campaignId).collection('leads');

  // ── Number bucket documents ──────────────────────────────────────────────

  /// Raw-number bucket document.
  /// [bucket] must be one of: 'unfiltered', 'connected', 'missed',
  ///   'disconnected', 'incoming'.
  static DocumentReference rawNumbersDoc(
          String tenantId, String campaignId, String bucket) =>
      campaignsCol(tenantId)
          .doc(campaignId)
          .collection('raw_numbers')
          .doc(bucket);

  /// Warm-number bucket document.
  /// [bucket] must be one of: 'callback', 'retry'.
  static DocumentReference warmNumbersDoc(
          String tenantId, String campaignId, String bucket) =>
      campaignsCol(tenantId)
          .doc(campaignId)
          .collection('warm_numbers')
          .doc(bucket);
}
