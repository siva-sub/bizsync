import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// File Import Result
class FileImportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final Map<String, dynamic>? data;

  FileImportResult({
    required this.success,
    this.filePath,
    this.error,
    this.data,
  });
}

/// Watch Folder Configuration
class WatchFolderConfig {
  final String id;
  final String folderPath;
  final List<String> allowedExtensions;
  final bool recursive;
  final String importType; // 'invoices', 'receipts', 'customers', etc.
  final bool autoImport;
  final Function(File file) onFileDetected;

  WatchFolderConfig({
    required this.id,
    required this.folderPath,
    required this.allowedExtensions,
    this.recursive = false,
    required this.importType,
    this.autoImport = false,
    required this.onFileDetected,
  });
}

/// Recent File Entry
class RecentFile {
  final String filePath;
  final String fileName;
  final DateTime lastAccessed;
  final String fileType;
  final int fileSize;

  RecentFile({
    required this.filePath,
    required this.fileName,
    required this.lastAccessed,
    required this.fileType,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'fileName': fileName,
    'lastAccessed': lastAccessed.toIso8601String(),
    'fileType': fileType,
    'fileSize': fileSize,
  };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
    filePath: json['filePath'],
    fileName: json['fileName'],
    lastAccessed: DateTime.parse(json['lastAccessed']),
    fileType: json['fileType'],
    fileSize: json['fileSize'],
  );
}

/// File System Integration Service for Linux Desktop
/// 
/// Provides comprehensive file system integration:
/// - Drag & drop file imports
/// - Watch folders for automatic import
/// - Native file dialogs
/// - Recent files menu
/// - File type associations
class FileSystemService extends ChangeNotifier {
  static final FileSystemService _instance = FileSystemService._internal();
  factory FileSystemService() => _instance;
  FileSystemService._internal();

  bool _isInitialized = false;
  final Map<String, WatchFolderConfig> _watchFolders = {};
  final Map<String, StreamSubscription<WatchEvent>> _watchSubscriptions = {};
  final List<RecentFile> _recentFiles = [];
  static const int _maxRecentFiles = 20;

  /// Initialize the file system service
  Future<void> initialize() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      debugPrint('File system integration not available on this platform');
      return;
    }

    try {
      // Load recent files
      await _loadRecentFiles();
      
      // Load watch folder configurations
      await _loadWatchFolderConfigs();
      
      _isInitialized = true;
      debugPrint('✅ File system service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize file system service: $e');
    }
  }

  /// Show native file picker dialog
  Future<FileImportResult> showFilePickerDialog({
    String? dialogTitle,
    List<String>? allowedExtensions,
    String? initialDirectory,
    bool allowMultiple = false,
  }) async {
    if (!_isInitialized) {
      return FileImportResult(
        success: false,
        error: 'File system service not initialized',
      );
    }

    try {
      final typeGroup = XTypeGroup(
        label: dialogTitle ?? 'Select Files',
        extensions: allowedExtensions ?? ['pdf', 'csv', 'xlsx', 'json', 'txt'],
      );

      if (allowMultiple) {
        final files = await openFiles(
          acceptedTypeGroups: [typeGroup],
          initialDirectory: initialDirectory,
        );
        
        if (files.isNotEmpty) {
          // Process multiple files
          final results = <Map<String, dynamic>>[];
          for (final file in files) {
            final result = await _processImportedFile(file);
            if (result.success && result.data != null) {
              results.add(result.data!);
            }
          }
          
          return FileImportResult(
            success: true,
            data: {'files': results},
          );
        }
      } else {
        final file = await openFile(
          acceptedTypeGroups: [typeGroup],
          initialDirectory: initialDirectory,
        );
        
        if (file != null) {
          return await _processImportedFile(file);
        }
      }
      
      return FileImportResult(
        success: false,
        error: 'No file selected',
      );
    } catch (e) {
      debugPrint('File picker error: $e');
      return FileImportResult(
        success: false,
        error: 'Failed to open file picker: $e',
      );
    }
  }

  /// Show native directory picker dialog
  Future<String?> showDirectoryPickerDialog({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    if (!_isInitialized) return null;

    try {
      final directory = await getDirectoryPath(
        confirmButtonText: 'Select',
        initialDirectory: initialDirectory,
      );
      
      return directory;
    } catch (e) {
      debugPrint('Directory picker error: $e');
      return null;
    }
  }

  /// Show save file dialog
  Future<String?> showSaveFileDialog({
    String? dialogTitle,
    String? suggestedName,
    List<String>? allowedExtensions,
    String? initialDirectory,
  }) async {
    if (!_isInitialized) return null;

    try {
      final typeGroup = XTypeGroup(
        label: dialogTitle ?? 'Save File',
        extensions: allowedExtensions ?? ['pdf', 'csv', 'xlsx'],
      );

      final result = await getSaveLocation(
        acceptedTypeGroups: [typeGroup],
        suggestedName: suggestedName,
        initialDirectory: initialDirectory,
      );
      
      return result?.path;
    } catch (e) {
      debugPrint('Save file dialog error: $e');
      return null;
    }
  }

  /// Create drag and drop widget
  Widget createDragDropWidget({
    required Widget child,
    required Function(List<XFile> files) onFilesDropped,
    List<String>? allowedExtensions,
    String? hoverText,
  }) {
    return DropTarget(
      onDragDone: (detail) {
        final files = detail.files;
        
        // Filter by allowed extensions if specified
        if (allowedExtensions != null) {
          final filteredFiles = files.where((file) {
            final extension = path.extension(file.path).toLowerCase();
            return allowedExtensions.contains(extension.substring(1));
          }).toList();
          
          if (filteredFiles.isNotEmpty) {
            onFilesDropped(filteredFiles);
          } else {
            debugPrint('No files with allowed extensions found');
          }
        } else {
          onFilesDropped(files);
        }
      },
      onDragEntered: (detail) {
        debugPrint('Drag entered');
      },
      onDragExited: (detail) {
        debugPrint('Drag exited');
      },
      child: child,
    );
  }

  /// Process imported file based on type
  Future<FileImportResult> _processImportedFile(XFile file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();
      final fileSize = await File(file.path).length();
      
      // Add to recent files
      await _addToRecentFiles(RecentFile(
        filePath: file.path,
        fileName: path.basename(file.path),
        lastAccessed: DateTime.now(),
        fileType: extension,
        fileSize: fileSize,
      ));
      
      Map<String, dynamic>? data;
      
      switch (extension) {
        case '.csv':
          data = await _processCsvFile(file);
          break;
        case '.xlsx':
          data = await _processExcelFile(file);
          break;
        case '.json':
          data = await _processJsonFile(file);
          break;
        case '.pdf':
          data = await _processPdfFile(file);
          break;
        case '.txt':
          data = await _processTextFile(file);
          break;
        default:
          data = {'type': 'unknown', 'path': file.path};
      }
      
      return FileImportResult(
        success: true,
        filePath: file.path,
        data: data,
      );
    } catch (e) {
      debugPrint('Error processing file ${file.path}: $e');
      return FileImportResult(
        success: false,
        filePath: file.path,
        error: 'Failed to process file: $e',
      );
    }
  }

  /// Process CSV file
  Future<Map<String, dynamic>> _processCsvFile(XFile file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    
    if (lines.isEmpty) {
      throw Exception('Empty CSV file');
    }
    
    final headers = lines.first.split(',');
    final rows = <Map<String, String>>[];
    
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        final values = lines[i].split(',');
        final row = <String, String>{};
        
        for (int j = 0; j < headers.length && j < values.length; j++) {
          row[headers[j].trim()] = values[j].trim();
        }
        
        rows.add(row);
      }
    }
    
    return {
      'type': 'csv',
      'headers': headers,
      'rows': rows,
      'rowCount': rows.length,
    };
  }

  /// Process Excel file (placeholder - would need excel package)
  Future<Map<String, dynamic>> _processExcelFile(XFile file) async {
    // In a real implementation, you'd use the excel package
    return {
      'type': 'excel',
      'path': file.path,
      'message': 'Excel processing not yet implemented',
    };
  }

  /// Process JSON file
  Future<Map<String, dynamic>> _processJsonFile(XFile file) async {
    final content = await file.readAsString();
    final data = jsonDecode(content);
    
    return {
      'type': 'json',
      'data': data,
    };
  }

  /// Process PDF file (placeholder - would need pdf processing)
  Future<Map<String, dynamic>> _processPdfFile(XFile file) async {
    return {
      'type': 'pdf',
      'path': file.path,
      'message': 'PDF processing not yet implemented',
    };
  }

  /// Process text file
  Future<Map<String, dynamic>> _processTextFile(XFile file) async {
    final content = await file.readAsString();
    
    return {
      'type': 'text',
      'content': content,
      'lineCount': content.split('\n').length,
    };
  }

  /// Add watch folder
  Future<bool> addWatchFolder(WatchFolderConfig config) async {
    if (!_isInitialized) return false;
    
    try {
      final directory = Directory(config.folderPath);
      if (!await directory.exists()) {
        debugPrint('Watch folder does not exist: ${config.folderPath}');
        return false;
      }
      
      // Create watcher
      final watcher = DirectoryWatcher(config.folderPath);
      
      // Subscribe to events
      final subscription = watcher.events.listen((event) {
        _handleWatchEvent(config, event);
      });
      
      _watchFolders[config.id] = config;
      _watchSubscriptions[config.id] = subscription;
      
      await _saveWatchFolderConfigs();
      
      debugPrint('Watch folder added: ${config.folderPath}');
      return true;
    } catch (e) {
      debugPrint('Failed to add watch folder: $e');
      return false;
    }
  }

  /// Handle watch folder events
  void _handleWatchEvent(WatchFolderConfig config, WatchEvent event) {
    if (event.type == ChangeType.ADD) {
      final file = File(event.path);
      final extension = path.extension(event.path).toLowerCase();
      
      // Check if file extension is allowed
      if (config.allowedExtensions.contains(extension.substring(1))) {
        debugPrint('New file detected in watch folder: ${event.path}');
        
        if (config.autoImport) {
          // Auto-import the file
          _autoImportFile(file, config);
        } else {
          // Just notify about the file
          config.onFileDetected(file);
        }
      }
    }
  }

  /// Auto-import file from watch folder
  Future<void> _autoImportFile(File file, WatchFolderConfig config) async {
    try {
      final xFile = XFile(file.path);
      final result = await _processImportedFile(xFile);
      
      if (result.success) {
        debugPrint('Auto-imported file: ${file.path}');
        // Handle the imported data based on config.importType
        _handleAutoImportedData(result.data!, config.importType);
      } else {
        debugPrint('Failed to auto-import file: ${result.error}');
      }
    } catch (e) {
      debugPrint('Auto-import error: $e');
    }
  }

  /// Handle auto-imported data
  void _handleAutoImportedData(Map<String, dynamic> data, String importType) {
    switch (importType) {
      case 'invoices':
        _importInvoiceData(data);
        break;
      case 'customers':
        _importCustomerData(data);
        break;
      case 'products':
        _importProductData(data);
        break;
      case 'receipts':
        _importReceiptData(data);
        break;
      default:
        debugPrint('Unknown import type: $importType');
    }
  }

  /// Import invoice data
  void _importInvoiceData(Map<String, dynamic> data) {
    debugPrint('Importing invoice data: $data');
    // Process invoice data
  }

  /// Import customer data
  void _importCustomerData(Map<String, dynamic> data) {
    debugPrint('Importing customer data: $data');
    // Process customer data
  }

  /// Import product data
  void _importProductData(Map<String, dynamic> data) {
    debugPrint('Importing product data: $data');
    // Process product data
  }

  /// Import receipt data
  void _importReceiptData(Map<String, dynamic> data) {
    debugPrint('Importing receipt data: $data');
    // Process receipt data
  }

  /// Remove watch folder
  Future<bool> removeWatchFolder(String configId) async {
    final subscription = _watchSubscriptions[configId];
    if (subscription != null) {
      await subscription.cancel();
      _watchSubscriptions.remove(configId);
    }
    
    _watchFolders.remove(configId);
    await _saveWatchFolderConfigs();
    
    debugPrint('Watch folder removed: $configId');
    return true;
  }

  /// Add file to recent files list
  Future<void> _addToRecentFiles(RecentFile file) async {
    // Remove existing entry for the same file
    _recentFiles.removeWhere((f) => f.filePath == file.filePath);
    
    // Add to beginning of list
    _recentFiles.insert(0, file);
    
    // Limit list size
    if (_recentFiles.length > _maxRecentFiles) {
      _recentFiles.removeRange(_maxRecentFiles, _recentFiles.length);
    }
    
    await _saveRecentFiles();
    notifyListeners();
  }

  /// Get recent files
  List<RecentFile> getRecentFiles({int? limit}) {
    if (limit != null && limit < _recentFiles.length) {
      return _recentFiles.sublist(0, limit);
    }
    return List.unmodifiable(_recentFiles);
  }

  /// Clear recent files
  Future<void> clearRecentFiles() async {
    _recentFiles.clear();
    await _saveRecentFiles();
    notifyListeners();
  }

  /// Save recent files to persistent storage
  Future<void> _saveRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFilesJson = _recentFiles.map((f) => f.toJson()).toList();
      await prefs.setString('recent_files', jsonEncode(recentFilesJson));
    } catch (e) {
      debugPrint('Failed to save recent files: $e');
    }
  }

  /// Load recent files from persistent storage
  Future<void> _loadRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFilesString = prefs.getString('recent_files');
      
      if (recentFilesString != null) {
        final recentFilesList = jsonDecode(recentFilesString) as List;
        _recentFiles.clear();
        
        for (final fileJson in recentFilesList) {
          try {
            final recentFile = RecentFile.fromJson(fileJson);
            // Check if file still exists
            if (await File(recentFile.filePath).exists()) {
              _recentFiles.add(recentFile);
            }
          } catch (e) {
            debugPrint('Failed to load recent file entry: $e');
          }
        }
        
        debugPrint('Loaded ${_recentFiles.length} recent files');
      }
    } catch (e) {
      debugPrint('Failed to load recent files: $e');
    }
  }

  /// Save watch folder configurations
  Future<void> _saveWatchFolderConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = _watchFolders.values.map((config) => {
        'id': config.id,
        'folderPath': config.folderPath,
        'allowedExtensions': config.allowedExtensions,
        'recursive': config.recursive,
        'importType': config.importType,
        'autoImport': config.autoImport,
      }).toList();
      
      await prefs.setString('watch_folder_configs', jsonEncode(configsJson));
    } catch (e) {
      debugPrint('Failed to save watch folder configs: $e');
    }
  }

  /// Load watch folder configurations
  Future<void> _loadWatchFolderConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsString = prefs.getString('watch_folder_configs');
      
      if (configsString != null) {
        final configsList = jsonDecode(configsString) as List;
        
        for (final configJson in configsList) {
          // Note: We can't restore the onFileDetected callback from storage
          // This would need to be re-registered by the application
          debugPrint('Watch folder config found: ${configJson['folderPath']}');
        }
      }
    } catch (e) {
      debugPrint('Failed to load watch folder configs: $e');
    }
  }

  /// Get watch folders
  List<WatchFolderConfig> get watchFolders => _watchFolders.values.toList();

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the file system service
  Future<void> dispose() async {
    // Cancel all watch subscriptions
    for (final subscription in _watchSubscriptions.values) {
      await subscription.cancel();
    }
    
    _watchSubscriptions.clear();
    _watchFolders.clear();
    
    await _saveRecentFiles();
    
    _isInitialized = false;
    debugPrint('File system service disposed');
  }
}