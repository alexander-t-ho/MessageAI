#!/usr/bin/env python3
"""
Create Cloudy app icon with realistic cloud and sunset gradient
Based on reference images provided
"""

from PIL import Image, ImageDraw
import math

def create_cloudy_icon(size=1024):
    """Create realistic cloud icon with beautiful sunset gradient background"""
    
    # Create image
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    
    # Draw realistic sunset gradient (based on reference image)
    # Purple/blue at top transitioning to pink/orange at bottom
    for y in range(size):
        # Calculate gradient position (0 to 1)
        t = y / size
        
        # Color stops for realistic sunset
        # Top: Deep purple-blue
        r1, g1, b1 = 100, 80, 150      # Deep purple
        # Upper middle: Purple-pink
        r2, g2, b2 = 150, 100, 180     # Purple-pink
        # Middle: Pink-orange
        r3, g3, b3 = 255, 140, 160     # Soft pink
        # Lower: Orange-pink
        r4, g4, b4 = 255, 165, 130     # Orange-pink
        # Bottom: Warm orange
        r5, g5, b5 = 255, 180, 120     # Warm orange
        
        # Multi-stop gradient for realistic sunset
        if t < 0.25:
            # Top quarter: Deep purple to purple-pink
            t2 = t * 4
            r = int(r1 + (r2 - r1) * t2)
            g = int(g1 + (g2 - g1) * t2)
            b = int(b1 + (b2 - b1) * t2)
        elif t < 0.5:
            # Second quarter: Purple-pink to soft pink
            t2 = (t - 0.25) * 4
            r = int(r2 + (r3 - r2) * t2)
            g = int(g2 + (g3 - g2) * t2)
            b = int(b2 + (b3 - b2) * t2)
        elif t < 0.75:
            # Third quarter: Soft pink to orange-pink
            t2 = (t - 0.5) * 4
            r = int(r3 + (r4 - r3) * t2)
            g = int(g3 + (g4 - g3) * t2)
            b = int(b3 + (b4 - b3) * t2)
        else:
            # Bottom quarter: Orange-pink to warm orange
            t2 = (t - 0.75) * 4
            r = int(r4 + (r5 - r4) * t2)
            g = int(g4 + (g5 - g4) * t2)
            b = int(b4 + (b5 - b4) * t2)
        
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    # Draw realistic white cloud shape (like reference image)
    cloud_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cloud_draw = ImageDraw.Draw(cloud_img)
    
    # Cloud parameters - more elongated horizontal shape
    center_x = size // 2
    center_y = int(size * 0.45)  # Position slightly above center
    
    # Pure white with slight transparency for realistic look
    white = (255, 255, 255, 255)
    
    # Create elongated cloud shape like reference
    # Base elongated ellipse for main cloud body
    cloud_width = int(size * 0.7)
    cloud_height = int(size * 0.35)
    
    # Main body - elongated horizontal ellipse
    base_bbox = [
        center_x - cloud_width // 2,
        center_y - cloud_height // 2,
        center_x + cloud_width // 2,
        center_y + cloud_height // 2
    ]
    cloud_draw.ellipse(base_bbox, fill=white)
    
    # Top bumps to create realistic fluffy cloud shape
    # Left top bump
    bump1_x = center_x - int(cloud_width * 0.3)
    bump1_y = center_y - int(cloud_height * 0.4)
    bump1_r = int(cloud_height * 0.5)
    cloud_draw.ellipse([
        bump1_x - bump1_r,
        bump1_y - bump1_r,
        bump1_x + bump1_r,
        bump1_y + bump1_r
    ], fill=white)
    
    # Center top bump (largest)
    bump2_x = center_x + int(cloud_width * 0.05)
    bump2_y = center_y - int(cloud_height * 0.55)
    bump2_r = int(cloud_height * 0.6)
    cloud_draw.ellipse([
        bump2_x - bump2_r,
        bump2_y - bump2_r,
        bump2_x + bump2_r,
        bump2_y + bump2_r
    ], fill=white)
    
    # Right top bump
    bump3_x = center_x + int(cloud_width * 0.25)
    bump3_y = center_y - int(cloud_height * 0.35)
    bump3_r = int(cloud_height * 0.45)
    cloud_draw.ellipse([
        bump3_x - bump3_r,
        bump3_y - bump3_r,
        bump3_x + bump3_r,
        bump3_y + bump3_r
    ], fill=white)
    
    # Additional smaller bumps for more realistic texture
    # Small left bump
    bump4_x = center_x - int(cloud_width * 0.15)
    bump4_y = center_y - int(cloud_height * 0.25)
    bump4_r = int(cloud_height * 0.35)
    cloud_draw.ellipse([
        bump4_x - bump4_r,
        bump4_y - bump4_r,
        bump4_x + bump4_r,
        bump4_y + bump4_r
    ], fill=white)
    
    # Small right bump
    bump5_x = center_x + int(cloud_width * 0.15)
    bump5_y = center_y - int(cloud_height * 0.2)
    bump5_r = int(cloud_height * 0.4)
    cloud_draw.ellipse([
        bump5_x - bump5_r,
        bump5_y - bump5_r,
        bump5_x + bump5_r,
        bump5_y + bump5_r
    ], fill=white)
    
    # Composite cloud onto gradient background
    img.paste(cloud_img, (0, 0), cloud_img)
    
    return img

def create_all_icon_sizes():
    """Create all required iOS icon sizes"""
    
    sizes = {
        'Icon-1024.png': 1024,  # App Store
        'Icon-180.png': 180,    # iPhone @3x
        'Icon-167.png': 167,    # iPad Pro
        'Icon-152.png': 152,    # iPad @2x
        'Icon-120.png': 120,    # iPhone @2x
        'Icon-87.png': 87,      # iPhone @3x Settings
        'Icon-80.png': 80,      # iPad @2x Spotlight
        'Icon-76.png': 76,      # iPad
        'Icon-60.png': 60,      # iPhone @1x
        'Icon-58.png': 58,      # iPhone @2x Settings
        'Icon-40.png': 40,      # Spotlight @1x
        'Icon-29.png': 29,      # Settings @1x
        'Icon-20.png': 20,      # Notification @1x
    }
    
    import os
    output_dir = '/Users/alexho/MessageAI/AppIcons'
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate master 1024x1024 first
    print("🎨 Generating realistic cloud icon with sunset gradient...")
    print("   Cloud: Fluffy white cumulus (like reference image)")
    print("   Background: Purple-pink-orange sunset gradient")
    print()
    master_icon = create_cloudy_icon(1024)
    
    # Save all sizes
    for filename, size in sizes.items():
        if size == 1024:
            icon = master_icon
        else:
            icon = master_icon.resize((size, size), Image.Resampling.LANCZOS)
        
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG')
        print(f"✓ Created {filename} ({size}x{size})")
    
    print(f"\n✅ All icons saved to: {output_dir}")
    print(f"\nNext steps:")
    print(f"1. Run: bash update_app_icon.sh")
    print(f"2. Or manually: open {output_dir}")
    print(f"3. Then rebuild in Xcode")

if __name__ == '__main__':
    try:
        create_all_icon_sizes()
    except ImportError:
        print("❌ PIL (Pillow) not installed!")
        print("Install with: pip3 install --user Pillow")
        print("\nOr it may already be installed - try running anyway")
