#!/bin/bash

set -e  # Exit on any error

# Configuration
APP_NAME="PortList"
BUILD_DIR="build"
DIST_DIR="dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Packaging $APP_NAME for distribution...${NC}"

# Check if app bundle exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo -e "${RED}❌ App bundle not found at $APP_BUNDLE${NC}"
    echo -e "${YELLOW}💡 Run ./build.sh first to build the application${NC}"
    exit 1
fi

# Create distribution directory
echo -e "${YELLOW}📁 Creating distribution directory...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy app bundle to distribution directory
echo -e "${YELLOW}📋 Copying app bundle...${NC}"
cp -r "$APP_BUNDLE" "$DIST_DIR/"

# Create a README for the distribution
echo -e "${YELLOW}📝 Creating distribution README...${NC}"
cat > "$DIST_DIR/README.txt" << EOF
PortList - macOS Port Monitor
============================

Installation Instructions:
1. Drag PortList.app to your Applications folder
2. Right-click PortList.app and select "Open" (required for first launch)
3. Grant necessary permissions when prompted
4. The app will appear in your menu bar with a network icon

Usage:
- Click the network icon in your menu bar to view active ports
- Hover over port entries for detailed process information
- Use the action buttons to terminate or force-kill processes
- Use Pause/Resume to control monitoring
- Use Exit to quit the application

Requirements:
- macOS 11.0 or later
- Administrator privileges may be required for some operations

For more information, visit: https://github.com/your-username/portlist

Version: 1.0.0
Built: $(date)
EOF

# Create ZIP archive
echo -e "${YELLOW}🗜️  Creating ZIP archive...${NC}"
cd "$DIST_DIR"
zip -r "../$APP_NAME.app.zip" . -x "*.DS_Store"
cd ..

# Remove temporary distribution directory
rm -rf "$DIST_DIR"

# Calculate file size
if command -v du &> /dev/null; then
    FILE_SIZE=$(du -h "$APP_NAME.app.zip" | cut -f1)
    echo -e "${GREEN}✅ Package created successfully!${NC}"
    echo -e "${GREEN}📦 File: $APP_NAME.app.zip ($FILE_SIZE)${NC}"
else
    echo -e "${GREEN}✅ Package created successfully!${NC}"
    echo -e "${GREEN}📦 File: $APP_NAME.app.zip${NC}"
fi

# Create checksum
if command -v shasum &> /dev/null; then
    echo -e "${YELLOW}🔐 Generating checksum...${NC}"
    shasum -a 256 "$APP_NAME.app.zip" > "$APP_NAME.app.zip.sha256"
    echo -e "${GREEN}✅ Checksum saved to $APP_NAME.app.zip.sha256${NC}"
fi

echo -e "${YELLOW}💡 Distribution ready!${NC}"
echo -e "   📦 Archive: $APP_NAME.app.zip"
echo -e "   🔐 Checksum: $APP_NAME.app.zip.sha256"
echo -e "${YELLOW}💡 To distribute:${NC}"
echo -e "   1. Upload $APP_NAME.app.zip to your distribution platform"
echo -e "   2. Include the checksum file for verification"
echo -e "   3. Provide installation instructions from README.txt"

echo -e "${GREEN}🎉 Packaging complete!${NC}"