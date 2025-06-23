#!/bin/bash

set -e  # Exit on any error

# Configuration
APP_NAME="PortList"
BUILD_DIR="build"
DMG_DIR="dmg_temp"
FINAL_DMG_NAME="PortList-Installer.dmg"
VOLUME_NAME="PortList Installer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Creating DMG installer for $APP_NAME...${NC}"

# Check if app bundle exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo -e "${RED}❌ App bundle not found at $APP_BUNDLE${NC}"
    echo -e "${YELLOW}💡 Run ./build.sh first to build the application${NC}"
    exit 1
fi

# Check required tools
if ! command -v hdiutil &> /dev/null; then
    echo -e "${RED}❌ hdiutil not found. This tool is required for creating DMG files.${NC}"
    exit 1
fi

# Clean up any existing DMG temp directory
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "$DMG_DIR"
rm -f "$FINAL_DMG_NAME"
rm -f "temp.dmg"

# Create temporary DMG directory
mkdir -p "$DMG_DIR"

echo -e "${YELLOW}📋 Preparing DMG contents...${NC}"

# Copy app bundle to DMG directory
cp -r "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications folder symlink for easy installation
ln -s /Applications "$DMG_DIR/Applications"

# Create a README file for the DMG
cat > "$DMG_DIR/README.txt" << EOF
PortList - macOS Port Monitor
============================

INSTALLATION:
Drag PortList.app to the Applications folder

FIRST RUN:
1. Go to Applications folder
2. Right-click PortList.app and select "Open"
3. Click "Open" in the security dialog
4. Grant network access permissions when prompted

The app will appear in your menu bar with a network icon.

USAGE:
- Click the network icon to view active ports
- Hover over entries for detailed process information
- Use action buttons to manage processes
- Use Pause/Resume to control monitoring

REQUIREMENTS:
- macOS 11.0 or later
- Network access permissions

For support and updates:
https://github.com/your-username/portlist

Version: 1.0.0
EOF

# Create .DS_Store file for custom view settings (optional)
echo -e "${YELLOW}🎨 Setting up DMG appearance...${NC}"

# Calculate DMG size (add some padding)
SIZE_MB=$(du -sm "$DMG_DIR" | cut -f1)
SIZE_MB=$((SIZE_MB + 50))  # Add 50MB padding

echo -e "${YELLOW}💾 Creating temporary disk image (${SIZE_MB}MB)...${NC}"

# Create temporary DMG
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${SIZE_MB}m \
    temp.dmg

echo -e "${YELLOW}🔧 Mounting temporary disk image...${NC}"

# Mount the temporary DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "temp.dmg" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

echo -e "${BLUE}📀 Mounted device: $DEVICE${NC}"

# Wait a moment for the mount to complete
sleep 2

# Get the mount point
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Set custom icon for the volume (if available)
if [[ -f "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.png" ]]; then
    echo -e "${YELLOW}🎨 Setting volume icon...${NC}"
    # Convert PNG to icns if needed and set as volume icon
    cp "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.png" "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
fi

# Set up the window appearance using AppleScript
echo -e "${YELLOW}🖼️  Configuring window appearance...${NC}"

osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {350, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Give time for Finder to complete the setup
sleep 3

echo -e "${YELLOW}📤 Unmounting temporary disk image...${NC}"

# Unmount the temporary DMG
hdiutil detach "$DEVICE"

echo -e "${YELLOW}🗜️  Converting to final DMG format...${NC}"

# Convert to final compressed DMG
hdiutil convert "temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG_NAME"

# Clean up temporary files
rm -f "temp.dmg"
rm -rf "$DMG_DIR"

# Get final file size
if command -v du &> /dev/null; then
    FILE_SIZE=$(du -h "$FINAL_DMG_NAME" | cut -f1)
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo -e "${GREEN}📦 File: $FINAL_DMG_NAME ($FILE_SIZE)${NC}"
else
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo -e "${GREEN}📦 File: $FINAL_DMG_NAME${NC}"
fi

# Create checksum
if command -v shasum &> /dev/null; then
    echo -e "${YELLOW}🔐 Generating checksum...${NC}"
    shasum -a 256 "$FINAL_DMG_NAME" > "$FINAL_DMG_NAME.sha256"
    echo -e "${GREEN}✅ Checksum saved to $FINAL_DMG_NAME.sha256${NC}"
fi

# Optional: Code sign the DMG (requires developer certificate)
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    echo -e "${YELLOW}✍️  Code signing DMG...${NC}"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "$FINAL_DMG_NAME"
    echo -e "${GREEN}✅ DMG code signed with: $CODE_SIGN_IDENTITY${NC}"
fi

echo -e "${GREEN}🎉 DMG creation complete!${NC}"
echo -e "${YELLOW}💡 To test the DMG:${NC}"
echo -e "   open $FINAL_DMG_NAME"
echo -e "${YELLOW}💡 To distribute:${NC}"
echo -e "   1. Upload $FINAL_DMG_NAME to your distribution platform"
echo -e "   2. Include the checksum file for verification"
echo -e "   3. Users can simply drag the app to Applications"

# Test mount the final DMG to verify it works
echo -e "${YELLOW}🧪 Testing final DMG...${NC}"
TEST_MOUNT=$(hdiutil attach "$FINAL_DMG_NAME" -nobrowse -quiet)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ DMG mounts successfully${NC}"
    # Unmount test
    hdiutil detach "/Volumes/$VOLUME_NAME" -quiet
else
    echo -e "${RED}❌ DMG test mount failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎊 All done! Your DMG installer is ready for distribution.${NC}" 