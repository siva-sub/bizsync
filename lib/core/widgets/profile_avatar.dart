import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A reusable widget for displaying user profile avatars with fallback to initials
class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String initials;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatar({
    Key? key,
    this.imagePath,
    this.imageBytes,
    required this.initials,
    this.size = 100,
    this.onTap,
    this.showEditIcon = false,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.primary;
    final effectiveTextColor = textColor ?? theme.colorScheme.onPrimary;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _hasImage
            ? null
            : LinearGradient(
                colors: [
                  effectiveBackgroundColor,
                  effectiveBackgroundColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: effectiveBackgroundColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _buildAvatarContent(effectiveTextColor),
    );

    if (showEditIcon && onTap != null) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                color: theme.colorScheme.onPrimary,
                size: size * 0.16,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  bool get _hasImage => imageBytes != null || (imagePath != null && File(imagePath!).existsSync());

  Widget _buildAvatarContent(Color textColor) {
    if (imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsContent(textColor),
        ),
      );
    }

    if (imagePath != null) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsContent(textColor),
          ),
        );
      }
    }

    return _buildInitialsContent(textColor);
  }

  Widget _buildInitialsContent(Color textColor) {
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A smaller variant of ProfileAvatar for use in lists and smaller spaces
class ProfileAvatarSmall extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String initials;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatarSmall({
    Key? key,
    this.imagePath,
    this.imageBytes,
    required this.initials,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      imagePath: imagePath,
      imageBytes: imageBytes,
      initials: initials,
      size: 40,
      onTap: onTap,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}

/// A large variant of ProfileAvatar for profile screens
class ProfileAvatarLarge extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String initials;
  final VoidCallback? onTap;
  final bool showEditIcon;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatarLarge({
    Key? key,
    this.imagePath,
    this.imageBytes,
    required this.initials,
    this.onTap,
    this.showEditIcon = false,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      imagePath: imagePath,
      imageBytes: imageBytes,
      initials: initials,
      size: 120,
      onTap: onTap,
      showEditIcon: showEditIcon,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}