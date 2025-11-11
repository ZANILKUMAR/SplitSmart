import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestFirebaseScreen extends StatefulWidget {
  const TestFirebaseScreen({super.key});

  @override
  State<TestFirebaseScreen> createState() => _TestFirebaseScreenState();
}

class _TestFirebaseScreenState extends State<TestFirebaseScreen> {
  String _status = 'Testing...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _status = 'Starting tests...\n';
      _isLoading = true;
    });

    try {
      // Test 1: Check Auth
      _addStatus('1. Checking Authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addStatus('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }
      _addStatus('✅ User logged in: ${user.email}');
      _addStatus('   User ID: ${user.uid}');

      // Test 2: Test Firestore Read
      _addStatus('\n2. Testing Firestore Read...');
      try {
        final testQuery = await FirebaseFirestore.instance
            .collection('groups')
            .limit(1)
            .get(const GetOptions(source: Source.server));
        _addStatus('✅ Firestore read successful');
        _addStatus('   Found ${testQuery.docs.length} documents');
      } catch (e) {
        _addStatus('❌ Firestore read failed: $e');
      }

      // Test 3: Test Firestore Write
      _addStatus('\n3. Testing Firestore Write...');
      try {
        final testDoc = FirebaseFirestore.instance
            .collection('test_collection')
            .doc('test_doc');

        await testDoc.set({
          'test': true,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
        });
        _addStatus('✅ Firestore write successful');

        // Clean up
        await testDoc.delete();
        _addStatus('✅ Test document cleaned up');
      } catch (e) {
        _addStatus('❌ Firestore write failed: $e');
        if (e.toString().contains('PERMISSION_DENIED')) {
          _addStatus('\n⚠️  PERMISSION DENIED ERROR DETECTED!');
          _addStatus('    You need to update Firestore security rules.');
          _addStatus('    See GROUP_TROUBLESHOOTING.md for instructions.');
        }
      }

      // Test 4: Try creating a group
      _addStatus('\n4. Testing Group Creation...');
      try {
        final groupRef = await FirebaseFirestore.instance
            .collection('groups')
            .add({
              'name': 'Test Group ${DateTime.now().millisecondsSinceEpoch}',
              'description': 'Automated test group',
              'createdBy': user.uid,
              'members': [user.uid],
              'createdAt': FieldValue.serverTimestamp(),
            });
        _addStatus('✅ Group created successfully!');
        _addStatus('   Group ID: ${groupRef.id}');

        // Clean up
        await groupRef.delete();
        _addStatus('✅ Test group cleaned up');
      } catch (e) {
        _addStatus('❌ Group creation failed: $e');
      }

      _addStatus('\n✅ All tests completed!');
    } catch (e) {
      _addStatus('\n❌ Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addStatus(String message) {
    setState(() {
      _status += '$message\n';
    });
    print(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Connection Test')),
      body: Column(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runTests,
                    child: const Text('Run Tests Again'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
