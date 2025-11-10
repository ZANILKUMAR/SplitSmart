import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/SettlementModel.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new settlement
  Future<String> createSettlement({
    required String groupId,
    required String paidBy,
    required String paidTo,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    try {
      print('SettlementService: Creating settlement...');
      
      final settlementRef = await _firestore.collection('settlements').add({
        'groupId': groupId,
        'paidBy': paidBy,
        'paidTo': paidTo,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('SettlementService: Settlement created with ID: ${settlementRef.id}');
      return settlementRef.id;
    } catch (e, stackTrace) {
      print('SettlementService: Error creating settlement: $e');
      print('SettlementService: Stack trace: $stackTrace');
      throw Exception('Failed to create settlement: $e');
    }
  }

  // Get all settlements for a group
  Stream<List<SettlementModel>> getGroupSettlements(String groupId) {
    try {
      return _firestore
          .collection('settlements')
          .where('groupId', isEqualTo: groupId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        print('SettlementService: Retrieved ${snapshot.docs.length} settlements');
        final settlements = snapshot.docs
            .map((doc) => SettlementModel.fromJson(doc.data(), doc.id))
            .toList();
        return settlements;
      });
    } catch (e) {
      print('SettlementService: Error getting group settlements: $e');
      return Stream.value([]);
    }
  }

  // Get settlements involving a specific user
  Stream<List<SettlementModel>> getUserSettlements(String userId) {
    try {
      return _firestore
          .collection('settlements')
          .where('paidBy', isEqualTo: userId)
          .snapshots()
          .asyncMap((paidBySnapshot) async {
        final paidToSnapshot = await _firestore
            .collection('settlements')
            .where('paidTo', isEqualTo: userId)
            .get();

        final allSettlements = <SettlementModel>[];
        
        for (var doc in paidBySnapshot.docs) {
          allSettlements.add(SettlementModel.fromJson(doc.data(), doc.id));
        }
        
        for (var doc in paidToSnapshot.docs) {
          if (!allSettlements.any((s) => s.id == doc.id)) {
            allSettlements.add(SettlementModel.fromJson(doc.data(), doc.id));
          }
        }

        allSettlements.sort((a, b) => b.date.compareTo(a.date));
        return allSettlements;
      });
    } catch (e) {
      print('SettlementService: Error getting user settlements: $e');
      return Stream.value([]);
    }
  }

  // Delete settlement
  Future<void> deleteSettlement(String settlementId) async {
    try {
      await _firestore.collection('settlements').doc(settlementId).delete();
      print('SettlementService: Settlement deleted: $settlementId');
    } catch (e) {
      throw Exception('Failed to delete settlement: $e');
    }
  }

  // Calculate net balances for a group (including settlements)
  Future<Map<String, double>> calculateNetBalances(
    String groupId,
    List<dynamic> expenses, // ExpenseModel list
    List<SettlementModel> settlements,
  ) async {
    final balances = <String, double>{};

    // Calculate balances from expenses
    for (var expense in expenses) {
      final shareAmount = expense.amount / expense.splitBetween.length;
      
      // Person who paid gets positive balance
      balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
      
      // Each person in splitBetween owes their share
      for (var personId in expense.splitBetween) {
        balances[personId] = (balances[personId] ?? 0) - shareAmount;
      }
    }

    // Apply settlements (reduce balances)
    for (var settlement in settlements) {
      // Person who paid reduces their debt (becomes less negative or more positive)
      balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
      
      // Person who received reduces what they're owed (becomes less positive or more negative)
      balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
    }

    return balances;
  }
}
