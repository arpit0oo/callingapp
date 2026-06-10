import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeadService {

  // Get next available lead for caller.
  // NOTE: No transaction — db.runTransaction() is unreliable on Flutter Web.
  // A small race condition is accepted here; migrate to a Cloud Function
  // for atomic locking before production.
  static Future<Map<String, dynamic>?> getNextLead(
      String tenantId, String campaignId, String callerId,
      {String role = 'cold_caller'}) async {

    // ── Warm-caller path: pull from callbacks queue ──────────────────────
    if (role == 'warm_caller') {
      final db = FirebaseFirestore.instance;
      final now = Timestamp.now();

      // 1. Find the oldest pending callback whose scheduled time has passed.
      final cbQuery = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('callbacks')
          .where('status', isEqualTo: 'pending')
          .where('scheduledAt', isLessThanOrEqualTo: now)
          .orderBy('scheduledAt')
          .limit(1)
          .get();

      if (cbQuery.docs.isEmpty) return null;

      final cbDoc = cbQuery.docs.first;

      // 2. Lock the callback doc.
      await cbDoc.reference.update({
        'status': 'locked',
        'assignedTo': callerId,
        'lockedAt': FieldValue.serverTimestamp(),
      });

      // 3. Fetch the originating lead.
      final leadId = cbDoc.data()['leadId'] as String? ?? '';
      if (leadId.isEmpty) return null;

      final leadDoc = await FirestoreService.leadsCol(tenantId).doc(leadId).get();
      if (!leadDoc.exists) return null;

      // 4. Return lead data merged with the callback document ID.
      return {
        'id': leadDoc.id,
        'callbackId': cbDoc.id,
        ...leadDoc.data() as Map<String, dynamic>,
      };
    }

    // ── Cold-caller path: raw leads queue (unchanged) ─────────────────────
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
      Map<String, dynamic> data,
      String dispositionType,
      Map<String, dynamic> extraData) async {
    final db = FirebaseFirestore.instance;
    final leadRef = FirestoreService.leadsCol(tenantId).doc(leadId);

    if (dispositionType == 'retry') {
      // ── Retry: reset lead to raw with a future retryAfter timestamp ──────
      final minutes = (extraData['retryMinutes'] as num?)?.toInt() ?? 30;
      await leadRef.update({
        ...data,
        'status': 'raw',
        'assignedTo': '',
        'retryAfter': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: minutes))),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // For all other types: mark lead as disposed first.
    await leadRef.update({
      ...data,
      'status': 'disposed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (dispositionType == 'callback') {
      // ── Callback: schedule a new callback doc ─────────────────────────────
      await db
          .collection('tenants')
          .doc(tenantId)
          .collection('callbacks')
          .add({
        'leadId': leadId,
        'phone': extraData['phone'] ?? '',
        'campaignId': extraData['campaignId'] ?? '',
        'scheduledAt': extraData['scheduledAt'],
        'status': 'pending',
        'assignedTo': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (dispositionType == 'dnc') {
      // ── DNC: write to suppression list keyed by phone number ──────────────
      final phone = extraData['phone'] as String? ?? '';
      if (phone.isNotEmpty) {
        await db
            .collection('tenants')
            .doc(tenantId)
            .collection('suppression_list')
            .doc(phone)
            .set({
          'addedBy': extraData['addedBy'] ?? '',
          'reason': 'DNC',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
    // 'convert', 'close', 'info' → no extra action needed.
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
