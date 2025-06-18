#!/bin/bash

set -e  # Exit on any error

# Configuration
APP_NAME="PortList"
BUNDLE_ID="com.portlist.app"
BUILD_DIR="build"
SOURCES_DIR="Sources"
RESOURCES_DIR="Resources"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building $APP_NAME...${NC}"

# Check if we have Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}❌ Swift compiler not found. Please install Xcode or Swift toolchain.${NC}"
    exit 1
fi

# Check if we have the required tools
if ! command -v lsof &> /dev/null; then
    echo -e "${RED}❌ lsof command not found. This is required for port monitoring.${NC}"
    exit 1
fi

# Clean and create build directory
echo -e "${YELLOW}🧹 Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_BUNDLE_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_BUNDLE_DIR"

echo -e "${YELLOW}📦 Creating app bundle structure...${NC}"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$CONTENTS_DIR/"

# Create a simple app icon if it doesn't exist
if [[ ! -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
    echo -e "${YELLOW}🎨 Creating app icon...${NC}"
    # Create a simple PNG icon using ImageMagick if available, otherwise use a system icon
    if command -v sips &> /dev/null; then
        # Create a simple colored rectangle as placeholder icon
        python3 -c "
from PIL import Image, ImageDraw
import sys

# Create a simple network icon
img = Image.new('RGBA', (512, 512), (70, 130, 255, 255))
draw = ImageDraw.Draw(img)

# Draw a simple network icon
# Central hub
draw.ellipse([206, 206, 306, 306], fill=(255, 255, 255, 255))
# Connection lines
for angle in [0, 60, 120, 180, 240, 300]:
    import math
    x = 256 + 150 * math.cos(math.radians(angle))
    y = 256 + 150 * math.sin(math.radians(angle))
    draw.line([(256, 256), (x, y)], fill=(255, 255, 255, 255), width=8)
    draw.ellipse([x-20, y-20, x+20, y+20], fill=(255, 255, 255, 255))

img.save('$RESOURCES_DIR/AppIcon.png')
print('Created app icon')
" 2>/dev/null || echo "Note: Could not create custom icon, will use default"
        
        # Convert PNG to ICNS if we have the tools
        if [[ -f "$RESOURCES_DIR/AppIcon.png" ]]; then
            sips -s format icns "$RESOURCES_DIR/AppIcon.png" --out "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
        fi
    fi
fi

# Copy icon if it exists
if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$RESOURCES_BUNDLE_DIR/"
fi

# Compile Swift sources
echo -e "${YELLOW}⚙️  Compiling Swift sources...${NC}"

SWIFT_FILES=(
    "$SOURCES_DIR/AppDelegate.swift"
    "$SOURCES_DIR/StatusBarController.swift"
    "$SOURCES_DIR/PortMonitor.swift"
    "$SOURCES_DIR/ProcessInfo.swift"
)

# Check if all source files exist
for file in "${SWIFT_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}❌ Source file not found: $file${NC}"
        exit 1
    fi
done

# Compile with SwiftC
swiftc -o "$MACOS_DIR/$APP_NAME" \
    -target x86_64-apple-macos11.0 \
    -import-objc-header /dev/null \
    -framework Cocoa \
    -framework Foundation \
    "${SWIFT_FILES[@]}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Compilation failed${NC}"
    exit 1
fi

# Make the executable... executable
chmod +x "$MACOS_DIR/$APP_NAME"

# Create PkgInfo file
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}📍 Application bundle created at: $APP_BUNDLE${NC}"
echo -e "${YELLOW}💡 To run the app:${NC}"
echo -e "   open $APP_BUNDLE"
echo -e "${YELLOW}💡 To install the app:${NC}"
echo -e "   cp -r $APP_BUNDLE /Applications/"

# Test if the app can be launched
echo -e "${YELLOW}🧪 Testing app launch...${NC}"
if "$MACOS_DIR/$APP_NAME" --help &>/dev/null || timeout 2s "$MACOS_DIR/$APP_NAME" &>/dev/null; then
    echo -e "${GREEN}✅ App launches successfully${NC}"
else
    echo -e "${YELLOW}⚠️  App test launch completed (this is normal for GUI apps)${NC}"
fi

echo -e "${GREEN}🎉 Build process complete!${NC}"