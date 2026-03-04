import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/settings/data/models/settings_model.dart';

void main() {
  group('AppSettingsModel', () {
    test('has correct default values', () {
      const settings = AppSettingsModel();

      expect(settings.darkMode, true);
      expect(settings.autoPlayVideos, false);
      expect(settings.downloadOverWifiOnly, true);
    });

    test('static defaults matches default constructor', () {
      expect(AppSettingsModel.defaults, const AppSettingsModel());
    });

    test('creates instance with custom values', () {
      const settings = AppSettingsModel(
        darkMode: false,
        autoPlayVideos: true,
        downloadOverWifiOnly: false,
      );

      expect(settings.darkMode, false);
      expect(settings.autoPlayVideos, true);
      expect(settings.downloadOverWifiOnly, false);
    });

    test('copyWith updates only specified fields', () {
      const original = AppSettingsModel();

      final updated = original.copyWith(darkMode: false);

      expect(updated.darkMode, false);
      expect(updated.autoPlayVideos, false); // unchanged
      expect(updated.downloadOverWifiOnly, true); // unchanged
    });

    test('copyWith with no arguments returns equal instance', () {
      const original = AppSettingsModel();
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('toMap creates correct map', () {
      const settings = AppSettingsModel(
        darkMode: false,
        autoPlayVideos: true,
        downloadOverWifiOnly: false,
      );

      final map = settings.toMap();

      expect(map['darkMode'], false);
      expect(map['autoPlayVideos'], true);
      expect(map['downloadOverWifiOnly'], false);
      expect(map.length, 3);
    });

    test('fromMap creates correct instance', () {
      final map = {
        'darkMode': false,
        'autoPlayVideos': true,
        'downloadOverWifiOnly': false,
      };

      final settings = AppSettingsModel.fromMap(map);

      expect(settings.darkMode, false);
      expect(settings.autoPlayVideos, true);
      expect(settings.downloadOverWifiOnly, false);
    });

    test('fromMap uses defaults for missing keys', () {
      final settings = AppSettingsModel.fromMap({});

      expect(settings.darkMode, true);
      expect(settings.autoPlayVideos, false);
      expect(settings.downloadOverWifiOnly, true);
    });

    test('fromMap handles null values with defaults', () {
      final settings = AppSettingsModel.fromMap({
        'darkMode': null,
        'autoPlayVideos': null,
        'downloadOverWifiOnly': null,
      });

      expect(settings.darkMode, true);
      expect(settings.autoPlayVideos, false);
      expect(settings.downloadOverWifiOnly, true);
    });

    test('roundtrip toMap -> fromMap preserves values', () {
      const original = AppSettingsModel(
        darkMode: false,
        autoPlayVideos: true,
        downloadOverWifiOnly: false,
      );

      final roundtripped = AppSettingsModel.fromMap(original.toMap());

      expect(roundtripped, equals(original));
    });

    test('equatable: two identical instances are equal', () {
      const a = AppSettingsModel(darkMode: false);
      const b = AppSettingsModel(darkMode: false);
      expect(a, equals(b));
    });

    test('equatable: different instances are not equal', () {
      const a = AppSettingsModel(darkMode: true);
      const b = AppSettingsModel(darkMode: false);
      expect(a, isNot(equals(b)));
    });
  });
}
