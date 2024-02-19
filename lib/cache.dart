part of 'reusable_isolate.dart';

/// 获取缓存实例，不同的 Isolate 会返回不同的缓存实例
/// 在 [reusableCompute] 的 [callback] 函数中调用时，对应的 Isolate 退出后缓存依然会被保留
ValueCache get cache => ValueCache.instance;

abstract class ValueCache {
  static ValueCache? _instance;
  static ValueCache get instance => _instance ??= ValueCacheImpl();

  /// 如果缓存中存在 [key] 则返回缓存中的值，否则调用 [ifAbsent] 并将结果存入缓存
  /// [objects] 可选值，用于检查缓存是否有效，使用 [Object.hashAll] 生成 hashCode
  /// [ifAbsent] 生成缓存值的回调
  FutureOr<R> putIfAbsent<R>(
    String key,
    FutureOr<R> Function() ifAbsent, {
    List<Object?>? objects,
  });

  void put<R>(String key, dynamic value, {List<Object?>? objects});

  void clear();

  operator [](String key);
}

final class ValueCacheImpl extends ValueCache {
  final Map<String, dynamic> _cache = {};
  final Map<String, int?> _hashCodes = {};

  @override
  FutureOr<R> putIfAbsent<R>(String key, FutureOr<R> Function() ifAbsent,
      {List<Object?>? objects}) async {
    final hashCode = objects == null ? null : Object.hashAll(objects);
    if (_cache.containsKey(key)) {
      if (_hashCodes[key] == hashCode) {
        // f.debugPrint('cache hit: $key');
        return _cache[key];
      }
    }
    final value = await ifAbsent();
    return put(key, value, objects: objects);
  }

  @override
  dynamic put<R>(String key, value, {List<Object?>? objects}) {
    final hashCode = objects == null ? null : Object.hashAll(objects);
    _cache[key] = value;
    _hashCodes[key] = hashCode;
    return value;
  }

  @override
  operator [](String key) => _cache[key];

  @override
  void clear() {
    _cache.clear();
    _hashCodes.clear();
  }
}
