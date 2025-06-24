#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🍎 PortList Code Signing Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if user has developer account
echo -e "${YELLOW}📋 Prerequisites Checklist:${NC}"
echo ""
echo -e "   ${YELLOW}1.${NC} Apple Developer Account ($99/year)"
echo -e "      Sign up at: ${BLUE}https://developer.apple.com/programs/${NC}"
echo ""
echo -e "   ${YELLOW}2.${NC} Account Approved & Active"
echo -e "      Check at: ${BLUE}https://developer.apple.com/account/${NC}"
echo ""

read -p "Do you have an active Apple Developer account? (y/n): " has_account

if [[ "$has_account" != "y" && "$has_account" != "Y" ]]; then
    echo ""
    echo -e "${RED}❌ Apple Developer Account Required${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo -e "   1. Visit: https://developer.apple.com/programs/"
    echo -e "   2. Sign in with your Apple ID"
    echo -e "   3. Click 'Enroll' and follow the process"
    echo -e "   4. Pay the $99 annual fee"
    echo -e "   5. Wait for approval (usually same day)"
    echo -e "   6. Run this script again"
    echo ""
    echo -e "${BLUE}💡 Why you need this:${NC}"
    echo -e "   • Professional app signing"
    echo -e "   • No security warnings for users"
    echo -e "   • Ability to distribute publicly"
    echo -e "   • Notarization capability"
    exit 0
fi

echo ""
echo -e "${GREEN}✅ Great! Let's set up your certificate...${NC}"
echo ""

# Step 1: Create certificate request
echo -e "${YELLOW}🔐 Step 1: Creating Certificate Request${NC}"
echo ""

read -p "Enter your email address (for certificate): " email
read -p "Enter your full name (for certificate): " full_name

# Create certificate request directory
mkdir -p certificates
cd certificates

# Generate private key and certificate request
echo -e "${BLUE}   Generating private key...${NC}"
openssl genrsa -out PortListCertificateRequest.key 2048

echo -e "${BLUE}   Creating certificate request...${NC}"
openssl req -new -key PortListCertificateRequest.key -out PortListCertificateRequest.certSigningRequest -subj "/emailAddress=$email/CN=$full_name/C=US"

echo -e "${GREEN}✅ Certificate request files created:${NC}"
echo -e "   📄 PortListCertificateRequest.certSigningRequest"
echo -e "   🔐 PortListCertificateRequest.key"

# Step 2: Instructions for Apple Developer Portal
echo ""
echo -e "${YELLOW}🌐 Step 2: Upload to Apple Developer Portal${NC}"
echo ""
echo -e "${BLUE}Manual steps (I'll open the pages for you):${NC}"
echo -e "   1. Go to Apple Developer Portal"
echo -e "   2. Navigate to Certificates section"
echo -e "   3. Create new 'Developer ID Application' certificate"
echo -e "   4. Upload: $(pwd)/PortListCertificateRequest.certSigningRequest"
echo -e "   5. Download the resulting certificate"
echo -e "   6. Save it as: $(pwd)/PortListCertificate.cer"
echo ""

read -p "Press Enter to open Apple Developer Portal..."

# Open Apple Developer Portal
open "https://developer.apple.com/account/resources/certificates/list"

echo ""
echo -e "${YELLOW}⏳ Waiting for you to complete the portal steps...${NC}"
echo ""
echo -e "${BLUE}When you're done:${NC}"
echo -e "   1. Download your certificate from the portal"
echo -e "   2. Save it as: ${BLUE}PortListCertificate.cer${NC}"
echo -e "   3. Put it in: ${BLUE}$(pwd)/${NC}"
echo -e "   4. Come back here and press Enter"
echo ""

read -p "Certificate downloaded and saved? Press Enter to continue..."

# Step 3: Install certificate
echo ""
echo -e "${YELLOW}🔧 Step 3: Installing Certificate${NC}"

if [[ -f "PortListCertificate.cer" ]]; then
    echo -e "${BLUE}   Installing certificate in Keychain...${NC}"
    security import PortListCertificate.cer -k ~/Library/Keychains/login.keychain-db
    
    echo -e "${GREEN}✅ Certificate installed!${NC}"
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}🔍 Verifying installation...${NC}"
    security find-identity -v -p codesigning
    
else
    echo -e "${RED}❌ Certificate file not found: PortListCertificate.cer${NC}"
    echo -e "${YELLOW}💡 Please download it from Apple Developer Portal and save it here${NC}"
    exit 1
fi

# Step 4: Test signing
echo ""
echo -e "${YELLOW}🧪 Step 4: Testing Code Signing${NC}"

cd ..  # Back to project root

# List available identities
echo -e "${BLUE}Available signing identities:${NC}"
IDENTITIES=$(security find-identity -v -p codesigning | grep "Developer ID Application")

if [[ -n "$IDENTITIES" ]]; then
    echo "$IDENTITIES"
    echo ""
    
    # Extract the identity name
    IDENTITY_NAME=$(echo "$IDENTITIES" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    
    echo -e "${BLUE}Testing with identity: $IDENTITY_NAME${NC}"
    
    # Sign the app
    codesign --force --sign "$IDENTITY_NAME" build/PortList.app/
    
    # Verify
    codesign -dv build/PortList.app/
    
    echo ""
    echo -e "${GREEN}🎉 SUCCESS! Your app is now properly signed!${NC}"
    echo ""
    echo -e "${YELLOW}📝 Your signing identity:${NC}"
    echo -e "   ${BLUE}$IDENTITY_NAME${NC}"
    echo ""
    echo -e "${YELLOW}💡 To use in scripts:${NC}"
    echo -e "   ${BLUE}export CODE_SIGN_IDENTITY=\"$IDENTITY_NAME\"${NC}"
    echo -e "   ${BLUE}./create_dmg.sh${NC}"
    echo ""
    
    # Save identity for future use
    echo "export CODE_SIGN_IDENTITY=\"$IDENTITY_NAME\"" > .signing_identity
    echo -e "${GREEN}✅ Signing identity saved to .signing_identity${NC}"
    
else
    echo -e "${RED}❌ No Developer ID certificates found${NC}"
    echo -e "${YELLOW}💡 Please check that you completed all portal steps correctly${NC}"
fi

echo ""
echo -e "${BLUE}🎊 Setup Complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "   • Run: ${BLUE}./create_dmg.sh${NC} to create signed DMG"
echo -e "   • Consider notarization for public distribution"
echo -e "   • Test your signed app on different machines" 