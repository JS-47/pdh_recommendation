import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class UserPopularity {
  final String userId;
  final String username;
  final int totalLikes;
  final String? avatarUrl;
  final DateTime? lastUpdated;

  const UserPopularity({
    required this.userId,
    required this.username,
    required this.totalLikes,
    this.avatarUrl,
    this.lastUpdated,
  });

  factory UserPopularity.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _fromMap(doc.id, doc.data());
  }

  factory UserPopularity.fromDocSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return _fromMap(doc.id, doc.data() ?? {});
  }

  UserPopularity copyWith({
    String? userId,
    String? username,
    int? totalLikes,
    String? avatarUrl,
    DateTime? lastUpdated,
  }) {
    return UserPopularity(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      totalLikes: totalLikes ?? this.totalLikes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static UserPopularity _fromMap(String id, Map<String, dynamic> data) {
    final usernameRaw = data['username'];
    final avatarRaw = data['avatarUrl'];
    final updatedRaw = data['lastUpdated'];

    DateTime? lastUpdated;
    if (updatedRaw is Timestamp) {
      lastUpdated = updatedRaw.toDate();
    } else if (updatedRaw is DateTime) {
      lastUpdated = updatedRaw;
    } else if (updatedRaw is String) {
      lastUpdated = DateTime.tryParse(updatedRaw);
    }

    final totalLikes = _parseLikes(data['totalLikes']);

    return UserPopularity(
      userId: id,
      username: (usernameRaw is String && usernameRaw.trim().isNotEmpty)
          ? usernameRaw
          : 'Deleted User',
      totalLikes: totalLikes,
      avatarUrl: avatarRaw is String && avatarRaw.isNotEmpty ? avatarRaw : null,
      lastUpdated: lastUpdated,
    );
  }

  static int _parseLikes(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
