import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/GroupModel.dart';
import '../../models/ExpenseModel.dart';
import '../../models/SettlementModel.dart';
import '../../models/UserModel.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../../constants/currencies.dart';
import '../groups/group_details_screen.dart';
import 'record_settlement_screen.dart';

class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlements'),
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: _groupService.getUserGroups(currentUserId ?? ''),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupSnapshot.hasError) {
            return Center(child: Text('Error: ${groupSnapshot.error}'));
          }

          final groups = groupSnapshot.data ?? [];

          if (groups.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: isDark ? Colors.grey[400] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No settlements yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create groups and add expenses to see who owes whom',
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Overall Summary
                return _buildOverallSummary(currentUserId, groups);
              }

              final group = groups[index - 1];
              return _buildGroupSettlement(currentUserId, group);
            },
          );
        },
      ),
    );
  }

  Widget _buildOverallSummary(String? currentUserId, List<GroupModel> groups) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _expenseService.getUserExpenses(currentUserId ?? ''),
      builder: (context, expenseSnapshot) {
        if (!expenseSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final expenses = expenseSnapshot.data ?? [];
        final activeGroupIds = groups.map((g) => g.id).toSet();
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

        return StreamBuilder<List<SettlementModel>>(
          stream: _settlementService.getUserSettlements(currentUserId ?? ''),
          builder: (context, allSettlementsSnapshot) {
            final allSettlements = allSettlementsSnapshot.data ?? [];
            final Map<String, double> youOweByCurrency = {};
            final Map<String, double> youAreOwedByCurrency = {};

            final Map<String, List<SettlementModel>> settlementsByGroup = {};
            for (var settlement in allSettlements) {
              if (!settlementsByGroup.containsKey(settlement.groupId)) {
                settlementsByGroup[settlement.groupId] = [];
              }
              settlementsByGroup[settlement.groupId]!.add(settlement);
            }

            for (var groupId in expensesByGroup.keys) {
              final groupExpenses = expensesByGroup[groupId]!;
              final group = groups.firstWhere((g) => g.id == groupId);
              final currency = group.currency;
              final groupSettlements = settlementsByGroup[groupId] ?? [];

              final balances = <String, double>{};
              for (var expense in groupExpenses) {
                balances[expense.paidBy] =
                    (balances[expense.paidBy] ?? 0) + expense.amount;
                for (var personId in expense.splitBetween) {
                  final shareAmount = expense.getShareForUser(personId);
                  balances[personId] = (balances[personId] ?? 0) - shareAmount;
                }
              }

              for (var settlement in groupSettlements) {
                balances[settlement.paidBy] =
                    (balances[settlement.paidBy] ?? 0) + settlement.amount;
                balances[settlement.paidTo] =
                    (balances[settlement.paidTo] ?? 0) - settlement.amount;
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

            final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        Expanded(
                          child: Column(
                            children: [
                              if (youOweByCurrency.isEmpty)
                                Text(
                                  AppConstants.formatAmount(0, 'USD'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                )
                              else
                                ...youOweByCurrency.entries.map(
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
                                            youOweByCurrency.length > 1 ? 22 : 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                'You owe',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 50,
                          width: 1,
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              if (youAreOwedByCurrency.isEmpty)
                                Text(
                                  AppConstants.formatAmount(0, 'USD'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                )
                              else
                                ...youAreOwedByCurrency.entries.map(
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
                                        fontSize: youAreOwedByCurrency.length > 1
                                            ? 22
                                            : 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                'You are owed',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.grey[400] : Colors.grey[600],
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
            );
          },
        );
      },
    );
  }

  Widget _buildGroupSettlement(String? currentUserId, GroupModel group) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _expenseService.getGroupExpenses(group.id),
      builder: (context, expenseSnapshot) {
        return StreamBuilder<List<SettlementModel>>(
          stream: _settlementService.getGroupSettlements(group.id),
          builder: (context, settlementSnapshot) {
            if (!expenseSnapshot.hasData || !settlementSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final expenses = expenseSnapshot.data ?? [];
            final settlements = settlementSnapshot.data ?? [];

            if (expenses.isEmpty) {
              return const SizedBox.shrink();
            }

            final balances = <String, double>{};
            for (var expense in expenses) {
              balances[expense.paidBy] =
                  (balances[expense.paidBy] ?? 0) + expense.amount;
              for (var personId in expense.splitBetween) {
                final shareAmount = expense.getShareForUser(personId);
                balances[personId] = (balances[personId] ?? 0) - shareAmount;
              }
            }

            for (var settlement in settlements) {
              balances[settlement.paidBy] =
                  (balances[settlement.paidBy] ?? 0) + settlement.amount;
              balances[settlement.paidTo] =
                  (balances[settlement.paidTo] ?? 0) - settlement.amount;
            }

            final myBalance = balances[currentUserId] ?? 0.0;

            if (myBalance == 0) {
              return const SizedBox.shrink();
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
                subtitle: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      myBalance < 0
                          ? 'You owe ${AppConstants.formatAmount(-myBalance, group.currency)}'
                          : 'You are owed ${AppConstants.formatAmount(myBalance, group.currency)}',
                      style: TextStyle(
                        color: myBalance < 0
                            ? (isDark ? Colors.red[400] : Colors.red[700])
                            : (isDark ? Colors.green[400] : Colors.green[700]),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
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
                              final userName =
                                  userSnapshot.data?.name ?? 'Loading...';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.1),
                                          child: Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          memberId == currentUserId
                                              ? 'You'
                                              : userName,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final isDark = Theme.of(context)
                                                .brightness ==
                                            Brightness.dark;
                                        return Text(
                                          balance < 0
                                              ? 'owes ${AppConstants.formatAmount(-balance, group.currency)}'
                                              : 'gets ${AppConstants.formatAmount(balance, group.currency)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: balance < 0
                                                ? (isDark
                                                    ? Colors.red[400]
                                                    : Colors.red[700])
                                                : (isDark
                                                    ? Colors.green[400]
                                                    : Colors.green[700]),
                                          ),
                                        );
                                      },
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
                                      builder: (context) =>
                                          RecordSettlementScreen(
                                        group: group,
                                        balances: balances,
                                      ),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    // Settlement recorded, UI updates automatically
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
                                      builder: (context) =>
                                          GroupDetailsScreen(groupId: group.id),
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
  }
}
