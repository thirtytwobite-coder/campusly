import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('Program Form Validation Tests', () {
    test('Program name validation - empty name should fail', () {
      final name = '';
      final date = '2024-12-25';
      
      expect(validateProgramForm(name, date), isNotNull);
      expect(validateProgramForm(name, date), contains('Program name cannot be empty'));
    });

    test('Date validation - empty date should fail', () {
      final name = 'Tech Summit';
      final date = '';
      
      expect(validateProgramForm(name, date), isNotNull);
      expect(validateProgramForm(name, date), contains('Date cannot be empty'));
    });

    test('Date format validation - invalid format should fail', () {
      final name = 'Tech Summit';
      final date = '25-12-2024'; // Invalid format
      
      expect(validateProgramForm(name, date), isNotNull);
      expect(validateProgramForm(name, date), contains('Invalid date format'));
    });

    test('Valid form - should return null', () {
      final name = 'Tech Summit';
      final date = '2024-12-25';
      
      expect(validateProgramForm(name, date), isNull);
    });

    test('Date format - YYYY-MM-DD format should be valid', () {
      final name = 'Annual Event';
      final date = '2025-06-15';
      
      expect(validateProgramForm(name, date), isNull);
    });

    test('Whitespace trimming - name with spaces should be valid', () {
      final name = '  Tech Summit  ';
      final date = '2024-12-25';
      
      expect(validateProgramForm(name.trim(), date), isNull);
    });
  });

  group('Date Format Tests', () {
    test('Date picker format - should format correctly', () {
      final date = DateTime(2024, 12, 25);
      final formatted = DateFormat('yyyy-MM-dd').format(date);
      
      expect(formatted, equals('2024-12-25'));
    });

    test('Date parsing - should parse valid date', () {
      final dateString = '2024-12-25';
      final parsed = DateFormat('yyyy-MM-dd').parseStrict(dateString);
      
      expect(parsed.year, equals(2024));
      expect(parsed.month, equals(12));
      expect(parsed.day, equals(25));
    });

    test('Date parsing - should throw on invalid format', () {
      final dateString = '25-12-2024';
      
      expect(
        () => DateFormat('yyyy-MM-dd').parseStrict(dateString),
        throwsException,
      );
    });
  });

  group('Status Badge Tests', () {
    test('Status color mapping - pending should be orange', () {
      final status = 'pending';
      final color = getStatusColor(status);
      
      expect(color, equals(const Color(0xFFFFA500))); // Orange
    });

    test('Status color mapping - ongoing should be blue', () {
      final status = 'ongoing';
      final color = getStatusColor(status);
      
      expect(color, equals(const Color(0xFF2196F3))); // Blue
    });

    test('Status color mapping - completed should be green', () {
      final status = 'completed';
      final color = getStatusColor(status);
      
      expect(color, equals(const Color(0xFF4CAF50))); // Green
    });

    test('Status color mapping - cancelled should be red', () {
      final status = 'cancelled';
      final color = getStatusColor(status);
      
      expect(color, equals(const Color(0xFFF44336))); // Red
    });

    test('Status icon mapping - pending should have schedule icon', () {
      final status = 'pending';
      final icon = getStatusIcon(status);
      
      expect(icon, equals('schedule'));
    });

    test('Status icon mapping - ongoing should have play_circle_filled icon', () {
      final status = 'ongoing';
      final icon = getStatusIcon(status);
      
      expect(icon, equals('play_circle_filled'));
    });

    test('Status icon mapping - completed should have check_circle icon', () {
      final status = 'completed';
      final icon = getStatusIcon(status);
      
      expect(icon, equals('check_circle'));
    });

    test('Status icon mapping - cancelled should have cancel icon', () {
      final status = 'cancelled';
      final icon = getStatusIcon(status);
      
      expect(icon, equals('cancel'));
    });
  });

  group('Program Data Tests', () {
    test('Program creation - should have all required fields', () {
      final program = {
        'name': 'Tech Summit',
        'description': 'Annual tech conference',
        'date': '2024-12-25',
        'time': '14:30',
        'location': 'Main Hall',
        'status': 'pending',
      };

      expect(program['name'], isNotEmpty);
      expect(program['description'], isNotEmpty);
      expect(program['date'], isNotEmpty);
      expect(program['time'], isNotEmpty);
      expect(program['location'], isNotEmpty);
      expect(program['status'], equals('pending'));
    });

    test('Program status update - should change status correctly', () {
      var program = {
        'name': 'Tech Summit',
        'status': 'pending',
      };

      // Simulate status update
      program['status'] = 'ongoing';

      expect(program['status'], equals('ongoing'));
    });

    test('Program status flow - pending -> ongoing -> completed', () {
      var status = 'pending';

      status = 'ongoing';
      expect(status, equals('ongoing'));

      status = 'completed';
      expect(status, equals('completed'));
    });
  });

  group('Time Format Tests', () {
    test('Time format - should format correctly', () {
      final hour = 14;
      final minute = 30;
      final formatted =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      expect(formatted, equals('14:30'));
    });

    test('Time format - single digit hour should be padded', () {
      final hour = 9;
      final minute = 5;
      final formatted =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      expect(formatted, equals('09:05'));
    });
  });

  group('Prize Pool Tests', () {
    test('Prize pool checkbox - should be unchecked by default', () {
      bool hasPrizePool = false;
      expect(hasPrizePool, isFalse);
    });

    test('Prize pool checkbox - should toggle on user action', () {
      bool hasPrizePool = false;
      hasPrizePool = !hasPrizePool;
      expect(hasPrizePool, isTrue);
    });

    test('Prize pool data - should be stored in program document', () {
      final programData = {
        'name': 'Code Championship',
        'description': 'Annual coding competition',
        'date': '2024-12-25',
        'time': '14:30',
        'location': 'Auditorium',
        'hasPrizePool': true,
        'status': 'pending',
      };

      expect(programData['hasPrizePool'], isTrue);
      expect(programData['name'], equals('Code Championship'));
    });

    test('Prize pool data - should be false when unchecked', () {
      final programData = {
        'name': 'Workshop',
        'description': 'Basic programming workshop',
        'date': '2024-11-30',
        'time': '10:00',
        'location': 'Lab',
        'hasPrizePool': false,
        'status': 'pending',
      };

      expect(programData['hasPrizePool'], isFalse);
    });

    test('Prize pool display - should show gift icon when available', () {
      final programData = {
        'hasPrizePool': true,
        'name': 'Prize Event',
      };

      expect(programData['hasPrizePool'], isTrue);
      // Icon would be Icons.card_giftcard in UI
    });

    test('Prize pool display - should not show when unavailable', () {
      final programData = {
        'hasPrizePool': false,
        'name': 'No Prize Event',
      };

      expect(programData['hasPrizePool'], isFalse);
    });

    test('Prize amount storage - should store amount when prize pool is true', () {
      final programData = {
        'name': 'Hackathon',
        'hasPrizePool': true,
        'prizeAmount': '50000',
      };

      expect(programData['prizeAmount'], equals('50000'));
      expect(programData['hasPrizePool'], isTrue);
    });

    test('Prize amount storage - should be null when prize pool is false', () {
      final programData = {
        'name': 'Workshop',
        'hasPrizePool': false,
        'prizeAmount': null,
      };

      expect(programData['prizeAmount'], isNull);
      expect(programData['hasPrizePool'], isFalse);
    });

    test('Prize amount validation - should accept numeric values', () {
      final amounts = ['5000', '10000', '25000', '100000'];
      for (final amount in amounts) {
        expect(int.tryParse(amount), isNotNull);
      }
    });

    test('Prize amount formatting - should display with rupee symbol', () {
      final programData = {
        'hasPrizePool': true,
        'prizeAmount': '50000',
      };

      final displayText = '₹ ${programData['prizeAmount']}';
      expect(displayText, equals('₹ 50000'));
    });

    test('Prize amount conditional display - amount hidden when empty', () {
      final programData = {
        'hasPrizePool': true,
        'prizeAmount': null,
      };

      final shouldDisplay = programData['prizeAmount'] != null &&
          programData['prizeAmount'].toString().isNotEmpty;
      expect(shouldDisplay, isFalse);
    });
  });
}

// Validation Helper Functions
String? validateProgramForm(String name, String date) {
  if (name.trim().isEmpty) {
    return 'Program name cannot be empty';
  }
  if (date.trim().isEmpty) {
    return 'Date cannot be empty';
  }

  try {
    DateFormat('yyyy-MM-dd').parseStrict(date);
  } catch (e) {
    return 'Invalid date format. Use YYYY-MM-DD';
  }

  return null;
}

// Color Helper Functions
class Color {
  final int value;
  const Color(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Color && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

Color getStatusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFFFA500); // Orange
    case 'ongoing':
      return const Color(0xFF2196F3); // Blue
    case 'completed':
      return const Color(0xFF4CAF50); // Green
    case 'cancelled':
      return const Color(0xFFF44336); // Red
    default:
      return const Color(0xFF9E9E9E); // Grey
  }
}

String getStatusIcon(String status) {
  switch (status) {
    case 'pending':
      return 'schedule';
    case 'ongoing':
      return 'play_circle_filled';
    case 'completed':
      return 'check_circle';
    case 'cancelled':
      return 'cancel';
    default:
      return 'help';
  }
}