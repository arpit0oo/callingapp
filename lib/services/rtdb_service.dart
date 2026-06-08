import 'package:firebase_database/firebase_database.dart';

class RtdbService {
  static final _db = FirebaseDatabase.instance;

  // Update caller state
  static Future<void> updateCallerState(
      String tenantId, String userId, Map<String, dynamic> state) async {
    return _db.ref('caller_state/$tenantId/$userId').update(state);
  }

  // Watch all callers in tenant (for manager dashboard)
  static Stream<DatabaseEvent> watchCallers(String tenantId) {
    return _db.ref('caller_state/$tenantId').onValue;
  }

  // Update queue counts
  static Future<void> updateQueueCounts(
      String tenantId,
      String campaignId,
      int rawDelta,
      int warmDelta) async {
    final ref = _db.ref('queue_counts/$tenantId/$campaignId');
    await ref.runTransaction((data) {
      if (data == null) {
        return Transaction.success({
          'rawPending': rawDelta,
          'warmPending': warmDelta,
        });
      }
      final map = Map<String, dynamic>.from(data as Map);
      map['rawPending'] = (map['rawPending'] ?? 0) + rawDelta;
      map['warmPending'] = (map['warmPending'] ?? 0) + warmDelta;
      return Transaction.success(map);
    });
  }

  // Watch queue counts (for dashboards)
  static Stream<DatabaseEvent> watchQueueCounts(
      String tenantId, String campaignId) {
    return _db.ref('queue_counts/$tenantId/$campaignId').onValue;
  }
}
