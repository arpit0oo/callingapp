import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class UserService {

  // Get all users for tenant
  static Stream<QuerySnapshot> getUsers(String tenantId) {
    return FirestoreService.usersCol(tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get single user
  static Future<DocumentSnapshot> getUser(
      String tenantId, String userId) async {
    return FirestoreService.usersCol(tenantId).doc(userId).get();
  }

  // Get users by role
  static Stream<QuerySnapshot> getUsersByRole(
      String tenantId, String role) {
    return FirestoreService.usersCol(tenantId)
        .where('role', isEqualTo: role)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  // Create user doc in Firestore (after Firebase Auth creates the account)
  static Future<void> createUser(
      String tenantId, String userId, Map<String, dynamic> data) async {
    return FirestoreService.usersCol(tenantId).doc(userId).set({
      ...data,
      'tenantId': tenantId,
      'status': 'active',
      'assignedCampaigns': [],
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Update user
  static Future<void> updateUser(
      String tenantId, String userId, Map<String, dynamic> data) async {
    return FirestoreService.usersCol(tenantId)
        .doc(userId)
        .update(data);
  }

  // Assign user to campaign
  static Future<void> assignCampaign(
      String tenantId, String userId, String campaignId) async {
    return FirestoreService.usersCol(tenantId)
        .doc(userId)
        .update({
          'assignedCampaigns': FieldValue.arrayUnion([campaignId]),
        });
  }

  // Remove user from campaign
  static Future<void> removeCampaign(
      String tenantId, String userId, String campaignId) async {
    return FirestoreService.usersCol(tenantId)
        .doc(userId)
        .update({
          'assignedCampaigns': FieldValue.arrayRemove([campaignId]),
        });
  }

  // Update last active timestamp
  static Future<void> updateLastActive(
      String tenantId, String userId) async {
    return FirestoreService.usersCol(tenantId)
        .doc(userId)
        .update({'lastActive': FieldValue.serverTimestamp()});
  }
}
