import 'package:shared_preferences/shared_preferences.dart';

class EmailNotificationService {
  static const String _addedToGroupKey = 'email_notif_added_to_group';
  static const String _expenseAddedKey = 'email_notif_expense_added';
  static const String _expenseUpdatedKey = 'email_notif_expense_updated';
  static const String _settlementRecordedKey = 'email_notif_settlement_recorded';
  static const String _groupUpdatedKey = 'email_notif_group_updated';
  static const String _memberAddedKey = 'email_notif_member_added';
  static const String _weeklyDigestKey = 'email_notif_weekly_digest';
  static const String _monthlyReportKey = 'email_notif_monthly_report';

  // Get notification settings
  Future<bool> isAddedToGroupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_addedToGroupKey) ?? true; // Default enabled
  }

  Future<bool> isExpenseAddedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expenseAddedKey) ?? true;
  }

  Future<bool> isExpenseUpdatedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expenseUpdatedKey) ?? true;
  }

  Future<bool> isSettlementRecordedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_settlementRecordedKey) ?? true;
  }

  Future<bool> isGroupUpdatedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_groupUpdatedKey) ?? true;
  }

  Future<bool> isMemberAddedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memberAddedKey) ?? true;
  }

  Future<bool> isWeeklyDigestEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weeklyDigestKey) ?? false; // Default disabled
  }

  Future<bool> isMonthlyReportEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monthlyReportKey) ?? false; // Default disabled
  }

  // Set notification settings
  Future<void> setAddedToGroupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_addedToGroupKey, enabled);
  }

  Future<void> setExpenseAddedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expenseAddedKey, enabled);
  }

  Future<void> setExpenseUpdatedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expenseUpdatedKey, enabled);
  }

  Future<void> setSettlementRecordedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settlementRecordedKey, enabled);
  }

  Future<void> setGroupUpdatedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_groupUpdatedKey, enabled);
  }

  Future<void> setMemberAddedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memberAddedKey, enabled);
  }

  Future<void> setWeeklyDigestEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklyDigestKey, enabled);
  }

  Future<void> setMonthlyReportEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monthlyReportKey, enabled);
  }

  // Get all settings at once
  Future<Map<String, bool>> getAllSettings() async {
    return {
      'addedToGroup': await isAddedToGroupEnabled(),
      'expenseAdded': await isExpenseAddedEnabled(),
      'expenseUpdated': await isExpenseUpdatedEnabled(),
      'settlementRecorded': await isSettlementRecordedEnabled(),
      'groupUpdated': await isGroupUpdatedEnabled(),
      'memberAdded': await isMemberAddedEnabled(),
      'weeklyDigest': await isWeeklyDigestEnabled(),
      'monthlyReport': await isMonthlyReportEnabled(),
    };
  }

  // Enable all notifications
  Future<void> enableAll() async {
    await setAddedToGroupEnabled(true);
    await setExpenseAddedEnabled(true);
    await setExpenseUpdatedEnabled(true);
    await setSettlementRecordedEnabled(true);
    await setGroupUpdatedEnabled(true);
    await setMemberAddedEnabled(true);
    await setWeeklyDigestEnabled(true);
    await setMonthlyReportEnabled(true);
  }

  // Disable all notifications
  Future<void> disableAll() async {
    await setAddedToGroupEnabled(false);
    await setExpenseAddedEnabled(false);
    await setExpenseUpdatedEnabled(false);
    await setSettlementRecordedEnabled(false);
    await setGroupUpdatedEnabled(false);
    await setMemberAddedEnabled(false);
    await setWeeklyDigestEnabled(false);
    await setMonthlyReportEnabled(false);
  }
}
