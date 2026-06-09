import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeadService {

  // Get next available lead for caller.
  // NOTE: No transaction — db.runTransaction() is unreliable on Flutter Web.
  // A small race condition is accepted here; migrate to a Cloud Function
  // for atomic locking before production.
  static Future<Map<String, dynamic>?> getNextLead(
      String tenantId, String campaignId, String callerId) async {
    // 1. Query the first raw lead for this campaign, oldest first.
    final query = await FirestoreService.leadsCol(tenantId)
        .where('campaignId', isEqualTo: campaignId)
        .where('status', isEqualTo: 'raw')
        .orderBy('createdAt')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final leadDoc = query.docs.first;

    // 2. Immediately lock it with a simple update (no transaction).
    await leadDoc.reference.update({
      'status': 'locked',
      'assignedTo': callerId,
      'lockedAt': FieldValue.serverTimestamp(),
    });

    // 3. Return the lead data with its document ID included.
    return {'id': leadDoc.id, ...leadDoc.data() as Map<String, dynamic>};
  }

  // Submit disposition after call
  static Future<void> submitDisposition(
      String tenantId,
      String leadId,
      Map<String, dynamic> data) async {
    return FirestoreService.leadsCol(tenantId)
        .doc(leadId)
        .update({
          ...data,
          'status': 'disposed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Get leads for audit (manager)
  static Stream<QuerySnapshot> getLeadsForAudit(
      String tenantId, String campaignId) {
    return FirestoreService.leadsCol(tenantId)
        .where('campaignId', isEqualTo: campaignId)
        .where('status', isEqualTo: 'disposed')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots();
  }

  // Search leads by phone
  static Future<QuerySnapshot> searchLeadByPhone(
      String tenantId, String phone) async {
    return FirestoreService.leadsCol(tenantId)
        .where('phone', isEqualTo: phone)
        .get();
  }

  // Batch insert leads from CSV
  static Future<void> batchInsertLeads(
      String tenantId,
      String campaignId,
      List<Map<String, dynamic>> leads) async {
    final db = FirebaseFirestore.instance;
    final batches = <WriteBatch>[];
    var batch = db.batch();
    int count = 0;

    for (final lead in leads) {
      final ref = FirestoreService.leadsCol(tenantId).doc();
      batch.set(ref, {
        ...lead,
        'campaignId': campaignId,
        'tenantId': tenantId,
        'status': 'raw',
        'source': 'csv',
        'attempts': 0,
        'retryCount': 0,
        'formData': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;

      // Firestore batch limit is 500
      if (count == 500) {
        batches.add(batch);
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) batches.add(batch);
    for (final b in batches) await b.commit();
  }

  // Release lock if caller goes idle
  static Future<void> releaseLead(
      String tenantId, String leadId) async {
    return FirestoreService.leadsCol(tenantId)
        .doc(leadId)
        .update({
          'status': 'raw',
          'assignedTo': '',
          'lockedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
