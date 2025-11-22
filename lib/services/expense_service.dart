import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ExpenseModel.dart';
import 'notification_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new expense
  Future<String> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> splitBetween,
    required DateTime date,
    String? category,
    String? notes,
    SplitType splitType = SplitType.equal,
    Map<String, double>? customSplits,
  }) async {
    try {
      print('ExpenseService: Creating expense...');

      final expenseRef = await _firestore.collection('expenses').add({
        'groupId': groupId,
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitBetween': splitBetween,
        'date': Timestamp.fromDate(date),
        'category': category,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'splitType': splitType.toString().split('.').last,
        'customSplits': customSplits,
      });

      print('ExpenseService: Expense created with ID: ${expenseRef.id}');

      // Get group name and send notifications
      try {
        final groupDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .get();
        final groupName = groupDoc.data()?['name'] ?? 'Unknown Group';
        final currency = groupDoc.data()?['currency'] ?? 'USD';

        // Send notifications to members
        await _notificationService.notifyExpenseAdded(
          groupId: groupId,
          groupName: groupName,
          expenseId: expenseRef.id,
          expenseDescription: description,
          amount: amount,
          currency: currency,
          splitBetween: splitBetween,
          paidBy: paidBy,
        );
      } catch (e) {
        print('ExpenseService: Error sending notifications: $e');
        // Don't throw error for notification failure
      }

      return expenseRef.id;
    } catch (e, stackTrace) {
      print('ExpenseService: Error creating expense: $e');
      print('ExpenseService: Stack trace: $stackTrace');
      throw Exception('Failed to create expense: $e');
    }
  }

  // Get all expenses for a group
  Stream<List<ExpenseModel>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          print(
            'ExpenseService: Retrieved ${snapshot.docs.length} expenses for group $groupId',
          );
          final expenses = snapshot.docs
              .map((doc) {
                try {
                  return ExpenseModel.fromJson(doc.data(), doc.id);
                } catch (e) {
                  print('ExpenseService: Error parsing expense ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<ExpenseModel>()
              .toList();

          // Sort by date (most recent first)
          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        })
        .handleError((error) {
          print('ExpenseService: Stream error for group $groupId: $error');
        });
  }

  // Get a single expense by ID
  Future<ExpenseModel?> getExpense(String expenseId) async {
    try {
      final doc = await _firestore.collection('expenses').doc(expenseId).get();
      if (doc.exists) {
        return ExpenseModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get expense: $e');
    }
  }

  // Update expense
  Future<void> updateExpense(
    String expenseId, {
    String? description,
    double? amount,
    String? paidBy,
    List<String>? splitBetween,
    DateTime? date,
    String? category,
    String? notes,
    SplitType? splitType,
    Map<String, double>? customSplits,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (description != null) updates['description'] = description;
      if (amount != null) updates['amount'] = amount;
      if (paidBy != null) updates['paidBy'] = paidBy;
      if (splitBetween != null) updates['splitBetween'] = splitBetween;
      if (date != null) updates['date'] = Timestamp.fromDate(date);
      if (category != null) updates['category'] = category;
      if (notes != null) updates['notes'] = notes;
      if (splitType != null) {
        updates['splitType'] = splitType.toString().split('.').last;
      }
      if (customSplits != null) updates['customSplits'] = customSplits;

      await _firestore.collection('expenses').doc(expenseId).update(updates);
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Delete expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Calculate balances for a group
  Future<Map<String, double>> calculateBalances(String groupId) async {
    try {
      final expenses = await _firestore
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .get();

      final balances = <String, double>{};

      for (var doc in expenses.docs) {
        final expense = ExpenseModel.fromJson(doc.data(), doc.id);

        // Person who paid gets positive balance
        balances[expense.paidBy] =
            (balances[expense.paidBy] ?? 0) + expense.amount;

        // Each person in splitBetween owes their share (use custom calculation)
        for (var personId in expense.splitBetween) {
          final shareAmount = expense.getShareForUser(personId);
          balances[personId] = (balances[personId] ?? 0) - shareAmount;
        }
      }

      return balances;
    } catch (e) {
      print('ExpenseService: Error calculating balances: $e');
      return {};
    }
  }

  // Get expenses by user (where user paid or is part of split)
  Stream<List<ExpenseModel>> getUserExpenses(String userId) {
    return _firestore
        .collection('expenses')
        .where('splitBetween', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          print(
            'ExpenseService: Retrieved ${snapshot.docs.length} expenses for user $userId',
          );
          final expenses = snapshot.docs
              .map((doc) => ExpenseModel.fromJson(doc.data(), doc.id))
              .toList();
          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        })
        .handleError((error) {
          print('ExpenseService: Stream error for user $userId: $error');
        });
  }
}
