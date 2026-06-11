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

  // Read the current state snapshot for a single caller
  static Future<DataSnapshot> getCallerState(
      String tenantId, String userId) async {
    return _db.ref('caller_state/$tenantId/$userId').get();
  }
}
