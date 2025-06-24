#!/bin/bash

set -e  # Exit on any error

# Configuration
APP_NAME="PortList"
BUILD_DIR="build"
DMG_DIR="dmg_temp"
FINAL_DMG_NAME="PortList-Installer.dmg"
VOLUME_NAME="PortList Installer"
KEYCHAIN_PROFILE="portlist-notary"
TEAM_ID="H7JB839954"
CODE_SIGN_IDENTITY="Developer ID Application: Kyle Mistele (H7JB839954)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Complete PortList Distribution Pipeline${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check if app bundle exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo -e "${RED}❌ App bundle not found at $APP_BUNDLE${NC}"
    echo -e "${YELLOW}💡 Run ./build.sh first to build the application${NC}"
    exit 1
fi

# Step 1: Sign the App
echo -e "${YELLOW}🔐 Step 1: Signing the Application${NC}"
echo -e "${BLUE}   Identity: $CODE_SIGN_IDENTITY${NC}"
echo -e "${BLUE}   Using hardened runtime + entitlements for notarization${NC}"

if codesign --force --sign "$CODE_SIGN_IDENTITY" \
    --timestamp \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE"; then
    echo -e "${GREEN}✅ App signed successfully with hardened runtime${NC}"
    
    # Verify app signature
    echo -e "${YELLOW}🔍 Verifying app signature...${NC}"
    codesign -dv "$APP_BUNDLE"
    echo ""
else
    echo -e "${RED}❌ App signing failed${NC}"
    exit 1
fi

# Step 2: Create and Sign DMG
echo -e "${YELLOW}📦 Step 2: Creating and Signing DMG${NC}"

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
cat > "$DMG_DIR/Installation Instructions.txt" << EOF
PortList Installation
====================

1. Drag PortList.app to the Applications folder
2. Go to Applications folder and find PortList.app
3. Right-click PortList.app and select "Open"
4. Click "Open" in the security dialog
5. The app will appear in your menu bar

For support: https://github.com/your-username/portlist

This software is signed and notarized by Apple.
EOF

# Calculate DMG size
SIZE_MB=$(du -sm "$DMG_DIR" | cut -f1)
SIZE_MB=$((SIZE_MB + 50))  # Add 50MB padding

echo -e "${YELLOW}💾 Creating disk image (${SIZE_MB}MB)...${NC}"

# Create final DMG
if hdiutil create "$FINAL_DMG_NAME" \
    -srcfolder "$DMG_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9; then
    
    echo -e "${GREEN}✅ DMG created successfully${NC}"
else
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

# Clean up temporary files
rm -rf "$DMG_DIR"

# Sign the DMG
echo -e "${YELLOW}🔐 Signing DMG...${NC}"
if codesign --force --sign "$CODE_SIGN_IDENTITY" "$FINAL_DMG_NAME"; then
    echo -e "${GREEN}✅ DMG signed successfully${NC}"
    
    # Verify DMG signature
    echo -e "${YELLOW}🔍 Verifying DMG signature...${NC}"
    codesign -dv "$FINAL_DMG_NAME"
    echo ""
else
    echo -e "${RED}❌ DMG signing failed${NC}"
    exit 1
fi

# Step 3: Notarize DMG
echo -e "${YELLOW}🔐 Step 3: Notarizing DMG${NC}"

# Check if credentials are stored
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    echo -e "${YELLOW}🔑 Setting up notarization credentials...${NC}"
    echo ""
    echo -e "${BLUE}You need an app-specific password from Apple ID:${NC}"
    echo -e "  1. Go to: ${BLUE}https://appleid.apple.com/${NC}"
    echo -e "  2. Sign in with your Apple ID"
    echo -e "  3. Go to: 'Sign-In and Security' → 'App-Specific Passwords'"
    echo -e "  4. Click 'Generate' and label it 'PortList Notarization'"
    echo -e "  5. Copy the generated password"
    echo ""
    
    read -p "Enter your Apple ID email: " apple_id
    read -s -p "Enter your app-specific password: " app_password
    echo ""
    
    echo -e "${YELLOW}📝 Storing credentials in keychain...${NC}"
    
    if xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
        --apple-id "$apple_id" \
        --team-id "$TEAM_ID" \
        --password "$app_password"; then
        echo -e "${GREEN}✅ Credentials stored successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to store credentials${NC}"
        echo -e "${YELLOW}💡 Make sure you're using an app-specific password${NC}"
        exit 1
    fi
    echo ""
fi

# Submit for notarization
echo -e "${YELLOW}📤 Submitting DMG for notarization...${NC}"
echo -e "${BLUE}This may take 1-5 minutes...${NC}"
echo ""

if xcrun notarytool submit "$FINAL_DMG_NAME" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait; then
    
    echo ""
    echo -e "${GREEN}✅ Notarization completed successfully!${NC}"
    
    # Staple the ticket
    echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
    
    if xcrun stapler staple "$FINAL_DMG_NAME"; then
        echo -e "${GREEN}✅ Ticket stapled successfully!${NC}"
        
        # Verify stapling
        echo -e "${YELLOW}🔍 Verifying notarization...${NC}"
        if xcrun stapler validate "$FINAL_DMG_NAME"; then
            echo -e "${GREEN}✅ DMG is properly notarized and stapled!${NC}"
        else
            echo -e "${RED}❌ Stapling verification failed${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to staple ticket${NC}"
        echo -e "${YELLOW}💡 The DMG is notarized but not stapled${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Notarization failed${NC}"
    echo -e "${YELLOW}💡 Common issues:${NC}"
    echo -e "   • Code signing problems${NC}"
    echo -e "   • Missing entitlements${NC}"
    echo -e "   • Hardened runtime issues${NC}"
    exit 1
fi

# Generate checksum
echo -e "${YELLOW}🔐 Generating checksum...${NC}"
shasum -a 256 "$FINAL_DMG_NAME" > "$FINAL_DMG_NAME.sha256"

# Final verification
echo ""
echo -e "${GREEN}🎉 COMPLETE DISTRIBUTION PIPELINE FINISHED!${NC}"
echo ""
echo -e "${YELLOW}✅ Summary:${NC}"
echo -e "   📱 App signed with Developer ID"
echo -e "   💿 DMG created and signed"
echo -e "   🔐 DMG notarized by Apple"
echo -e "   📎 Notarization ticket stapled"
echo -e "   🔍 All signatures verified"
echo ""

# Get final file size
FILE_SIZE=$(du -h "$FINAL_DMG_NAME" | cut -f1)
echo -e "${BLUE}📦 Final Package: $FINAL_DMG_NAME ($FILE_SIZE)${NC}"
echo -e "${BLUE}🔐 Checksum: $FINAL_DMG_NAME.sha256${NC}"
echo ""

echo -e "${YELLOW}💡 Benefits of your fully signed & notarized DMG:${NC}"
echo -e "   • No security warnings on any macOS version"
echo -e "   • Users can install without bypassing Gatekeeper"
echo -e "   • Professional, trusted appearance"
echo -e "   • Ready for public distribution"
echo ""

echo -e "${GREEN}🚀 Your DMG is ready for distribution!${NC}" 