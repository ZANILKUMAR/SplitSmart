import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ExpenseModel.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      });

      print('ExpenseService: Expense created with ID: ${expenseRef.id}');
      return expenseRef.id;
    } catch (e, stackTrace) {
      print('ExpenseService: Error creating expense: $e');
      print('ExpenseService: Stack trace: $stackTrace');
      throw Exception('Failed to create expense: $e');
    }
  }

  // Get all expenses for a group
  Stream<List<ExpenseModel>> getGroupExpenses(String groupId) {
    try {
      return _firestore
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .snapshots()
          .map((snapshot) {
        print('ExpenseService: Retrieved ${snapshot.docs.length} expenses');
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
      });
    } catch (e) {
      print('ExpenseService: Error getting group expenses: $e');
      return Stream.value([]);
    }
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
        final shareAmount = expense.getShareAmount();

        // Person who paid gets positive balance
        balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;

        // Each person in splitBetween owes their share
        for (var personId in expense.splitBetween) {
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
    try {
      return _firestore
          .collection('expenses')
          .where('splitBetween', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
        final expenses = snapshot.docs
            .map((doc) => ExpenseModel.fromJson(doc.data(), doc.id))
            .toList();
        expenses.sort((a, b) => b.date.compareTo(a.date));
        return expenses;
      });
    } catch (e) {
      print('ExpenseService: Error getting user expenses: $e');
      return Stream.value([]);
    }
  }
}
