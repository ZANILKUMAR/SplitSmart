import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../models/ExpenseModel.dart';
import '../../services/expense_service.dart';
import '../../constants/currencies.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;
  final ExpenseModel? expense; // Optional - if provided, edit mode

  const AddExpenseScreen({super.key, required this.group, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _expenseService = ExpenseService();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _selectedPaidBy;
  List<String> _selectedSplitBetween = [];
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  List<UserModel> _members = [];
  bool _isLoadingMembers = true;
  SplitType _splitType = SplitType.equal;
  final Map<String, TextEditingController> _customAmountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  bool _showAllPaidByMembers = false;

  final List<String> _categories = [
    'Food & Drinks',
    'Transportation',
    'Accommodation',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Healthcare',
    'Other',
  ];

  final Map<String, IconData> _categoryIcons = {
    'Food & Drinks': Icons.restaurant,
    'Transportation': Icons.directions_car,
    'Accommodation': Icons.hotel,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_bag,
    'Utilities': Icons.bolt,
    'Healthcare': Icons.medical_services,
    'Other': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _initializeFormForEdit();
  }

  void _initializeFormForEdit() {
    if (widget.expense != null) {
      final expense = widget.expense!;
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toString();
      _notesController.text = expense.notes ?? '';
      _selectedPaidBy = expense.paidBy;
      _selectedSplitBetween = expense.splitBetween.toList();
      _selectedDate = expense.date;
      _selectedCategory = expense.category;
      _splitType = expense.splitType;

      // Initialize custom split controllers if needed
      if (expense.customSplits != null) {
        for (var entry in expense.customSplits!.entries) {
          if (_splitType == SplitType.unequal) {
            _customAmountControllers[entry.key] = TextEditingController(
              text: entry.value.toString(),
            );
          } else if (_splitType == SplitType.percentage) {
            _percentageControllers[entry.key] = TextEditingController(
              text: entry.value.toString(),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (var controller in _customAmountControllers.values) {
      controller.dispose();
    }
    for (var controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllersForMembers() {
    for (var member in _members) {
      if (_selectedSplitBetween.contains(member.uid)) {
        if (!_customAmountControllers.containsKey(member.uid)) {
          _customAmountControllers[member.uid] = TextEditingController();
        }
        if (!_percentageControllers.containsKey(member.uid)) {
          _percentageControllers[member.uid] = TextEditingController();
        }
      }
    }
  }

  Future<void> _loadMembers() async {
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

      final currentUser = FirebaseAuth.instance.currentUser;

      setState(() {
        _members = membersData.whereType<UserModel>().toList();
        _selectedPaidBy = currentUser?.uid;
        _selectedSplitBetween = widget.group.members.toList();
        _isLoadingMembers = false;
        _initializeControllersForMembers();
      });
    } catch (e) {
      print('Error loading members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPaidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who paid'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedSplitBetween.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one person to split with'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate custom splits
    Map<String, double>? customSplits;
    final totalAmount = double.parse(_amountController.text.trim());

    if (_splitType == SplitType.unequal) {
      customSplits = {};
      double sum = 0;
      for (var userId in _selectedSplitBetween) {
        final amountText = _customAmountControllers[userId]?.text.trim() ?? '';
        if (amountText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter amount for all selected members'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        final amount = double.tryParse(amountText);
        if (amount == null || amount < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter valid amounts'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        customSplits[userId] = amount;
        sum += amount;
      }
      if ((sum - totalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sum of amounts (${AppConstants.formatAmount(sum, widget.group.currency)}) must equal total (${AppConstants.formatAmount(totalAmount, widget.group.currency)})',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      customSplits = {};
      double sum = 0;
      for (var userId in _selectedSplitBetween) {
        final percentText = _percentageControllers[userId]?.text.trim() ?? '';
        if (percentText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter percentage for all selected members'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        final percent = double.tryParse(percentText);
        if (percent == null || percent < 0 || percent > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter valid percentages (0-100)'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        customSplits[userId] = percent;
        sum += percent;
      }
      if ((sum - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sum of percentages ($sum%) must equal 100%'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final isEditMode = widget.expense != null;

      if (isEditMode) {
        // Update existing expense
        await _expenseService.updateExpense(
          widget.expense!.id,
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          paidBy: _selectedPaidBy!,
          splitBetween: _selectedSplitBetween,
          date: _selectedDate,
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          splitType: _splitType,
          customSplits: customSplits,
        );

        print('Expense updated: ${widget.expense!.id}');

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new expense
        final expenseId = await _expenseService.createExpense(
          groupId: widget.group.id,
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          paidBy: _selectedPaidBy!,
          splitBetween: _selectedSplitBetween,
          date: _selectedDate,
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          splitType: _splitType,
          customSplits: customSplits,
        );

        print('Expense created: $expenseId');

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error saving expense: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

  double _calculateEnteredAmount() {
    double total = 0.0;
    for (var controller in _customAmountControllers.values) {
      final value = double.tryParse(controller.text) ?? 0.0;
      total += value;
    }
    return total;
  }

  double _calculateEnteredPercentage() {
    double total = 0.0;
    for (var controller in _percentageControllers.values) {
      final value = double.tryParse(controller.text) ?? 0.0;
      total += value;
    }
    return total;
  }

  Widget _buildAmountSummary() {
    final totalExpense = double.tryParse(_amountController.text) ?? 0.0;
    final enteredAmount = _calculateEnteredAmount();
    final remaining = totalExpense - enteredAmount;
    final isValid = (remaining.abs() < 0.01);
    final isOverLimit = remaining < -0.01;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Expense',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            Text(
              AppConstants.formatAmount(totalExpense, widget.group.currency),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entered',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            Text(
              AppConstants.formatAmount(enteredAmount, widget.group.currency),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isOverLimit ? Colors.red[700] : Colors.blue[700],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            Row(
              children: [
                Text(
                  AppConstants.formatAmount(
                    remaining.abs(),
                    widget.group.currency,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isValid
                        ? Colors.green[700]
                        : isOverLimit
                        ? Colors.red[700]
                        : Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isValid
                      ? Icons.check_circle
                      : isOverLimit
                      ? Icons.error
                      : Icons.warning,
                  size: 18,
                  color: isValid
                      ? Colors.green[700]
                      : isOverLimit
                      ? Colors.red[700]
                      : Colors.orange[700],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPercentageSummary() {
    final enteredPercentage = _calculateEnteredPercentage();
    final remaining = 100.0 - enteredPercentage;
    final isValid = (remaining.abs() < 0.01);
    final isOverLimit = remaining < -0.01;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Required',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            const Text(
              '100%',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entered',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            Text(
              '${enteredPercentage.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isOverLimit ? Colors.red[700] : Colors.blue[700],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            Row(
              children: [
                Text(
                  '${remaining.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isValid
                        ? Colors.green[700]
                        : isOverLimit
                        ? Colors.red[700]
                        : Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isValid
                      ? Icons.check_circle
                      : isOverLimit
                      ? Icons.error
                      : Icons.warning,
                  size: 18,
                  color: isValid
                      ? Colors.green[700]
                      : isOverLimit
                      ? Colors.red[700]
                      : Colors.orange[700],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final shareAmount =
        _amountController.text.isEmpty || _selectedSplitBetween.isEmpty
        ? 0.0
        : double.tryParse(_amountController.text)! /
              _selectedSplitBetween.length;

    final isEditMode = widget.expense != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What was this expense for?',
                prefixIcon: Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money),
                prefixText:
                    '${AppConstants.getCurrencySymbol(widget.group.currency)} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(_categoryIcons[category], size: 20),
                      const SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),

            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: const Text('Change'),
              ),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // Paid By
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paid By',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_members.length > 1)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAllPaidByMembers = !_showAllPaidByMembers;
                      });
                    },
                    icon: Icon(
                      _showAllPaidByMembers
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                    label: Text(
                      _showAllPaidByMembers ? 'Show Less' : 'Show All',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Show current user first (always visible)
            ...(() {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final currentUserMember = _members.firstWhere(
                (m) => m.uid == currentUserId,
                orElse: () => _members.first,
              );
              
              return [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Text(currentUserMember.name),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    currentUserMember.email,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: currentUserMember.uid,
                  groupValue: _selectedPaidBy,
                  onChanged: (value) {
                    setState(() => _selectedPaidBy = value);
                  },
                ),
              ];
            })(),
            // Show other members only when expanded
            if (_showAllPaidByMembers)
              ..._members.where((member) {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                return member.uid != currentUserId;
              }).map((member) {
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.name),
                  subtitle: Text(
                    member.email,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: member.uid,
                  groupValue: _selectedPaidBy,
                  onChanged: (value) {
                    setState(() => _selectedPaidBy = value);
                  },
                );
              }),

            const Divider(),
            const SizedBox(height: 8),

            // Split Between
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Split Between',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedSplitBetween.length ==
                          widget.group.members.length) {
                        _selectedSplitBetween.clear();
                      } else {
                        _selectedSplitBetween = widget.group.members.toList();
                      }
                    });
                  },
                  child: Text(
                    _selectedSplitBetween.length == widget.group.members.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._members.map((member) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.name),
                subtitle: Text(
                  member.email,
                  style: const TextStyle(fontSize: 12),
                ),
                value: _selectedSplitBetween.contains(member.uid),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedSplitBetween.add(member.uid);
                      _initializeControllersForMembers();
                    } else {
                      _selectedSplitBetween.remove(member.uid);
                    }
                  });
                },
              );
            }),

            const Divider(),
            const SizedBox(height: 8),

            // Split Type
            const Text(
              'Split Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<SplitType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Equally',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: SplitType.equal,
                    groupValue: _splitType,
                    onChanged: (value) {
                      setState(() => _splitType = value!);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<SplitType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Unequally',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: SplitType.unequal,
                    groupValue: _splitType,
                    onChanged: (value) {
                      setState(() => _splitType = value!);
                    },
                  ),
                ),
              ],
            ),
            RadioListTile<SplitType>(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'By Percentage',
                style: TextStyle(fontSize: 14),
              ),
              value: SplitType.percentage,
              groupValue: _splitType,
              onChanged: (value) {
                setState(() => _splitType = value!);
              },
            ),

            // Custom split inputs
            if (_splitType == SplitType.unequal &&
                _selectedSplitBetween.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter amount for each person:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedSplitBetween.map((userId) {
                      final member = _members.firstWhere(
                        (m) => m.uid == userId,
                      );
                      if (!_customAmountControllers.containsKey(userId)) {
                        _customAmountControllers[userId] =
                            TextEditingController();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          controller: _customAmountControllers[userId],
                          decoration: InputDecoration(
                            labelText: member.name,
                            prefixText:
                                '${AppConstants.getCurrencySymbol(widget.group.currency)} ',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          onChanged: (value) => setState(() {}),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildAmountSummary(),
                  ],
                ),
              ),
            ],

            if (_splitType == SplitType.percentage &&
                _selectedSplitBetween.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter percentage for each person (total must be 100%):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedSplitBetween.map((userId) {
                      final member = _members.firstWhere(
                        (m) => m.uid == userId,
                      );
                      if (!_percentageControllers.containsKey(userId)) {
                        _percentageControllers[userId] =
                            TextEditingController();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          controller: _percentageControllers[userId],
                          decoration: InputDecoration(
                            labelText: member.name,
                            suffixText: '%',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          onChanged: (value) => setState(() {}),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildPercentageSummary(),
                  ],
                ),
              ),
            ],

            if (_selectedSplitBetween.isNotEmpty &&
                _splitType == SplitType.equal &&
                shareAmount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Each person pays:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppConstants.formatAmount(
                        shareAmount,
                        widget.group.currency,
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any additional details',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 24),

            // Add/Update Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addExpense,
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
                    : Text(
                        isEditMode ? 'Update Expense' : 'Add Expense',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
