import 'package:flutter_test/flutter_test.dart';
import 'package:dobelgodelivery/models/way_event.dart';

void main() {
  group('WayEvent Mode Parsing Tests', () {
    test('Parses "ONLINE" mode correctly as EventMode.online', () {
      final json = {
        'id': 'evt_1',
        'title': 'Online Hackathon',
        'mode': 'ONLINE',
      };
      final event = WayEvent.fromJson(json);
      expect(event.mode, equals(EventMode.online));
    });

    test('Parses "OFFLINE" mode correctly as EventMode.offline', () {
      final json = {
        'id': 'evt_2',
        'title': 'Offline Meetup',
        'mode': 'OFFLINE',
      };
      final event = WayEvent.fromJson(json);
      expect(event.mode, equals(EventMode.offline));
    });

    test('Parses case-insensitive and trimmed mode strings correctly', () {
      final onlineJson = {'id': 'evt_3', 'title': 'Event 3', 'mode': '  online  '};
      final offlineJson = {'id': 'evt_4', 'title': 'Event 4', 'mode': 'offline'};

      expect(WayEvent.fromJson(onlineJson).mode, equals(EventMode.online));
      expect(WayEvent.fromJson(offlineJson).mode, equals(EventMode.offline));
    });

    test('Defaults to EventMode.online if mode is missing or null', () {
      final nullModeJson = {'id': 'evt_5', 'title': 'Event 5', 'mode': null};
      final missingModeJson = {'id': 'evt_6', 'title': 'Event 6'};
      final unknownModeJson = {'id': 'evt_7', 'title': 'Event 7', 'mode': 'HYBRID'};

      expect(WayEvent.fromJson(nullModeJson).mode, equals(EventMode.online));
      expect(WayEvent.fromJson(missingModeJson).mode, equals(EventMode.online));
      expect(WayEvent.fromJson(unknownModeJson).mode, equals(EventMode.online));
    });

    test('Serializes to JSON correctly', () {
      final onlineEvent = WayEvent(id: '1', title: 'Test 1', mode: EventMode.online);
      final offlineEvent = WayEvent(id: '2', title: 'Test 2', mode: EventMode.offline);

      expect(onlineEvent.toJson()['mode'], equals('ONLINE'));
      expect(offlineEvent.toJson()['mode'], equals('OFFLINE'));
    });
  });
}
