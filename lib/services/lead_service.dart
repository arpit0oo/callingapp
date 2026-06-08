import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeadService {

  // Get next available lead for caller — uses transaction for atomic locking
  static Future<Map<String, dynamic>?> getNextLead(
      String tenantId, String campaignId, String callerId) async {
    final db = FirebaseFirestore.instance;
    Map<String, dynamic>? assignedLead;

    await db.runTransaction((transaction) async {
      // Find first pending lead
      final query = await FirestoreService.leadsCol(tenantId)
          .where('campaignId', isEqualTo: campaignId)
          .where('status', isEqualTo: 'raw')
          .orderBy('createdAt')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final leadDoc = query.docs.first;
      final leadRef = leadDoc.reference;

      // Check it's still raw inside transaction
      final freshLead = await transaction.get(leadRef);
      if (freshLead.data()?['status'] != 'raw') return;

      // Lock it
      transaction.update(leadRef, {
        'status': 'locked',
        'assignedTo': callerId,
        'lockedAt': FieldValue.serverTimestamp(),
      });

      assignedLead = {'id': leadDoc.id, ...leadDoc.data() as Map<String, dynamic>};
    });

    return assignedLead;
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
