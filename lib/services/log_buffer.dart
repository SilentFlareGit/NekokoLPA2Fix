import 'dart:collection';
import 'package:logging/logging.dart';

class LogBuffer {
  static final LogBuffer _instance = LogBuffer._internal();
  factory LogBuffer() => _instance;
  LogBuffer._internal() {
    Logger.root.onRecord.listen((record) {
      _logs.add(record);
      if (_logs.length > _maxLogs) {
        _logs.removeFirst();
      }
    });
  }

  final int _maxLogs = 1000;
  final Queue<LogRecord> _logs = Queue<LogRecord>();

  List<LogRecord> get logs => _logs.toList();

  void init() {
    // Just to trigger the singleton initialization
  }
}
