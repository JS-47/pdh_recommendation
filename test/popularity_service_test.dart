import 'package:flutter_test/flutter_test.dart';
import 'package:pdh_recommendation/services/popularity_service.dart';

void main() {
  group('PopularityService.computeRanks', () {
    test('assigns sequential ranks when likes are unique', () {
      final ranks = PopularityService.computeRanks(likes: [30, 20, 10]);
      expect(ranks, equals([1, 2, 3]));
    });

    test('gives identical likes the same rank', () {
      final ranks = PopularityService.computeRanks(likes: [40, 40, 35, 35, 30]);
      expect(ranks, equals([1, 1, 3, 3, 5]));
    });

    test('continues ranking when additional pages are loaded', () {
      final firstRanks = PopularityService.computeRanks(likes: [50, 40]);
      expect(firstRanks, equals([1, 2]));

      final nextRanks = PopularityService.computeRanks(
        likes: [40, 30],
        offset: 2,
        previousLikes: 40,
        previousRank: 2,
      );
      expect(nextRanks, equals([2, 4]));
    });
  });
}
