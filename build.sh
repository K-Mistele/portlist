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

# Process app icons from Assets.xcassets
if [[ -d "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset" ]]; then
    echo -e "${YELLOW}📱 Processing app icons...${NC}"
    
    # Copy the main app icon (using the largest size for best quality)
    if [[ -f "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/1024-mac.png" ]]; then
        cp "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/1024-mac.png" "$RESOURCES_BUNDLE_DIR/AppIcon.png"
        echo -e "${GREEN}✅ App icon copied (1024x1024)${NC}"
    elif [[ -f "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/512-mac.png" ]]; then
        cp "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/512-mac.png" "$RESOURCES_BUNDLE_DIR/AppIcon.png"
        echo -e "${GREEN}✅ App icon copied (512x512)${NC}"
    elif [[ -f "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/256-mac.png" ]]; then
        cp "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset/256-mac.png" "$RESOURCES_BUNDLE_DIR/AppIcon.png"
        echo -e "${GREEN}✅ App icon copied (256x256)${NC}"
    else
        echo -e "${YELLOW}⚠️  No suitable app icon found in Assets.xcassets${NC}"
    fi
    
    # Copy menu bar template icon
    if [[ -f "$RESOURCES_DIR/network.png" ]]; then
        cp "$RESOURCES_DIR/network.png" "$RESOURCES_BUNDLE_DIR/MenuBarIcon.png"
        echo -e "${GREEN}✅ Menu bar template icon copied (network.png)${NC}"
    else
        echo -e "${YELLOW}⚠️  network.png not found - will use fallback icon${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No Assets.xcassets found - using default app icon${NC}"
fi

# Compile Swift sources
echo -e "${YELLOW}⚙️  Compiling Swift sources for Universal Binary...${NC}"

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

# Create temporary directory for individual architecture binaries
TEMP_DIR="$BUILD_DIR/temp_architectures"
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}🔧 Compiling for x86_64 (Intel)...${NC}"
# Compile for Intel (x86_64)
swiftc -o "$TEMP_DIR/${APP_NAME}_x86_64" \
    -target x86_64-apple-macos11.0 \
    -framework Cocoa \
    -framework Foundation \
    "${SWIFT_FILES[@]}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ x86_64 compilation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Compiling for arm64 (Apple Silicon)...${NC}"
# Compile for Apple Silicon (arm64)
swiftc -o "$TEMP_DIR/${APP_NAME}_arm64" \
    -target arm64-apple-macos11.0 \
    -framework Cocoa \
    -framework Foundation \
    "${SWIFT_FILES[@]}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ arm64 compilation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Creating universal binary with lipo...${NC}"
# Combine both architectures into a universal binary
lipo -create "$TEMP_DIR/${APP_NAME}_x86_64" "$TEMP_DIR/${APP_NAME}_arm64" \
     -output "$MACOS_DIR/$APP_NAME"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Universal binary creation failed${NC}"
    exit 1
fi

# Clean up temporary files
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Universal binary created successfully!${NC}"

# Verify the universal binary
echo -e "${YELLOW}🔍 Verifying universal binary architectures...${NC}"
lipo -info "$MACOS_DIR/$APP_NAME"

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

# Test if the app binary is properly built
echo -e "${YELLOW}🧪 Testing app binary...${NC}"

# For GUI apps, we just verify the binary exists and is executable
if [[ -x "$MACOS_DIR/$APP_NAME" ]]; then
    echo -e "${GREEN}✅ App binary is executable and ready${NC}"
    
    # Optional: Quick syntax check by attempting to get version info
    # This won't hang because we're not actually launching the GUI
    if file "$MACOS_DIR/$APP_NAME" | grep -q "executable"; then
        echo -e "${GREEN}✅ App binary format is valid${NC}"
    fi
else
    echo -e "${RED}❌ App binary is not executable${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Build process complete!${NC}"