import 'package:flutter/material.dart';
import '../../services/email_notification_service.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final _emailNotificationService = EmailNotificationService();
  bool _isLoading = true;

  // Individual notification settings
  bool _addedToGroup = true;
  bool _expenseAdded = true;
  bool _expenseUpdated = true;
  bool _settlementRecorded = true;
  bool _groupUpdated = true;
  bool _memberAdded = true;
  bool _weeklyDigest = false;
  bool _monthlyReport = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await _emailNotificationService.getAllSettings();
      setState(() {
        _addedToGroup = settings['addedToGroup'] ?? true;
        _expenseAdded = settings['expenseAdded'] ?? true;
        _expenseUpdated = settings['expenseUpdated'] ?? true;
        _settlementRecorded = settings['settlementRecorded'] ?? true;
        _groupUpdated = settings['groupUpdated'] ?? true;
        _memberAdded = settings['memberAdded'] ?? true;
        _weeklyDigest = settings['weeklyDigest'] ?? false;
        _monthlyReport = settings['monthlyReport'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateSetting(
    Future<void> Function(bool) setter,
    bool newValue,
    String settingName,
  ) async {
    try {
      await setter(newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$settingName ${newValue ? 'enabled' : 'disabled'}'),
            duration: const Duration(seconds: 1),
            backgroundColor: newValue ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableAll() async {
    await _emailNotificationService.enableAll();
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All email notifications enabled'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _disableAll() async {
    await _emailNotificationService.disableAll();
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All email notifications disabled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Settings'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'enable_all') {
                _enableAll();
              } else if (value == 'disable_all') {
                _disableAll();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'enable_all',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 12),
                    Text('Enable All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'disable_all',
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 20),
                    SizedBox(width: 12),
                    Text('Disable All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Card
                Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Choose which email notifications you want to receive',
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Activity Notifications Section
                Text(
                  'Activity Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _addedToGroup,
                        onChanged: (value) {
                          setState(() => _addedToGroup = value);
                          _updateSetting(
                            _emailNotificationService.setAddedToGroupEnabled,
                            value,
                            'Added to group notifications',
                          );
                        },
                        title: const Text('Added to Group'),
                        subtitle: const Text(
                          'When someone adds you to a new group',
                        ),
                        secondary: const Icon(Icons.group_add),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _memberAdded,
                        onChanged: (value) {
                          setState(() => _memberAdded = value);
                          _updateSetting(
                            _emailNotificationService.setMemberAddedEnabled,
                            value,
                            'Member added notifications',
                          );
                        },
                        title: const Text('Member Added'),
                        subtitle: const Text(
                          'When a new member joins your group',
                        ),
                        secondary: const Icon(Icons.person_add),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _groupUpdated,
                        onChanged: (value) {
                          setState(() => _groupUpdated = value);
                          _updateSetting(
                            _emailNotificationService.setGroupUpdatedEnabled,
                            value,
                            'Group updated notifications',
                          );
                        },
                        title: const Text('Group Updated'),
                        subtitle: const Text(
                          'When group details or settings change',
                        ),
                        secondary: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Expense Notifications Section
                Text(
                  'Expense Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _expenseAdded,
                        onChanged: (value) {
                          setState(() => _expenseAdded = value);
                          _updateSetting(
                            _emailNotificationService.setExpenseAddedEnabled,
                            value,
                            'Expense added notifications',
                          );
                        },
                        title: const Text('Expense Added'),
                        subtitle: const Text(
                          'When an expense is added that involves you',
                        ),
                        secondary: const Icon(Icons.receipt_long),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _expenseUpdated,
                        onChanged: (value) {
                          setState(() => _expenseUpdated = value);
                          _updateSetting(
                            _emailNotificationService.setExpenseUpdatedEnabled,
                            value,
                            'Expense updated notifications',
                          );
                        },
                        title: const Text('Expense Updated'),
                        subtitle: const Text(
                          'When an expense you\'re part of is modified',
                        ),
                        secondary: const Icon(Icons.edit_note),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settlement Notifications Section
                Text(
                  'Settlement Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  child: SwitchListTile(
                    value: _settlementRecorded,
                    onChanged: (value) {
                      setState(() => _settlementRecorded = value);
                      _updateSetting(
                        _emailNotificationService.setSettlementRecordedEnabled,
                        value,
                        'Settlement recorded notifications',
                      );
                    },
                    title: const Text('Settlement Recorded'),
                    subtitle: const Text(
                      'When a settlement payment is recorded',
                    ),
                    secondary: const Icon(Icons.account_balance_wallet),
                  ),
                ),

                const SizedBox(height: 24),

                // Digest & Reports Section
                Text(
                  'Digests & Reports',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _weeklyDigest,
                        onChanged: (value) {
                          setState(() => _weeklyDigest = value);
                          _updateSetting(
                            _emailNotificationService.setWeeklyDigestEnabled,
                            value,
                            'Weekly digest',
                          );
                        },
                        title: const Text('Weekly Digest'),
                        subtitle: const Text(
                          'Summary of your activity every week',
                        ),
                        secondary: const Icon(Icons.calendar_today),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _monthlyReport,
                        onChanged: (value) {
                          setState(() => _monthlyReport = value);
                          _updateSetting(
                            _emailNotificationService.setMonthlyReportEnabled,
                            value,
                            'Monthly report',
                          );
                        },
                        title: const Text('Monthly Report'),
                        subtitle: const Text(
                          'Detailed monthly expense report',
                        ),
                        secondary: const Icon(Icons.assessment),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Additional Info
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Email Preferences',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Email notifications help you stay updated about group activities\n'
                          '• You can customize which events trigger emails\n'
                          '• All settings are saved automatically\n'
                          '• You can change these preferences anytime',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
