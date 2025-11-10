import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../models/ExpenseModel.dart';
import '../../services/expense_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;
  final ExpenseModel? expense; // Optional - if provided, edit mode

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.expense,
  });

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
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final shareAmount = _amountController.text.isEmpty ||
            _selectedSplitBetween.isEmpty
        ? 0.0
        : double.tryParse(_amountController.text)! / _selectedSplitBetween.length;

    final isEditMode = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Expense' : 'Add Expense'),
      ),
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
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              value: _selectedCategory,
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
            const Text(
              'Paid By',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._members.map((member) {
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(member.name),
                subtitle: Text(member.email, style: const TextStyle(fontSize: 12)),
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
                      if (_selectedSplitBetween.length == widget.group.members.length) {
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
                subtitle: Text(member.email, style: const TextStyle(fontSize: 12)),
                value: _selectedSplitBetween.contains(member.uid),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedSplitBetween.add(member.uid);
                    } else {
                      _selectedSplitBetween.remove(member.uid);
                    }
                  });
                },
              );
            }),

            if (_selectedSplitBetween.isNotEmpty && shareAmount > 0) ...[
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
                      '\$${shareAmount.toStringAsFixed(2)}',
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
