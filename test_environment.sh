#!/bin/bash

# Test script to verify macOS development environment

echo "🔍 Testing PortList Development Environment"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results counter
PASS=0
FAIL=0

test_command() {
    local cmd="$1"
    local desc="$2"
    local required="$3"
    
    echo -n "Testing $desc... "
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓ Found${NC}"
        PASS=$((PASS + 1))
        
        # Show version if available
        case "$cmd" in
            "swiftc")
                echo "  Version: $(swiftc --version | head -1)"
                ;;
            "xcodebuild")
                echo "  Version: $(xcodebuild -version | head -1)"
                ;;
            "python3")
                echo "  Version: $(python3 --version)"
                ;;
        esac
    else
        if [[ "$required" == "required" ]]; then
            echo -e "${RED}✗ Missing (Required)${NC}"
            FAIL=$((FAIL + 1))
        else
            echo -e "${YELLOW}✗ Missing (Optional)${NC}"
        fi
    fi
}

test_file() {
    local file="$1"
    local desc="$2"
    
    echo -n "Checking $desc... "
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ Found${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ Missing${NC}"
        FAIL=$((FAIL + 1))
    fi
}

echo "🛠️  Development Tools"
echo "-------------------"
test_command "swiftc" "Swift Compiler" "required"
test_command "xcodebuild" "Xcode Build Tools" "optional"
test_command "codesign" "Code Signing Tool" "optional"

echo ""
echo "🔧 System Tools"
echo "---------------"
test_command "lsof" "List Open Files (lsof)" "required"
test_command "ps" "Process Status (ps)" "required"
test_command "kill" "Kill Command" "required"

echo ""
echo "🎨 Icon Tools"
echo "-------------"
test_command "python3" "Python 3" "optional"
test_command "sips" "Scriptable Image Processing" "optional"
test_command "convert" "ImageMagick" "optional"

echo ""
echo "📁 Project Files"
echo "----------------"
test_file "Sources/AppDelegate.swift" "App Delegate"
test_file "Sources/StatusBarController.swift" "Status Bar Controller"
test_file "Sources/PortMonitor.swift" "Port Monitor"
test_file "Sources/ProcessInfo.swift" "Process Info"
test_file "Resources/Info.plist" "Info.plist"
test_file "build.sh" "Build Script"

echo ""
echo "🧪 Python Dependencies"
echo "----------------------"
echo -n "Testing PIL/Pillow... "
if python3 -c "from PIL import Image" 2>/dev/null; then
    echo -e "${GREEN}✓ Available${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${YELLOW}✗ Not available${NC}"
    echo "  Install with: pip3 install Pillow"
fi

echo ""
echo "🏁 Environment Test Results"
echo "==========================="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}🎉 Environment is ready for development!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./build.sh"
    echo "2. Test: open build/PortList.app"
    echo "3. Package: ./package.sh"
elif [[ $FAIL -le 2 ]]; then
    echo -e "${YELLOW}⚠️  Environment mostly ready with minor issues${NC}"
    echo ""
    echo "You can probably build the app, but consider installing missing optional tools."
else
    echo -e "${RED}❌ Environment needs setup${NC}"
    echo ""
    echo "Required steps:"
    if ! command -v swiftc &> /dev/null; then
        echo "- Install Xcode or Swift toolchain"
        echo "  Download from: https://developer.apple.com/xcode/"
        echo "  Or run: xcode-select --install"
    fi
    if ! command -v lsof &> /dev/null; then
        echo "- lsof should be available on macOS by default"
        echo "  If missing, install via Homebrew: brew install lsof"
    fi
fi

echo ""
echo "💡 For detailed instructions, see: build_instructions.md"