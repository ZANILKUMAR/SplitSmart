import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
import '../settlements/settlements_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../members/members_screen.dart';
import '../account/account_screen.dart';
import 'create_member_screen.dart';

import '../../services/notification_service.dart';
import '../../constants/currencies.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  final _notificationService = NotificationService();
  int _selectedIndex = 0;

  // Category icons map
  final Map<String, IconData> _categoryIcons = {
    'Food & Drinks': Icons.restaurant,
    'Transportation': Icons.directions_car,
    'Accommodation': Icons.hotel,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_bag,
    'Utilities': Icons.bolt,
    'Healthcare': Icons.medical_services,
    'Other': Icons.more_horiz,
  };

  IconData _getCategoryIcon(String? category) {
    return _categoryIcons[category] ?? Icons.receipt;
  }

  // Helper method to get user name
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['name'] ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Unknown';
    }
  }

  // Helper method to get top people you owe and who owe you
  Future<Map<String, dynamic>> _getTopPeople(
    Map<String, List<ExpenseModel>> expensesByGroup,
    Map<String, List<SettlementModel>> settlementsByGroup,
    List<GroupModel> activeGroups,
    String currentUserId,
  ) async {
    // Calculate balances per person across all groups
    final Map<String, double> personBalances = {};
    final Map<String, String> personCurrencies = {};
    final Map<String, String> personNames = {};

    for (var group in activeGroups) {
      final groupId = group.id;
      final currency = group.currency;
      final groupExpenses = expensesByGroup[groupId] ?? [];
      final groupSettlements = settlementsByGroup[groupId] ?? [];

      // Calculate balances for this group
      final balances = <String, double>{};
      
      for (var expense in groupExpenses) {
        balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
        for (var personId in expense.splitBetween) {
          final shareAmount = expense.getShareForUser(personId);
          balances[personId] = (balances[personId] ?? 0) - shareAmount;
        }
      }

      // Apply settlements
      for (var settlement in groupSettlements) {
        balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
        balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
      }

      // Extract balances between current user and others
      final myBalance = balances[currentUserId] ?? 0.0;
      
      for (var memberId in group.members) {
        if (memberId == currentUserId) continue;
        
        final theirBalance = balances[memberId] ?? 0.0;
        
        // Calculate what current user owes/is owed by this person
        double netBalance = 0.0;
        if (myBalance < 0 && theirBalance > 0) {
          // I owe money and they are owed money
          netBalance = myBalance; // negative = I owe
        } else if (myBalance > 0 && theirBalance < 0) {
          // I am owed and they owe money
          netBalance = myBalance; // positive = they owe me
        }
        
        if (netBalance != 0) {
          personBalances[memberId] = (personBalances[memberId] ?? 0) + netBalance;
          personCurrencies[memberId] = currency;
        }
      }
    }

    // Fetch names for all people with balances
    for (var personId in personBalances.keys) {
      if (!personNames.containsKey(personId)) {
        personNames[personId] = await _getUserName(personId);
      }
    }

    // Separate into owe and owed lists
    final List<Map<String, dynamic>> peopleIOwe = [];
    final List<Map<String, dynamic>> peopleWhoOweMe = [];

    personBalances.forEach((personId, balance) {
      final data = {
        'id': personId,
        'name': personNames[personId] ?? 'Unknown',
        'amount': balance.abs(),
        'currency': personCurrencies[personId] ?? 'USD',
      };

      if (balance < 0) {
        peopleIOwe.add(data);
      } else if (balance > 0) {
        peopleWhoOweMe.add(data);
      }
    });

    // Sort by amount (highest first)
    peopleIOwe.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    peopleWhoOweMe.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    return {
      'owe': peopleIOwe,
      'owed': peopleWhoOweMe,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent going back to login screen
      onPopInvoked: (didPop) {
        if (!didPop) {
          // If user tries to go back, show exit confirmation
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SplitSmart'),
          actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadNotificationsCount(
              widget.user.uid,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelect,
            itemBuilder: (BuildContext context) => [
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
          const MembersScreen(),
          _buildExpensesTab(),
          _buildAccountTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
      ), // Close PopScope
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Exit the app
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuSelect(String value) async {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
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
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to logout')));
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
      case 2: // Members tab - No FAB needed (screen has its own)
        return null;
      case 3: // Expenses tab
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
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
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

  Future<void> _showExpenseDetailsDialog(
    ExpenseModel expense,
    GroupModel? group,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currency = group?.currency ?? 'USD';

    // Get payer name
    String payerName = 'Unknown';
    if (expense.paidBy == currentUserId) {
      payerName = 'You';
    } else {
      final payerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(expense.paidBy)
          .get();
      if (payerDoc.exists) {
        payerName = payerDoc.data()?['name'] ?? 'Unknown';
      }
    }

    // Get split details
    final splitDetails = <String, String>{};
    for (var userId in expense.splitBetween) {
      String memberName = 'Unknown';
      if (userId == currentUserId) {
        memberName = 'You';
      } else {
        final memberDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (memberDoc.exists) {
          memberName = memberDoc.data()?['name'] ?? 'Unknown';
        }
      }
      final shareAmount = expense.getShareForUser(userId);
      splitDetails[memberName] = AppConstants.formatAmount(
        shareAmount,
        currency,
      );
    }

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.receipt,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expense.description,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group info
              if (group != null) ...[
                _buildDetailRow(
                  'Group',
                  group.name,
                  Icons.group,
                ),
                const Divider(height: 24),
              ],

              // Amount
              _buildDetailRow(
                'Total Amount',
                AppConstants.formatAmount(expense.amount, currency),
                Icons.account_balance_wallet,
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),

              // Paid by
              _buildDetailRow(
                'Paid by',
                payerName,
                Icons.person,
              ),
              const SizedBox(height: 16),

              // Date
              _buildDetailRow(
                'Date',
                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                Icons.calendar_today,
              ),
              const SizedBox(height: 16),

              // Split type
              _buildDetailRow(
                'Split Type',
                expense.splitType.toString().split('.').last.toUpperCase(),
                Icons.splitscreen,
              ),

              // Split details
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Split Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...splitDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: entry.key == 'You'
                              ? Theme.of(context).primaryColor
                              : null,
                          fontWeight: entry.key == 'You'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Notes if any
              if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  expense.notes!,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (group != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GroupDetailsScreen(groupId: expense.groupId),
                  ),
                );
              },
              child: const Text('View Group'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    TextStyle? valueStyle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : '?',
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
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.user.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
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
        StreamBuilder<List<GroupModel>>(
          stream: _groupService.getUserGroups(currentUserId ?? ''),
          builder: (context, groupSnapshot) {
            return StreamBuilder<List<ExpenseModel>>(
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                final activeGroups = groupSnapshot.data ?? [];
                final activeGroupIds = activeGroups.map((g) => g.id).toSet();

                // Filter out expenses from deleted groups
                final activeExpenses = expenses
                    .where((e) => activeGroupIds.contains(e.groupId))
                    .toList();

                final Map<String, List<ExpenseModel>> expensesByGroup = {};
                for (var expense in activeExpenses) {
                  if (!expensesByGroup.containsKey(expense.groupId)) {
                    expensesByGroup[expense.groupId] = [];
                  }
                  expensesByGroup[expense.groupId]!.add(expense);
                }

                // Map groups to their currencies
                final Map<String, String> groupCurrencies = {};
                for (var group in activeGroups) {
                  groupCurrencies[group.id] = group.currency;
                }

                // Get settlements to include in balance calculation
                return StreamBuilder<List<SettlementModel>>(
                  stream: _settlementService.getUserSettlements(
                    currentUserId ?? '',
                  ),
                  builder: (context, settlementSnapshot) {
                    final allSettlements = settlementSnapshot.data ?? [];

                    // Re-initialize maps inside settlement StreamBuilder
                    final Map<String, double> youOweByCurrency = {};
                    final Map<String, double> youAreOwedByCurrency = {};

                    // Group settlements by groupId
                    final Map<String, List<SettlementModel>>
                    settlementsByGroup = {};
                    for (var settlement in allSettlements) {
                      if (!settlementsByGroup.containsKey(settlement.groupId)) {
                        settlementsByGroup[settlement.groupId] = [];
                      }
                      settlementsByGroup[settlement.groupId]!.add(settlement);
                    }

                    for (var entry in expensesByGroup.entries) {
                      final groupId = entry.key;
                      final groupExpenses = entry.value;
                      final currency = groupCurrencies[groupId] ?? 'USD';
                      final groupSettlements =
                          settlementsByGroup[groupId] ?? [];

                      final balances = <String, double>{};
                      for (var expense in groupExpenses) {
                        balances[expense.paidBy] =
                            (balances[expense.paidBy] ?? 0) + expense.amount;
                        for (var personId in expense.splitBetween) {
                          final shareAmount = expense.getShareForUser(personId);
                          balances[personId] =
                              (balances[personId] ?? 0) - shareAmount;
                        }
                      }

                      // Apply settlements to balances
                      for (var settlement in groupSettlements) {
                        balances[settlement.paidBy] =
                            (balances[settlement.paidBy] ?? 0) +
                            settlement.amount;
                        balances[settlement.paidTo] =
                            (balances[settlement.paidTo] ?? 0) -
                            settlement.amount;
                      }

                      final myBalance = balances[currentUserId] ?? 0.0;
                      if (myBalance < 0) {
                        youOweByCurrency[currency] =
                            (youOweByCurrency[currency] ?? 0) + (-myBalance);
                      } else if (myBalance > 0) {
                        youAreOwedByCurrency[currency] =
                            (youAreOwedByCurrency[currency] ?? 0) + myBalance;
                      }
                    }

                    // Determine display format based on number of currencies
                    final allCurrencies = {
                      ...youOweByCurrency.keys,
                      ...youAreOwedByCurrency.keys,
                    }.toList();
                    final bool multipleCurrencies = allCurrencies.length > 1;

                    // Calculate totals (for single currency or primary display)
                    String oweDisplay, owedDisplay, totalDisplay;
                    Color totalColor;

                    if (multipleCurrencies) {
                      // Show "Multiple" for mixed currencies
                      oweDisplay = youOweByCurrency.isEmpty ? '0' : 'Multiple';
                      owedDisplay = youAreOwedByCurrency.isEmpty
                          ? '0'
                          : 'Multiple';
                      totalDisplay = 'Multiple Currencies';
                      totalColor = Colors.grey;
                    } else if (allCurrencies.isNotEmpty) {
                      // Single currency - show with proper symbol
                      final currency = allCurrencies.first;
                      final youOwe = youOweByCurrency[currency] ?? 0.0;
                      final youAreOwed = youAreOwedByCurrency[currency] ?? 0.0;
                      final totalBalance = youAreOwed - youOwe;

                      oweDisplay = AppConstants.formatAmount(youOwe, currency);
                      owedDisplay = AppConstants.formatAmount(
                        youAreOwed,
                        currency,
                      );
                      totalDisplay = totalBalance >= 0
                          ? '+${AppConstants.formatAmount(totalBalance, currency)}'
                          : AppConstants.formatAmount(totalBalance, currency);
                      totalColor = totalBalance >= 0
                          ? Colors.green
                          : Colors.red;
                    } else {
                      // No balances
                      oweDisplay = '\$0.00';
                      owedDisplay = '\$0.00';
                      totalDisplay = '\$0.00';
                      totalColor = Colors.grey;
                    }

                    return Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettlementsScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Your Balance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _SummaryItem(
                                    title: 'You owe',
                                    amount: oweDisplay,
                                    color: Colors.red,
                                  ),
                                  _SummaryItem(
                                    title: 'You are owed',
                                    amount: owedDisplay,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                              if (multipleCurrencies) ...[
                                const SizedBox(height: 12),
                                // Show breakdown by currency
                                ...allCurrencies.map((currency) {
                                  final owe = youOweByCurrency[currency] ?? 0.0;
                                  final owed =
                                      youAreOwedByCurrency[currency] ?? 0.0;
                                  if (owe == 0 && owed == 0)
                                    return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (owe > 0) ...[
                                          Text(
                                            'Owe ${AppConstants.formatAmount(owe, currency)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (owed > 0)
                                          Text(
                                            'Owed ${AppConstants.formatAmount(owed, currency)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              
                              // Top people section
                              FutureBuilder<Map<String, dynamic>>(
                                future: _getTopPeople(
                                  expensesByGroup,
                                  settlementsByGroup,
                                  activeGroups,
                                  currentUserId ?? '',
                                ),
                                builder: (context, topPeopleSnapshot) {
                                  if (!topPeopleSnapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final topPeople = topPeopleSnapshot.data!;
                                  final topOwed = topPeople['owed'] as List<Map<String, dynamic>>;
                                  final topOwe = topPeople['owe'] as List<Map<String, dynamic>>;
                                  
                                  if (topOwed.isEmpty && topOwe.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  return Column(
                                    children: [
                                      if (topOwe.isNotEmpty) ...[
                                        Text(
                                          'You owe:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...topOwe.take(3).map((person) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    person['name'],
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  AppConstants.formatAmount(
                                                    person['amount'],
                                                    person['currency'],
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.red[400] : Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 12),
                                      ],
                                      if (topOwed.isNotEmpty) ...[
                                        Text(
                                          'People who owe you:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...topOwed.take(3).map((person) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    person['name'],
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  AppConstants.formatAmount(
                                                    person['amount'],
                                                    person['currency'],
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.green[400] : Colors.green[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 12),
                                      ],
                                      const Divider(),
                                      const SizedBox(height: 8),
                                    ],
                                  );
                                },
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Total Balance: ',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    totalDisplay,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: totalColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Quick Actions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.group_add,
                        label: 'Add Group',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateGroupScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.person_add,
                        label: 'Add Member',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateMemberScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.receipt_long,
                        label: 'Add Expense',
                        color: Colors.orange,
                        onTap: () {
                          _showGroupSelectionDialog(); // Direct expense creation
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.account_balance_wallet,
                        label: 'Settle',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettlementsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recent Activity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedIndex = 3); // Switch to Expenses tab
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
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: isDark ? Colors.grey[400] : Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a group and add expenses to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
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
                  stream: Stream.fromFuture(
                    _groupService.getGroup(expense.groupId),
                  ),
                  builder: (context, groupSnapshot) {
                    final group = groupSnapshot.data;

                    // Skip if group is deleted
                    if (groupSnapshot.connectionState == ConnectionState.done &&
                        group == null) {
                      return const SizedBox.shrink();
                    }

                    final groupName = group?.name ?? 'Loading...';
                    final currency = group?.currency ?? 'USD';

                    // Fetch payer name if not current user
                    return FutureBuilder<String>(
                      future: expense.paidBy == currentUserId
                          ? Future.value('You')
                          : _getUserName(expense.paidBy),
                      builder: (context, payerSnapshot) {
                        final payerName = payerSnapshot.data ?? 'Loading...';

                        // Calculate user's share - handle null safety
                        final myShare = currentUserId != null 
                            ? expense.getShareForUser(currentUserId)
                            : 0.0;
                        
                        return Card(
                          child: ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(expense.category),
                                  color: Theme.of(context).primaryColor,
                                  size: 26,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d').format(expense.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              expense.description,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            trailing: SizedBox(
                              width: 95,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppConstants.formatAmount(
                                      myShare,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'Paid by $payerName',
                                    style: TextStyle(
                                      fontSize: 9,
                                      height: 1.0,
                                      color: expense.paidBy == currentUserId
                                          ? (isDark ? Colors.green[400] : Colors.green[700])
                                          : (isDark ? Colors.grey[500] : Colors.grey[500]),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              _showExpenseDetailsDialog(expense, group);
                            },
                          ),
                        );
                      },
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

    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.getUserGroups(currentUserId ?? ''),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = groupSnapshot.data ?? [];
        final activeGroupIds = groups.map((g) => g.id).toSet();

        return StreamBuilder<List<ExpenseModel>>(
          stream: _expenseService.getUserExpenses(currentUserId ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final allExpenses = snapshot.data ?? [];
            // Filter out expenses from deleted groups
            final expenses = allExpenses
                .where((expense) => activeGroupIds.contains(expense.groupId))
                .toList();

            if (expenses.isEmpty) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: isDark ? Colors.grey[400] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group and add expenses to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
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
                final aDate = DateTime(
                  int.parse(aParts[1]),
                  int.parse(aParts[0]),
                );
                final bDate = DateTime(
                  int.parse(bParts[1]),
                  int.parse(bParts[0]),
                );
                return bDate.compareTo(aDate);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedMonths.length + 1, // +1 for header
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Summary header - Calculate amounts by currency
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final totalExpenses = expenses.length;

                  // Group amounts by currency for expenses you paid
                  final Map<String, double> amountsByCurrency = {};
                  for (var expense in expenses.where(
                    (e) => e.paidBy == currentUserId,
                  )) {
                    final group = groups.firstWhere(
                      (g) => g.id == expense.groupId,
                    );
                    final currency = group.currency;
                    amountsByCurrency[currency] =
                        (amountsByCurrency[currency] ?? 0) + expense.amount;
                  }

                  return Card(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettlementsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
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
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 50,
                                width: 1,
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                              ),
                              Column(
                                children: [
                                  if (amountsByCurrency.isEmpty)
                                    Text(
                                      AppConstants.formatAmount(0, 'USD'),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    )
                                  else
                                    ...amountsByCurrency.entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          AppConstants.formatAmount(
                                            entry.value,
                                            entry.key,
                                          ),
                                          style: TextStyle(
                                            fontSize:
                                                amountsByCurrency.length > 1
                                                ? 24
                                                : 32,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    'You Paid',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ), // Close InkWell
                  );
                }

                final monthKey = sortedMonths[index - 1];
                final monthExpenses = expensesByMonth[monthKey]!;
                final monthParts = monthKey.split('/');
                final monthNames = [
                  '',
                  'January',
                  'February',
                  'March',
                  'April',
                  'May',
                  'June',
                  'July',
                  'August',
                  'September',
                  'October',
                  'November',
                  'December',
                ];
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final monthName =
                    '${monthNames[int.parse(monthParts[0])]} ${monthParts[1]}';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
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
                        stream: Stream.fromFuture(
                          _groupService.getGroup(expense.groupId),
                        ),
                        builder: (context, groupSnapshot) {
                          final group = groupSnapshot.data;

                          // Skip if group is deleted
                          if (groupSnapshot.connectionState ==
                                  ConnectionState.done &&
                              group == null) {
                            return const SizedBox.shrink();
                          }

                          final groupName = group?.name ?? 'Loading...';
                          final currency = group?.currency ?? 'USD';
                          
                          // Calculate user's share - handle null safety
                          final myShare = currentUserId != null
                              ? expense.getShareForUser(currentUserId)
                              : 0.0;

                          return FutureBuilder<String>(
                            future: expense.paidBy == currentUserId
                                ? Future.value('You')
                                : _getUserName(expense.paidBy),
                            builder: (context, payerSnapshot) {
                              final payerName = payerSnapshot.data ?? 'Loading...';

                              return Card(
                                child: ListTile(
                                  leading: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getCategoryIcon(expense.category),
                                        color: Theme.of(context).primaryColor,
                                        size: 26,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('MMM d').format(expense.date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    expense.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    groupName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  trailing: SizedBox(
                                    width: 95,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppConstants.formatAmount(
                                            myShare,
                                            currency,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          'Paid by $payerName',
                                          style: TextStyle(
                                            fontSize: 9,
                                            height: 1.0,
                                            color: expense.paidBy == currentUserId
                                                ? (isDark ? Colors.green[400] : Colors.green[700])
                                                : (isDark ? Colors.grey[500] : Colors.grey[500]),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    _showExpenseDetailsDialog(expense, group);
                                  },
                                ),
                              );
                            },
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
      },
    );
  }

  Widget _buildAccountTab() {
    return AccountScreen(user: widget.user);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey,
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

