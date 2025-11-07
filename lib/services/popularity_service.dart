import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_popularity.dart';

enum PopularityWindow { week, month, all }

extension PopularityWindowExtension on PopularityWindow {
  String get cacheKey => name;

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case PopularityWindow.week:
        final weekday = now.weekday; // Monday = 1
        final difference = Duration(days: weekday - DateTime.monday);
        final start = DateTime(now.year, now.month, now.day).subtract(difference);
        return DateTime(start.year, start.month, start.day);
      case PopularityWindow.month:
        return DateTime(now.year, now.month, 1);
      case PopularityWindow.all:
        return null;
    }
  }

  String get label {
    switch (this) {
      case PopularityWindow.week:
        return 'This Week';
      case PopularityWindow.month:
        return 'This Month';
      case PopularityWindow.all:
        return 'All Time';
    }
  }
}

@immutable
class PopularityCursor {
  final int totalLikes;
  final String userId;

  const PopularityCursor({
    required this.totalLikes,
    required this.userId,
  });
}

@immutable
class RankedPopularity {
  final UserPopularity user;
  final int? rank;

  const RankedPopularity({
    required this.user,
    required this.rank,
  });

  RankedPopularity copyWith({
    UserPopularity? user,
    int? rank,
  }) {
    return RankedPopularity(
      user: user ?? this.user,
      rank: rank ?? this.rank,
    );
  }
}

@immutable
class LeaderboardPage {
  final List<RankedPopularity> entries;
  final PopularityCursor? cursor;
  final int? totalCount;
  final RankedPopularity? myEntry;
  final int processed;
  final int? lastLikes;
  final int? lastRank;
  final bool fromCache;

  const LeaderboardPage({
    required this.entries,
    required this.cursor,
    required this.totalCount,
    required this.myEntry,
    required this.processed,
    required this.lastLikes,
    required this.lastRank,
    required this.fromCache,
  });

  LeaderboardPage copyWith({
    List<RankedPopularity>? entries,
    PopularityCursor? cursor,
    int? totalCount,
    RankedPopularity? myEntry,
    int? processed,
    int? lastLikes,
    int? lastRank,
    bool? fromCache,
  }) {
    return LeaderboardPage(
      entries: entries ?? this.entries,
      cursor: cursor ?? this.cursor,
      totalCount: totalCount ?? this.totalCount,
      myEntry: myEntry ?? this.myEntry,
      processed: processed ?? this.processed,
      lastLikes: lastLikes ?? this.lastLikes,
      lastRank: lastRank ?? this.lastRank,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

abstract class PopularityRepository {
  Future<LeaderboardPage> fetchLeaderboardPage({
    required PopularityWindow window,
    int limit,
    PopularityCursor? cursor,
    int offset,
    int? lastLikes,
    int? lastRank,
    bool bypassCache,
  });

  void clearCache(PopularityWindow window);
}

class PopularityService implements PopularityRepository {
  PopularityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _cacheDuration = Duration(seconds: 60);
  final Map<String, _CachedLeaderboard> _cache = {};

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('userPopularity');

  @override
  Future<LeaderboardPage> fetchLeaderboardPage({
    required PopularityWindow window,
    int limit = 20,
    PopularityCursor? cursor,
    int offset = 0,
    int? lastLikes,
    int? lastRank,
    bool bypassCache = false,
  }) async {
    final shouldUseCache = !bypassCache && cursor == null && offset == 0;
    final cacheKey = '${window.cacheKey}:$limit';
    final now = DateTime.now();

    if (shouldUseCache) {
      final cached = _cache[cacheKey];
      if (cached != null && now.difference(cached.timestamp) < _cacheDuration) {
        return cached.page.copyWith(fromCache: true);
      }
    }

    final query = _baseQuery(window)
        .orderBy('totalLikes', descending: true)
        .orderBy('userId')
        .limit(limit);

    final effectiveQuery = cursor == null
        ? query
        : query.startAfter([cursor.totalLikes, cursor.userId]);

    final snapshot = await effectiveQuery.get();
    final docs = snapshot.docs;

    final likesList = docs.map((doc) => _readLikes(doc.data())).toList();
    final ranks = computeRanks(
      likes: likesList,
      offset: offset,
      previousLikes: lastLikes,
      previousRank: lastRank,
    );

    final entries = <RankedPopularity>[];
    for (var i = 0; i < docs.length; i++) {
      final record = UserPopularity.fromFirestore(docs[i]);
      entries.add(RankedPopularity(
        user: record,
        rank: ranks[i],
      ));
    }

    final nextCursor = docs.isNotEmpty
        ? PopularityCursor(
            totalLikes: _readLikes(docs.last.data()),
            userId: docs.last.id,
          )
        : null;

    RankedPopularity? myEntry;
    int? totalCount;
    int? trailingLikes;
    int? trailingRank;

    if (entries.isNotEmpty) {
      trailingLikes = entries.last.user.totalLikes;
      trailingRank = entries.last.rank;
    } else {
      trailingLikes = lastLikes;
      trailingRank = lastRank;
    }

    if (cursor == null && offset == 0) {
      myEntry = await _resolveMyEntry(window, seed: entries);
      totalCount = await _countForWindow(window);
    }

    final page = LeaderboardPage(
      entries: entries,
      cursor: nextCursor,
      totalCount: totalCount,
      myEntry: myEntry,
      processed: offset + entries.length,
      lastLikes: trailingLikes,
      lastRank: trailingRank,
      fromCache: false,
    );

    if (shouldUseCache) {
      _cache[cacheKey] = _CachedLeaderboard(page: page, timestamp: now);
    }

    return page;
  }

  @override
  void clearCache(PopularityWindow window) {
    _cache.removeWhere((key, _) => key.startsWith('${window.cacheKey}:'));
  }

  Query<Map<String, dynamic>> _baseQuery(PopularityWindow window) {
    final startDate = window.startDate;
    Query<Map<String, dynamic>> query = _collection;
    if (startDate != null) {
      query = query.where(
        'lastUpdated',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    return query;
  }

  Future<int?> _countForWindow(PopularityWindow window) async {
    try {
      final aggregate = await _baseQuery(window).count().get();
      return aggregate.count;
    } catch (_) {
      return null;
    }
  }

  Future<RankedPopularity?> _resolveMyEntry(
    PopularityWindow window, {
    List<RankedPopularity> seed = const [],
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    final seeded = seed.where((entry) => entry.user.userId == currentUser.uid);
    if (seeded.isNotEmpty) {
      return seeded.first;
    }

    final doc = await _collection.doc(currentUser.uid).get();
    if (!doc.exists) {
      return null;
    }

    final record = UserPopularity.fromDocSnapshot(doc);

    final startDate = window.startDate;
    if (startDate != null) {
      final updated = record.lastUpdated;
      if (updated == null || updated.isBefore(startDate)) {
        return RankedPopularity(
          user: record.copyWith(totalLikes: 0),
          rank: null,
        );
      }
    }

    final orderedQuery = _baseQuery(window)
        .orderBy('totalLikes', descending: true)
        .orderBy('userId');

    Query<Map<String, dynamic>> pagedQuery = orderedQuery.limit(100);
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

    var processed = 0;
    int? previousLikes;
    int? previousRank;

    while (true) {
      if (lastDoc != null) {
        pagedQuery = orderedQuery
            .startAfter([
              _readLikes(lastDoc.data()),
              lastDoc.id,
            ])
            .limit(100);
      }

      final snapshot = await pagedQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      for (final doc in snapshot.docs) {
        processed++;
        final record = UserPopularity.fromFirestore(doc);
        final likes = record.totalLikes;
        final rank = _rankForPosition(
          position: processed,
          likes: likes,
          previousLikes: previousLikes,
          previousRank: previousRank,
        );
        if (record.userId == currentUser.uid) {
          return RankedPopularity(user: record, rank: rank);
        }
        previousLikes = likes;
        previousRank = rank;
      }

      lastDoc = snapshot.docs.last;
    }

    return RankedPopularity(
      user: record.copyWith(totalLikes: 0),
      rank: null,
    );
  }

  static int _readLikes(Map<String, dynamic> data) {
    final value = data['totalLikes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int _rankForPosition({
    required int position,
    required int likes,
    required int? previousLikes,
    required int? previousRank,
  }) {
    if (previousLikes == null || previousLikes != likes) {
      return position;
    }
    return previousRank ?? position;
  }

  @visibleForTesting
  static List<int?> computeRanks({
    required List<int> likes,
    int offset = 0,
    int? previousLikes,
    int? previousRank,
  }) {
    final ranks = <int?>[];
    var processed = offset;
    var lastLikes = previousLikes;
    var lastRank = previousRank;

    for (final likesValue in likes) {
      processed++;
      if (lastLikes == null || lastLikes != likesValue) {
        lastRank = processed;
      }
      ranks.add(lastRank);
      lastLikes = likesValue;
    }
    return ranks;
  }
}

class _CachedLeaderboard {
  final LeaderboardPage page;
  final DateTime timestamp;

  _CachedLeaderboard({
    required this.page,
    required this.timestamp,
  });
}
