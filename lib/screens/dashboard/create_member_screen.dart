import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../widgets/common/country_code_picker.dart';

class CreateMemberScreen extends StatefulWidget {
  const CreateMemberScreen({super.key});

  @override
  State<CreateMemberScreen> createState() => _CreateMemberScreenState();
}

class _CreateMemberScreenState extends State<CreateMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isImportingContacts = false;
  CountryCode _selectedCountry = CountryCodePicker.countries[0]; // Default to India

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact import is only available on mobile devices'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

      // Request permission
      final permission = await FlutterContacts.requestPermission();
      if (!permission) {
        // Close loading dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact permission denied'),
              backgroundColor: Colors.red,
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

      // Show contact selection dialog with search
      final selectedContact = await showDialog<Contact>(
        context: context,
        builder: (context) => _ContactSelectionDialog(contacts: contacts),
      );

      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (selectedContact != null) {
        // Pre-fill form with contact data
        _nameController.text = selectedContact.displayName;
        if (selectedContact.phones.isNotEmpty) {
          _phoneController.text = selectedContact.phones.first.number;
        }
        if (selectedContact.emails.isNotEmpty) {
          _emailController.text = selectedContact.emails.first.address;
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contact: $e'),
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

  Future<void> _createMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not logged in');

      // Combine country code with phone number
      final fullPhoneNumber = _phoneController.text.trim().isEmpty
          ? ''
          : '${_selectedCountry.dialCode}${_phoneController.text.trim()}';

      // Check if member already exists by phone number
      if (fullPhoneNumber.isNotEmpty) {
        final existingPhoneQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: fullPhoneNumber)
            .get();

        if (existingPhoneQuery.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Member with this phone number already exists'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Check if member already exists by email
      if (_emailController.text.trim().isNotEmpty) {
        final existingEmailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (existingEmailQuery.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Member with this email already exists'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Create new member with a unique ID
      final newMemberDoc = _firestore.collection('users').doc();
      await newMemberDoc.set({
        'uid': newMemberDoc.id,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? ''
            : _emailController.text.trim(),
        'phoneNumber': fullPhoneNumber,
        'isRegistered': false,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Member'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Import from Contacts button (only on mobile)
              if (!kIsWeb) ...[
                ElevatedButton.icon(
                  onPressed: _isImportingContacts ? null : _importFromContacts,
                  icon: _isImportingContacts
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.contacts),
                  label: Text(_isImportingContacts ? 'Loading...' : 'Import from Contacts'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter member name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Email or Phone (at least one required)',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  final phone = _phoneController.text.trim();
                  
                  // Check if both are empty
                  if (email.isEmpty && phone.isEmpty) {
                    return 'Please provide either email or phone';
                  }
                  
                  // Validate email format if provided
                  if (email.isNotEmpty && !email.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone field with country code
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountryCodePicker(
                    selectedCountry: _selectedCountry,
                    onChanged: (country) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(),
                        helperText: 'Email or Phone (at least one required)',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        final email = _emailController.text.trim();
                        
                        // Check if both are empty
                        if (phone.isEmpty && email.isEmpty) {
                          return 'Please provide either email or phone';
                        }
                        
                        // Validate phone format if provided (basic check)
                        if (phone.isNotEmpty && phone.length < 10) {
                          return 'Phone must be at least 10 digits';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create button
              ElevatedButton(
                onPressed: _isLoading ? null : _createMember,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Member',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Contact Selection Dialog with Search
class _ContactSelectionDialog extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactSelectionDialog({required this.contacts});

  @override
  State<_ContactSelectionDialog> createState() => _ContactSelectionDialogState();
}

class _ContactSelectionDialogState extends State<_ContactSelectionDialog> {
  final _searchController = TextEditingController();
  List<Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = widget.contacts;
      } else {
        final queryLower = query.toLowerCase();
        _filteredContacts = widget.contacts.where((contact) {
          final nameLower = contact.displayName.toLowerCase();
          final phone = contact.phones.isNotEmpty
              ? contact.phones.first.number.toLowerCase()
              : '';
          final email = contact.emails.isNotEmpty
              ? contact.emails.first.address.toLowerCase()
              : '';
          
          return nameLower.contains(queryLower) ||
                 phone.contains(queryLower) ||
                 email.contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Select Contact'),
              const Spacer(),
              Text(
                '${widget.contacts.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _filterContacts('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: _filterContacts,
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _filteredContacts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No contacts found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_searchController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  final phone = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : 'No phone';
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
                        Text(phone),
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
                    isThreeLine: email.isNotEmpty,
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
    );
  }
}
