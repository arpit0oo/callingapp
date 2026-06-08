import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class CampaignService {

  // Get all campaigns for a tenant — returns stream for real-time updates
  static Stream<QuerySnapshot> getCampaigns(String tenantId) {
    return FirestoreService.campaignsCol(tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get single campaign
  static Stream<DocumentSnapshot> getCampaign(String tenantId, String campaignId) {
    return FirestoreService.campaignsCol(tenantId)
        .doc(campaignId)
        .snapshots();
  }

  // Create campaign
  static Future<DocumentReference> createCampaign(
      String tenantId, Map<String, dynamic> data) async {
    return FirestoreService.campaignsCol(tenantId).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rawQueueCount': 0,
      'warmQueueCount': 0,
      'status': 'active',
    });
  }

  // Update campaign
  static Future<void> updateCampaign(
      String tenantId, String campaignId, Map<String, dynamic> data) async {
    return FirestoreService.campaignsCol(tenantId)
        .doc(campaignId)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Pause / Resume campaign
  static Future<void> setCampaignStatus(
      String tenantId, String campaignId, String status) async {
    return FirestoreService.campaignsCol(tenantId)
        .doc(campaignId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // Get form schema for campaign
  static Stream<QuerySnapshot> getFormSchema(
      String tenantId, String campaignId) {
    return FirestoreService.formSchemaCol(tenantId, campaignId)
        .orderBy('order')
        .snapshots();
  }

  // Save form schema field
  static Future<void> saveFormField(
      String tenantId,
      String campaignId,
      String fieldId,
      Map<String, dynamic> data) async {
    return FirestoreService.formSchemaCol(tenantId, campaignId)
        .doc(fieldId)
        .set(data, SetOptions(merge: true));
  }

  // Delete form field
  static Future<void> deleteFormField(
      String tenantId, String campaignId, String fieldId) async {
    return FirestoreService.formSchemaCol(tenantId, campaignId)
        .doc(fieldId)
        .delete();
  }

  // Get disposition config
  static Stream<QuerySnapshot> getDispositions(
      String tenantId, String campaignId) {
    return FirestoreService.dispositionCol(tenantId, campaignId)
        .orderBy('order')
        .snapshots();
  }

  // Save disposition
  static Future<void> saveDisposition(
      String tenantId,
      String campaignId,
      String dispositionId,
      Map<String, dynamic> data) async {
    return FirestoreService.dispositionCol(tenantId, campaignId)
        .doc(dispositionId)
        .set(data, SetOptions(merge: true));
  }

  // Delete disposition
  static Future<void> deleteDisposition(
      String tenantId, String campaignId, String dispositionId) async {
    return FirestoreService.dispositionCol(tenantId, campaignId)
        .doc(dispositionId)
        .delete();
  }
}
