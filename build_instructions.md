# Building PortList on macOS

Since this project was developed in a Linux environment, here are the specific instructions for building and running PortList on macOS.

## Prerequisites

1. **macOS 11.0 or later**
2. **Xcode 13.0 or later** (or Swift toolchain)
   - Install from Mac App Store or Apple Developer site
   - Run: `xcode-select --install` to install command line tools
3. **Python 3 with PIL (optional for icon generation)**
   - Install: `pip3 install Pillow`

## Quick Start

1. **Clone/Download the project**
   ```bash
   git clone <repository>
   cd portlist
   ```

2. **Create app icon (optional)**
   ```bash
   # If you have PIL installed:
   python3 create_icon.py
   
   # Or use the simple SVG-based approach:
   ./create_simple_icon.sh
   ```

3. **Build the application**
   ```bash
   ./build.sh
   ```

4. **Test the application**
   ```bash
   open build/PortList.app
   ```

5. **Package for distribution**
   ```bash
   ./package.sh
   ```

## Manual Build Process

If the build script doesn't work, you can build manually:

### Step 1: Create App Bundle Structure
```bash
mkdir -p build/PortList.app/Contents/{MacOS,Resources}
```

### Step 2: Copy Configuration Files
```bash
cp Resources/Info.plist build/PortList.app/Contents/
cp Resources/AppIcon.icns build/PortList.app/Contents/Resources/ 2>/dev/null || true
echo "APPL????" > build/PortList.app/Contents/PkgInfo
```

### Step 3: Compile Swift Sources
```bash
swiftc -o build/PortList.app/Contents/MacOS/PortList \
    -target x86_64-apple-macos11.0 \
    -framework Cocoa \
    -framework Foundation \
    Sources/AppDelegate.swift \
    Sources/StatusBarController.swift \
    Sources/PortMonitor.swift \
    Sources/ProcessInfo.swift
```

### Step 4: Set Permissions
```bash
chmod +x build/PortList.app/Contents/MacOS/PortList
```

## Alternative: Using Xcode

1. **Create New Xcode Project**
   - Open Xcode
   - Create new macOS App project
   - Choose Swift as language

2. **Import Source Files**
   - Copy all `.swift` files from `Sources/` to your Xcode project
   - Add `Info.plist` settings to your project configuration
   - Import app icon to Assets catalog

3. **Configure Project Settings**
   - Set minimum deployment target to macOS 11.0
   - Add required frameworks: Cocoa, Foundation
   - Set LSUIElement to true in Info.plist for menu bar app

4. **Build and Run**
   - Press Cmd+R to build and run
   - Or Cmd+B to build only

## Troubleshooting

### Common Issues

**"Swift compiler not found"**
- Install Xcode command line tools: `xcode-select --install`
- Or install full Xcode from Mac App Store

**"Permission denied" when running app**
- Right-click the app and select "Open" for first launch
- Grant network access permissions when prompted

**"App damaged" warning**
- This happens with unsigned apps
- Right-click app → Open, then click "Open" in dialog

**No ports showing**
- Ensure you have active network connections
- Try running a local server: `python3 -m http.server 8000`
- Check that lsof command is available: `which lsof`

### Debugging

**Run from Terminal for debug output:**
```bash
./build/PortList.app/Contents/MacOS/PortList
```

**Check app bundle structure:**
```bash
find build/PortList.app -type f
```

**Verify Swift compilation:**
```bash
swiftc --version
```

## Code Signing (for Distribution)

### Development Signing
```bash
codesign --force --sign - build/PortList.app
```

### Distribution Signing (requires Apple Developer account)
```bash
codesign --force --sign "Developer ID Application: Your Name" build/PortList.app
```

### Notarization (for distribution outside App Store)
```bash
# Create app-specific password in Apple ID settings first
xcrun altool --notarize-app \
    --primary-bundle-id "com.portlist.app" \
    --username "your@email.com" \
    --password "app-specific-password" \
    --file PortList.app.zip
```

## Next Steps for macOS Development

1. **Set up Apple Developer Account** (for distribution)
2. **Learn Xcode** (for easier development)
3. **Understand App Store Guidelines** (if planning to distribute via App Store)
4. **Consider SwiftUI** (for modern UI development)
5. **Add Unit Tests** (using XCTest framework)

## File Structure

```
portlist/
├── Sources/                    # Swift source files
│   ├── AppDelegate.swift      # Main app entry point
│   ├── StatusBarController.swift  # Menu bar management
│   ├── PortMonitor.swift      # Port scanning logic
│   └── ProcessInfo.swift      # Process info structures
├── Resources/                 # App resources
│   ├── Info.plist            # App configuration
│   └── AppIcon.icns          # App icon
├── build/                    # Build output directory
├── build.sh                  # Build script
├── package.sh               # Packaging script
└── README.md                # Main documentation
```