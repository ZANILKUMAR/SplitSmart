import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isSearching = false);
        return;
      }

      // Fetch all members created by current user
      final allMembersQuery = await _firestore
          .collection('users')
          .where('createdBy', isEqualTo: currentUser.uid)
          .get();

      final allMembers = allMembersQuery.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();

      // Filter locally by search query (case-insensitive)
      final queryLower = query.toLowerCase();
      final filtered = allMembers.where((user) {
        // Check if already in group
        if (widget.group.members.contains(user.uid)) {
          return false;
        }

        // Search in name, email, or phone
        final matchesName = user.name.toLowerCase().contains(queryLower);
        final matchesEmail = user.email.toLowerCase().contains(queryLower);
        final matchesPhone = user.phoneNumber.toLowerCase().contains(queryLower);

        return matchesName || matchesEmail || matchesPhone;
      }).toList();

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
            child: Column(
              children: [
                TextField(
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
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _importFromContacts,
                    icon: const Icon(Icons.contacts),
                    label: const Text('Import from Contacts'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ],
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
        // Create New Member button
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

  Future<void> _importFromContacts() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact import is only available on mobile devices'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Check current permission status first
      bool permissionGranted = await FlutterContacts.requestPermission(readonly: true);
      
      if (!permissionGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact permission is required to import contacts. Please grant permission in your device settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Get contacts
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts found on your device'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show contact selection dialog
      final selectedContact = await showDialog<Contact>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.contacts),
              const SizedBox(width: 8),
              Text('Select Contact (${contacts.length})'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final phone = contact.phones.isNotEmpty
                    ? contact.phones.first.number
                    : '';
                final email = contact.emails.isNotEmpty
                    ? contact.emails.first.address
                    : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(contact.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phone.isNotEmpty) Text(phone),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: email.isNotEmpty && phone.isNotEmpty,
                  onTap: () => Navigator.pop(context, contact),
                );
              },
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

      if (selectedContact != null && mounted) {
        // Pre-fill create member dialog with contact data
        _showCreateMemberDialogWithData(
          name: selectedContact.displayName,
          phone: selectedContact.phones.isNotEmpty 
              ? selectedContact.phones.first.number 
              : '',
          email: selectedContact.emails.isNotEmpty 
              ? selectedContact.emails.first.address 
              : '',
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contact: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateMemberDialogWithData({
    String name = '',
    String email = '',
    String phone = '',
  }) {
    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);
    final phoneController = TextEditingController(text: phone);
    bool isLoading = false;

    _showCreateMemberDialogInternal(
      nameController,
      emailController,
      phoneController,
      isLoading,
    );
  }

  void _showCreateMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;

    _showCreateMemberDialogInternal(
      nameController,
      emailController,
      phoneController,
      isLoading,
    );
  }

  void _showCreateMemberDialogInternal(
    TextEditingController nameController,
    TextEditingController emailController,
    TextEditingController phoneController,
    bool isLoading,
  ) {

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
                    labelText: 'Email',
                    hintText: 'Enter email address',
                    prefixIcon: Icon(Icons.email),
                    helperText: 'Email or Phone required',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Enter mobile number',
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'Email or Phone required',
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

                      // Validate name
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Validate at least one: email or phone
                      if (email.isEmpty && phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please provide either email or phone number'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Validate email format if provided
                      if (email.isNotEmpty && !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email address'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Validate phone format if provided (basic check)
                      if (phone.isNotEmpty && phone.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid phone number (minimum 10 digits)'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Check if user with this email or phone already exists
                        if (email.isNotEmpty) {
                          final existingEmailUsers = await FirebaseFirestore.instance
                              .collection('users')
                              .where('email', isEqualTo: email)
                              .get();

                          if (existingEmailUsers.docs.isNotEmpty) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'User with this email already exists. Try searching for them.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                            return;
                          }
                        }

                        if (phone.isNotEmpty) {
                          final existingPhoneUsers = await FirebaseFirestore.instance
                              .collection('users')
                              .where('phoneNumber', isEqualTo: phone)
                              .get();

                          if (existingPhoneUsers.docs.isNotEmpty) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'User with this phone number already exists. Try searching for them.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                            return;
                          }
                        }

                        // Generate unique ID
                        final newUserId = FirebaseFirestore.instance
                            .collection('users')
                            .doc()
                            .id;

                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                        // Create new user document
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(newUserId)
                            .set({
                              'uid': newUserId,
                              'email': email,
                              'name': name,
                              'phoneNumber': phone,
                              'isRegistered': false,
                              'createdBy': currentUserId,
                              'createdAt': FieldValue.serverTimestamp(),
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
