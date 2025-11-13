import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/GroupModel.dart';
import '../../models/UserModel.dart';
import '../../services/settlement_service.dart';
import '../../constants/currencies.dart';

class RecordSettlementScreen extends StatefulWidget {
  final GroupModel group;
  final Map<String, double> balances;

  const RecordSettlementScreen({
    super.key,
    required this.group,
    required this.balances,
  });

  @override
  State<RecordSettlementScreen> createState() => _RecordSettlementScreenState();
}

class _RecordSettlementScreenState extends State<RecordSettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _settlementService = SettlementService();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _selectedPaidBy;
  String? _selectedPaidTo;
  DateTime _selectedDate = DateTime.now();
  List<UserModel> _members = [];
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
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

      setState(() {
        _members = membersData.whereType<UserModel>().toList();
        _isLoadingMembers = false;
        _preselectUsers();
      });
    } catch (e) {
      print('Error loading members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _preselectUsers() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Find who owes the most and who is owed the most
    String? maxOwesUser;
    String? maxOwedUser;
    double maxOwes = 0;
    double maxOwed = 0;

    widget.balances.forEach((userId, balance) {
      if (balance < maxOwes) {
        maxOwes = balance;
        maxOwesUser = userId;
      }
      if (balance > maxOwed) {
        maxOwed = balance;
        maxOwedUser = userId;
      }
    });

    // Preselect based on current user's balance
    final myBalance = widget.balances[currentUserId] ?? 0.0;

    if (myBalance < 0 && maxOwedUser != null) {
      // Current user owes money, preselect them as payer to who is owed most
      _selectedPaidBy = currentUserId;
      _selectedPaidTo = maxOwedUser;
      _amountController.text = (-myBalance).toStringAsFixed(2);
    } else if (myBalance > 0 && maxOwesUser != null) {
      // Current user is owed money, preselect who owes most to pay current user
      _selectedPaidBy = maxOwesUser;
      _selectedPaidTo = currentUserId;
      _amountController.text = myBalance.toStringAsFixed(2);
    } else if (maxOwesUser != null && maxOwedUser != null) {
      // Current user is settled, preselect the largest imbalance
      _selectedPaidBy = maxOwesUser;
      _selectedPaidTo = maxOwedUser;
      _amountController.text = (-maxOwes).toStringAsFixed(2);
    }
  }

  Future<void> _recordSettlement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPaidBy == null || _selectedPaidTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both payer and receiver'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPaidBy == _selectedPaidTo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payer and receiver cannot be the same person'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final settlementId = await _settlementService.createSettlement(
        groupId: widget.group.id,
        paidBy: _selectedPaidBy!,
        paidTo: _selectedPaidTo!,
        amount: double.parse(_amountController.text.trim()),
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      print('Settlement recorded: $settlementId');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Balance settled successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error recording settlement: $e');
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
        appBar: AppBar(title: const Text('Settle Balance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Balance'),
        backgroundColor: Colors.green,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Settle Balance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Already paid someone outside the app (cash, UPI, bank transfer)? Record it here to settle the balance.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tip: Click on suggested amounts to settle full balance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money),
                prefixText:
                    '${AppConstants.getCurrencySymbol(widget.group.currency)} ',
                border: const OutlineInputBorder(),
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
            ),

            const SizedBox(height: 16),

            // Date
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Payment Date'),
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
            ),

            const SizedBox(height: 24),

            // Paid By
            const Text(
              'Who Paid? (Select the person who sent money)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._members.map((member) {
              final balance = widget.balances[member.uid] ?? 0.0;
              final owesAmount = balance < 0 ? -balance : 0.0;
              return Card(
                color: _selectedPaidBy == member.uid
                    ? Colors.green.withOpacity(0.1)
                    : null,
                child: RadioListTile<String>(
                  title: Row(
                    children: [
                      Expanded(child: Text(member.name)),
                      if (balance < 0 && _selectedPaidBy == member.uid)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _amountController.text = owesAmount
                                  .toStringAsFixed(2);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppConstants.formatAmount(
                                    owesAmount,
                                    widget.group.currency,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.email, style: const TextStyle(fontSize: 12)),
                      if (balance != 0)
                        Text(
                          balance < 0
                              ? 'Owes ${AppConstants.formatAmount(-balance, widget.group.currency)}'
                              : 'Owed ${AppConstants.formatAmount(balance, widget.group.currency)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: balance < 0
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                    ],
                  ),
                  value: member.uid,
                  groupValue: _selectedPaidBy,
                  onChanged: (value) {
                    setState(() => _selectedPaidBy = value);
                  },
                ),
              );
            }),

            const SizedBox(height: 24),

            // Paid To
            const Text(
              'Paid To? (Select the person who received money)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._members.map((member) {
              final balance = widget.balances[member.uid] ?? 0.0;
              final owedAmount = balance > 0 ? balance : 0.0;
              return Card(
                color: _selectedPaidTo == member.uid
                    ? Colors.blue.withOpacity(0.1)
                    : null,
                child: RadioListTile<String>(
                  title: Row(
                    children: [
                      Expanded(child: Text(member.name)),
                      if (balance > 0 && _selectedPaidTo == member.uid)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _amountController.text = owedAmount
                                  .toStringAsFixed(2);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppConstants.formatAmount(
                                    owedAmount,
                                    widget.group.currency,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.email, style: const TextStyle(fontSize: 12)),
                      if (balance != 0)
                        Text(
                          balance < 0
                              ? 'Owes ${AppConstants.formatAmount(-balance, widget.group.currency)}'
                              : 'Owed ${AppConstants.formatAmount(balance, widget.group.currency)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: balance < 0
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                    ],
                  ),
                  value: member.uid,
                  groupValue: _selectedPaidTo,
                  onChanged: (value) {
                    setState(() => _selectedPaidTo = value);
                  },
                ),
              );
            }),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any additional details',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 24),

            // Settle Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _recordSettlement,
                icon: _isLoading
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
                    : const Icon(Icons.check_circle),
                label: const Text(
                  'Settle Balance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
