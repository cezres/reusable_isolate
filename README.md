# ReusableIsolate

创建可重用的 Isolate，同时在隔离内启用数据缓存，简化执行高频并行计算任务的代码。

## Usage

```dart
final result = await reusableCompute(
  (message, cache) => cache.putIfAbsent('key1', () => message * 10), 2
);
expect(result, 20);
```


```dart
/// 使用 [message] 在后台运行 [callback] 并返回结果
/// [label] Isolate 的重用标签
Future<R> reusableCompute<M, R>(
  FutureOr<R> Function(M, ValueCache) callback,
  M message, {
  String label = 'default',
})

/// 如果缓存中存在 [key] 则返回缓存中的值，否则调用 [ifAbsent] 并将结果存入缓存
/// [objects] 可选值，用于检查缓存是否有效，使用 [Object.hashAll] 生成 hashCode
/// [ifAbsent] 生成缓存值的回调
FutureOr<R> putIfAbsent<R>(
  String key,
  FutureOr<R> Function() ifAbsent, {
  List<Object?>? objects,
})
```


