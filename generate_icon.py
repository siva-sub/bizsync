#!/usr/bin/env python3
"""
Generate app icons for BizSync using Font Awesome icons
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Create assets/icon directory if it doesn't exist
os.makedirs('assets/icon', exist_ok=True)

# Icon configuration
ICON_SIZE = 512
ICON_COLOR = (33, 150, 243)  # Material Blue
BG_COLOR = (255, 255, 255)  # White
FONT_SIZE = 320

def create_icon(size, icon_unicode, color, bg_color, transparent_bg=False):
    """Create an icon image"""
    # Create image with background
    if transparent_bg:
        image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    else:
        image = Image.new('RGBA', (size, size), bg_color + (255,))
    
    draw = ImageDraw.Draw(image)
    
    # Draw a business/sync related shape (simplified briefcase)
    # Since we can't use actual Font Awesome, let's draw a simple business icon
    margin = size // 8
    icon_rect = [margin, margin * 2, size - margin, size - margin]
    
    # Draw briefcase shape
    # Main body
    draw.rounded_rectangle(
        [icon_rect[0], icon_rect[1] + size // 8, icon_rect[2], icon_rect[3]], 
        radius=size // 20, 
        fill=color + (255,),
        outline=None
    )
    
    # Handle
    handle_width = size // 3
    handle_x = (size - handle_width) // 2
    draw.arc(
        [handle_x, icon_rect[1] - size // 16, handle_x + handle_width, icon_rect[1] + size // 8],
        start=180, end=0,
        fill=color + (255,),
        width=size // 20
    )
    
    # Lock/latch in center
    lock_size = size // 8
    lock_x = (size - lock_size) // 2
    lock_y = icon_rect[1] + (icon_rect[3] - icon_rect[1]) // 3
    draw.rectangle(
        [lock_x, lock_y, lock_x + lock_size, lock_y + lock_size // 2],
        fill=bg_color + (255,)
    )
    
    return image

# Generate main icon
main_icon = create_icon(ICON_SIZE, '\\uf0b1', ICON_COLOR, BG_COLOR, transparent_bg=False)
main_icon.save('assets/icon/app_icon.png')

# Generate foreground icon for adaptive icon (transparent background)
foreground_icon = create_icon(ICON_SIZE, '\\uf0b1', ICON_COLOR, BG_COLOR, transparent_bg=True)
foreground_icon.save('assets/icon/app_icon_foreground.png')

print("Icons generated successfully!")
print("- assets/icon/app_icon.png")
print("- assets/icon/app_icon_foreground.png")
print("\nNext steps:")
print("1. Run: flutter pub get")
print("2. Run: flutter pub run flutter_launcher_icons")