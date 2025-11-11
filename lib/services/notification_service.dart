import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/NotificationModel.dart';
import '../constants/currencies.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a notification
  Future<String> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? groupId,
    String? expenseId,
    String? settlementId,
    String? actionBy,
  }) async {
    try {
      final notificationRef = await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'groupId': groupId,
        'expenseId': expenseId,
        'settlementId': settlementId,
        'actionBy': actionBy,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print(
        'NotificationService: Notification created with ID: ${notificationRef.id}',
      );
      return notificationRef.id;
    } catch (e) {
      print('NotificationService: Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  // Create notifications for multiple users (bulk)
  Future<void> createBulkNotifications({
    required List<String> userIds,
    required String type,
    required String title,
    required String message,
    String? groupId,
    String? expenseId,
    String? settlementId,
    String? actionBy,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in userIds) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userId,
          'type': type,
          'title': title,
          'message': message,
          'groupId': groupId,
          'expenseId': expenseId,
          'settlementId': settlementId,
          'actionBy': actionBy,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('NotificationService: Created ${userIds.length} notifications');
    } catch (e) {
      print('NotificationService: Error creating bulk notifications: $e');
      throw Exception('Failed to create bulk notifications: $e');
    }
  }

  // Get user's notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) {
                  try {
                    return NotificationModel.fromJson(doc.data(), doc.id);
                  } catch (e) {
                    print(
                      'NotificationService: Error parsing notification: $e',
                    );
                    return null;
                  }
                })
                .whereType<NotificationModel>()
                .toList();

            // Sort by createdAt in memory (descending - newest first)
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return notifications;
          });
    } catch (e) {
      print('NotificationService: Error creating notifications stream: $e');
      // Return a stream that emits an empty list instead of throwing
      return Stream.value([]);
    }
  }

  // Get unread notifications count
  Stream<int> getUnreadNotificationsCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('NotificationService: Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      print('NotificationService: Marked all notifications as read');
    } catch (e) {
      print('NotificationService: Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('NotificationService: Error deleting notification: $e');
    }
  }

  // Delete all read notifications
  Future<void> deleteReadNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('NotificationService: Deleted read notifications');
    } catch (e) {
      print('NotificationService: Error deleting read notifications: $e');
    }
  }

  // Helper method to create expense notification for group members
  Future<void> notifyExpenseAdded({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String expenseDescription,
    required double amount,
    required String currency,
    required List<String> splitBetween,
    required String paidBy,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get payer's name
      final payerDoc = await _firestore.collection('users').doc(paidBy).get();
      final payerName = payerDoc.data()?['name'] ?? 'Someone';

      // Notify all members who are in splitBetween (except the payer)
      final membersToNotify = splitBetween.where((id) => id != paidBy).toList();

      if (membersToNotify.isEmpty) return;

      final formattedAmount = AppConstants.formatAmount(amount, currency);

      await createBulkNotifications(
        userIds: membersToNotify,
        type: 'expense_added',
        title: 'New Expense in $groupName',
        message: '$payerName added "$expenseDescription" - $formattedAmount',
        groupId: groupId,
        expenseId: expenseId,
        actionBy: paidBy,
      );
    } catch (e) {
      print('NotificationService: Error notifying expense added: $e');
    }
  }

  // Helper method to create settlement notification
  Future<void> notifySettlementReceived({
    required String groupId,
    required String groupName,
    required String settlementId,
    required double amount,
    required String currency,
    required String paidBy,
    required String paidTo,
  }) async {
    try {
      // Get payer's name
      final payerDoc = await _firestore.collection('users').doc(paidBy).get();
      final payerName = payerDoc.data()?['name'] ?? 'Someone';

      final formattedAmount = AppConstants.formatAmount(amount, currency);

      // Notify the person who received the payment
      await createNotification(
        userId: paidTo,
        type: 'settlement_received',
        title: 'Payment Received',
        message: '$payerName settled $formattedAmount in $groupName',
        groupId: groupId,
        settlementId: settlementId,
        actionBy: paidBy,
      );
    } catch (e) {
      print('NotificationService: Error notifying settlement: $e');
    }
  }

  // Helper method to notify when added to a group
  Future<void> notifyMemberAdded({
    required String userId,
    required String groupId,
    required String groupName,
    required String addedBy,
  }) async {
    try {
      final adderDoc = await _firestore.collection('users').doc(addedBy).get();
      final adderName = adderDoc.data()?['name'] ?? 'Someone';

      await createNotification(
        userId: userId,
        type: 'member_added',
        title: 'Added to Group',
        message: '$adderName added you to "$groupName"',
        groupId: groupId,
        actionBy: addedBy,
      );
    } catch (e) {
      print('NotificationService: Error notifying member added: $e');
    }
  }
}
