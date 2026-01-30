
class PerformanceMonitor {
  static final Map<String, Stopwatch> _stopwatches = {};


  static void start(String name) {
    if (!_stopwatches.containsKey(name)) {
      _stopwatches[name] = Stopwatch();
    }
    _stopwatches[name]!.start();
  }


  static int stop(String name) {
    final stopwatch = _stopwatches[name];
    if (stopwatch == null) {
      print('Warning: Stopwatch "$name" not found');
      return 0;
    }
    
    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;
    
    if (duration > 100) {
      print('⏱️ Slow operation detected: "$name" took ${duration}ms');
    }
    
    stopwatch.reset();
    return duration;
  }

  static void log(String name, int durationMs) {
    if (durationMs > 100) {
      print('⏱️ Slow operation: "$name" took ${durationMs}ms');
    } else {
      print('✓ Operation: "$name" took ${durationMs}ms');
    }
  }

  static void clear() {
    _stopwatches.clear();
  }

  static Map<String, Stopwatch> get stopwatches => _stopwatches;
}

extension PerformanceExtension on Future {

  Future<T> withPerformanceMonitoring<T>(String operationName) async {
    PerformanceMonitor.start(operationName);
    try {
      final result = await this as T;
      PerformanceMonitor.stop(operationName);
      return result;
    } catch (e) {
      PerformanceMonitor.stop(operationName);
      rethrow;
    }
  }
}
