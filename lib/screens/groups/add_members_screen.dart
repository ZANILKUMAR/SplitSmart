import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';

class AddMembersScreen extends StatefulWidget {
  final GroupModel group;

  const AddMembersScreen({super.key, required this.group});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _searchController = TextEditingController();
  final _groupService = GroupService();
  final _notificationService = NotificationService();
  final _firestore = FirebaseFirestore.instance;

  List<UserModel> _searchResults = [];
  List<UserModel> _currentMembers = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          .where(
            (user) =>
                !widget.group.members.contains(user.uid) &&
                user.uid != currentUser?.uid,
          )
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

  Future<void> _addMember(UserModel user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      await _groupService.addMember(
        widget.group.id,
        user.uid,
        addedBy: currentUserId,
      );

      // Send notification to the added member
      if (currentUserId != null) {
        await _notificationService.notifyMemberAdded(
          userId: user.uid,
          groupId: widget.group.id,
          groupName: widget.group.name,
          addedBy: currentUserId,
        );
      }

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
      appBar: AppBar(title: const Text('Add Members'), elevation: 0),
      body: Column(
        children: [
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
            child: _searchController.text.isEmpty
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._currentMembers.map(
          (member) => _buildMemberTile(member, isCurrentMember: true),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        // Always show "Create New Member" button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showCreateMemberDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('Create New Member'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        if (_searchResults.isEmpty && _searchController.text.isNotEmpty) ...[
          // No results message
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User not registered in the app',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ] else if (_searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Search Results (${_searchResults.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._searchResults.map(
            (user) => _buildMemberTile(user, isCurrentMember: false),
          ),
        ],
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

  void _showCreateMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'Enter full name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter email address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: 'Enter mobile number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final phone = phoneController.text.trim();

                      // Validate inputs
                      if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All fields are required'),
                          ),
                        );
                        return;
                      }

                      // Validate email format
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email address'),
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Check if user with this email already exists
                        final existingUsers = await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: email)
                            .get();

                        if (existingUsers.docs.isNotEmpty) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'User with this email already exists. Try searching for them.',
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        // Generate unique ID
                        final newUserId = FirebaseFirestore.instance
                            .collection('users')
                            .doc()
                            .id;

                        // Create new user document
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(newUserId)
                            .set({
                              'uid': newUserId,
                              'email': email,
                              'name': name,
                              'phoneNumber': phone,
                            });

                        // Create UserModel object
                        final newUser = UserModel(
                          uid: newUserId,
                          email: email,
                          name: name,
                          phoneNumber: phone,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);

                          // Add the user to the group
                          await _addMember(newUser);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$name has been created and added to the group',
                              ),
                            ),
                          );

                          // Clear search to show updated members list
                          _searchController.clear();
                          _searchUsers('');
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating member: $e'),
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create & Add'),
            ),
          ],
        ),
      ),
    );
  }
}
