library reusable_isolate;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

part 'impls.dart';

/// 后台运行 [callback] 使用提供的 [message] 并返回结果
/// [label] Isolate 的重用标签
Future<R> reusableCompute<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String label = 'default',
}) {
  return ReusableIsolate(label).compute(callback, message);
}

/// 获取缓存实例，不同的 Isolate 会返回不同的缓存实例
/// 在 [reusableCompute] 的 [callback] 函数中调用时，对应的 Isolate 退出后缓存依然会被保留
ValueCache get cache => ValueCacheImpl.instance;

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

abstract class ReusableIsolate {
  ReusableIsolate._(this.label);

  /// 重用标签
  final String label;

  factory ReusableIsolate(String label) => ReusableIsolateImpl(label);

  Future<R> compute<M, R>(ComputeCallback<M, R> callback, M message);

  // void dispose();
}
