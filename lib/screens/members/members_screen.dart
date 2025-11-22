import 'dart:async';
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

enum MemberFilter { all, outstanding, youOwe, theyOwe }

class _MembersScreenState extends State<MembersScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _cachedMembers = [];
  MemberFilter _selectedFilter = MemberFilter.all;
  bool _isSearching = false;
  bool _isInitialized = false;
  List<Map<String, dynamic>>? _cachedData;

  @override
  void initState() {
    super.initState();
    // Load all members data once on init
    _loadAllMembersData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Load all members data once and cache it
  Future<void> _loadAllMembersData() async {
    if (_isInitialized) return;
    
    try {
      final data = await _getMembersWithBalancesStream().first;
      setState(() {
        _allMembers = data;
        _isInitialized = true;
      });
    } catch (e) {
      print('Error loading members data: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // Get all unique members from all groups the user is part of AND members created by user
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
      final Map<String, String> memberCurrencies = {};
      
      for (var group in groups) {
        for (var memberId in group.members) {
          if (memberId != currentUserId) {
            allMemberIds.add(memberId);
            if (!memberCurrencies.containsKey(memberId)) {
              memberCurrencies[memberId] = group.currency;
            }
          }
        }
      }

      // Also fetch all members created by the current user
      try {
        final createdMembersQuery = await _firestore
            .collection('users')
            .where('createdBy', isEqualTo: currentUserId)
            .limit(500) // Limit to prevent excessive reads
            .get();
        
        for (var doc in createdMembersQuery.docs) {
          final memberId = doc.id;
          if (memberId != currentUserId) {
            allMemberIds.add(memberId);
            if (!memberCurrencies.containsKey(memberId)) {
              memberCurrencies[memberId] = 'USD';
            }
          }
        }
      } catch (e) {
        print('Error fetching created members: $e');
      }

      // Fetch user details for all members - Use batch operations
      final List<Map<String, dynamic>> membersWithBalances = [];
      
      // Process in batches to avoid excessive reads
      final memberIdsList = allMemberIds.toList();
      const batchSize = 10;
      
      for (int i = 0; i < memberIdsList.length; i += batchSize) {
        final batch = memberIdsList.sublist(
          i,
          i + batchSize > memberIdsList.length ? memberIdsList.length : i + batchSize,
        );

        final futures = batch.map((memberId) async {
          try {
            final userDoc = await _firestore.collection('users').doc(memberId).get();
            if (!userDoc.exists) return null;
            
            final userData = userDoc.data()!;
            final member = UserModel.fromJson({...userData, 'uid': memberId});

            // Fast balance calculation - only sum up group balances
            double totalBalance = 0.0;
            String primaryCurrency = memberCurrencies[memberId] ?? 'USD';
            
            for (var group in groups) {
              if (!group.members.contains(memberId)) continue;
              
              final groupExpenses = expenses.where((e) => e.groupId == group.id).toList();
              final groupSettlements = settlements.where((s) => s.groupId == group.id).toList();
              
              // Quick balance calculation
              final Map<String, double> balances = {};
              
              for (var expense in groupExpenses) {
                balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
                for (var personId in expense.splitBetween) {
                  final shareAmount = expense.getShareForUser(personId);
                  balances[personId] = (balances[personId] ?? 0) - shareAmount;
                }
              }
              
              for (var settlement in groupSettlements) {
                balances[settlement.paidBy] = (balances[settlement.paidBy] ?? 0) + settlement.amount;
                balances[settlement.paidTo] = (balances[settlement.paidTo] ?? 0) - settlement.amount;
              }
              
              final myBalance = balances[currentUserId] ?? 0.0;
              final theirBalance = balances[memberId] ?? 0.0;
              
              if (myBalance < 0 && theirBalance > 0) {
                totalBalance -= myBalance.abs();
              } else if (myBalance > 0 && theirBalance < 0) {
                totalBalance += myBalance;
              }
            }

            return {
              'member': member,
              'balance': totalBalance,
              'currency': primaryCurrency,
            };
          } catch (e) {
            print('Error processing member: $e');
            return null;
          }
        });

        final results = await Future.wait(futures);
        membersWithBalances.addAll(results.whereType<Map<String, dynamic>>());
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
    // First apply balance filter
    List<Map<String, dynamic>> filtered = membersWithBalances;
    
    switch (_selectedFilter) {
      case MemberFilter.all:
        filtered = membersWithBalances;
        break;
      case MemberFilter.outstanding:
        filtered = membersWithBalances.where((item) => item['balance'] != 0).toList();
        break;
      case MemberFilter.youOwe:
        filtered = membersWithBalances.where((item) => (item['balance'] as double) < 0).toList();
        break;
      case MemberFilter.theyOwe:
        filtered = membersWithBalances.where((item) => (item['balance'] as double) > 0).toList();
        break;
    }

    // Then apply search query - optimized search
    if (_searchQuery.isEmpty) return filtered;

    final query = _searchQuery.toLowerCase();
    return filtered.where((item) {
      final member = item['member'] as UserModel;
      // Short-circuit evaluation: stop checking once a match is found
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
          // Filter chips - Using cached data for instant updates
          if (_isInitialized)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  FilterChip(
                    label: Text('All (${_allMembers.length})'),
                    selected: _selectedFilter == MemberFilter.all,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = MemberFilter.all;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Outstanding (${_allMembers.where((m) => m['balance'] != 0).length})'),
                    selected: _selectedFilter == MemberFilter.outstanding,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = MemberFilter.outstanding;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('You owe (${_allMembers.where((m) => (m['balance'] as double) < 0).length})'),
                    selected: _selectedFilter == MemberFilter.youOwe,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = MemberFilter.youOwe;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('They owe (${_allMembers.where((m) => (m['balance'] as double) > 0).length})'),
                    selected: _selectedFilter == MemberFilter.theyOwe,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = MemberFilter.theyOwe;
                      });
                    },
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
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
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
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
                // Cancel previous timer
                _debounceTimer?.cancel();
                
                // Start new timer for debouncing (100ms delay - instant on cached data)
                _debounceTimer = Timer(const Duration(milliseconds: 100), () {
                  setState(() {
                    _searchQuery = value;
                  });
                });
              },
            ),
          ),
          // Members list - Using cached data with instant filtering and search
          Expanded(
            child: _buildMembersList(),
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

  Widget _buildMembersList() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply current filter and search to cached data
    final filteredMembers = _filterMembers(_allMembers);

    if (_allMembers.isEmpty) {
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
  }
}
