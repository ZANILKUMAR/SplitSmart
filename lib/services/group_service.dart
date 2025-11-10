import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/GroupModel.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    String? imageUrl,
    String currency = 'USD',
  }) async {
    try {
      print('GroupService: Creating group in Firestore...');
      print('GroupService: Name=$name, CreatedBy=$createdBy, Currency=$currency');
      
      // Create group document
      final groupRef = await _firestore.collection('groups').add({
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'members': [createdBy], // Creator is the first member
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'currency': currency,
      });

      print('GroupService: Group created with ID: ${groupRef.id}');
      return groupRef.id;
    } catch (e, stackTrace) {
      print('GroupService: Error creating group: $e');
      print('GroupService: Stack trace: $stackTrace');
      
      // Provide more specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Permission denied. Please check Firestore security rules.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      
      throw Exception('Failed to create group: $e');
    }
  }

  // Get all groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    try {
      return _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
        print('GroupService: Retrieved ${snapshot.docs.length} groups');
        final groups = snapshot.docs
            .map((doc) {
              try {
                return GroupModel.fromJson(doc.data(), doc.id);
              } catch (e) {
                print('GroupService: Error parsing group ${doc.id}: $e');
                return null;
              }
            })
            .whereType<GroupModel>()
            .toList();
        
        // Sort by createdAt in memory (to avoid index issues)
        groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return groups;
      });
    } catch (e) {
      print('GroupService: Error getting user groups: $e');
      return Stream.value([]);
    }
  }

  // Get a single group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get group: $e');
    }
  }

  // Update group details
  Future<void> updateGroup(String groupId, {
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      await _firestore.collection('groups').doc(groupId).update(updates);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  // Add member to group
  Future<void> addMember(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  // Remove member from group
  Future<void> removeMember(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  // Delete group
  Future<void> deleteGroup(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).delete();
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }
}
