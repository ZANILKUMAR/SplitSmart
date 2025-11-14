import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/group_service.dart';
import '../../constants/currencies.dart';
import '../../models/UserModel.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _groupService = GroupService();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isSearching = false;

  List<UserModel> _selectedMembers = [];
  List<UserModel> _searchResults = [];

  // Group icons
  final List<IconData> _groupIcons = [
    Icons.group,
    Icons.family_restroom,
    Icons.sports_soccer,
    Icons.school,
    Icons.work,
    Icons.home,
    Icons.beach_access,
    Icons.flight,
    Icons.restaurant,
    Icons.shopping_bag,
    Icons.fitness_center,
    Icons.music_note,
  ];

  IconData _selectedIcon = Icons.group;
  Color _selectedColor = Colors.blue;
  String _selectedCurrency = 'USD'; // Default currency

  final List<Color> _groupColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
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
        // Check if already selected
        if (_selectedMembers.any((m) => m.uid == user.uid)) {
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
    }
  }

  void _addMember(UserModel user) {
    setState(() {
      _selectedMembers.add(user);
      _searchResults.remove(user);
      _searchController.clear();
    });
  }

  void _removeMember(UserModel user) {
    setState(() {
      _selectedMembers.remove(user);
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _groupColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 30,
                        )
                      : null,
                ),
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
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Icon'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _groupIcons.length,
            itemBuilder: (context, index) {
              final icon = _groupIcons[index];
              final isSelected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = icon;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.2)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: _selectedColor.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? _selectedColor : Colors.grey[600],
                    size: 28,
                  ),
                ),
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
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      print('Creating group with name: ${_nameController.text.trim()}');
      print('User ID: ${user.uid}');

      print('Creating group with icon: ${_selectedIcon.codePoint} (0x${_selectedIcon.codePoint.toRadixString(16)}), color: ${_selectedColor.value}');
      print('Selected icon details: ${_selectedIcon.toString()}');
      
      final groupId = await _groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: user.uid,
        currency: _selectedCurrency,
        iconCodePoint: _selectedIcon.codePoint,
        colorValue: _selectedColor.value,
      );

      print('Group created successfully with ID: $groupId');

      // Add selected members to the group
      if (_selectedMembers.isNotEmpty) {
        for (var member in _selectedMembers) {
          await _groupService.addMember(groupId, member.uid, addedBy: user.uid);
        }
        print('Added ${_selectedMembers.length} members to group');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, groupId);
      }
    } catch (e, stackTrace) {
      print('Error creating group: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Color Selection (at top)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Selector
                    GestureDetector(
                      onTap: _showIconPicker,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _selectedIcon,
                          color: _selectedColor,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Color Selector
                    GestureDetector(
                      onTap: _showColorPicker,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.palette,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Group Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  if (value.trim().length < 3) {
                    return 'Group name must be at least 3 characters';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Group Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What is this group about?',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Currency Selection
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
                items: AppConstants.currencies.map((currency) {
                  return DropdownMenuItem<String>(
                    value: currency['code'],
                    child: Row(
                      children: [
                        Text(
                          currency['symbol']!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(currency['name']!),
                        const SizedBox(width: 4),
                        Text(
                          '(${currency['code']})',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Add Members Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Members (Optional)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedMembers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedMembers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                        )
                      : null,
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 8),

              // Search Results
              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            user.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                          onPressed: () => _addMember(user),
                        ),
                      );
                    },
                  ),
                ),

              // Selected Members List
              if (_selectedMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Members',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                          Text(
                            '${_selectedMembers.length} member${_selectedMembers.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(_selectedMembers.map((user) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green,
                                child: Text(
                                  user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle,
                                  color: Colors.red[400],
                                ),
                                onPressed: () => _removeMember(user),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Create Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Info Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMembers.isEmpty
                            ? 'You can add members now or after creating the group.'
                            : 'Selected members will be added when you create the group.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 13),
                      ),
                    ),
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
