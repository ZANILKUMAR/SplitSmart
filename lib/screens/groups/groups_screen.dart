import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/GroupModel.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../../constants/currencies.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

enum GroupFilter { all, outstanding, youOwe, theyOwe }

class _GroupsScreenState extends State<GroupsScreen> {
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  GroupFilter _selectedFilter = GroupFilter.all;

  Future<List<Map<String, dynamic>>> _getGroupsWithBalances(String userId, List<GroupModel> groups) async {
    final List<Map<String, dynamic>> groupsWithBalances = [];

    for (var group in groups) {
      final expenses = await _expenseService.getGroupExpenses(group.id).first;
      final settlements = await _settlementService.getGroupSettlements(group.id).first;

      final Map<String, double> balances = {};
      
      // Find most recent activity date
      DateTime? lastActivityDate;
      
      for (var expense in expenses) {
        if (lastActivityDate == null || expense.date.isAfter(lastActivityDate)) {
          lastActivityDate = expense.date;
        }
        balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
        for (var personId in expense.splitBetween) {
          final shareAmount = expense.getShareForUser(personId);
          balances[personId] = (balances[personId] ?? 0) - shareAmount;
        }
      }
      
      for (var settlement in settlements) {
        if (lastActivityDate == null || settlement.date.isAfter(lastActivityDate)) {
          lastActivityDate = settlement.date;
        }
        balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
        balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
      }

      double iOwe = 0.0;
      double owedToMe = 0.0;

      for (var memberId in group.members) {
        if (memberId == userId) continue;
        
        final myBalance = balances[userId] ?? 0.0;
        final theirBalance = balances[memberId] ?? 0.0;
        
        if (myBalance < 0 && theirBalance > 0) {
          iOwe += myBalance.abs();
        } else if (myBalance > 0 && theirBalance < 0) {
          owedToMe += myBalance;
        }
      }

      groupsWithBalances.add({
        'group': group,
        'iOwe': iOwe,
        'owedToMe': owedToMe,
        'lastActivity': lastActivityDate ?? group.createdAt,
      });
    }

    // Sort by most recent activity first
    groupsWithBalances.sort((a, b) {
      final dateA = a['lastActivity'] as DateTime;
      final dateB = b['lastActivity'] as DateTime;
      return dateB.compareTo(dateA); // Most recent first
    });

    return groupsWithBalances;
  }

  List<Map<String, dynamic>> _filterGroups(List<Map<String, dynamic>> groupsWithBalances) {
    switch (_selectedFilter) {
      case GroupFilter.all:
        return groupsWithBalances;
      case GroupFilter.outstanding:
        return groupsWithBalances.where((g) => g['iOwe'] > 0 || g['owedToMe'] > 0).toList();
      case GroupFilter.youOwe:
        return groupsWithBalances.where((g) => g['iOwe'] > 0).toList();
      case GroupFilter.theyOwe:
        return groupsWithBalances.where((g) => g['owedToMe'] > 0).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view groups'));
    }

    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.getUserGroups(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: isDark ? Colors.red[400] : Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading groups',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_add,
                    size: 80,
                    color: isDark ? Colors.grey[400] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start splitting expenses',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateGroupScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getGroupsWithBalances(user.uid, groups),
          builder: (context, futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupsWithBalances = futureSnapshot.data ?? [];
            final filteredGroups = _filterGroups(groupsWithBalances);

            return Column(
              children: [
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('All (${groupsWithBalances.length})'),
                        selected: _selectedFilter == GroupFilter.all,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = GroupFilter.all);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Outstanding (${groupsWithBalances.where((g) => g['iOwe'] > 0 || g['owedToMe'] > 0).length})'),
                        selected: _selectedFilter == GroupFilter.outstanding,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = GroupFilter.outstanding);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('You owe (${groupsWithBalances.where((g) => g['iOwe'] > 0).length})'),
                        selected: _selectedFilter == GroupFilter.youOwe,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = GroupFilter.youOwe);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('They owe (${groupsWithBalances.where((g) => g['owedToMe'] > 0).length})'),
                        selected: _selectedFilter == GroupFilter.theyOwe,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = GroupFilter.theyOwe);
                        },
                      ),
                    ],
                  ),
                ),
                // Groups list
                Expanded(
                  child: filteredGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_alt_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No groups match this filter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredGroups.length,
                          itemBuilder: (context, index) {
                            final groupData = filteredGroups[index];
                            final group = groupData['group'] as GroupModel;
                            return _GroupCard(group: group);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _GroupCard extends StatefulWidget {
  final GroupModel group;

  const _GroupCard({required this.group});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  bool _isLoadingBalance = true;
  double _iOwe = 0.0; // Total amount I owe to others
  double _owedToMe = 0.0; // Total amount others owe to me
  bool _hasExpenses = false; // Track if group has any expenses

  @override
  void initState() {
    super.initState();
    _calculateBalance();
  }

  Future<void> _calculateBalance() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get expenses and settlements for this group
      final expenses = await _expenseService.getGroupExpenses(widget.group.id).first;
      final settlements = await _settlementService.getGroupSettlements(widget.group.id).first;
      
      final hasExpenses = expenses.isNotEmpty || settlements.isNotEmpty;

      // Calculate balances for all members
      final Map<String, double> balances = {};
      
      // Process expenses
      for (var expense in expenses) {
        balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
        for (var personId in expense.splitBetween) {
          final shareAmount = expense.getShareForUser(personId);
          balances[personId] = (balances[personId] ?? 0) - shareAmount;
        }
      }
      
      // Apply settlements
      for (var settlement in settlements) {
        balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
        balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
      }

      // Calculate separate amounts
      double iOwe = 0.0;
      double owedToMe = 0.0;

      // Check balance with each member
      for (var memberId in widget.group.members) {
        if (memberId == currentUserId) continue;
        
        final myBalance = balances[currentUserId] ?? 0.0;
        final theirBalance = balances[memberId] ?? 0.0;
        
        // Calculate net balance between me and this person
        if (myBalance < 0 && theirBalance > 0) {
          // I owe them
          iOwe += myBalance.abs();
        } else if (myBalance > 0 && theirBalance < 0) {
          // They owe me
          owedToMe += myBalance;
        }
      }

      if (mounted) {
        setState(() {
          _iOwe = iOwe;
          _owedToMe = owedToMe;
          _hasExpenses = hasExpenses;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailsScreen(groupId: widget.group.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Group Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.group.colorValue != null
                          ? Color(widget.group.colorValue!).withOpacity(0.2)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.group.iconCodePoint != null
                          ? IconData(widget.group.iconCodePoint!)
                          : Icons.group,
                      color: widget.group.colorValue != null
                          ? Color(widget.group.colorValue!)
                          : Theme.of(context).primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Group Name and Members Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.group.members.length} ${widget.group.members.length == 1 ? 'member' : 'members'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ],
              ),
              if (widget.group.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.group.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Balance section
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[800]?.withOpacity(0.5)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoadingBalance
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading balance...', style: TextStyle(fontSize: 12)),
                        ],
                      )
                    : Column(
                        children: [
                          // Amount others owe me
                          if (_owedToMe > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'You are owed',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppConstants.formatAmount(_owedToMe, widget.group.currency),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            if (_iOwe > 0) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                            ],
                          ],
                          // Amount I owe
                          if (_iOwe > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'You owe',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppConstants.formatAmount(_iOwe, widget.group.currency),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // No expenses or Settled up
                          if (_iOwe == 0 && _owedToMe == 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasExpenses ? Icons.check_circle : Icons.receipt_long_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _hasExpenses ? 'Settled up' : 'No expenses yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
