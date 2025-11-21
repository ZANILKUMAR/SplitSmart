import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../models/ExpenseModel.dart';
import '../../models/SettlementModel.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../../constants/currencies.dart';
import 'add_members_screen.dart';
import 'edit_group_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../settlements/record_settlement_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  final _firestore = FirebaseFirestore.instance;

  GroupModel? _group;
  List<UserModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    try {
      final group = await _groupService.getGroup(widget.groupId);

      if (group == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Group not found')));
          Navigator.pop(context);
        }
        return;
      }

      // Load member details
      final membersData = await Future.wait(
        group.members.map((memberId) async {
          try {
            final doc = await _firestore
                .collection('users')
                .doc(memberId)
                .get();
            if (doc.exists) {
              return UserModel.fromJson(doc.data()!);
            }
            return null;
          } catch (e) {
            print('Error loading member $memberId: $e');
            return null;
          }
        }),
      );

      setState(() {
        _group = group;
        _members = membersData.whereType<UserModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading group details: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBalanceBreakdown(Map<String, double> balances) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final shouldSimplify = _group?.simplifyDebts ?? false;

    // Separate creditors (positive balance) and debtors (negative balance)
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    balances.forEach((userId, balance) {
      if (balance > 0.01) {
        // creditor
        creditors[userId] = balance;
      } else if (balance < -0.01) {
        // debtor
        debtors[userId] = -balance; // store as positive
      }
    });

    if (creditors.isEmpty && debtors.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Card(
        color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.check_circle, 
                color: isDark ? Colors.green[400] : Colors.green[700],
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'All settled up! No outstanding balances.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate debts based on simplifyDebts setting
    final List<Map<String, dynamic>> settlements = [];

    if (shouldSimplify) {
      // Use greedy algorithm to simplify debts
      final debtorsCopy = Map<String, double>.from(debtors);
      final creditorsCopy = Map<String, double>.from(creditors);

      while (debtorsCopy.isNotEmpty && creditorsCopy.isNotEmpty) {
        // Get max debtor and max creditor
        var maxDebtorId = debtorsCopy.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        var maxCreditorId = creditorsCopy.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        var debtAmount = debtorsCopy[maxDebtorId]!;
        var creditAmount = creditorsCopy[maxCreditorId]!;

        // Settle the minimum of the two
        var settleAmount = debtAmount < creditAmount
            ? debtAmount
            : creditAmount;

        settlements.add({
          'from': maxDebtorId,
          'to': maxCreditorId,
          'amount': settleAmount,
        });

        // Update balances
        debtorsCopy[maxDebtorId] = debtAmount - settleAmount;
        creditorsCopy[maxCreditorId] = creditAmount - settleAmount;

        // Remove if settled
        if (debtorsCopy[maxDebtorId]! < 0.01) {
          debtorsCopy.remove(maxDebtorId);
        }
        if (creditorsCopy[maxCreditorId]! < 0.01) {
          creditorsCopy.remove(maxCreditorId);
        }
      }
    } else {
      // Show individual debts without simplification
      // Each debtor owes each creditor their proportional share
      debtors.forEach((debtorId, debtAmount) {
        creditors.forEach((creditorId, creditAmount) {
          // Calculate proportional amount this debtor owes to this creditor
          final totalDebt = debtors.values.fold<double>(
            0,
            (sum, val) => sum + val,
          );
          final proportionalAmount = (debtAmount / totalDebt) * creditAmount;

          if (proportionalAmount > 0.01) {
            settlements.add({
              'from': debtorId,
              'to': creditorId,
              'amount': proportionalAmount,
            });
          }
        });
      });
    }

    // Show balances related to current user first
    final myRelatedBalances = <Widget>[];
    final otherBalances = <Widget>[];

    for (var settlement in settlements) {
      final fromId = settlement['from'] as String;
      final toId = settlement['to'] as String;
      final amount = settlement['amount'] as double;

      final fromUser = _members.firstWhere(
        (m) => m.uid == fromId,
        orElse: () => UserModel(
          uid: fromId,
          email: 'Unknown',
          name: 'Unknown User',
          phoneNumber: '',
        ),
      );

      final toUser = _members.firstWhere(
        (m) => m.uid == toId,
        orElse: () => UserModel(
          uid: toId,
          email: 'Unknown',
          name: 'Unknown User',
          phoneNumber: '',
        ),
      );

      final isCurrentUserInvolved =
          fromId == currentUserId || toId == currentUserId;

      final balanceWidget = _buildBalanceItem(
        fromName: fromId == currentUserId ? 'You' : fromUser.name,
        toName: toId == currentUserId ? 'you' : toUser.name,
        amount: amount,
        isCurrentUser: isCurrentUserInvolved,
        isOwing: fromId == currentUserId,
      );

      if (isCurrentUserInvolved) {
        myRelatedBalances.add(balanceWidget);
      } else {
        otherBalances.add(balanceWidget);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Balance Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // My related balances
        if (myRelatedBalances.isNotEmpty) ...[
          ...myRelatedBalances,
          if (otherBalances.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]
                  : Colors.grey[300],
            ),
            const SizedBox(height: 8),
          ],
        ],

        // Other member balances
        ...otherBalances,
      ],
    );
  }

  Widget _buildBalanceItem({
    required String fromName,
    required String toName,
    required double amount,
    required bool isCurrentUser,
    required bool isOwing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isCurrentUser
          ? (isOwing 
              ? (isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50])
              : (isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50]))
          : (isDark ? Colors.grey[800] : Colors.grey[50]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // From avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: isCurrentUser && isOwing
                  ? Colors.red[200]
                  : Colors.blue[200],
              child: Text(
                fromName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser && isOwing
                      ? Colors.red[900]
                      : Colors.blue[900],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // From name
            Text(
              fromName,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),

            const SizedBox(width: 8),

            // Arrow
            Icon(
              Icons.arrow_forward,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),

            const SizedBox(width: 8),

            // To name
            Text(
              toName,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // Amount
            Text(
              AppConstants.formatAmount(amount, _group!.currency),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCurrentUser
                    ? (isOwing 
                        ? (isDark ? Colors.red[400] : Colors.red[700])
                        : (isDark ? Colors.green[400] : Colors.green[700]))
                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: Text('Group not found')),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == _group!.createdBy;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group!.name),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditGroupScreen(group: _group!),
                  ),
                );

                // If group was updated, reload details
                if (result == true) {
                  _loadGroupDetails();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGroupMenu(context, isCreator),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroupDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Group Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(
                              _group!.colorValue ?? Colors.blue.value,
                            ).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(
                                _group!.colorValue ?? Colors.blue.value,
                              ),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _group!.iconCodePoint != null
                                ? IconData(_group!.iconCodePoint!)
                                : Icons.group,
                            size: 32,
                            color: Color(
                              _group!.colorValue ?? Colors.blue.value,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _group!.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_members.length} ${_members.length == 1 ? 'member' : 'members'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_group!.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _group!.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Members Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Members',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMembersScreen(group: _group!),
                      ),
                    );
                    // Reload group details after adding members
                    _loadGroupDetails();
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 36),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Members List
            ..._members.map((member) {
              final isMemberCreator = member.uid == _group!.createdBy;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.2),
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(member.name)),
                      if (isMemberCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Creator',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      if (member.uid == currentUser?.uid && !isMemberCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    member.email,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Expenses Section
            const Text(
              'Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Display Expenses with Balance (including settlements)
            StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getGroupExpenses(widget.groupId),
              builder: (context, expenseSnapshot) {
                return StreamBuilder<List<SettlementModel>>(
                  stream: _settlementService.getGroupSettlements(
                    widget.groupId,
                  ),
                  builder: (context, settlementSnapshot) {
                    if (expenseSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        settlementSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    if (expenseSnapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error,
                                size: 48,
                                color: Colors.red[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading expenses',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expenseSnapshot.error.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final expenses = expenseSnapshot.data ?? [];
                    final settlements = settlementSnapshot.data ?? [];

                    if (expenses.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No expenses yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add an expense to start tracking',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Calculate balances from expenses list
                    final balances = <String, double>{};
                    for (var expense in expenses) {
                      // Person who paid gets positive balance
                      balances[expense.paidBy] =
                          (balances[expense.paidBy] ?? 0) + expense.amount;

                      // Each person in splitBetween owes their share
                      for (var personId in expense.splitBetween) {
                        final shareAmount = expense.getShareForUser(personId);
                        balances[personId] =
                            (balances[personId] ?? 0) - shareAmount;
                      }
                    }

                    // Apply settlements to reduce balances
                    for (var settlement in settlements) {
                      balances[settlement.paidBy] =
                          (balances[settlement.paidBy] ?? 0) +
                          settlement.amount;
                      balances[settlement.paidTo] =
                          (balances[settlement.paidTo] ?? 0) -
                          settlement.amount;
                    }

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    final myBalance = balances[currentUserId] ?? 0.0;

                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance Summary Card
                        Card(
                          color: myBalance > 0
                              ? (isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50])
                              : myBalance < 0
                              ? (isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50])
                              : (isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50]),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Your Balance:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  myBalance > 0
                                      ? '+${AppConstants.formatAmount(myBalance, _group!.currency)}'
                                      : myBalance < 0
                                      ? '-${AppConstants.formatAmount(-myBalance, _group!.currency)}'
                                      : AppConstants.formatAmount(
                                          0,
                                          _group!.currency,
                                        ),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: myBalance > 0
                                        ? (isDark ? Colors.green[400] : Colors.green[700])
                                        : myBalance < 0
                                        ? (isDark ? Colors.red[400] : Colors.red[700])
                                        : (isDark ? Colors.blue[400] : Colors.blue[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Detailed Balance Breakdown - Who owes whom
                        _buildBalanceBreakdown(balances),

                        const SizedBox(height: 8),

                        Text(
                          '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Expenses List
                        ...expenses.map((expense) {
                          final payer = _members.firstWhere(
                            (m) => m.uid == expense.paidBy,
                            orElse: () => UserModel(
                              uid: expense.paidBy,
                              email: 'Unknown',
                              name: 'Unknown User',
                              phoneNumber: '',
                            ),
                          );

                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          final shareAmount = expense.getShareForUser(
                            currentUserId,
                          );

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.receipt,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              title: Text(
                                expense.description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${payer.name} paid ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                            height: 1.3,
                                          ),
                                        ),
                                        TextSpan(
                                          text: AppConstants.formatAmount(
                                            expense.amount,
                                            _group!.currency,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context).primaryColor,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      height: 1.3,
                                    ),
                                  ),
                                  if (expense.category != null)
                                    Builder(
                                      builder: (context) {
                                        final isDark = Theme.of(context).brightness == Brightness.dark;
                                        return Text(
                                          expense.category!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                                            height: 1.3,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    expense.paidBy == currentUserId
                                        ? 'You lent'
                                        : 'You borrowed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: expense.paidBy == currentUserId
                                          ? (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.green[400]
                                              : Colors.green[700])
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.red[400]
                                              : Colors.red[700]),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppConstants.formatAmount(
                                      shareAmount,
                                      _group!.currency,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showExpenseDetails(expense, payer);
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Settlements Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settlements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _group == null
                      ? null
                      : () async {
                          try {
                            // Calculate current balances
                            final expenses = await _expenseService
                                .getGroupExpenses(widget.groupId)
                                .first;
                            final settlements = await _settlementService
                                .getGroupSettlements(widget.groupId)
                                .first;

                            final balances = <String, double>{};
                            for (var expense in expenses) {
                              balances[expense.paidBy] =
                                  (balances[expense.paidBy] ?? 0) +
                                  expense.amount;
                              for (var personId in expense.splitBetween) {
                                final shareAmount = expense.getShareForUser(
                                  personId,
                                );
                                balances[personId] =
                                    (balances[personId] ?? 0) - shareAmount;
                              }
                            }

                            // Apply settlements
                            for (var settlement in settlements) {
                              balances[settlement.paidBy] =
                                  (balances[settlement.paidBy] ?? 0) +
                                  settlement.amount;
                              balances[settlement.paidTo] =
                                  (balances[settlement.paidTo] ?? 0) -
                                  settlement.amount;
                            }

                            if (!mounted) return;

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecordSettlementScreen(
                                  group: _group!,
                                  balances: balances,
                                ),
                              ),
                            );

                            if (result == true && mounted) {
                              _loadGroupDetails();
                            }
                          } catch (e) {
                            print('Error opening settle screen: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Settle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(110, 36),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            StreamBuilder<List<SettlementModel>>(
              stream: _settlementService.getGroupSettlements(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final settlements = snapshot.data ?? [];

                if (settlements.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No settlements yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record payments to settle balances',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: settlements.map((settlement) {
                    final payer = _members.firstWhere(
                      (m) => m.uid == settlement.paidBy,
                      orElse: () => UserModel(
                        uid: settlement.paidBy,
                        email: 'Unknown',
                        name: 'Unknown User',
                        phoneNumber: '',
                      ),
                    );
                    final receiver = _members.firstWhere(
                      (m) => m.uid == settlement.paidTo,
                      orElse: () => UserModel(
                        uid: settlement.paidTo,
                        email: 'Unknown',
                        name: 'Unknown User',
                        phoneNumber: '',
                      ),
                    );

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: const Icon(Icons.payment, color: Colors.green),
                        ),
                        title: Text(
                          '${payer.name} paid ${receiver.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${settlement.date.day}/${settlement.date.month}/${settlement.date.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                        ),
                        trailing: Text(
                          AppConstants.formatAmount(
                            settlement.amount,
                            _group!.currency,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        onTap: () {
                          _showSettlementDetails(settlement, payer, receiver);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(group: _group!),
            ),
          );

          if (result == true) {
            // Reload group details after adding expense
            _loadGroupDetails();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _showGroupMenu(BuildContext context, bool isCreator) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCreator)
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Group Settings'),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupSettings();
                },
              ),
            if (isCreator)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Group',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteGroup();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: const Text(
                  'Leave Group',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveGroup();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showGroupSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Group Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Simplify Group Debts'),
                subtitle: const Text(
                  'Automatically combine debts to reduce the total number of repayments between group members',
                ),
                value: _group?.simplifyDebts ?? false,
                onChanged: (value) async {
                  try {
                    await _groupService.updateGroup(
                      widget.groupId,
                      simplifyDebts: value,
                    );

                    // Update both dialog state and parent state
                    setDialogState(() {
                      _group = _group?.copyWith(simplifyDebts: value);
                    });
                    
                    setState(() {
                      _group = _group?.copyWith(simplifyDebts: value);
                    });

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Debt simplification enabled - balances recalculated'
                              : 'Debt simplification disabled - showing individual debts',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _groupService.deleteGroup(widget.groupId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmLeaveGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _groupService.removeMember(widget.groupId, currentUser.uid);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to leave group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showExpenseDetails(ExpenseModel expense, UserModel payer) {
    final splitMembers = _members
        .where((m) => expense.splitBetween.contains(m.uid))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense.description),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Amount',
                AppConstants.formatAmount(expense.amount, _group!.currency),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Paid by', payer.name),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Date',
                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
              ),
              if (expense.category != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Category', expense.category!),
              ],
              const SizedBox(height: 8),
              if (expense.splitType == SplitType.equal)
                _buildDetailRow(
                  'Each person pays',
                  AppConstants.formatAmount(
                    expense.getShareAmount(),
                    _group!.currency,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                expense.splitType == SplitType.equal
                    ? 'Split equally between:'
                    : expense.splitType == SplitType.unequal
                    ? 'Split unequally:'
                    : 'Split by percentage:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...splitMembers.map((member) {
                if (expense.splitType == SplitType.equal) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${member.name}'),
                  );
                } else {
                  final shareAmount = expense.getShareForUser(member.uid);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${member.name}: ${AppConstants.formatAmount(shareAmount, _group!.currency)}${expense.splitType == SplitType.percentage ? " (${expense.customSplits?[member.uid]?.toStringAsFixed(1) ?? 0}%)" : ""}',
                    ),
                  );
                }
              }),
              if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(expense.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (expense.paidBy == FirebaseAuth.instance.currentUser?.uid) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddExpenseScreen(group: _group!, expense: expense),
                  ),
                );
                if (result == true) {
                  _loadGroupDetails();
                }
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteExpense(expense.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _expenseService.deleteExpense(expenseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSettlementDetails(
    SettlementModel settlement,
    UserModel payer,
    UserModel receiver,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settlement Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Amount',
                AppConstants.formatAmount(settlement.amount, _group!.currency),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Paid by', payer.name),
              const SizedBox(height: 8),
              _buildDetailRow('Paid to', receiver.name),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Date',
                '${settlement.date.day}/${settlement.date.month}/${settlement.date.year}',
              ),
              if (settlement.notes != null && settlement.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(settlement.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (settlement.paidBy == FirebaseAuth.instance.currentUser?.uid ||
              settlement.paidTo == FirebaseAuth.instance.currentUser?.uid) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteSettlement(settlement.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSettlement(String settlementId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Settlement'),
        content: const Text(
          'Are you sure you want to delete this settlement record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _settlementService.deleteSettlement(settlementId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settlement deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete settlement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
