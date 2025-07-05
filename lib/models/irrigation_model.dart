import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

class MoistureRecord {
  final DateTime timestamp;
  final int moistureValue;
  final String soilStatus;

  MoistureRecord({
    required this.timestamp,
    required this.moistureValue,
    required this.soilStatus,
  });

  // Add operator [] to support accessing properties like a Map
  dynamic operator [](String key) {
    switch (key) {
      case 'timestamp':
        return timestamp;
      case 'moistureValue':
        return moistureValue;
      case 'soilStatus':
        return soilStatus;
      default:
        throw ArgumentError('Key "$key" not found in MoistureRecord');
    }
  }

  // Convert to Map for easy serialization
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'moistureValue': moistureValue,
      'soilStatus': soilStatus,
    };
  }

  // Create from Map
  factory MoistureRecord.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    try {
      final timestampValue = map['timestamp'];
      int? timestampInt;

      // Convert value to integer regardless of initial type (String or int)
      if (timestampValue is String) {
        timestampInt = int.tryParse(timestampValue);
      } else if (timestampValue is int) {
        timestampInt = timestampValue;
      }

      if (timestampInt != null) {
        // Check if the timestamp is in seconds (usually a 10-digit number)
        // vs. milliseconds (usually a 13-digit number).
        if (timestampInt < 10000000000) { // A simple check for seconds-based timestamps
          // If it's seconds, multiply by 1000 to convert to milliseconds.
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampInt * 1000);
        } else {
          // If it's already milliseconds, use it directly.
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampInt);
        }
      } else {
        // Fallback if timestamp is null or not a valid number format
        timestamp = DateTime.now();
      }
    } catch (e) {
      print('Error parsing timestamp: $e. Defaulting to current time.');
      timestamp = DateTime.now();
    }

    return MoistureRecord(
      timestamp: timestamp,
      // Handle both 'moisture' (from ESP32) and 'moistureValue' (legacy/app)
      moistureValue: map['moisture'] ?? map['moistureValue'] ?? 0,
      soilStatus: map['soilStatus'] ?? 'unknown',
    );
  }
}

class IrrigationModel with ChangeNotifier {
  final FirebaseService _firebaseService;
  Timer? _localPumpTimer;

  // State variables
  bool _isLoading = true;
  int _moistureValue = 0;
  String _soilStatus = 'unknown';
  bool _pumpStatus = false;
  bool _autoMode = true;
  List<MoistureRecord> _moistureHistory = [];
  int? _pumpTimer; // Timer in seconds from Firebase
  int _localTimerValue = 0; // Local counter for UI

  // Getters
  bool get isLoading => _isLoading;
  int get moistureValue => _moistureValue;
  String get soilStatus => _soilStatus;
  bool get pumpStatus => _pumpStatus;
  bool get autoMode => _autoMode;
  List<MoistureRecord> get moistureHistory => _moistureHistory;
  int? get pumpTimer => _pumpTimer;
  int get localTimerValue => _localTimerValue;
  bool get isTimerActive => _pumpTimer != null && _pumpTimer! > 0;

  IrrigationModel(this._firebaseService) {
    // Set timer backup jika onHistoryUpdated tidak terpanggil
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
        debugPrint("Fallback: _isLoading di-set false setelah timeout");
      }
    });

    _firebaseService.subscribeToIrrigationData(
      onMoistureChanged: (value) {
        _moistureValue = value;
        notifyListeners();
      },
      onSoilStatusChanged: (status) {
        _soilStatus = status;
        notifyListeners();
      },
      onPumpStatusChanged: (status) {
        _pumpStatus = status;
        notifyListeners();
      },
      onAutoModeChanged: (mode) {
        _autoMode = mode;
        notifyListeners();
      },
      onHistoryUpdated: (history) {
        // The history data is now a List<Map<String, dynamic>>
        _moistureHistory = history
            .map<MoistureRecord>((item) {
              if (item is Map) {
                return MoistureRecord.fromMap(Map<String, dynamic>.from(item));
              }
              return MoistureRecord(
                timestamp: DateTime.now(),
                moistureValue: 0,
                soilStatus: 'unknown',
              );
            })
            .toList();
        
        // Sort by timestamp (newest first) after mapping
        _moistureHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _isLoading = false;
        notifyListeners();
      },
      onPumpTimerChanged: (timer) {
        _handlePumpTimerChanged(timer);
      },
    );
  }

  // Handle pump timer changes
  void _handlePumpTimerChanged(int? timer) {
    _pumpTimer = timer;

    // If the timer is active (value > 0), start local countdown
    if (timer != null && timer > 0) {
      _localTimerValue = timer;

      // Cancel existing timer if any
      _localPumpTimer?.cancel();

      // Start a new timer
      _localPumpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_localTimerValue > 0) {
          _localTimerValue--;
          notifyListeners();
        } else {
          timer.cancel();
        }
      });
    } else {
      // Timer was removed or reached 0
      _localPumpTimer?.cancel();
      _localTimerValue = 0;
    }

    notifyListeners();
  }

  // Methods to update Firebase
  Future toggleAutoMode() async {
    await _firebaseService.setAutoMode(!_autoMode);
  }

  Future togglePump() async {
    if (!_autoMode) {
      await _firebaseService.setPumpCommand(!_pumpStatus);
    }
  }

  // Method untuk handle pump command - ini yang diperlukan untuk onPumpCommand
  Future sendPumpCommand(bool command) async {
    await _firebaseService.setPumpCommand(command);
  }

  // Start pump with timer
  Future startPumpWithTimer(int seconds) async {
    if (!_autoMode) {
      await _firebaseService.setPumpTimer(seconds);
    }
  }

  // Cancel pump timer
  Future cancelPumpTimer() async {
    await _firebaseService.cancelPumpTimer();
  }

  // Reset pump timer - Method baru untuk reset timer
  Future resetPumpTimer() async {
    // Cancel local timer
    _localPumpTimer?.cancel();

    // Reset local values
    _localTimerValue = 0;
    _pumpTimer = null;

    // Also cancel timer in Firebase to ensure consistency
    await _firebaseService.cancelPumpTimer();

    notifyListeners();
  }

  // --- TEST METHODS (DISABLED) --- //

  // Method to add a fake history entry for testing (disabled)
  Future<void> addTestHistoryEntry() async {
    // This function is intentionally left blank to ensure only data from Firebase is used.
    if (kDebugMode) {
      print('Warning: addTestHistoryEntry called, but it is disabled.');
    }
  }

  // Method to add multiple fake history entries (disabled)
  Future<void> addMultipleTestEntries() async {
    // This function is intentionally left blank to ensure only data from Firebase is used.
    if (kDebugMode) {
      print('Warning: addMultipleTestEntries called, but it is disabled.');
    }
  }

  @override
  void dispose() {
    _localPumpTimer?.cancel();
    super.dispose();
  }
}
