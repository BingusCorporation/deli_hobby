/// Performance monitoring utilities for debugging and optimization
class PerformanceMonitor {
  static final Map<String, Stopwatch> _stopwatches = {};

  /// Start monitoring a named operation
  static void start(String name) {
    if (!_stopwatches.containsKey(name)) {
      _stopwatches[name] = Stopwatch();
    }
    _stopwatches[name]!.start();
  }

  /// Stop monitoring and get duration in milliseconds
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

  /// Log operation duration
  static void log(String name, int durationMs) {
    if (durationMs > 100) {
      print('⏱️ Slow operation: "$name" took ${durationMs}ms');
    } else {
      print('✓ Operation: "$name" took ${durationMs}ms');
    }
  }

  /// Clear all stopwatches
  static void clear() {
    _stopwatches.clear();
  }

  /// Get all recorded operations
  static Map<String, Stopwatch> get stopwatches => _stopwatches;
}

/// Extension to easily measure async operations
extension PerformanceExtension on Future {
  /// Measure and log the duration of a future
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
