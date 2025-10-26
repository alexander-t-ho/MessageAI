#!/bin/bash
# Update AppIcon in Assets.xcassets with generated icons

ICON_DIR="/Users/alexho/MessageAI/AppIcons"
ASSETS_DIR="/Users/alexho/MessageAI/MessageAI/MessageAI/Assets.xcassets/AppIcon.appiconset"

echo "📱 Updating App Icon..."

# Create AppIcon directory if it doesn't exist
mkdir -p "$ASSETS_DIR"

# Copy icons to Assets
echo "Copying icons..."

# Map icon files to their required names
# iPhone
cp "$ICON_DIR/Icon-180.png" "$ASSETS_DIR/Icon-App-60x60@3x.png"  # 180x180
cp "$ICON_DIR/Icon-120.png" "$ASSETS_DIR/Icon-App-60x60@2x.png"  # 120x120

# iPhone Spotlight
cp "$ICON_DIR/Icon-120.png" "$ASSETS_DIR/Icon-App-40x40@3x.png"  # 120x120
cp "$ICON_DIR/Icon-80.png" "$ASSETS_DIR/Icon-App-40x40@2x.png"   # 80x80
cp "$ICON_DIR/Icon-40.png" "$ASSETS_DIR/Icon-App-40x40@1x.png"   # 40x40

# iPhone Settings
cp "$ICON_DIR/Icon-87.png" "$ASSETS_DIR/Icon-App-29x29@3x.png"   # 87x87
cp "$ICON_DIR/Icon-58.png" "$ASSETS_DIR/Icon-App-29x29@2x.png"   # 58x58
cp "$ICON_DIR/Icon-29.png" "$ASSETS_DIR/Icon-App-29x29@1x.png"   # 29x29

# iPhone Notification
cp "$ICON_DIR/Icon-60.png" "$ASSETS_DIR/Icon-App-20x20@3x.png"   # 60x60
cp "$ICON_DIR/Icon-40.png" "$ASSETS_DIR/Icon-App-20x20@2x.png"   # 40x40
cp "$ICON_DIR/Icon-20.png" "$ASSETS_DIR/Icon-App-20x20@1x.png"   # 20x20

# iPad
cp "$ICON_DIR/Icon-152.png" "$ASSETS_DIR/Icon-App-76x76@2x.png"  # 152x152
cp "$ICON_DIR/Icon-76.png" "$ASSETS_DIR/Icon-App-76x76@1x.png"   # 76x76

# iPad Pro
cp "$ICON_DIR/Icon-167.png" "$ASSETS_DIR/Icon-App-83.5x83.5@2x.png"  # 167x167

# App Store
cp "$ICON_DIR/Icon-1024.png" "$ASSETS_DIR/Icon-App-1024x1024@1x.png"  # 1024x1024

# Create Contents.json
cat > "$ASSETS_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "Icon-App-20x20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-60x60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-60x60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-20x20@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-76x76@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-76x76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-83.5x83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ App icon updated!"
echo ""
echo "Next steps:"
echo "1. Clean build: Product → Clean Build Folder (Shift+Cmd+K)"
echo "2. Delete app from simulator"
echo "3. Rebuild: Cmd+R"
echo "4. Check homescreen for 'Cloudy' name and cloud icon"
echo ""
echo "Or run: xcodebuild -scheme MessageAI -sdk iphonesimulator clean"

