import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdh_recommendation/models/user_popularity.dart';
import 'package:pdh_recommendation/services/popularity_service.dart';
import 'package:pdh_recommendation/widgets/dashboard_popularity_card.dart';

class _FakePopularityRepository implements PopularityRepository {
  _FakePopularityRepository({required this.onFetch});

  final Future<LeaderboardPage> Function({
    required PopularityWindow window,
    required int limit,
    PopularityCursor? cursor,
    required int offset,
    int? lastLikes,
    int? lastRank,
    required bool bypassCache,
  }) onFetch;

  @override
  Future<LeaderboardPage> fetchLeaderboardPage({
    required PopularityWindow window,
    int limit = 20,
    PopularityCursor? cursor,
    int offset = 0,
    int? lastLikes,
    int? lastRank,
    bool bypassCache = false,
  }) {
    return onFetch(
      window: window,
      limit: limit,
      cursor: cursor,
      offset: offset,
      lastLikes: lastLikes,
      lastRank: lastRank,
      bypassCache: bypassCache,
    );
  }

  @override
  void clearCache(PopularityWindow window) {}
}

RankedPopularity _entry({
  required String id,
  required String name,
  required int likes,
  required int rank,
}) {
  return RankedPopularity(
    user: UserPopularity(
      userId: id,
      username: name,
      totalLikes: likes,
      lastUpdated: DateTime.now(),
    ),
    rank: rank,
  );
}

LeaderboardPage _page({
  required List<RankedPopularity> entries,
  RankedPopularity? me,
  int? totalCount,
  int? lastLikes,
  int? lastRank,
}) {
  return LeaderboardPage(
    entries: entries,
    cursor: null,
    totalCount: totalCount,
    myEntry: me,
    processed: entries.length,
    lastLikes: lastLikes ?? (entries.isNotEmpty ? entries.last.user.totalLikes : null),
    lastRank: lastRank ?? (entries.isNotEmpty ? entries.last.rank : null),
    fromCache: false,
  );
}

void main() {
  testWidgets('PopularityDrawer renders empty state', (tester) async {
    final repository = _FakePopularityRepository(
      onFetch: ({
        required PopularityWindow window,
        required int limit,
        PopularityCursor? cursor,
        required int offset,
        int? lastLikes,
        int? lastRank,
        required bool bypassCache,
      }) async {
        return _page(entries: [], totalCount: 0);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PopularityDrawer(
          service: repository,
          initialWindow: PopularityWindow.week,
          currentUserId: 'user-1',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('No popularity data found. Be the first to collect some likes!'),
      findsOneWidget,
    );
  });

  testWidgets('PopularityDrawer pins my rank outside the visible page', (tester) async {
    final entries = [
      _entry(id: 'user-a', name: 'Alice', likes: 120, rank: 1),
      _entry(id: 'user-b', name: 'Bob', likes: 110, rank: 2),
    ];
    final me = _entry(id: 'user-me', name: 'Me', likes: 12, rank: 8);

    final repository = _FakePopularityRepository(
      onFetch: ({
        required PopularityWindow window,
        required int limit,
        PopularityCursor? cursor,
        required int offset,
        int? lastLikes,
        int? lastRank,
        required bool bypassCache,
      }) async {
        return _page(entries: entries, me: me, totalCount: 12);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PopularityDrawer(
          service: repository,
          initialWindow: PopularityWindow.week,
          seededEntry: me,
          currentUserId: 'user-me',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('My Rank'), findsOneWidget);
    expect(find.text('Not ranked yet'), findsNothing);
  });
}
