import 'package:firebase_database/firebase_database.dart';
import '../models/irrigation_model.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('irrigation');

  // Subscribe to real-time updates
  void subscribeToIrrigationData({
    required Function(int) onMoistureChanged,
    required Function(String) onSoilStatusChanged,
    required Function(bool) onPumpStatusChanged,
    required Function(bool) onAutoModeChanged,
    required Function(List<dynamic>) onHistoryUpdated, // Changed to List<dynamic>
    required Function(int?) onPumpTimerChanged,
  }) {
    // Listen to moisture value
    _dbRef.child('moisture').onValue.listen((event) {
      if (event.snapshot.exists) {
        final value = event.snapshot.value as int;
        onMoistureChanged(value);
      }
    });

    // Listen to soil status
    _dbRef.child('soilStatus').onValue.listen((event) {
      if (event.snapshot.exists) {
        final status = event.snapshot.value as String;
        onSoilStatusChanged(status);
      }
    });

    // Listen to pump status
    _dbRef.child('pumpStatus').onValue.listen((event) {
      if (event.snapshot.exists) {
        final status = event.snapshot.value as bool;
        onPumpStatusChanged(status);
      }
    });

    // Listen to auto mode
    _dbRef.child('autoMode').onValue.listen((event) {
      if (event.snapshot.exists) {
        final mode = event.snapshot.value as bool;
        onAutoModeChanged(mode);
      }
    });

    // Listen to pump timer (if exists)
    _dbRef.child('pumpTimer').onValue.listen((event) {
      if (event.snapshot.exists) {
        final timer = event.snapshot.value as int;
        onPumpTimerChanged(timer);
      } else {
        onPumpTimerChanged(null);
      }
    });

    // Listen to history
    _dbRef.child('history').limitToLast(50).onValue.listen((event) {
      if (event.snapshot.exists) {
        // Get the raw data as a Map
        final historyData = event.snapshot.value as Map<dynamic, dynamic>;
        // Pass the list of map values directly to the model
        onHistoryUpdated(historyData.values.toList());
      } else {
        // If no history exists, pass an empty list
        onHistoryUpdated([]);
      }
    });
  }

  // Update auto mode
  Future<void> setAutoMode(bool mode) async {
    await _dbRef.child('autoMode').set(mode);
  }

  // Update pump command (for manual mode)
  Future<void> setPumpCommand(bool command) async {
    await _dbRef.child('pumpCommand').set(command);
  }

  // Set pump timer for manual mode (in seconds)
  Future<void> setPumpTimer(int seconds) async {
    await _dbRef.child('pumpTimer').set(seconds);

    // Also set the pump command to true
    if (seconds > 0) {
      await setPumpCommand(true);
    }
  }

  // Cancel pump timer
  Future<void> cancelPumpTimer() async {
    await _dbRef.child('pumpTimer').remove();
    await setPumpCommand(false);
  }

  // Add test entry to history (for testing only)
  Future<void> addTestHistoryEntry() async {
    final now = DateTime.now();
    print('Current DateTime: $now');
    
    final timestamp = now.millisecondsSinceEpoch;
    print('Milliseconds since epoch: $timestamp');
    
    final randomMoisture = 1500 + (now.millisecond % 1000);
    final soilStatus = randomMoisture > 2000 ? 'dry' : 'wet';

    await _dbRef.child('history').child(timestamp.toString()).set({
      'timestamp': timestamp.toString(),
      'moisture': randomMoisture,
      'soilStatus': soilStatus,
    });
    
    print('Added test entry with timestamp: $timestamp');
  }

  // Add multiple test entries with different conditions (for testing)
  Future<void> addMultipleTestEntries() async {
    final now = DateTime.now();
    
    // Add entries for the last few hours with realistic data
    for (int i = 0; i < 10; i++) {
      final entryTime = now.subtract(Duration(minutes: i * 15)); // Every 15 minutes
      final timestamp = entryTime.millisecondsSinceEpoch;
      
      // Simulate realistic moisture readings
      int moistureValue;
      String status;
      
      if (i < 3) {
        // Recent entries - wet soil
        moistureValue = 100 + (i * 200); // 100, 300, 500
        status = 'wet';
      } else if (i < 7) {
        // Middle entries - transitioning to dry
        moistureValue = 1800 + (i * 100); // 2000+
        status = 'dry';
      } else {
        // Older entries - dry soil
        moistureValue = 2500 + (i * 50);
        status = 'dry';
      }

      await _dbRef.child('history').child(timestamp.toString()).set({
        'timestamp': timestamp.toString(),
        'moisture': moistureValue,
        'soilStatus': status,
      });
      
      print('Added test entry: time=${entryTime}, moisture=${moistureValue}, status=${status}');
    }
    
    print('Added 10 test history entries');
  }
}
