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
  List<UserModel> _allMembers = [];
  List<UserModel> _allCreatedMembers = []; // All members created by user
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isImportingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadCurrentMembers(),
      _loadAllMembers(),
    ]);
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

      if (mounted) {
        setState(() {
          _currentMembers = membersData.whereType<UserModel>().toList();
        });
      }
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _loadAllMembers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Fetch all members created by current user
      final allMembersQuery = await _firestore
          .collection('users')
          .where('createdBy', isEqualTo: currentUser.uid)
          .get();

      final Set<String> allMemberIds = {};
      final Map<String, UserModel> memberMap = {};

      // Add members created by current user
      for (var doc in allMembersQuery.docs) {
        final member = UserModel.fromJson(doc.data());
        allMemberIds.add(member.uid);
        memberMap[member.uid] = member;
      }

      // Also fetch all members from all groups the user is part of
      final userGroupsQuery = await _firestore
          .collection('groups')
          .where('members', arrayContains: currentUser.uid)
          .get();

      for (var groupDoc in userGroupsQuery.docs) {
        final groupData = groupDoc.data();
        final memberIds = List<String>.from(groupData['members'] ?? []);
        
        for (var memberId in memberIds) {
          if (memberId != currentUser.uid && !allMemberIds.contains(memberId)) {
            // Fetch this member's details
            try {
              final memberDoc = await _firestore.collection('users').doc(memberId).get();
              if (memberDoc.exists) {
                final member = UserModel.fromJson(memberDoc.data()!);
                allMemberIds.add(member.uid);
                memberMap[member.uid] = member;
              }
            } catch (e) {
              print('Error fetching member $memberId: $e');
            }
          }
        }
      }

      final allMembers = memberMap.values.toList();

      // Separate members into those in group and those not
      final availableMembers = allMembers
          .where((user) => !widget.group.members.contains(user.uid))
          .toList();

      print('AddMembersScreen: Total unique members: ${allMembers.length}');
      print('AddMembersScreen: Current group members: ${widget.group.members.length}');
      print('AddMembersScreen: Available to add: ${availableMembers.length}');

      if (mounted) {
        setState(() {
          // Store all created members for search AND display
          _allCreatedMembers = allMembers;
          // Show only members NOT already in the group in "All Members" section
          _allMembers = availableMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading all members: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _searchUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // If members not loaded yet, wait
    if (_allCreatedMembers.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Search from ALL created members (including those already in group)
    final queryLower = query.toLowerCase();
    final filtered = _allCreatedMembers.where((user) {
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
          _allMembers.remove(user);
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
          _allMembers.add(user);
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
                              setState(() {}); // Rebuild to update UI
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {}); // Rebuild to update suffixIcon
                    _searchUsers(value);
                  },
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isImportingContacts ? null : _importFromContacts,
                    icon: _isImportingContacts
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.contacts),
                    label: Text(_isImportingContacts ? 'Loading...' : 'Import from Contacts'),
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
        
        // Current Members Section
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
        
        // All Members Section
        if (_allMembers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(
              thickness: 2,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.group_add,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'All Members (${_allMembers.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Select members to add to this group',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            ),
          ),
          ..._allMembers.map(
            (member) => _buildMemberTile(member, isCurrentMember: false),
          ),
        ],
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
          ..._searchResults.map((user) {
            final isInGroup = widget.group.members.contains(user.uid);
            return _buildMemberTile(user, isCurrentMember: isInGroup);
          }),
        ],
      ],
    );
  }

  Widget _buildMemberTile(UserModel user, {required bool isCurrentMember}) {
    final isCreator = user.uid == widget.group.createdBy;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            if (isCurrentMember && !isCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'In Group',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
          ],
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600], 
            fontSize: 13,
          ),
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

    // Prevent multiple clicks
    if (_isImportingContacts) return;

    setState(() {
      _isImportingContacts = true;
    });

    try {
      // Show loading indicator immediately
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Loading contacts...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Check current permission status
      bool permissionGranted = await FlutterContacts.requestPermission(readonly: true);
      
      if (!permissionGranted) {
        // Close loading dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
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
    } finally {
      if (mounted) {
        setState(() {
          _isImportingContacts = false;
        });
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
    String selectedCountryCode = '+91'; // Default to India

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Email or Phone (at least one required)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter full name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country Code Dropdown (smaller)
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCountryCode,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            prefixIcon: Icon(Icons.flag, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: '+1', child: Text('+1')),
                            DropdownMenuItem(value: '+44', child: Text('+44')),
                            DropdownMenuItem(value: '+91', child: Text('+91')),
                            DropdownMenuItem(value: '+86', child: Text('+86')),
                            DropdownMenuItem(value: '+81', child: Text('+81')),
                            DropdownMenuItem(value: '+61', child: Text('+61')),
                            DropdownMenuItem(value: '+49', child: Text('+49')),
                            DropdownMenuItem(value: '+33', child: Text('+33')),
                            DropdownMenuItem(value: '+39', child: Text('+39')),
                            DropdownMenuItem(value: '+34', child: Text('+34')),
                            DropdownMenuItem(value: '+7', child: Text('+7')),
                            DropdownMenuItem(value: '+55', child: Text('+55')),
                            DropdownMenuItem(value: '+52', child: Text('+52')),
                            DropdownMenuItem(value: '+82', child: Text('+82')),
                            DropdownMenuItem(value: '+65', child: Text('+65')),
                            DropdownMenuItem(value: '+971', child: Text('+971')),
                            DropdownMenuItem(value: '+966', child: Text('+966')),
                            DropdownMenuItem(value: '+27', child: Text('+27')),
                            DropdownMenuItem(value: '+234', child: Text('+234')),
                            DropdownMenuItem(value: '+254', child: Text('+254')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedCountryCode = value!;
                            });
                          },
                          isExpanded: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Phone Number Field (larger)
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            hintText: 'Enter mobile number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                      final phoneOnly = phoneController.text.trim();
                      
                      // Combine country code with phone number if phone is provided
                      final phone = phoneOnly.isNotEmpty 
                          ? '$selectedCountryCode$phoneOnly' 
                          : '';

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
                      if (email.isEmpty && phoneOnly.isEmpty) {
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
                      if (phoneOnly.isNotEmpty && phoneOnly.length < 10) {
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
                          
                          // Reload all members to update the list
                          _loadAllMembers();
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
