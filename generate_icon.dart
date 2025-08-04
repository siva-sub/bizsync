import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// This script generates app icons from Font Awesome icons
// Run: dart run generate_icon.dart

void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Icon configuration
  const iconData = Icons.business_center; // Business briefcase icon
  const iconSize = 192.0;
  const iconColor = Color(0xFF2196F3); // Material Blue
  const backgroundColor = Colors.white;
  
  // Create main icon
  final mainIcon = await createIcon(
    iconData: iconData,
    size: 512,
    iconSize: iconSize * 2.0,
    iconColor: iconColor,
    backgroundColor: backgroundColor,
  );
  
  // Create foreground icon for adaptive icon
  final foregroundIcon = await createIcon(
    iconData: iconData,
    size: 512,
    iconSize: iconSize * 2.0,
    iconColor: iconColor,
    backgroundColor: Colors.transparent,
  );
  
  // Save icons
  await File('assets/icon/app_icon.png').writeAsBytes(mainIcon);
  await File('assets/icon/app_icon_foreground.png').writeAsBytes(foregroundIcon);
  
  print('Icons generated successfully!');
  print('- assets/icon/app_icon.png');
  print('- assets/icon/app_icon_foreground.png');
  print('\nNext steps:');
  print('1. Run: flutter pub get');
  print('2. Run: flutter pub run flutter_launcher_icons');
  
  exit(0);
}

Future<Uint8List> createIcon({
  required IconData iconData,
  required double size,
  required double iconSize,
  required Color iconColor,
  required Color backgroundColor,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size, size),
  );
  
  // Draw background
  if (backgroundColor != Colors.transparent) {
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), backgroundPaint);
  }
  
  // Draw icon
  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: iconData.fontFamily,
        color: iconColor,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  final offset = Offset(
    (size - textPainter.width) / 2,
    (size - textPainter.height) / 2,
  );
  textPainter.paint(canvas, offset);
  
  // Convert to image
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return byteData!.buffer.asUint8List();
}