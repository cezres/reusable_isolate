# ReusableIsolate

简化执行高频计算任务的代码，与`compute`接口参数一致。

- 复用 Isolate，使用 SendPort 传递数据。
- 创建的 Isolate 将在闲置 5 秒钟后退出。
- 可缓存任务执行过程中的数据，下次使用相同的标签调用 `reusableCompute` 函数执行任务时缓存依然会存在，无论 Isolate 是否因为闲置退出过。

## 示例

#### 执行一个任务
```dart
complexTaskExample(int value) => value.toString();

final result = await reusableCompute(complexTaskExample, 100);
expect(result, '100');
```

#### 执行多个任务并使用缓存的计算结果
```dart
final result1 = await reusableCompute((message) {
  return cache.putIfAbsent('key1', () => complexTaskExample(message));
}, 100);
expect(result1, '100');

final result2 = await reusableCompute((message) {
  return cache.putIfAbsent('key1', () => complexTaskExample(message));
}, 200);
// 由于使用了相同的缓存key，应该命中缓存，不会重新执行任务，结果与第一个相同
expect(result2, '100');
```


## 关键接口

```dart
/// 使用 [message] 在后台运行 [callback] 并返回结果
/// [label] Isolate 的重用标签
Future<R> reusableCompute<M, R>(
  FutureOr<R> Function(M) callback,
  M message, {
  String label = 'default',
})

/// 获取缓存实例，不同的 Isolate 会返回不同的缓存实例
/// 在 [reusableCompute] 的 [callback] 函数中调用时，对应的 Isolate 退出后缓存依然会被保留
ValueCache get cache => ValueCache.instance;

abstract class ValueCache {
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
```


