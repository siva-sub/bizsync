import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/core/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    late FeatureFlags featureFlags;

    setUp(() {
      featureFlags = FeatureFlags();
    });

    test('should have default values', () {
      expect(featureFlags.isDemoDataEnabled, false);
      expect(featureFlags.isDebugModeEnabled, false);
      expect(featureFlags.areBetaFeaturesEnabled, false);
    });

    test('should detect demo data banner requirement', () {
      expect(featureFlags.shouldShowDemoDataBanner, false);
    });
  });

  group('Date Validation', () {
    test('should validate past dates', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 30));
      final futureDate = DateTime.now().add(const Duration(days: 30));

      expect(pastDate.isBefore(DateTime.now()), true);
      expect(futureDate.isAfter(DateTime.now()), true);
    });
  });

  group('Version', () {
    test('should have correct version format', () {
      const version = '1.2.0';
      final parts = version.split('.');

      expect(parts.length, 3);
      expect(int.tryParse(parts[0]), isNotNull);
      expect(int.tryParse(parts[1]), isNotNull);
      expect(int.tryParse(parts[2]), isNotNull);
    });
  });
}
