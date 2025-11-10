class AppConstants {
  // Supported currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': 'ر.س', 'name': 'Saudi Riyal'},
  ];

  static String getCurrencySymbol(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => currencies[0],
    );
    return currency['symbol']!;
  }

  static String getCurrencyName(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => currencies[0],
    );
    return currency['name']!;
  }

  // Helper function to format amount with currency
  static String formatAmount(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
