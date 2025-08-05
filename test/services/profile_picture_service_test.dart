import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bizsync/services/profile_picture_service.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/tmp/test_app_documents';
  }

  @override
  Future<String?> getApplicationCachePath() async => '/tmp/test_cache';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/test_support';

  @override
  Future<String?> getDownloadsPath() async => '/tmp/test_downloads';

  @override
  Future<List<String>?> getExternalCachePaths() async => ['/tmp/test_external_cache'];

  @override
  Future<String?> getExternalStoragePath() async => '/tmp/test_external_storage';

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => ['/tmp/test_external'];

  @override
  Future<String?> getLibraryPath() async => '/tmp/test_library';

  @override
  Future<String?> getTemporaryPath() async => '/tmp/test_temp';
}

void main() {
  group('ProfilePictureService', () {
    late ProfilePictureService service;

    setUpAll(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
    });

    setUp(() {
      service = ProfilePictureService();
      SharedPreferences.setMockInitialValues({});
    });

    test('should return null when no profile picture exists', () async {
      final picturePath = await service.getProfilePicturePath();
      expect(picturePath, isNull);
    });

    test('should return null when no profile picture bytes exist', () async {
      final pictureBytes = await service.getProfilePictureBytes();
      expect(pictureBytes, isNull);
    });

    test('should successfully delete non-existent profile picture', () async {
      final result = await service.deleteProfilePicture();
      expect(result, isTrue);
    });

    test('should cleanup old profile pictures without error', () async {
      await expectLater(
        service.cleanupOldProfilePictures(),
        completes,
      );
    });
  });
}

// Mock class for testing
class Mock {
  // Empty mock class for testing
}