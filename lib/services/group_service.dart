import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/GroupModel.dart';
import 'notification_service.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    String? imageUrl,
    String currency = 'USD',
    int? iconCodePoint,
    int? colorValue,
  }) async {
    try {
      print('GroupService: Creating group in Firestore...');
      print(
        'GroupService: Name=$name, CreatedBy=$createdBy, Currency=$currency',
      );
      print('GroupService: IconCodePoint=$iconCodePoint, ColorValue=$colorValue');

      // Create group document
      final groupRef = await _firestore.collection('groups').add({
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'members': [createdBy], // Creator is the first member
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'currency': currency,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
      });

      print('GroupService: Group created with ID: ${groupRef.id}');
      print('GroupService: Saved iconCodePoint=$iconCodePoint, colorValue=$colorValue');
      return groupRef.id;
    } catch (e, stackTrace) {
      print('GroupService: Error creating group: $e');
      print('GroupService: Stack trace: $stackTrace');

      // Provide more specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception(
          'Permission denied. Please check Firestore security rules.',
        );
      } else if (e.toString().contains('network')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      }

      throw Exception('Failed to create group: $e');
    }
  }

  // Get all groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          print(
            'GroupService: Retrieved ${snapshot.docs.length} groups for user $userId',
          );
          final groups = snapshot.docs
              .map((doc) {
                try {
                  return GroupModel.fromJson(doc.data(), doc.id);
                } catch (e) {
                  print('GroupService: Error parsing group ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<GroupModel>()
              .toList();

          // Sort by createdAt in memory (to avoid index issues)
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        })
        .handleError((error) {
          print('GroupService: Stream error for user $userId: $error');
        });
  }

  // Get a single group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('GroupService: Error getting group $groupId: $e');
      return null; // Return null instead of throwing to allow graceful handling
    }
  }

  // Update group details
  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? imageUrl,
    String? currency,
    bool? simplifyDebts,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (currency != null) updates['currency'] = currency;
      if (simplifyDebts != null) updates['simplifyDebts'] = simplifyDebts;

      await _firestore.collection('groups').doc(groupId).update(updates);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  // Add member to group
  Future<void> addMember(
    String groupId,
    String userId, {
    String? addedBy,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
      });

      // Send notification to the added member
      if (addedBy != null) {
        try {
          final groupDoc = await _firestore
              .collection('groups')
              .doc(groupId)
              .get();
          final groupName = groupDoc.data()?['name'] ?? 'Unknown Group';

          await _notificationService.notifyMemberAdded(
            userId: userId,
            groupId: groupId,
            groupName: groupName,
            addedBy: addedBy,
          );
        } catch (e) {
          print('GroupService: Error sending notification: $e');
          // Don't throw error for notification failure
        }
      }
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  // Remove member from group
  Future<void> removeMember(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  // Delete group and all related data (expenses, settlements, notifications)
  Future<void> deleteGroup(String groupId) async {
    try {
      print('GroupService: Deleting group and related data: $groupId');

      // Delete all expenses for this group
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .get();

      final expenseBatch = _firestore.batch();
      for (var doc in expensesSnapshot.docs) {
        expenseBatch.delete(doc.reference);
      }
      await expenseBatch.commit();
      print('GroupService: Deleted ${expensesSnapshot.docs.length} expenses');

      // Delete all settlements for this group
      final settlementsSnapshot = await _firestore
          .collection('settlements')
          .where('groupId', isEqualTo: groupId)
          .get();

      final settlementBatch = _firestore.batch();
      for (var doc in settlementsSnapshot.docs) {
        settlementBatch.delete(doc.reference);
      }
      await settlementBatch.commit();
      print(
        'GroupService: Deleted ${settlementsSnapshot.docs.length} settlements',
      );

      // Delete all notifications for this group
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('groupId', isEqualTo: groupId)
          .get();

      final notificationBatch = _firestore.batch();
      for (var doc in notificationsSnapshot.docs) {
        notificationBatch.delete(doc.reference);
      }
      await notificationBatch.commit();
      print(
        'GroupService: Deleted ${notificationsSnapshot.docs.length} notifications',
      );

      // Finally, delete the group itself
      await _firestore.collection('groups').doc(groupId).delete();
      print('GroupService: Group deleted successfully');
    } catch (e) {
      print('GroupService: Error deleting group: $e');
      throw Exception('Failed to delete group: $e');
    }
  }
}
