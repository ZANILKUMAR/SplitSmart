import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/UserModel.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../../constants/currencies.dart';
import '../dashboard/create_member_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get all unique members from all groups the user is part of
  Stream<List<Map<String, dynamic>>> _getMembersWithBalancesStream() async* {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      yield [];
      return;
    }

    // Listen to groups, expenses, and settlements
    await for (final groups in _groupService.getUserGroups(currentUserId)) {
      final expenses = await _expenseService.getUserExpenses(currentUserId).first;
      final settlements = await _settlementService.getUserSettlements(currentUserId).first;

      // Get all unique member IDs from all groups
      final Set<String> allMemberIds = {};
      final Map<String, String> memberCurrencies = {}; // Store primary currency for each member
      
      for (var group in groups) {
        for (var memberId in group.members) {
          if (memberId != currentUserId) {
            allMemberIds.add(memberId);
            // Store the first currency we see for each member (could be from any group)
            if (!memberCurrencies.containsKey(memberId)) {
              memberCurrencies[memberId] = group.currency;
            }
          }
        }
      }

      // Fetch user details for all members
      final List<Map<String, dynamic>> membersWithBalances = [];
      
      for (var memberId in allMemberIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(memberId).get();
          if (!userDoc.exists) continue;
          
          final userData = userDoc.data()!;
          final member = UserModel.fromJson({...userData, 'uid': memberId});

          // Calculate balance with this member across all groups
          double totalBalance = 0.0;
          String primaryCurrency = memberCurrencies[memberId] ?? 'USD';
          
          // Group expenses and settlements by group to calculate balances
          for (var group in groups) {
            if (!group.members.contains(memberId)) continue;
            
            final groupExpenses = expenses.where((e) => e.groupId == group.id).toList();
            final groupSettlements = settlements.where((s) => s.groupId == group.id).toList();
            
            // Calculate balance for this specific group
            final Map<String, double> balances = {};
            
            // Process expenses
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
            
            // Get balance between current user and this member
            final myBalance = balances[currentUserId] ?? 0.0;
            final theirBalance = balances[memberId] ?? 0.0;
            
            // If positive: they owe me, if negative: I owe them
            if (myBalance > 0 || theirBalance < 0) {
              totalBalance += myBalance;
            } else if (theirBalance > 0 || myBalance < 0) {
              totalBalance += myBalance;
            }
          }

          membersWithBalances.add({
            'member': member,
            'balance': totalBalance,
            'currency': primaryCurrency,
          });
        } catch (e) {
          print('Error fetching member $memberId: $e');
        }
      }

      // Sort by name
      membersWithBalances.sort((a, b) {
        final memberA = a['member'] as UserModel;
        final memberB = b['member'] as UserModel;
        return memberA.name.toLowerCase().compareTo(memberB.name.toLowerCase());
      });

      yield membersWithBalances;
    }
  }

  List<Map<String, dynamic>> _filterMembers(List<Map<String, dynamic>> membersWithBalances) {
    if (_searchQuery.isEmpty) return membersWithBalances;

    final query = _searchQuery.toLowerCase();
    return membersWithBalances.where((item) {
      final member = item['member'] as UserModel;
      return member.name.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  void _showMemberDetails(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.email,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      member.email,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (member.phoneNumber.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      member.phoneNumber,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  size: 20,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  member.isRegistered ? 'Registered User' : 'Unregistered',
                  style: TextStyle(
                    fontSize: 14,
                    color: member.isRegistered ? Colors.green : Colors.orange,
                  ),
                ),
              ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          // Members list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getMembersWithBalancesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final allMembers = snapshot.data ?? [];
          final filteredMembers = _filterMembers(allMembers);

          if (allMembers.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No members yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a group and add members to see them here',
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

          if (filteredMembers.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredMembers.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final memberData = filteredMembers[index];
              final member = memberData['member'] as UserModel;
              final balance = memberData['balance'] as double;
              final currency = memberData['currency'] as String;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.isRegistered
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: member.isRegistered
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(member.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (member.email.isNotEmpty)
                        Text(
                          member.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                        ),
                      if (member.phoneNumber.isNotEmpty)
                        Text(
                          member.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Balance display
                      if (balance != 0)
                        Row(
                          children: [
                            Icon(
                              balance > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                              size: 14,
                              color: balance > 0 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              balance > 0
                                  ? 'owes you ${AppConstants.formatAmount(balance.abs(), currency)}'
                                  : 'you owe ${AppConstants.formatAmount(balance.abs(), currency)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: balance > 0 ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Settled up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (balance != 0)
                        Text(
                          AppConstants.formatAmount(balance.abs(), currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: balance > 0 ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      if (member.isRegistered)
                        Icon(Icons.verified, size: 14, color: Colors.green[700])
                      else
                        Icon(Icons.person_outline, size: 14, color: Colors.orange[700]),
                    ],
                  ),
                  onTap: () => _showMemberDetails(member),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMemberScreen(),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}
