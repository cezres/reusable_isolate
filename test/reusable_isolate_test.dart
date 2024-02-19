import 'package:flutter_test/flutter_test.dart';

import 'package:reusable_isolate/reusable_isolate.dart';

void main() {
  group('reusableCompute', () {
    complexTaskExample(int value) => value.toString();

    test('compute', () async {
      final result = await reusableCompute(complexTaskExample, 100);
      expect(result, '100');
    });

    test('compute with cache', () async {
      final result1 = await reusableCompute((message) {
        return cache.putIfAbsent('key1', () => complexTaskExample(message));
      }, 100);
      expect(result1, '100');

      final result2 = await reusableCompute((message) {
        return cache.putIfAbsent('key1', () => complexTaskExample(message));
      }, 200);
      // 由于使用了相同的缓存key，应该命中缓存，不会重新执行任务，结果与第一个相同
      expect(result2, '100');
    });

    test('compute with isolate exit', () async {
      final result1 = await reusableCompute((message) {
        return cache.putIfAbsent('key1', () => complexTaskExample(message));
      }, 100);
      expect(result1, '100');

      // 等待 6 秒后，Isolate 退出
      await Future.delayed(const Duration(seconds: 6));

      final result2 = await reusableCompute((message) {
        return cache.putIfAbsent('key1', () => complexTaskExample(message));
      }, 200);
      // 即时 Isolate 退出，下次执行任务时缓存依然有效
      expect(result2, '100');
    });
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
