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
import '../expenses/add_expense_screen.dart';
import '../settlements/record_settlement_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
  });

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Load member details
      final membersData = await Future.wait(
        group.members.map((memberId) async {
          final doc = await _firestore.collection('users').doc(memberId).get();
          if (doc.exists) {
            return UserModel.fromJson(doc.data()!);
          }
          return null;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
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
              onPressed: () {
                // TODO: Navigate to edit group screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit feature coming soon')),
                );
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
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group,
                            size: 32,
                            color: Theme.of(context).primaryColor,
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
                                  color: Colors.grey[600],
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
                          color: Colors.grey[600],
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Creator',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      if (member.uid == currentUser?.uid && !isMemberCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Expenses Section
            const Text(
              'Expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Display Expenses
            StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getGroupExpenses(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading expenses',
                            style: TextStyle(fontSize: 16, color: Colors.red[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final expenses = snapshot.data ?? [];

                if (expenses.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No expenses yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add an expense to start tracking',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Calculate balances from expenses list
                final balances = <String, double>{};
                for (var expense in expenses) {
                  final shareAmount = expense.getShareAmount();
                  
                  // Person who paid gets positive balance
                  balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                  
                  // Each person in splitBetween owes their share
                  for (var personId in expense.splitBetween) {
                    balances[personId] = (balances[personId] ?? 0) - shareAmount;
                  }
                }
                
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                final myBalance = balances[currentUserId] ?? 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Summary Card
                    Card(
                      color: myBalance > 0
                          ? Colors.green[50]
                          : myBalance < 0
                              ? Colors.red[50]
                              : Colors.blue[50],
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
                                      : AppConstants.formatAmount(0, _group!.currency),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: myBalance > 0
                                    ? Colors.green[700]
                                    : myBalance < 0
                                        ? Colors.red[700]
                                        : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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
                      
                      final shareAmount = expense.getShareAmount();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.receipt,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(
                            expense.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Paid by ${payer.name}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              if (expense.category != null)
                                Text(
                                  expense.category!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppConstants.formatAmount(expense.amount, _group!.currency),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${AppConstants.formatAmount(shareAmount, _group!.currency)} per person',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
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
            ),

            const SizedBox(height: 24),

            // Settlements Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settlements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Calculate current balances
                    final expenses = await _expenseService.getGroupExpenses(widget.groupId).first;
                    final settlements = await _settlementService.getGroupSettlements(widget.groupId).first;
                    
                    final balances = <String, double>{};
                    for (var expense in expenses) {
                      final shareAmount = expense.getShareAmount();
                      balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                      for (var personId in expense.splitBetween) {
                        balances[personId] = (balances[personId] ?? 0) - shareAmount;
                      }
                    }

                    // Apply settlements
                    for (var settlement in settlements) {
                      balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
                      balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
                    }

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecordSettlementScreen(
                          group: _group!,
                          balances: balances,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadGroupDetails();
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
                          Icon(Icons.account_balance_wallet, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No settlements yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record payments to settle balances',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
                          child: const Icon(
                            Icons.payment,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          '${payer.name} paid ${receiver.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${settlement.date.day}/${settlement.date.month}/${settlement.date.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        trailing: Text(
                          AppConstants.formatAmount(settlement.amount, _group!.currency),
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
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteGroup();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: const Text('Leave Group', style: TextStyle(color: Colors.orange)),
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
              _buildDetailRow('Amount', AppConstants.formatAmount(expense.amount, _group!.currency)),
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
              _buildDetailRow(
                'Each person pays',
                AppConstants.formatAmount(expense.getShareAmount(), _group!.currency),
              ),
              const SizedBox(height: 16),
              const Text(
                'Split between:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...splitMembers.map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${member.name}'),
                  )),
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
                    builder: (context) => AddExpenseScreen(
                      group: _group!,
                      expense: expense,
                    ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
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

  void _showSettlementDetails(SettlementModel settlement, UserModel payer, UserModel receiver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settlement Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Amount', AppConstants.formatAmount(settlement.amount, _group!.currency)),
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
        content: const Text('Are you sure you want to delete this settlement record?'),
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
