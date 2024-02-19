part of 'reusable_isolate.dart';

class ReusableIsolateImpl extends ReusableIsolate {
  static final Map<String, ReusableIsolateImpl> _reuseableIsolates = {};

  factory ReusableIsolateImpl(String label) =>
      _reuseableIsolates.putIfAbsent(label, () => ReusableIsolateImpl._(label));

  ReusableIsolateImpl._(super.label) : super._() {
    _receivePort.listen((message) => _onResult(message));
  }

  Isolate? _isolate;
  SendPort? _sendPort;
  ValueCache? _cache;
  bool _disposed = false;
  bool _isolateStarted = false;
  final _completers = <int, Completer>{};
  final _receivePort = ReceivePort();
  final List<ReusableIsolateTask> _waiting = [];

  @override
  Future<R> compute<M, R>(ComputeCallback<M, R> callback, M message) {
    final completer = Completer<R>();
    final task = ReusableIsolateTask(callback, message);
    _completers[task.id] = completer;

    if (_sendPort != null) {
      _sendPort!.send(task);
    } else {
      _waiting.add(task);
      _runIsolate();
    }

    return completer.future;
  }

  void dispose() {
    _reuseableIsolates.remove(label);
    if (!_disposed) {
      _disposed = true;
      _isolate?.kill(priority: Isolate.immediate);
      _receivePort.close();
    }
  }

  void _runIsolate() async {
    if (_isolateStarted) {
      return;
    }
    _isolateStarted = true;
    _isolate = await Isolate.spawn(
      _resuableIsolateEntry,
      ResuableIsolateEntryValues(_receivePort.sendPort, _cache),
      debugName: 'ReusableIsolate',
    );
  }

  void _onResult(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      for (var element in _waiting) {
        message.send(element);
      }
      _waiting.clear();
    } else if (message is ReusableIsolateResult) {
      final completer = _completers.remove(message.id);
      if (completer != null) {
        if (message.success) {
          completer.complete(message.result);
        } else {
          completer.completeError(message.success);
        }
      }
    } else if (message is ReusableIsolateExit) {
      _isolateStarted = false;
      _sendPort = null;
      _cache = message.cache;
      for (var element in _completers.values) {
        element.completeError('Isolate exited');
      }
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

final class ReusableIsolateExit {
  ReusableIsolateExit(this.cache);
  final ValueCache? cache;
}

final class ResuableIsolateEntryValues {
  ResuableIsolateEntryValues(this.sendPort, this.cache);
  final SendPort sendPort;
  final ValueCache? cache;
}

void _resuableIsolateEntry(ResuableIsolateEntryValues values) async {
  final receivePort = ReceivePort();
  final sendPort = values.sendPort;
  if (values.cache != null) {
    ValueCacheImpl._instance = values.cache;
  }

  sendPort.send(receivePort.sendPort);

  var lastTaskId = -1;
  await for (var element in receivePort) {
    if (element is ReusableIsolateTask) {
      lastTaskId = element.id;
      try {
        final result = await element.run();
        sendPort.send(ReusableIsolateResult(element.id, true, result).encode());
      } catch (e) {
        sendPort.send(ReusableIsolateResult(element.id, false, e).encode());
      }
      Future.delayed(const Duration(seconds: 5)).whenComplete(() {
        if (lastTaskId == element.id) {
          receivePort.close();

          /// 5 秒后没有新任务则退出 isolate，退出时将缓存返回
          Isolate.exit(sendPort, ReusableIsolateExit(ValueCacheImpl._instance));
        }
      });
    }
  }
}

final class ValueCacheImpl extends ValueCache {
  static ValueCache? _instance;
  static ValueCache get instance => _instance ??= ValueCacheImpl();

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
