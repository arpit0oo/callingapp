import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LeadService {

  // ── Get next available lead ────────────────────────────────────────────────
  //
  // NOTE: No transaction — a small race condition is accepted here.
  // Migrate to a Cloud Function for atomic array-pop before production.

  static Future<Map<String, dynamic>?> getNextLead(
      String tenantId,
      String campaignId,
      String callerId,
      {String role = 'cold_caller'}) async {

    // ── Warm-caller path: pull from warm_numbers buckets ──────────────────
    if (role == 'warm_caller') {
      // Try callback bucket first, fall back to retry bucket.
      for (final bucket in ['callback', 'retry']) {
        final bucketRef =
            FirestoreService.warmNumbersDoc(tenantId, campaignId, bucket);
        final snap = await bucketRef.get();
        final numbers =
            ((snap.data() as Map<String, dynamic>?)?['numbers'] as List<dynamic>?)
                ?.cast<String>() ??
                [];

        if (numbers.isEmpty) continue;

        final phone = numbers.last;

        // Pop the number from the bucket atomically.
        await bucketRef.update({
          'numbers': FieldValue.arrayRemove([phone]),
        });

        // Fetch or create the lead doc (phone is the document ID).
        final leadRef =
            FirestoreService.leadsCol(tenantId, campaignId).doc(phone);
        final leadSnap = await leadRef.get();

        Map<String, dynamic> leadData;
        if (leadSnap.exists) {
          leadData = leadSnap.data() as Map<String, dynamic>;
        } else {
          leadData = {
            'phone': phone,
            'campaignId': campaignId,
            'status': 'locked',
            'assignedTo': callerId,
            'lockedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          };
          await leadRef.set(leadData);
        }

        // Decrement queue counter on the campaign stats document.
        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('campaigns')
            .doc(campaignId)
            .collection('stats')
            .doc('summary')
            .set({'queueRemaining': FieldValue.increment(-1)},
                SetOptions(merge: true));

        return {'id': phone, ...leadData};
      }

      return null; // Both buckets empty.
    }

    // ── Cold-caller path: pull from raw_numbers/unfiltered ────────────────
    final rawRef =
        FirestoreService.rawNumbersDoc(tenantId, campaignId, 'unfiltered');
    final rawSnap = await rawRef.get();
    final numbers =
        ((rawSnap.data() as Map<String, dynamic>?)?['numbers'] as List<dynamic>?)
            ?.cast<String>() ??
            [];

    if (numbers.isEmpty) return null;

    final phone = numbers.last;

    // Pop the number from the bucket atomically.
    await rawRef.update({
      'numbers': FieldValue.arrayRemove([phone]),
    });

    // Create / update the lead doc under the campaign.
    final leadRef =
        FirestoreService.leadsCol(tenantId, campaignId).doc(phone);
    await leadRef.set({
      'phone': phone,
      'campaignId': campaignId,
      'status': 'locked',
      'assignedTo': callerId,
      'lockedAt': FieldValue.serverTimestamp(),
      'attempts': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Decrement queue counter on the campaign stats document.
    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('campaigns')
        .doc(campaignId)
        .collection('stats')
        .doc('summary')
        .set({'queueRemaining': FieldValue.increment(-1)},
            SetOptions(merge: true));

    return {'id': phone, 'phone': phone};
  }

  // ── Submit disposition after call ─────────────────────────────────────────
  //
  // Routing Table for Dispositions:
  // - 'convert', 'close', 'info': No queue routing. Marks lead status.
  // - 'callback': Pushes phone to warm_numbers/callback bucket for warm follow-up.
  // - 'retry': Pushes phone to warm_numbers/retry bucket for warm follow-up.
  // - 'dnc': Suppresses the phone number globally (adds to suppression_list).
  //
  // Regardless of dispositionType, the lead document is updated with status = dispositionType.

  static Future<void> submitDisposition(
      String tenantId,
      String campaignId,
      String phone,
      Map<String, dynamic> data,
      String dispositionType,
      Map<String, dynamic> extraData) async {
    final db = FirebaseFirestore.instance;

    // Always update/create lead document in campaign.
    await FirestoreService.leadsCol(tenantId, campaignId).doc(phone).set({
      ...data,
      'status': dispositionType,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (dispositionType == 'callback') {
      // ── Queue for warm caller follow-up ──────────────────────────────────
      await FirestoreService.warmNumbersDoc(tenantId, campaignId, 'callback')
          .set({'numbers': FieldValue.arrayUnion([phone])},
              SetOptions(merge: true));

    } else if (dispositionType == 'retry') {
      // ── Queue for warm caller retry follow-up ─────────────────────────────
      await FirestoreService.warmNumbersDoc(tenantId, campaignId, 'retry')
          .set({'numbers': FieldValue.arrayUnion([phone])},
              SetOptions(merge: true));

    } else if (dispositionType == 'dnc') {
      // ── Blacklist number permanently ──────────────────────────────────────
      await FirestoreService.suppressionCol(tenantId).doc(phone).set({
        'addedBy': extraData['addedBy'] ?? '',
        'reason': 'DNC',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    // 'convert', 'close', 'info' → dispose only, no extra action.
  }

  // ── Release lead lock (caller goes idle) ──────────────────────────────────

  static Future<void> releaseLead(
      String tenantId, String campaignId, String phone) async {
    // Put the number back into the unfiltered bucket.
    await FirestoreService.rawNumbersDoc(tenantId, campaignId, 'unfiltered')
        .set({'numbers': FieldValue.arrayUnion([phone])},
            SetOptions(merge: true));

    // Reset lead doc status.
    await FirestoreService.leadsCol(tenantId, campaignId).doc(phone).update({
      'status': 'raw',
      'assignedTo': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Batch insert phone numbers ────────────────────────────────────────────
  //
  // Appends all phones to the unfiltered bucket in a single write.
  // Individual lead documents are NOT pre-created; they are created lazily
  // when a number is popped from the queue.

  static Future<void> batchInsertLeads(
      String tenantId,
      String campaignId,
      List<String> phones) async {
    if (phones.isEmpty) return;
    await FirestoreService.rawNumbersDoc(tenantId, campaignId, 'unfiltered')
        .set({'numbers': FieldValue.arrayUnion(phones)},
            SetOptions(merge: true));
  }

  // ── Audit query ───────────────────────────────────────────────────────────

  static Stream<QuerySnapshot> getLeadsForAudit(
      String tenantId, String campaignId) {
    return FirestoreService.leadsCol(tenantId, campaignId)
        .where('status', isEqualTo: 'disposed')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots();
  }

  // ── Search by phone ───────────────────────────────────────────────────────

  static Future<DocumentSnapshot> searchLeadByPhone(
      String tenantId, String campaignId, String phone) {
    return FirestoreService.leadsCol(tenantId, campaignId).doc(phone).get();
  }
}
