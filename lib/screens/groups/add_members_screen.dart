import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../services/group_service.dart';

class AddMembersScreen extends StatefulWidget {
  final GroupModel group;

  const AddMembersScreen({
    super.key,
    required this.group,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _searchController = TextEditingController();
  final _bulkInputController = TextEditingController();
  final _groupService = GroupService();
  final _firestore = FirebaseFirestore.instance;
  
  List<UserModel> _searchResults = [];
  List<UserModel> _currentMembers = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _showBulkInput = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bulkInputController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMembers() async {
    try {
      final membersData = await Future.wait(
        widget.group.members.map((memberId) async {
          final doc = await _firestore.collection('users').doc(memberId).get();
          if (doc.exists) {
            return UserModel.fromJson(doc.data()!);
          }
          return null;
        }),
      );

      setState(() {
        _currentMembers = membersData.whereType<UserModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading members: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Search by email
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('email', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      // Search by name
      final nameQuery = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      // Search by phone number
      final phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isGreaterThanOrEqualTo: query)
          .where('phoneNumber', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      final emailResults = emailQuery.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      final nameResults = nameQuery.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      final phoneResults = phoneQuery.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      // Combine and remove duplicates
      final allResults = <String, UserModel>{};
      for (var user in emailResults) {
        allResults[user.uid] = user;
      }
      for (var user in nameResults) {
        allResults[user.uid] = user;
      }
      for (var user in phoneResults) {
        allResults[user.uid] = user;
      }

      // Filter out current members and current user
      final currentUser = FirebaseAuth.instance.currentUser;
      final filtered = allResults.values
          .where((user) =>
              !widget.group.members.contains(user.uid) &&
              user.uid != currentUser?.uid)
          .toList();

      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() => _isSearching = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processBulkInput() async {
    final input = _bulkInputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email addresses or phone numbers'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Split by comma and clean up
    final items = input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid entries found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final allResults = <String, UserModel>{};
      int notFoundCount = 0;

      for (final item in items) {
        // Try to find user by email or phone
        QuerySnapshot? query;
        
        // Check if it looks like an email (contains @)
        if (item.contains('@')) {
          query = await _firestore
              .collection('users')
              .where('email', isEqualTo: item.toLowerCase())
              .limit(1)
              .get();
        } else {
          // Try as phone number
          query = await _firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: item)
              .limit(1)
              .get();
        }

        if (query.docs.isNotEmpty) {
          final user = UserModel.fromJson(query.docs.first.data() as Map<String, dynamic>);
          
          // Only add if not already a member
          if (!widget.group.members.contains(user.uid)) {
            allResults[user.uid] = user;
          }
        } else {
          notFoundCount++;
        }
      }

      setState(() {
        _searchResults = allResults.values.toList();
        _isSearching = false;
        _showBulkInput = false;
        _bulkInputController.clear();
      });

      if (mounted) {
        if (allResults.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found ${allResults.length} user(s)${notFoundCount > 0 ? ' ($notFoundCount not found)' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No users found for the provided entries'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error processing bulk input: $e');
      setState(() => _isSearching = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMember(UserModel user) async {
    try {
      await _groupService.addMember(widget.group.id, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} added to group'),
            backgroundColor: Colors.green,
          ),
        );

        // Update local state
        setState(() {
          _currentMembers.add(user);
          _searchResults.remove(user);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(UserModel user) async {
    // Prevent removing the creator
    if (user.uid == widget.group.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove group creator'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm removal
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${user.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupService.removeMember(widget.group.id, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} removed from group'),
            backgroundColor: Colors.orange,
          ),
        );

        setState(() {
          _currentMembers.remove(user);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showBulkInput ? Icons.search : Icons.format_list_bulleted),
            onPressed: () {
              setState(() {
                _showBulkInput = !_showBulkInput;
                if (!_showBulkInput) {
                  _bulkInputController.clear();
                }
              });
            },
            tooltip: _showBulkInput ? 'Search Mode' : 'Bulk Add Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showBulkInput)
            // Bulk Input Mode
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Multiple Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bulkInputController,
                    decoration: InputDecoration(
                      hintText: 'Enter emails or phone numbers separated by commas\nExample: user@email.com, +1234567890, another@email.com',
                      prefixIcon: const Icon(Icons.people),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _processBulkInput,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isSearching ? 'Searching...' : 'Find Users'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Users must be registered in the app',
                            style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _searchUsers(value);
                },
              ),
            ),

          // Search Results or Current Members
          Expanded(
            child: _searchController.text.isEmpty && !_showBulkInput
                ? _buildCurrentMembersList()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMembersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Current Members (${_currentMembers.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._currentMembers.map((member) => _buildMemberTile(
              member,
              isCurrentMember: true,
            )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by email or name',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Search Results (${_searchResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._searchResults.map((user) => _buildMemberTile(
              user,
              isCurrentMember: false,
            )),
      ],
    );
  }

  Widget _buildMemberTile(UserModel user, {required bool isCurrentMember}) {
    final isCreator = user.uid == widget.group.createdBy;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.name)),
            if (isCreator)
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
          ],
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: isCurrentMember
            ? (isCreator
                ? null
                : IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeMember(user),
                  ))
            : ElevatedButton.icon(
                onPressed: () => _addMember(user),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 36),
                ),
              ),
      ),
    );
  }
}
