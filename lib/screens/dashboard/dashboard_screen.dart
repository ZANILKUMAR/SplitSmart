import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/UserModel.dart';
import '../../models/GroupModel.dart';
import '../../models/ExpenseModel.dart';
import '../../models/SettlementModel.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../auth/login_screen.dart';
import '../groups/groups_screen.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../settlements/record_settlement_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../members/members_screen.dart';
import 'create_member_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../../services/notification_service.dart';
import '../../constants/currencies.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _groupService = GroupService();
  final _expenseService = ExpenseService();
  final _settlementService = SettlementService();
  final _notificationService = NotificationService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Smart'),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadNotificationsCount(
              widget.user.uid,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelect,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette, size: 20),
                    SizedBox(width: 8),
                    Text('Theme Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildGroupsTab(),
          const MembersScreen(),
          _buildExpensesTab(),
          _buildSettleTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Settle',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Future<void> _handleMenuSelect(String value) async {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
      case 'theme':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ThemeSettingsScreen()),
        );
        break;
      case 'logout':
        await _handleLogout();
        break;
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to logout')));
      }
    }
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 1: // Groups tab
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateGroupScreen(),
              ),
            );
          },
          child: const Icon(Icons.add),
        );
      case 2: // Members tab - No FAB needed (screen has its own)
        return null;
      case 3: // Expenses tab
        return FloatingActionButton.extended(
          onPressed: () => _showGroupSelectionDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        );
      default:
        return null;
    }
  }

  Future<void> _showGroupSelectionDialog() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final groups = await _groupService.getUserGroups(currentUserId ?? '').first;

    if (!mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Create a group first to add expenses'),
          action: SnackBarAction(
            label: 'Create Group',
            onPressed: () {
              setState(() => _selectedIndex = 1); // Switch to Groups tab
            },
          ),
        ),
      );
      return;
    }

    final selectedGroup = await showDialog<GroupModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: groups.map((group) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.group,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(group.name),
                subtitle: Text('${group.members.length} members'),
                onTap: () => Navigator.pop(context, group),
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

    if (selectedGroup != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(group: selectedGroup),
        ),
      );

      if (result == true) {
        // Expense added successfully
      }
    }
  }

  Future<void> _importFromContacts() async {
    // Check if running on web
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

    try {
      // Request permission
      if (!await FlutterContacts.requestPermission(readonly: true)) {
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

      // Get contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No contacts found')),
          );
        }
        return;
      }

      // Show contact selection dialog
      if (mounted) {
        final selectedContact = await showDialog<Contact>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Contact'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final phone = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : 'No phone';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        contact.displayName.isNotEmpty
                            ? contact.displayName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(contact.displayName),
                    subtitle: Text(phone),
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

        if (selectedContact != null) {
          // Pre-fill the create member form with contact data
          final nameController = TextEditingController(
            text: selectedContact.displayName,
          );
          final phoneController = TextEditingController(
            text: selectedContact.phones.isNotEmpty
                ? selectedContact.phones.first.number
                : '',
          );
          final emailController = TextEditingController(
            text: selectedContact.emails.isNotEmpty
                ? selectedContact.emails.first.address
                : '',
          );

          // Show create member dialog with pre-filled data
          await _showCreateMemberDialog(
            nameController: nameController,
            emailController: emailController,
            phoneController: phoneController,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCreateMemberDialog({
    TextEditingController? nameController,
    TextEditingController? emailController,
    TextEditingController? phoneController,
  }) async {
    final nameCtrl = nameController ?? TextEditingController();
    final emailCtrl = emailController ?? TextEditingController();
    final phoneCtrl = phoneController ?? TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name *',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email *',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Mobile Number *',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  emailCtrl.text.isEmpty ||
                  phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                // Create member in Firestore
                await FirebaseFirestore.instance.collection('users').add({
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phoneNumber': phoneCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'isRegistered': false,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Member ${nameCtrl.text} created successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating member: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMemberDialog() async {
    final TextEditingController searchController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    List<UserModel> searchResults = [];
    bool showCreateForm = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Import from Contacts Button (only on mobile)
                  if (!kIsWeb)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _importFromContacts();
                        },
                        icon: const Icon(Icons.contacts),
                        label: const Text('Import from Contacts'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (!kIsWeb) const SizedBox(height: 16),
                  
                  // Search Field
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.isEmpty) {
                      setState(() => searchResults = []);
                      return;
                    }

                    final users = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isGreaterThanOrEqualTo: value)
                        .where('email', isLessThan: '${value}z')
                        .limit(5)
                        .get();

                    final nameUsers = await FirebaseFirestore.instance
                        .collection('users')
                        .where('name', isGreaterThanOrEqualTo: value)
                        .where('name', isLessThan: '${value}z')
                        .limit(5)
                        .get();

                    final Set<String> seenIds = {};
                    final List<UserModel> results = [];

                    for (var doc in [...users.docs, ...nameUsers.docs]) {
                      if (!seenIds.contains(doc.id)) {
                        seenIds.add(doc.id);
                        final data = doc.data();
                        results.add(
                          UserModel(
                            uid: doc.id,
                            email: data['email'] ?? '',
                            name: data['name'] ?? '',
                            phoneNumber: data['phoneNumber'] ?? '',
                          ),
                        );
                      }
                    }

                    setState(() => searchResults = results);
                  },
                ),
                const SizedBox(height: 16),

                // Search Results
                if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(user.name[0].toUpperCase()),
                          ),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.name} is already a user'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                // Create New Member Section
                const Divider(height: 32),
                if (!showCreateForm) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => showCreateForm = true),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Create New Member'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Create New Member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number *',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => showCreateForm = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty ||
                                emailController.text.isEmpty ||
                                phoneController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fill all required fields',
                                  ),
                                ),
                              );
                              return;
                            }

                            // Create temporary password
                            final tempPassword =
                                'Temp@${DateTime.now().millisecondsSinceEpoch}';

                            try {
                              // Create user in Firebase Auth
                              final userCredential = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: tempPassword,
                                  );

                              // Create user document
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userCredential.user!.uid)
                                  .set({
                                    'name': nameController.text.trim(),
                                    'email': emailController.text.trim(),
                                    'phoneNumber': phoneController.text.trim(),
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                              if (!context.mounted) return;

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${nameController.text} added successfully!',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                ),
                              );
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              ),
            ),
          ),
          actions: [
            if (!showCreateForm)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.user.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateGroupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Add Group'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
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
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Balance Summary
        StreamBuilder<List<GroupModel>>(
          stream: _groupService.getUserGroups(currentUserId ?? ''),
          builder: (context, groupSnapshot) {
            return StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getUserExpenses(currentUserId ?? ''),
              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Your Balance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const [
                              _SummaryItem(
                                title: 'You owe',
                                amount: '\$0.00',
                                color: Colors.red,
                              ),
                              _SummaryItem(
                                title: 'You are owed',
                                amount: '\$0.00',
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final expenses = expenseSnapshot.data ?? [];
                final activeGroups = groupSnapshot.data ?? [];
                final activeGroupIds = activeGroups.map((g) => g.id).toSet();

                // Filter out expenses from deleted groups
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

                // Map groups to their currencies
                final Map<String, String> groupCurrencies = {};
                for (var group in activeGroups) {
                  groupCurrencies[group.id] = group.currency;
                }

                // Get settlements to include in balance calculation
                return StreamBuilder<List<SettlementModel>>(
                  stream: _settlementService.getUserSettlements(
                    currentUserId ?? '',
                  ),
                  builder: (context, settlementSnapshot) {
                    final allSettlements = settlementSnapshot.data ?? [];

                    // Re-initialize maps inside settlement StreamBuilder
                    final Map<String, double> youOweByCurrency = {};
                    final Map<String, double> youAreOwedByCurrency = {};

                    // Group settlements by groupId
                    final Map<String, List<SettlementModel>>
                    settlementsByGroup = {};
                    for (var settlement in allSettlements) {
                      if (!settlementsByGroup.containsKey(settlement.groupId)) {
                        settlementsByGroup[settlement.groupId] = [];
                      }
                      settlementsByGroup[settlement.groupId]!.add(settlement);
                    }

                    for (var entry in expensesByGroup.entries) {
                      final groupId = entry.key;
                      final groupExpenses = entry.value;
                      final currency = groupCurrencies[groupId] ?? 'USD';
                      final groupSettlements =
                          settlementsByGroup[groupId] ?? [];

                      final balances = <String, double>{};
                      for (var expense in groupExpenses) {
                        balances[expense.paidBy] =
                            (balances[expense.paidBy] ?? 0) + expense.amount;
                        for (var personId in expense.splitBetween) {
                          final shareAmount = expense.getShareForUser(personId);
                          balances[personId] =
                              (balances[personId] ?? 0) - shareAmount;
                        }
                      }

                      // Apply settlements to balances
                      for (var settlement in groupSettlements) {
                        balances[settlement.paidBy] =
                            (balances[settlement.paidBy] ?? 0) +
                            settlement.amount;
                        balances[settlement.paidTo] =
                            (balances[settlement.paidTo] ?? 0) -
                            settlement.amount;
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

                    // Determine display format based on number of currencies
                    final allCurrencies = {
                      ...youOweByCurrency.keys,
                      ...youAreOwedByCurrency.keys,
                    }.toList();
                    final bool multipleCurrencies = allCurrencies.length > 1;

                    // Calculate totals (for single currency or primary display)
                    String oweDisplay, owedDisplay, totalDisplay;
                    Color totalColor;

                    if (multipleCurrencies) {
                      // Show "Multiple" for mixed currencies
                      oweDisplay = youOweByCurrency.isEmpty ? '0' : 'Multiple';
                      owedDisplay = youAreOwedByCurrency.isEmpty
                          ? '0'
                          : 'Multiple';
                      totalDisplay = 'Multiple Currencies';
                      totalColor = Colors.grey;
                    } else if (allCurrencies.isNotEmpty) {
                      // Single currency - show with proper symbol
                      final currency = allCurrencies.first;
                      final youOwe = youOweByCurrency[currency] ?? 0.0;
                      final youAreOwed = youAreOwedByCurrency[currency] ?? 0.0;
                      final totalBalance = youAreOwed - youOwe;

                      oweDisplay = AppConstants.formatAmount(youOwe, currency);
                      owedDisplay = AppConstants.formatAmount(
                        youAreOwed,
                        currency,
                      );
                      totalDisplay = totalBalance >= 0
                          ? '+${AppConstants.formatAmount(totalBalance, currency)}'
                          : AppConstants.formatAmount(totalBalance, currency);
                      totalColor = totalBalance >= 0
                          ? Colors.green
                          : Colors.red;
                    } else {
                      // No balances
                      oweDisplay = '\$0.00';
                      owedDisplay = '\$0.00';
                      totalDisplay = '\$0.00';
                      totalColor = Colors.grey;
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Your Balance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SummaryItem(
                                  title: 'You owe',
                                  amount: oweDisplay,
                                  color: Colors.red,
                                ),
                                _SummaryItem(
                                  title: 'You are owed',
                                  amount: owedDisplay,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            if (multipleCurrencies) ...[
                              const SizedBox(height: 12),
                              // Show breakdown by currency
                              ...allCurrencies.map((currency) {
                                final owe = youOweByCurrency[currency] ?? 0.0;
                                final owed =
                                    youAreOwedByCurrency[currency] ?? 0.0;
                                if (owe == 0 && owed == 0)
                                  return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (owe > 0) ...[
                                        Text(
                                          'Owe ${AppConstants.formatAmount(owe, currency)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (owed > 0)
                                        Text(
                                          'Owed ${AppConstants.formatAmount(owed, currency)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Total Balance: ',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  totalDisplay,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: totalColor,
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
          },
        ),
        const SizedBox(height: 16),

        // Groups Overview
        StreamBuilder<List<GroupModel>>(
          stream: _groupService.getUserGroups(currentUserId ?? ''),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final groups = groupSnapshot.data ?? [];

            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = 1); // Switch to Groups tab
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Groups',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${groups.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        groups.isEmpty
                            ? 'Create your first group to start splitting expenses'
                            : 'Total members: ${groups.fold<int>(0, (sum, g) => sum + g.members.length)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Recent Activity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedIndex = 3); // Switch to Expenses tab
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        StreamBuilder<List<ExpenseModel>>(
          stream: _expenseService.getUserExpenses(currentUserId ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snapshot.error}'),
                ),
              );
            }

            final expenses = snapshot.data ?? [];

            if (expenses.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No expenses yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a group and add expenses to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show only last 5 expenses
            final recentExpenses = expenses.take(5).toList();

            return Column(
              children: recentExpenses.map((expense) {
                return StreamBuilder<GroupModel?>(
                  stream: Stream.fromFuture(
                    _groupService.getGroup(expense.groupId),
                  ),
                  builder: (context, groupSnapshot) {
                    final group = groupSnapshot.data;

                    // Skip if group is deleted
                    if (groupSnapshot.connectionState == ConnectionState.done &&
                        group == null) {
                      return const SizedBox.shrink();
                    }

                    final groupName = group?.name ?? 'Loading...';
                    final currency = group?.currency ?? 'USD';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          child: Icon(
                            Icons.receipt,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        title: Text(
                          expense.description,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppConstants.formatAmount(
                                expense.amount,
                                currency,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              expense.paidBy == currentUserId
                                  ? 'You paid'
                                  : 'Split',
                              style: TextStyle(
                                fontSize: 11,
                                color: expense.paidBy == currentUserId
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GroupDetailsScreen(groupId: expense.groupId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    return const GroupsScreen();
  }

  Widget _buildExpensesTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.getUserGroups(currentUserId ?? ''),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = groupSnapshot.data ?? [];
        final activeGroupIds = groups.map((g) => g.id).toSet();

        return StreamBuilder<List<ExpenseModel>>(
          stream: _expenseService.getUserExpenses(currentUserId ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading expenses',
                        style: TextStyle(fontSize: 18, color: Colors.red[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final allExpenses = snapshot.data ?? [];
            // Filter out expenses from deleted groups
            final expenses = allExpenses
                .where((expense) => activeGroupIds.contains(expense.groupId))
                .toList();

            if (expenses.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group and add expenses to get started',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(
                            () => _selectedIndex = 1,
                          ); // Switch to Groups tab
                        },
                        icon: const Icon(Icons.group),
                        label: const Text('View Groups'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Group expenses by month
            final Map<String, List<ExpenseModel>> expensesByMonth = {};
            for (var expense in expenses) {
              final monthKey = '${expense.date.month}/${expense.date.year}';
              if (!expensesByMonth.containsKey(monthKey)) {
                expensesByMonth[monthKey] = [];
              }
              expensesByMonth[monthKey]!.add(expense);
            }

            final sortedMonths = expensesByMonth.keys.toList()
              ..sort((a, b) {
                final aParts = a.split('/');
                final bParts = b.split('/');
                final aDate = DateTime(
                  int.parse(aParts[1]),
                  int.parse(aParts[0]),
                );
                final bDate = DateTime(
                  int.parse(bParts[1]),
                  int.parse(bParts[0]),
                );
                return bDate.compareTo(aDate);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedMonths.length + 1, // +1 for header
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Summary header - Calculate amounts by currency
                  final totalExpenses = expenses.length;

                  // Group amounts by currency for expenses you paid
                  final Map<String, double> amountsByCurrency = {};
                  for (var expense in expenses.where(
                    (e) => e.paidBy == currentUserId,
                  )) {
                    final group = groups.firstWhere(
                      (g) => g.id == expense.groupId,
                    );
                    final currency = group.currency;
                    amountsByCurrency[currency] =
                        (amountsByCurrency[currency] ?? 0) + expense.amount;
                  }

                  return Card(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'All Expenses',
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
                              Column(
                                children: [
                                  Text(
                                    '$totalExpenses',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Total Expenses',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 50,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              Column(
                                children: [
                                  if (amountsByCurrency.isEmpty)
                                    Text(
                                      AppConstants.formatAmount(0, 'USD'),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    )
                                  else
                                    ...amountsByCurrency.entries.map(
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
                                                amountsByCurrency.length > 1
                                                ? 24
                                                : 32,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    'You Paid',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final monthKey = sortedMonths[index - 1];
                final monthExpenses = expensesByMonth[monthKey]!;
                final monthParts = monthKey.split('/');
                final monthNames = [
                  '',
                  'January',
                  'February',
                  'March',
                  'April',
                  'May',
                  'June',
                  'July',
                  'August',
                  'September',
                  'October',
                  'November',
                  'December',
                ];
                final monthName =
                    '${monthNames[int.parse(monthParts[0])]} ${monthParts[1]}';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...monthExpenses.map((expense) {
                      return StreamBuilder<GroupModel?>(
                        stream: Stream.fromFuture(
                          _groupService.getGroup(expense.groupId),
                        ),
                        builder: (context, groupSnapshot) {
                          final group = groupSnapshot.data;

                          // Skip if group is deleted
                          if (groupSnapshot.connectionState ==
                                  ConnectionState.done &&
                              group == null) {
                            return const SizedBox.shrink();
                          }

                          final groupName = group?.name ?? 'Loading...';
                          final currency = group?.currency ?? 'USD';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.receipt,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              title: Text(
                                expense.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  if (expense.category != null)
                                    Text(
                                      expense.category!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppConstants.formatAmount(
                                      expense.amount,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    expense.paidBy == currentUserId
                                        ? 'You paid'
                                        : '${AppConstants.formatAmount(expense.getShareAmount(), currency)} your share',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: expense.paidBy == currentUserId
                                          ? Colors.green[700]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupDetailsScreen(
                                      groupId: expense.groupId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettleTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<GroupModel>>(
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No settlements yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create groups and add expenses to see who owes whom',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
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
              return StreamBuilder<List<ExpenseModel>>(
                stream: _expenseService.getUserExpenses(currentUserId ?? ''),
                builder: (context, expenseSnapshot) {
                  if (!expenseSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final expenses = expenseSnapshot.data ?? [];
                  final activeGroupIds = groups.map((g) => g.id).toSet();

                  // Filter out expenses from deleted groups
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

                  // Get settlements for all groups
                  return StreamBuilder<List<SettlementModel>>(
                    stream: _settlementService.getUserSettlements(
                      currentUserId ?? '',
                    ),
                    builder: (context, allSettlementsSnapshot) {
                      final allSettlements = allSettlementsSnapshot.data ?? [];

                      // Re-initialize maps inside the settlement StreamBuilder
                      final Map<String, double> youOweByCurrency = {};
                      final Map<String, double> youAreOwedByCurrency = {};

                      // Group settlements by groupId
                      final Map<String, List<SettlementModel>>
                      settlementsByGroup = {};
                      for (var settlement in allSettlements) {
                        if (!settlementsByGroup.containsKey(
                          settlement.groupId,
                        )) {
                          settlementsByGroup[settlement.groupId] = [];
                        }
                        settlementsByGroup[settlement.groupId]!.add(settlement);
                      }

                      for (var groupId in expensesByGroup.keys) {
                        final groupExpenses = expensesByGroup[groupId]!;
                        final group = groups.firstWhere((g) => g.id == groupId);
                        final currency = group.currency;
                        final groupSettlements =
                            settlementsByGroup[groupId] ?? [];

                        final balances = <String, double>{};
                        for (var expense in groupExpenses) {
                          balances[expense.paidBy] =
                              (balances[expense.paidBy] ?? 0) + expense.amount;
                          for (var personId in expense.splitBetween) {
                            final shareAmount = expense.getShareForUser(
                              personId,
                            );
                            balances[personId] =
                                (balances[personId] ?? 0) - shareAmount;
                          }
                        }

                        // Apply settlements
                        for (var settlement in groupSettlements) {
                          balances[settlement.paidBy] =
                              (balances[settlement.paidBy] ?? 0) +
                              settlement.amount;
                          balances[settlement.paidTo] =
                              (balances[settlement.paidTo] ?? 0) -
                              settlement.amount;
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: Text(
                                                AppConstants.formatAmount(
                                                  entry.value,
                                                  entry.key,
                                                ),
                                                style: TextStyle(
                                                  fontSize:
                                                      youOweByCurrency.length >
                                                          1
                                                      ? 22
                                                      : 28,
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
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 50,
                                    width: 1,
                                    color: Colors.grey[300],
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: Text(
                                                AppConstants.formatAmount(
                                                  entry.value,
                                                  entry.key,
                                                ),
                                                style: TextStyle(
                                                  fontSize:
                                                      youAreOwedByCurrency
                                                              .length >
                                                          1
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
                                            color: Colors.grey[600],
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

            final group = groups[index - 1];

            return StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getGroupExpenses(group.id),
              builder: (context, expenseSnapshot) {
                return StreamBuilder<List<SettlementModel>>(
                  stream: _settlementService.getGroupSettlements(group.id),
                  builder: (context, settlementSnapshot) {
                    if (!expenseSnapshot.hasData ||
                        !settlementSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final expenses = expenseSnapshot.data ?? [];
                    final settlements = settlementSnapshot.data ?? [];

                    if (expenses.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    // Calculate balances from expenses
                    final balances = <String, double>{};
                    for (var expense in expenses) {
                      balances[expense.paidBy] =
                          (balances[expense.paidBy] ?? 0) + expense.amount;
                      for (var personId in expense.splitBetween) {
                        final shareAmount = expense.getShareForUser(personId);
                        balances[personId] =
                            (balances[personId] ?? 0) - shareAmount;
                      }
                    }

                    // Apply settlements
                    for (var settlement in settlements) {
                      balances[settlement.paidBy] =
                          (balances[settlement.paidBy] ?? 0) +
                          settlement.amount;
                      balances[settlement.paidTo] =
                          (balances[settlement.paidTo] ?? 0) -
                          settlement.amount;
                    }

                    final myBalance = balances[currentUserId] ?? 0.0;

                    if (myBalance == 0) {
                      return const SizedBox.shrink(); // Skip if settled
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
                        subtitle: Text(
                          myBalance < 0
                              ? 'You owe ${AppConstants.formatAmount(-myBalance, group.currency)}'
                              : 'You are owed ${AppConstants.formatAmount(myBalance, group.currency)}',
                          style: TextStyle(
                            color: myBalance < 0
                                ? Colors.red[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Icon(
                          myBalance < 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
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
                                  if (balance == 0)
                                    return const SizedBox.shrink();

                                  return FutureBuilder<UserModel?>(
                                    future: () async {
                                      final doc = await FirebaseFirestore
                                          .instance
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
                                          userSnapshot.data?.name ??
                                          'Loading...';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .primaryColor
                                                          .withOpacity(0.1),
                                                  child: Text(
                                                    userName.isNotEmpty
                                                        ? userName[0]
                                                              .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  memberId == currentUserId
                                                      ? 'You'
                                                      : userName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              balance < 0
                                                  ? 'owes ${AppConstants.formatAmount(-balance, group.currency)}'
                                                  : 'gets ${AppConstants.formatAmount(balance, group.currency)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: balance < 0
                                                    ? Colors.red[700]
                                                    : Colors.green[700],
                                              ),
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
                                          if (result == true) {
                                            // Settlement recorded, UI will update automatically
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.check_circle,
                                          size: 20,
                                        ),
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
                                                  GroupDetailsScreen(
                                                    groupId: group.id,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.visibility,
                                          size: 20,
                                        ),
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
          },
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
