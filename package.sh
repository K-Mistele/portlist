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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if app bundle exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo -e "${RED}❌ App bundle not found at $APP_BUNDLE${NC}"
    echo -e "${YELLOW}💡 Run ./build.sh first to build the application${NC}"
    exit 1
fi

# Ask user what type of package they want to create
echo -e "${BLUE}📦 Choose packaging format:${NC}"
echo -e "  ${YELLOW}1)${NC} ZIP archive (cross-platform, smaller size)"
echo -e "  ${YELLOW}2)${NC} DMG installer (macOS only, professional look)"
echo -e "  ${YELLOW}3)${NC} Both ZIP and DMG"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo -e "${GREEN}📦 Creating ZIP package...${NC}"
        CREATE_ZIP=true
        CREATE_DMG=false
        ;;
    2)
        echo -e "${GREEN}📦 Creating DMG installer...${NC}"
        CREATE_ZIP=false
        CREATE_DMG=true
        ;;
    3)
        echo -e "${GREEN}📦 Creating both ZIP and DMG packages...${NC}"
        CREATE_ZIP=true
        CREATE_DMG=true
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Defaulting to ZIP package.${NC}"
        CREATE_ZIP=true
        CREATE_DMG=false
        ;;
esac

# Create ZIP package if requested
if [[ "$CREATE_ZIP" == true ]]; then
    echo -e "${YELLOW}📦 Packaging $APP_NAME as ZIP...${NC}"
    
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
        echo -e "${GREEN}✅ ZIP package created successfully!${NC}"
        echo -e "${GREEN}📦 File: $APP_NAME.app.zip ($FILE_SIZE)${NC}"
    else
        echo -e "${GREEN}✅ ZIP package created successfully!${NC}"
        echo -e "${GREEN}📦 File: $APP_NAME.app.zip${NC}"
    fi

    # Create checksum for ZIP
    if command -v shasum &> /dev/null; then
        echo -e "${YELLOW}🔐 Generating ZIP checksum...${NC}"
        shasum -a 256 "$APP_NAME.app.zip" > "$APP_NAME.app.zip.sha256"
        echo -e "${GREEN}✅ ZIP checksum saved to $APP_NAME.app.zip.sha256${NC}"
    fi
fi

# Create DMG package if requested
if [[ "$CREATE_DMG" == true ]]; then
    echo -e "${YELLOW}💿 Creating DMG installer...${NC}"
    
    # Check if create_dmg.sh exists
    if [[ -f "create_dmg.sh" ]]; then
        ./create_dmg.sh
    else
        echo -e "${RED}❌ create_dmg.sh script not found${NC}"
        echo -e "${YELLOW}💡 Please ensure create_dmg.sh is in the current directory${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}🎉 Packaging complete!${NC}"

# Summary of created files
echo -e "${YELLOW}📋 Summary of created packages:${NC}"
if [[ "$CREATE_ZIP" == true && -f "$APP_NAME.app.zip" ]]; then
    echo -e "   📦 ZIP: $APP_NAME.app.zip"
    echo -e "   🔐 ZIP Checksum: $APP_NAME.app.zip.sha256"
fi
if [[ "$CREATE_DMG" == true && -f "PortList-Installer.dmg" ]]; then
    echo -e "   💿 DMG: PortList-Installer.dmg"
    echo -e "   🔐 DMG Checksum: PortList-Installer.dmg.sha256"
fi

echo -e "${YELLOW}💡 Distribution tips:${NC}"
echo -e "   • ZIP files are smaller and work on any platform"
echo -e "   • DMG files provide a professional macOS installation experience"
echo -e "   • Always include checksum files for security verification"
echo -e "   • Test your packages on a clean system before distributing"