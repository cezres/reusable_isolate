library reusable_isolate;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

part 'cache.dart';

/// 后台运行 [callback] 使用提供的 [message] 并返回结果
/// [label] Isolate 的重用标签
Future<R> reusableCompute<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String label = 'default',
}) {
  return ReusableIsolate(label).compute(callback, message);
}

abstract class ReusableIsolate {
  static final Map<String, ReusableIsolate> _reuseableIsolates = {};
  ReusableIsolate._(this.label);

  /// 重用标签
  final String label;

  factory ReusableIsolate(String label) =>
      _reuseableIsolates.putIfAbsent(label, () => ReusableIsolateImpl._(label));

  Future<R> compute<M, R>(ComputeCallback<M, R> callback, M message);

  void dispose() {
    _reuseableIsolates.remove(label);
  }
}

class ReusableIsolateImpl extends ReusableIsolate {
  ReusableIsolateImpl._(super.label) : super._() {
    _resultReceivePort.listen((message) => _onResult(message));
    _exitReceivePort.listen((message) => _onExit(message));
    _errorReceivePort.listen((message) => _onError(message));
  }

  Isolate? _isolate;
  SendPort? _sendPort;
  ValueCache? _cache;
  bool _disposed = false;
  final _completers = <int, Completer>{};
  final _resultReceivePort = ReceivePort();
  final _exitReceivePort = ReceivePort();
  final _errorReceivePort = ReceivePort();

  @override
  Future<R> compute<M, R>(ComputeCallback<M, R> callback, M message) {
    final completer = Completer<R>();
    final task = ReusableIsolateTask(callback, message);
    _completers[task.id] = completer;

    if (_sendPort != null) {
      _sendPort!.send(task);
    } else {
      _runIsolate(task);
    }

    return completer.future;
  }

  @override
  void dispose() {
    super.dispose();
    if (!_disposed) {
      _disposed = true;
      _isolate?.kill(priority: Isolate.immediate);
      _resultReceivePort.close();
      _exitReceivePort.close();
      _errorReceivePort.close();
    }
  }

  void _runIsolate(ReusableIsolateTask task) async {
    _isolate = await Isolate.spawn(
      _resuableIsolateEntry,
      ResuableIsolateEntryValues(_resultReceivePort.sendPort, _cache, task),
      onExit: _exitReceivePort.sendPort,
      onError: _errorReceivePort.sendPort,
      debugName: 'ReusableIsolate',
    );
  }

  void _onResult(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
    } else if (message is ReusableIsolateResult) {
      final completer = _completers.remove(message.id);
      if (completer != null) {
        if (message.success) {
          completer.complete(message.result);
        } else {
          completer.completeError(message.success);
        }
      }
    }
  }

  void _onExit(ValueCache? cache) {
    _sendPort = null;
    _cache = cache;
  }

  void _onError(Object error) {
    _sendPort = null;
    for (var element in _completers.values) {
      element.completeError(error);
    }
  }
}

int _taskId = 0;
int get _nextTaskId => _taskId++;

final class ReusableIsolateTask<M, R> {
  ReusableIsolateTask(this.callback, this.message) : id = _nextTaskId;
  final int id;
  final ComputeCallback<M, R> callback;
  final M message;

  FutureOr<R> run() => callback(message);

  /// TODO: 支持 TransferableTypedData
  TypedData? encode() => null;
}

final class ReusableIsolateResult {
  ReusableIsolateResult(this.id, this.success, this.result);
  final int id;
  final bool success;
  final dynamic result;

  dynamic encode() => this;
}

final class ResuableIsolateEntryValues {
  ResuableIsolateEntryValues(this.sendPort, this.cache, this.task);
  final SendPort sendPort;
  final ValueCache? cache;
  final ReusableIsolateTask task;
}

Future<ValueCache?> _resuableIsolateEntry(
    ResuableIsolateEntryValues values) async {
  final sendPort = values.sendPort;

  Future runTask(ReusableIsolateTask task) async {
    try {
      final result = await task.run();
      sendPort.send(ReusableIsolateResult(task.id, true, result).encode());
    } catch (e) {
      sendPort.send(ReusableIsolateResult(task.id, false, e).encode());
    }
  }

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  await runTask(values.task);

  await for (var element in receivePort) {
    await runTask(element);
  }

  /// 在 isolate 退出时将缓存返回
  return ValueCache._instance;
}
