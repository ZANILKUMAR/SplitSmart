import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/UserModel.dart';
import '../../models/GroupModel.dart';
import '../../models/ExpenseModel.dart';
import '../../models/SettlementModel.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../auth/login_screen.dart';
import '../groups/groups_screen.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../settlements/record_settlement_screen.dart';
import '../test/test_firebase_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartSplit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelect,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20),
                    SizedBox(width: 8),
                    Text('Test Firebase'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildGroupsTab(),
          _buildExpensesTab(),
          _buildSettleTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Settle',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Future<void> _handleMenuSelect(String value) async {
    switch (value) {
      case 'test':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TestFirebaseScreen(),
          ),
        );
        break;
      case 'profile':
        // TODO: Implement profile navigation
        break;
      case 'logout':
        await _handleLogout();
        break;
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout')),
        );
      }
    }
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 1: // Groups tab
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateGroupScreen(),
              ),
            );
          },
          child: const Icon(Icons.add),
        );
      case 2: // Expenses tab
        return FloatingActionButton.extended(
          onPressed: () => _showGroupSelectionDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        );
      default:
        return null;
    }
  }

  Future<void> _showGroupSelectionDialog() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    final groups = await _groupService.getUserGroups(currentUserId ?? '').first;

    if (!mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Create a group first to add expenses'),
          action: SnackBarAction(
            label: 'Create Group',
            onPressed: () {
              setState(() => _selectedIndex = 1); // Switch to Groups tab
            },
          ),
        ),
      );
      return;
    }

    final selectedGroup = await showDialog<GroupModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: groups.map((group) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.group,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(group.name),
                subtitle: Text('${group.members.length} members'),
                onTap: () => Navigator.pop(context, group),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedGroup != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(group: selectedGroup),
        ),
      );

      if (result == true) {
        // Expense added successfully
      }
    }
  }

  Widget _buildHomeTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.user.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Balance Summary
        StreamBuilder<List<ExpenseModel>>(
          stream: _expenseService.getUserExpenses(currentUserId ?? ''),
          builder: (context, expenseSnapshot) {
            if (!expenseSnapshot.hasData) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Your Balance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _SummaryItem(
                            title: 'You owe',
                            amount: '\$0.00',
                            color: Colors.red,
                          ),
                          _SummaryItem(
                            title: 'You are owed',
                            amount: '\$0.00',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            final expenses = expenseSnapshot.data ?? [];
            
            // Calculate user's total balance across all groups
            double youOwe = 0.0;
            double youAreOwed = 0.0;

            final Map<String, List<ExpenseModel>> expensesByGroup = {};
            for (var expense in expenses) {
              if (!expensesByGroup.containsKey(expense.groupId)) {
                expensesByGroup[expense.groupId] = [];
              }
              expensesByGroup[expense.groupId]!.add(expense);
            }

            for (var groupExpenses in expensesByGroup.values) {
              final balances = <String, double>{};
              for (var expense in groupExpenses) {
                final shareAmount = expense.getShareAmount();
                balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                for (var personId in expense.splitBetween) {
                  balances[personId] = (balances[personId] ?? 0) - shareAmount;
                }
              }
              
              final myBalance = balances[currentUserId] ?? 0.0;
              if (myBalance < 0) {
                youOwe += -myBalance;
              } else if (myBalance > 0) {
                youAreOwed += myBalance;
              }
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Your Balance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          title: 'You owe',
                          amount: '\$${youOwe.toStringAsFixed(2)}',
                          color: Colors.red,
                        ),
                        _SummaryItem(
                          title: 'You are owed',
                          amount: '\$${youAreOwed.toStringAsFixed(2)}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Total Balance: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          (youAreOwed - youOwe) >= 0
                              ? '+\$${(youAreOwed - youOwe).toStringAsFixed(2)}'
                              : '-\$${(youOwe - youAreOwed).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: (youAreOwed - youOwe) >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Groups Overview
        StreamBuilder<List<GroupModel>>(
          stream: _groupService.getUserGroups(currentUserId ?? ''),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final groups = groupSnapshot.data ?? [];
            
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Groups',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${groups.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      groups.isEmpty
                          ? 'Create your first group to start splitting expenses'
                          : 'Total members: ${groups.fold<int>(0, (sum, g) => sum + g.members.length)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Recent Activity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedIndex = 2); // Switch to Expenses tab
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        StreamBuilder<List<ExpenseModel>>(
          stream: _expenseService.getUserExpenses(currentUserId ?? ''),
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
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snapshot.error}'),
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
                        'Create a group and add expenses to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show only last 5 expenses
            final recentExpenses = expenses.take(5).toList();

            return Column(
              children: recentExpenses.map((expense) {
                return StreamBuilder<GroupModel?>(
                  stream: Stream.fromFuture(_groupService.getGroup(expense.groupId)),
                  builder: (context, groupSnapshot) {
                    final groupName = groupSnapshot.data?.name ?? 'Loading...';
                    
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
                            Text(
                              groupName,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            Text(
                              '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${expense.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              expense.paidBy == currentUserId ? 'You paid' : 'Split',
                              style: TextStyle(
                                fontSize: 11,
                                color: expense.paidBy == currentUserId
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailsScreen(
                                groupId: expense.groupId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    return const GroupsScreen();
  }

  Widget _buildExpensesTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<ExpenseModel>>(
      stream: _expenseService.getUserExpenses(currentUserId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading expenses',
                    style: TextStyle(fontSize: 18, color: Colors.red[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final expenses = snapshot.data ?? [];

        if (expenses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group and add expenses to get started',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _selectedIndex = 1); // Switch to Groups tab
                    },
                    icon: const Icon(Icons.group),
                    label: const Text('View Groups'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group expenses by month
        final Map<String, List<ExpenseModel>> expensesByMonth = {};
        for (var expense in expenses) {
          final monthKey = '${expense.date.month}/${expense.date.year}';
          if (!expensesByMonth.containsKey(monthKey)) {
            expensesByMonth[monthKey] = [];
          }
          expensesByMonth[monthKey]!.add(expense);
        }

        final sortedMonths = expensesByMonth.keys.toList()
          ..sort((a, b) {
            final aParts = a.split('/');
            final bParts = b.split('/');
            final aDate = DateTime(int.parse(aParts[1]), int.parse(aParts[0]));
            final bDate = DateTime(int.parse(bParts[1]), int.parse(bParts[0]));
            return bDate.compareTo(aDate);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedMonths.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              // Summary header
              final totalExpenses = expenses.length;
              final totalAmount = expenses.fold<double>(
                0,
                (sum, e) => sum + (e.paidBy == currentUserId ? e.amount : 0),
              );

              return Card(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'All Expenses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$totalExpenses',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                'Total Expenses',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 50,
                            width: 1,
                            color: Colors.grey[300],
                          ),
                          Column(
                            children: [
                              Text(
                                '\$${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                'You Paid',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            final monthKey = sortedMonths[index - 1];
            final monthExpenses = expensesByMonth[monthKey]!;
            final monthParts = monthKey.split('/');
            final monthNames = [
              '', 'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];
            final monthName = '${monthNames[int.parse(monthParts[0])]} ${monthParts[1]}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...monthExpenses.map((expense) {
                  return StreamBuilder<GroupModel?>(
                    stream: Stream.fromFuture(_groupService.getGroup(expense.groupId)),
                    builder: (context, groupSnapshot) {
                      final groupName = groupSnapshot.data?.name ?? 'Loading...';

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
                              Text(
                                groupName,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              Text(
                                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              if (expense.category != null)
                                Text(
                                  expense.category!,
                                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${expense.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                expense.paidBy == currentUserId
                                    ? 'You paid'
                                    : '\$${expense.getShareAmount().toStringAsFixed(2)} your share',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: expense.paidBy == currentUserId
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupDetailsScreen(
                                  groupId: expense.groupId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettleTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.getUserGroups(currentUserId ?? ''),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groupSnapshot.hasError) {
          return Center(
            child: Text('Error: ${groupSnapshot.error}'),
          );
        }

        final groups = groupSnapshot.data ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No settlements yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create groups and add expenses to see who owes whom',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Overall Summary
              return StreamBuilder<List<ExpenseModel>>(
                stream: _expenseService.getUserExpenses(currentUserId ?? ''),
                builder: (context, expenseSnapshot) {
                  if (!expenseSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final expenses = expenseSnapshot.data ?? [];
                  double youOwe = 0.0;
                  double youAreOwed = 0.0;

                  final Map<String, List<ExpenseModel>> expensesByGroup = {};
                  for (var expense in expenses) {
                    if (!expensesByGroup.containsKey(expense.groupId)) {
                      expensesByGroup[expense.groupId] = [];
                    }
                    expensesByGroup[expense.groupId]!.add(expense);
                  }

                  for (var groupExpenses in expensesByGroup.values) {
                    final balances = <String, double>{};
                    for (var expense in groupExpenses) {
                      final shareAmount = expense.getShareAmount();
                      balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                      for (var personId in expense.splitBetween) {
                        balances[personId] = (balances[personId] ?? 0) - shareAmount;
                      }
                    }

                    final myBalance = balances[currentUserId] ?? 0.0;
                    if (myBalance < 0) {
                      youOwe += -myBalance;
                    } else if (myBalance > 0) {
                      youAreOwed += myBalance;
                    }
                  }

                  return Card(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Overall Balance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '\$${youOwe.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'You owe',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 50,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '\$${youAreOwed.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'You are owed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            final group = groups[index - 1];

            return StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getGroupExpenses(group.id),
              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final expenses = expenseSnapshot.data ?? [];

                if (expenses.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Calculate balances
                final balances = <String, double>{};
                for (var expense in expenses) {
                  final shareAmount = expense.getShareAmount();
                  balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                  for (var personId in expense.splitBetween) {
                    balances[personId] = (balances[personId] ?? 0) - shareAmount;
                  }
                }

                final myBalance = balances[currentUserId] ?? 0.0;

                if (myBalance == 0) {
                  return const SizedBox.shrink(); // Skip if settled
                }

                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: myBalance < 0
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      child: Icon(
                        Icons.group,
                        color: myBalance < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      myBalance < 0
                          ? 'You owe \$${(-myBalance).toStringAsFixed(2)}'
                          : 'You are owed \$${myBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: myBalance < 0 ? Colors.red[700] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      myBalance < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: myBalance < 0 ? Colors.red : Colors.green,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Group Balances:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...group.members.map((memberId) {
                              final balance = balances[memberId] ?? 0.0;
                              if (balance == 0) return const SizedBox.shrink();

                              return FutureBuilder<UserModel?>(
                                future: () async {
                                  final doc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(memberId)
                                      .get();
                                  if (doc.exists) {
                                    return UserModel.fromJson(doc.data()!);
                                  }
                                  return null;
                                }(),
                                builder: (context, userSnapshot) {
                                  final userName = userSnapshot.data?.name ?? 'Loading...';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  Theme.of(context).primaryColor.withOpacity(0.1),
                                              child: Text(
                                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              memberId == currentUserId ? 'You' : userName,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          balance < 0
                                              ? 'owes \$${(-balance).toStringAsFixed(2)}'
                                              : 'gets \$${balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: balance < 0 ? Colors.red[700] : Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RecordSettlementScreen(
                                            group: group,
                                            balances: balances,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        // Settlement recorded, UI will update automatically
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle, size: 20),
                                    label: const Text('Settle Balance'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => GroupDetailsScreen(
                                            groupId: group.id,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.visibility, size: 20),
                                    label: const Text('View Details'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}