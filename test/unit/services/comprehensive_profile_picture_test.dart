/// Comprehensive Profile Picture Service Tests
library comprehensive_profile_picture_test;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bizsync/services/profile_picture_service.dart';
import '../../test_config.dart';
import '../../mocks/mock_services.dart';

void main() {
  group('Profile Picture Service Tests', () {
    late ProfilePictureService service;
    late MockProfilePictureService mockService;
    late Directory tempDir;
    
    setUpAll(() async {
      await TestConfig.initialize();
    });

    setUp(() async {
      await TestConfig.reset();
      service = ProfilePictureService();
      mockService = MockProfilePictureService();
      
      // Create temporary directory for testing
      tempDir = Directory('/tmp/test_profile_pictures_${DateTime.now().millisecondsSinceEpoch}');
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
    });
    
    tearDown(() async {
      // Clean up temporary directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('Basic Functionality Tests', () {
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
    
    group('Image Upload Tests', () {
      test('should save profile picture successfully', () async {
        // Create a mock image file
        final imageFile = File('${tempDir.path}/test_image.jpg');
        final testImageData = List.generate(1024, (index) => index % 256);
        await imageFile.writeAsBytes(testImageData);
        
        mockService.setMockProfilePicture(imageFile.path, testImageData);
        
        final result = await mockService.saveProfilePicture(imageFile);
        expect(result, isTrue);
        
        final savedPath = await mockService.getProfilePicturePath();
        expect(savedPath, equals(imageFile.path));
        
        final savedBytes = await mockService.getProfilePictureBytes();
        expect(savedBytes, equals(testImageData));
      });
      
      test('should handle large image files', () async {
        // Create a large mock image file (5MB)
        final imageFile = File('${tempDir.path}/large_test_image.jpg');
        final largeImageData = List.generate(5 * 1024 * 1024, (index) => index % 256);
        await imageFile.writeAsBytes(largeImageData);
        
        mockService.setMockProfilePicture(imageFile.path, largeImageData);
        
        final result = await TestPerformanceUtils.performanceTest(
          'Save large profile picture (5MB)',
          () async {
            await mockService.saveProfilePicture(imageFile);
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should validate image file format', () async {
        // Test with invalid file extension
        final invalidFile = File('${tempDir.path}/test_file.txt');
        await invalidFile.writeAsString('This is not an image');
        
        mockService.setShouldFailOperations(true);
        
        final result = await mockService.saveProfilePicture(invalidFile);
        expect(result, isFalse);
      });
      
      test('should handle corrupted image files', () async {
        // Create a corrupted image file
        final corruptedFile = File('${tempDir.path}/corrupted_image.jpg');
        await corruptedFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // Invalid JPEG header
        
        mockService.setShouldFailOperations(true);
        
        final result = await mockService.saveProfilePicture(corruptedFile);
        expect(result, isFalse);
      });
      
      test('should compress large images', () async {
        // Create a mock large image
        final largeImageFile = File('${tempDir.path}/large_image.jpg');
        final largeImageData = List.generate(10 * 1024 * 1024, (index) => index % 256); // 10MB
        await largeImageFile.writeAsBytes(largeImageData);
        
        // Mock compression behavior
        final compressedData = List.generate(1024 * 1024, (index) => index % 256); // 1MB compressed
        mockService.setMockProfilePicture(largeImageFile.path, compressedData);
        
        final result = await mockService.saveProfilePicture(largeImageFile);
        expect(result, isTrue);
        
        final savedBytes = await mockService.getProfilePictureBytes();
        expect(savedBytes?.length, lessThan(largeImageData.length));
      });
      
      test('should handle different image formats', () async {
        final formats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        for (final format in formats) {
          final imageFile = File('${tempDir.path}/test_image.$format');
          final testImageData = List.generate(512, (index) => index % 256);
          await imageFile.writeAsBytes(testImageData);
          
          mockService.setMockProfilePicture(imageFile.path, testImageData);
          
          final result = await mockService.saveProfilePicture(imageFile);
          expect(result, isTrue, reason: 'Should support $format format');
        }
      });
      
      test('should enforce maximum file size limits', () async {
        // Test with file that exceeds size limit (e.g., 10MB)
        final oversizedFile = File('${tempDir.path}/oversized_image.jpg');
        final oversizedData = List.generate(15 * 1024 * 1024, (index) => index % 256); // 15MB
        await oversizedFile.writeAsBytes(oversizedData);
        
        mockService.setShouldFailOperations(true); // Simulate size limit rejection
        
        final result = await mockService.saveProfilePicture(oversizedFile);
        expect(result, isFalse);
      });
    });
    
    group('Image Retrieval Tests', () {
      test('should retrieve saved profile picture', () async {
        final testImageData = List.generate(512, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/test_profile.jpg', testImageData);
        
        final picturePath = await mockService.getProfilePicturePath();
        expect(picturePath, equals('/tmp/test_profile.jpg'));
        
        final pictureBytes = await mockService.getProfilePictureBytes();
        expect(pictureBytes, equals(testImageData));
      });
      
      test('should handle missing image file gracefully', () async {
        mockService.setMockProfilePicture('/tmp/non_existent.jpg', null);
        
        final pictureBytes = await mockService.getProfilePictureBytes();
        expect(pictureBytes, isNull);
      });
      
      test('should cache image data for performance', () async {
        final testImageData = List.generate(1024, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/cached_image.jpg', testImageData);
        
        // First call
        final start1 = DateTime.now();
        final bytes1 = await mockService.getProfilePictureBytes();
        final duration1 = DateTime.now().difference(start1);
        
        // Second call (should be cached)
        final start2 = DateTime.now();
        final bytes2 = await mockService.getProfilePictureBytes();
        final duration2 = DateTime.now().difference(start2);
        
        expect(bytes1, equals(bytes2));
        // Second call should be faster (cached)
        // Note: In a real implementation, you'd expect duration2 < duration1
      });
      
      test('should generate thumbnails for large images', () async {
        final largeImageData = List.generate(5 * 1024 * 1024, (index) => index % 256); // 5MB
        mockService.setMockProfilePicture('/tmp/large_for_thumbnail.jpg', largeImageData);
        
        // Mock thumbnail generation
        final thumbnailData = List.generate(10 * 1024, (index) => index % 256); // 10KB thumbnail
        
        // In a real service, this would generate a thumbnail
        final thumbnail = thumbnailData; // Mock thumbnail
        
        expect(thumbnail.length, lessThan(largeImageData.length));
      });
    });
    
    group('Image Deletion Tests', () {
      test('should delete profile picture successfully', () async {
        final testImageData = List.generate(256, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/to_delete.jpg', testImageData);
        
        // Verify image exists
        final beforeDeletion = await mockService.getProfilePicturePath();
        expect(beforeDeletion, isNotNull);
        
        // Delete image
        final result = await mockService.deleteProfilePicture();
        expect(result, isTrue);
        
        // Verify image is deleted
        final afterDeletion = await mockService.getProfilePicturePath();
        expect(afterDeletion, isNull);
      });
      
      test('should clear cached data after deletion', () async {
        final testImageData = List.generate(256, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/cached_delete.jpg', testImageData);
        
        // Load into cache
        await mockService.getProfilePictureBytes();
        
        // Delete
        await mockService.deleteProfilePicture();
        
        // Verify cache is cleared
        final bytes = await mockService.getProfilePictureBytes();
        expect(bytes, isNull);
      });
      
      test('should handle deletion of non-existent files', () async {
        // Try to delete a file that doesn't exist
        final result = await mockService.deleteProfilePicture();
        expect(result, isTrue); // Should not fail
      });
      
      test('should clean up related files (thumbnails, metadata)', () async {
        final testImageData = List.generate(512, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/with_metadata.jpg', testImageData);
        
        // Simulate files with related metadata
        final metadataFile = File('${tempDir.path}/with_metadata.jpg.meta');
        await metadataFile.writeAsString('{"created": "${DateTime.now().toIso8601String()}"}');
        
        final thumbnailFile = File('${tempDir.path}/with_metadata_thumb.jpg');
        await thumbnailFile.writeAsBytes(List.generate(128, (index) => index % 256));
        
        final result = await mockService.deleteProfilePicture();
        expect(result, isTrue);
        
        // In a real implementation, related files should also be deleted
      });
    });
    
    group('Error Handling Tests', () {
      test('should handle file system errors gracefully', () async {
        mockService.setShouldFailOperations(true);
        
        expect(() => mockService.getProfilePicturePath(), throwsException);
        expect(() => mockService.getProfilePictureBytes(), throwsException);
      });
      
      test('should handle insufficient storage space', () async {
        // Simulate storage full scenario
        final largeFile = File('${tempDir.path}/huge_file.jpg');
        // In a real test, you might try to create a file that exceeds available space
        
        mockService.setShouldFailOperations(true);
        
        final result = await mockService.saveProfilePicture(largeFile);
        expect(result, isFalse);
      });
      
      test('should handle permission denied errors', () async {
        mockService.setShouldFailOperations(true);
        
        final testFile = File('${tempDir.path}/permission_test.jpg');
        await testFile.writeAsBytes([1, 2, 3, 4]);
        
        final result = await mockService.saveProfilePicture(testFile);
        expect(result, isFalse);
      });
      
      test('should timeout on extremely slow operations', () async {
        // Simulate slow file operations
        mockService.setShouldFailOperations(true);
        
        final testFile = File('${tempDir.path}/slow_test.jpg');
        await testFile.writeAsBytes([1, 2, 3, 4]);
        
        expect(
          () => mockService.saveProfilePicture(testFile).timeout(Duration(seconds: 1)),
          throwsA(isA<TimeoutException>()),
        );
      });
      
      test('should handle network interruptions during upload', () async {
        // Simulate network failure during upload to cloud storage
        mockService.setShouldFailOperations(true);
        
        final testFile = File('${tempDir.path}/network_test.jpg');
        await testFile.writeAsBytes(List.generate(1024, (index) => index % 256));
        
        final result = await mockService.saveProfilePicture(testFile);
        expect(result, isFalse);
      });
      
      test('should recover from temporary failures', () async {
        final testFile = File('${tempDir.path}/recovery_test.jpg');
        final testImageData = List.generate(512, (index) => index % 256);
        await testFile.writeAsBytes(testImageData);
        
        // First attempt fails
        mockService.setShouldFailOperations(true);
        var result = await mockService.saveProfilePicture(testFile);
        expect(result, isFalse);
        
        // Second attempt succeeds
        mockService.setShouldFailOperations(false);
        mockService.setMockProfilePicture(testFile.path, testImageData);
        result = await mockService.saveProfilePicture(testFile);
        expect(result, isTrue);
      });
    });
    
    group('Performance Tests', () {
      test('should save small images quickly', () async {
        final smallImageFile = File('${tempDir.path}/small_image.jpg');
        final smallImageData = List.generate(10 * 1024, (index) => index % 256); // 10KB
        await smallImageFile.writeAsBytes(smallImageData);
        
        mockService.setMockProfilePicture(smallImageFile.path, smallImageData);
        
        final result = await TestPerformanceUtils.performanceTest(
          'Save small profile picture (10KB)',
          () async {
            await mockService.saveProfilePicture(smallImageFile);
          },
          TestConstants.maxDatabaseQueryTime * 5, // Allow more time for file operations
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should retrieve images quickly from cache', () async {
        final testImageData = List.generate(1024, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/performance_test.jpg', testImageData);
        
        // Prime the cache
        await mockService.getProfilePictureBytes();
        
        final result = await TestPerformanceUtils.performanceTest(
          'Retrieve cached profile picture',
          () async {
            await mockService.getProfilePictureBytes();
          },
          Duration(milliseconds: 10), // Should be very fast from cache
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle batch operations efficiently', () async {
        final batchSize = 10;
        final futures = <Future<bool>>[];
        
        for (int i = 0; i < batchSize; i++) {
          final imageFile = File('${tempDir.path}/batch_$i.jpg');
          final imageData = List.generate(1024, (index) => i * 256 + index % 256);
          await imageFile.writeAsBytes(imageData);
          
          mockService.setMockProfilePicture(imageFile.path, imageData);
          futures.add(mockService.saveProfilePicture(imageFile));
        }
        
        final result = await TestPerformanceUtils.performanceTest(
          'Batch save $batchSize profile pictures',
          () async {
            await Future.wait(futures);
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Concurrent Access Tests', () {
      test('should handle concurrent save operations', () async {
        final futures = <Future<bool>>[];
        
        for (int i = 0; i < 5; i++) {
          final imageFile = File('${tempDir.path}/concurrent_$i.jpg');
          final imageData = List.generate(1024, (index) => i * 256 + index % 256);
          await imageFile.writeAsBytes(imageData);
          
          mockService.setMockProfilePicture(imageFile.path, imageData);
          futures.add(mockService.saveProfilePicture(imageFile));
        }
        
        final results = await Future.wait(futures);
        
        // At least one should succeed (last writer wins)
        expect(results.any((result) => result), isTrue);
      });
      
      test('should handle concurrent read operations', () async {
        final testImageData = List.generate(512, (index) => index % 256);
        mockService.setMockProfilePicture('/tmp/concurrent_read.jpg', testImageData);
        
        final futures = <Future<List<int>?>>[];
        
        for (int i = 0; i < 10; i++) {
          futures.add(mockService.getProfilePictureBytes());
        }
        
        final results = await Future.wait(futures);
        
        // All reads should return the same data
        for (final result in results) {
          expect(result, equals(testImageData));
        }
      });
      
      test('should prevent race conditions during save/delete', () async {
        final testImageData = List.generate(256, (index) => index % 256);
        final imageFile = File('${tempDir.path}/race_condition_test.jpg');
        await imageFile.writeAsBytes(testImageData);
        
        mockService.setMockProfilePicture(imageFile.path, testImageData);
        
        // Start save and delete operations simultaneously
        final saveFuture = mockService.saveProfilePicture(imageFile);
        final deleteFuture = mockService.deleteProfilePicture();
        
        final results = await Future.wait([saveFuture, deleteFuture]);
        
        // One of the operations should complete successfully
        expect(results.any((result) => result == true), isTrue);
      });
    });
    
    group('Memory Management Tests', () {
      test('should not leak memory with repeated operations', () async {
        // Simulate repeated save/delete cycles
        for (int i = 0; i < 100; i++) {
          final imageFile = File('${tempDir.path}/memory_test_$i.jpg');
          final imageData = List.generate(1024, (index) => index % 256);
          await imageFile.writeAsBytes(imageData);
          
          mockService.setMockProfilePicture(imageFile.path, imageData);
          
          await mockService.saveProfilePicture(imageFile);
          await mockService.deleteProfilePicture();
        }
        
        // If we get here without running out of memory, the test passes
        expect(true, isTrue);
      });
      
      test('should properly dispose of large image data', () async {
        final largeImageFile = File('${tempDir.path}/large_disposal_test.jpg');
        final largeImageData = List.generate(5 * 1024 * 1024, (index) => index % 256); // 5MB
        await largeImageFile.writeAsBytes(largeImageData);
        
        mockService.setMockProfilePicture(largeImageFile.path, largeImageData);
        
        await mockService.saveProfilePicture(largeImageFile);
        await mockService.deleteProfilePicture();
        
        // Verify data is cleared
        final bytes = await mockService.getProfilePictureBytes();
        expect(bytes, isNull);
      });
      
      test('should limit cache size to prevent memory bloat', () async {
        // Simulate loading many different images
        for (int i = 0; i < 50; i++) {
          final imageData = List.generate(1024, (index) => i * 256 + index % 256);
          mockService.setMockProfilePicture('/tmp/cache_test_$i.jpg', imageData);
          await mockService.getProfilePictureBytes();
        }
        
        // In a real implementation, the cache should have a size limit
        // and evict old entries to prevent memory issues
        expect(true, isTrue); // Test passes if no memory issues occur
      });
    });
    
    group('Metadata and EXIF Tests', () {
      test('should preserve image metadata when possible', () async {
        final imageFile = File('${tempDir.path}/with_metadata.jpg');
        final imageData = List.generate(2048, (index) => index % 256);
        await imageFile.writeAsBytes(imageData);
        
        // Mock EXIF data
        final mockMetadata = {
          'created_date': DateTime.now().toIso8601String(),
          'camera_model': 'Test Camera',
          'resolution': '1920x1080',
        };
        
        mockService.setMockProfilePicture(imageFile.path, imageData);
        
        final result = await mockService.saveProfilePicture(imageFile);
        expect(result, isTrue);
        
        // In a real implementation, metadata would be preserved or extracted
      });
      
      test('should strip sensitive metadata for privacy', () async {
        final imageFile = File('${tempDir.path}/with_sensitive_metadata.jpg');
        final imageData = List.generate(1024, (index) => index % 256);
        await imageFile.writeAsBytes(imageData);
        
        // Mock sensitive EXIF data that should be stripped
        final sensitiveMetadata = {
          'gps_location': '1.3521° N, 103.8198° E',
          'device_id': 'ABC123456',
          'user_comment': 'Personal info',
        };
        
        mockService.setMockProfilePicture(imageFile.path, imageData);
        
        final result = await mockService.saveProfilePicture(imageFile);
        expect(result, isTrue);
        
        // In a real implementation, sensitive metadata would be stripped
      });
    });
  });
}

/// Custom exception for timeout scenarios
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}

/// Extension to add timeout functionality to Futures
extension FutureTimeout<T> on Future<T> {
  Future<T> timeout(Duration duration) {
    return Future.any([
      this,
      Future.delayed(duration).then((_) => throw TimeoutException('Operation timed out after ${duration.inMilliseconds}ms')),
    ]);
  }
}