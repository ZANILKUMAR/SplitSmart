import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({super.key});

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  bool _isLoading = true;

  // Push notification settings
  bool _pushEnabled = true;
  bool _addedToGroup = true;
  bool _expenseAdded = true;
  bool _expenseUpdated = true;
  bool _settlementRecorded = true;
  bool _groupUpdated = true;
  bool _memberAdded = true;
  bool _reminders = true;
  bool _sound = true;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushEnabled = prefs.getBool('push_enabled') ?? true;
        _addedToGroup = prefs.getBool('push_added_to_group') ?? true;
        _expenseAdded = prefs.getBool('push_expense_added') ?? true;
        _expenseUpdated = prefs.getBool('push_expense_updated') ?? true;
        _settlementRecorded = prefs.getBool('push_settlement_recorded') ?? true;
        _groupUpdated = prefs.getBool('push_group_updated') ?? true;
        _memberAdded = prefs.getBool('push_member_added') ?? true;
        _reminders = prefs.getBool('push_reminders') ?? true;
        _sound = prefs.getBool('push_sound') ?? true;
        _vibration = prefs.getBool('push_vibration') ?? true;
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

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', true);
    await prefs.setBool('push_added_to_group', true);
    await prefs.setBool('push_expense_added', true);
    await prefs.setBool('push_expense_updated', true);
    await prefs.setBool('push_settlement_recorded', true);
    await prefs.setBool('push_group_updated', true);
    await prefs.setBool('push_member_added', true);
    await prefs.setBool('push_reminders', true);
    await prefs.setBool('push_sound', true);
    await prefs.setBool('push_vibration', true);

    await _loadSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All push notifications enabled'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _disableAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', false);
    await prefs.setBool('push_added_to_group', false);
    await prefs.setBool('push_expense_added', false);
    await prefs.setBool('push_expense_updated', false);
    await prefs.setBool('push_settlement_recorded', false);
    await prefs.setBool('push_group_updated', false);
    await prefs.setBool('push_member_added', false);
    await prefs.setBool('push_reminders', false);

    await _loadSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All push notifications disabled'),
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
        title: const Text('Push Notifications'),
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
                // Master Toggle
                Card(
                  color: _pushEnabled
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  child: SwitchListTile(
                    value: _pushEnabled,
                    onChanged: (value) {
                      setState(() => _pushEnabled = value);
                      _saveSetting('push_enabled', value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Push notifications enabled'
                                : 'Push notifications disabled',
                          ),
                          backgroundColor: value ? Colors.green : Colors.orange,
                        ),
                      );
                    },
                    title: const Text(
                      'Enable Push Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      _pushEnabled
                          ? 'You will receive push notifications'
                          : 'All push notifications are turned off',
                    ),
                    secondary: Icon(
                      _pushEnabled ? Icons.notifications_active : Icons.notifications_off,
                      color: _pushEnabled ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                  ),
                ),

                if (!_pushEnabled) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enable push notifications to receive real-time updates',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_pushEnabled) ...[
                  const SizedBox(height: 24),

                  // Activity Notifications
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
                            _saveSetting('push_added_to_group', value);
                          },
                          title: const Text('Added to Group'),
                          subtitle: const Text('When someone adds you to a group'),
                          secondary: const Icon(Icons.group_add),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _memberAdded,
                          onChanged: (value) {
                            setState(() => _memberAdded = value);
                            _saveSetting('push_member_added', value);
                          },
                          title: const Text('Member Added'),
                          subtitle: const Text('When a new member joins'),
                          secondary: const Icon(Icons.person_add),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _groupUpdated,
                          onChanged: (value) {
                            setState(() => _groupUpdated = value);
                            _saveSetting('push_group_updated', value);
                          },
                          title: const Text('Group Updated'),
                          subtitle: const Text('When group details change'),
                          secondary: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Expense Notifications
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
                            _saveSetting('push_expense_added', value);
                          },
                          title: const Text('Expense Added'),
                          subtitle: const Text('When an expense involves you'),
                          secondary: const Icon(Icons.receipt_long),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _expenseUpdated,
                          onChanged: (value) {
                            setState(() => _expenseUpdated = value);
                            _saveSetting('push_expense_updated', value);
                          },
                          title: const Text('Expense Updated'),
                          subtitle: const Text('When an expense is modified'),
                          secondary: const Icon(Icons.edit_note),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settlement & Reminders
                  Text(
                    'Settlements & Reminders',
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
                          value: _settlementRecorded,
                          onChanged: (value) {
                            setState(() => _settlementRecorded = value);
                            _saveSetting('push_settlement_recorded', value);
                          },
                          title: const Text('Settlement Recorded'),
                          subtitle: const Text('When a payment is recorded'),
                          secondary: const Icon(Icons.account_balance_wallet),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _reminders,
                          onChanged: (value) {
                            setState(() => _reminders = value);
                            _saveSetting('push_reminders', value);
                          },
                          title: const Text('Payment Reminders'),
                          subtitle: const Text('Reminders for pending payments'),
                          secondary: const Icon(Icons.alarm),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Notification Style
                  Text(
                    'Notification Style',
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
                          value: _sound,
                          onChanged: (value) {
                            setState(() => _sound = value);
                            _saveSetting('push_sound', value);
                          },
                          title: const Text('Sound'),
                          subtitle: const Text('Play sound for notifications'),
                          secondary: const Icon(Icons.volume_up),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _vibration,
                          onChanged: (value) {
                            setState(() => _vibration = value);
                            _saveSetting('push_vibration', value);
                          },
                          title: const Text('Vibration'),
                          subtitle: const Text('Vibrate for notifications'),
                          secondary: const Icon(Icons.vibration),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Card
                  Card(
                    color: Colors.blue.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'About Push Notifications',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Get instant updates about your groups and expenses\n'
                            '• Customize which events trigger notifications\n'
                            '• All settings are saved automatically',
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
              ],
            ),
    );
  }
}
