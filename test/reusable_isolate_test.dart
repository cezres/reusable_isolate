import 'package:flutter_test/flutter_test.dart';

import 'package:reusable_isolate/reusable_isolate.dart';

void main() {
  test('compute', () async {
    final result = await reusableCompute((message) => message * 10, 2);
    expect(result, 20);
  });

  test('compute with cache', () async {
    final result1 = await reusableCompute((message) {
      return cache.putIfAbsent('key1', () => message * 10);
    }, 2);
    expect(result1, 20);

    final result2 = await reusableCompute((message) {
      /// Will hit the cache so no double counting is done
      return cache.putIfAbsent('key1', () => message * 20);
    }, 2);

    /// The result should be the same as the first one
    expect(result2, 20);
  });

  group('Test caches', () {
    test('cache', () async {
      final cache = ValueCacheImpl();
      final result1 = await cache.putIfAbsent('key1', () => 10);
      expect(result1, 10);

      final result2 = await cache.putIfAbsent('key1', () => 20);
      expect(result2, 10);
    });

    test('cache with Object.hashAll', () async {
      final cache = ValueCacheImpl();
      final result1 = await cache.putIfAbsent('key1', () => 10, objects: [1]);
      expect(result1, 10);

      final result2 = await cache.putIfAbsent('key1', () => 20, objects: [1]);
      expect(result2, 10);

      final result3 = await cache.putIfAbsent('key2', () => 30, objects: [2]);
      expect(result3, 30);
    });

    // test('cache with expiration', () async {
    //   final cache = ValueCache();
    //   final result1 =
    //       cache.putIfAbsent('key1', () => 10, expiration: Duration(seconds: 1));
    // });
  });
}
