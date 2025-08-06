import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system,
}

// Theme preferences model
class ThemePreferences {
  final AppThemeMode mode;
  final bool useSystemAccentColor;
  final Color? customPrimaryColor;

  const ThemePreferences({
    required this.mode,
    this.useSystemAccentColor = false,
    this.customPrimaryColor,
  });

  ThemePreferences copyWith({
    AppThemeMode? mode,
    bool? useSystemAccentColor,
    Color? customPrimaryColor,
  }) {
    return ThemePreferences(
      mode: mode ?? this.mode,
      useSystemAccentColor: useSystemAccentColor ?? this.useSystemAccentColor,
      customPrimaryColor: customPrimaryColor ?? this.customPrimaryColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.index,
      'useSystemAccentColor': useSystemAccentColor,
      'customPrimaryColor': customPrimaryColor?.value,
    };
  }

  static ThemePreferences fromJson(Map<String, dynamic> json) {
    return ThemePreferences(
      mode: AppThemeMode.values[json['mode'] ?? 0],
      useSystemAccentColor: json['useSystemAccentColor'] ?? false,
      customPrimaryColor: json['customPrimaryColor'] != null
          ? Color(json['customPrimaryColor'])
          : null,
    );
  }
}

// Theme service for managing app themes
class ThemeService extends ChangeNotifier {
  static const String _prefsKey = 'theme_preferences';

  ThemePreferences _preferences =
      const ThemePreferences(mode: AppThemeMode.system);
  SharedPreferences? _prefs;

  ThemePreferences get preferences => _preferences;
  ThemeMode get themeMode {
    switch (_preferences.mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    final prefsJson = _prefs!.getString(_prefsKey);
    if (prefsJson != null) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
            // Simple JSON decode - using basic parsing since we don't have dart:convert
            _parseJson(prefsJson));
        _preferences = ThemePreferences.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading theme preferences: $e');
      }
    }
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    _preferences = _preferences.copyWith(mode: mode);
    await _savePreferences();
    notifyListeners();
  }

  Future<void> updateSystemAccentColor(bool useSystemAccentColor) async {
    _preferences =
        _preferences.copyWith(useSystemAccentColor: useSystemAccentColor);
    await _savePreferences();
    notifyListeners();
  }

  Future<void> updateCustomPrimaryColor(Color? color) async {
    _preferences = _preferences.copyWith(customPrimaryColor: color);
    await _savePreferences();
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    if (_prefs == null) return;

    try {
      final prefsJson = _stringifyJson(_preferences.toJson());
      await _prefs!.setString(_prefsKey, prefsJson);
    } catch (e) {
      debugPrint('Error saving theme preferences: $e');
    }
  }

  // Simple JSON parsing without dart:convert
  Map<String, dynamic> _parseJson(String jsonString) {
    // This is a simplified parser - in production you'd use dart:convert
    // For now, we'll use a basic approach
    final Map<String, dynamic> result = {};

    // Remove brackets and split by comma
    final content = jsonString.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = content.split(',');

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();

        // Try to parse different types
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }

  String _stringifyJson(Map<String, dynamic> data) {
    final List<String> pairs = [];

    data.forEach((key, value) {
      String valueStr;
      if (value == null) {
        valueStr = 'null';
      } else if (value is bool) {
        valueStr = value.toString();
      } else if (value is int) {
        valueStr = value.toString();
      } else {
        valueStr = '"$value"';
      }
      pairs.add('"$key":$valueStr');
    });

    return '{${pairs.join(',')}}';
  }

  // Create light theme with customizations
  ThemeData createLightTheme() {
    final primaryColor =
        _preferences.customPrimaryColor ?? const Color(0xFF1565C0);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: Colors.black12,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        toolbarHeight: 64,
      ),

      // Card Theme - Commented out for Flutter 3.22.0 compatibility
      // cardTheme: CardThemeData(
      //   elevation: 2,
      //   shadowColor: Colors.black12,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(12),
      //   ),
      //   color: colorScheme.surface,
      // ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: colorScheme.surface,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: colorScheme.primary, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: colorScheme.onSurface);
        }),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Create dark theme with customizations
  ThemeData createDarkTheme() {
    final primaryColor =
        _preferences.customPrimaryColor ?? const Color(0xFF42A5F5);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Roboto',

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: Colors.black26,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        toolbarHeight: 64,
      ),

      // Card Theme - Commented out for Flutter 3.22.0 compatibility
      // cardTheme: CardThemeData(
      //   elevation: 2,
      //   shadowColor: Colors.black26,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(12),
      //   ),
      //   color: colorScheme.surface,
      // ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: colorScheme.surface,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: colorScheme.primary, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: colorScheme.onSurface);
        }),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

// Riverpod providers for theme management
final themeServiceProvider = Provider<ThemeService>((ref) {
  final service = ThemeService();
  service.initialize();
  return service;
});

final themePreferencesProvider =
    StateNotifierProvider<ThemeNotifier, ThemePreferences>((ref) {
  final service = ref.watch(themeServiceProvider);
  return ThemeNotifier(service);
});

class ThemeNotifier extends StateNotifier<ThemePreferences> {
  final ThemeService _service;

  ThemeNotifier(this._service) : super(_service.preferences) {
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    state = _service.preferences;
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    await _service.updateThemeMode(mode);
  }

  Future<void> updateSystemAccentColor(bool useSystemAccentColor) async {
    await _service.updateSystemAccentColor(useSystemAccentColor);
  }

  Future<void> updateCustomPrimaryColor(Color? color) async {
    await _service.updateCustomPrimaryColor(color);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }
}
