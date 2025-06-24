# PortList - macOS Port Monitor

A professional macOS menu bar application that displays active network ports, their associated processes, and provides process management capabilities.

## 🎯 Features

- **Menu Bar Integration**: Lives in your macOS menu bar for instant access
- **Real-time Port Monitoring**: Shows all active network ports and listening services
- **Process Information**: Displays process names with detailed tooltips
- **Process Management**: Terminate or force-kill processes directly from the interface
- **Performance Control**: Pause/resume monitoring to manage system resources
- **Native macOS Design**: Clean UI with smooth animations and system integration

## 📦 Quick Install (End Users)

### Option 1: Download Pre-built DMG
1. Download `PortList-Installer.dmg` from releases
2. Double-click to mount the DMG
3. Drag `PortList.app` to the `Applications` folder
4. Launch from Applications or Spotlight
5. Grant network permissions when prompted

### Option 2: Build from Source
Follow the [Development Setup](#-development-setup) section below.

## 🛠 Development Setup

Perfect for developers who want to build, modify, or distribute PortList.

### Prerequisites

- **macOS 11.0+** (Big Sur or later)
- **Xcode Command Line Tools**: Install with `xcode-select --install`
- **Apple Developer Account** (for signing & distribution)

### Quick Start

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd portlist

# 2. Build the application
./build.sh

# 3. Test your build
open build/PortList.app
```

## 🔐 Code Signing & Distribution

For distributing your app professionally without security warnings.

### Step 1: Apple Developer Account Setup

1. **Join Apple Developer Program**: Visit https://developer.apple.com/programs/ ($99/year)
2. **Wait for approval** (usually same day for individual accounts)

### Step 2: Certificate Setup

Run the interactive certificate setup:

```bash
./setup_signing.sh
```

This script will:
- ✅ Guide you through creating a certificate request
- ✅ Open Apple Developer Portal for you
- ✅ Install your certificate automatically
- ✅ Test code signing with your app

### Step 3: Complete Distribution Pipeline

Create a professionally signed and notarized DMG:

```bash
./complete_dmg_distribution.sh
```

This script handles **everything**:
1. **Signs your app** with Developer ID
2. **Creates DMG installer** with Applications folder
3. **Signs the DMG** for distribution
4. **Notarizes with Apple** (removes all security warnings)
5. **Staples notarization ticket** for offline verification
6. **Generates security checksum**

**Output**: `PortList-Installer.dmg` - Ready for professional distribution!

## 📁 Project Structure

```
portlist/
├── Sources/                        # Swift source code
│   ├── AppDelegate.swift          # Main app entry point
│   ├── StatusBarController.swift  # Menu bar management
│   ├── PortMonitor.swift          # Port scanning logic
│   └── ProcessInfo.swift          # Process information
├── Resources/                      # App resources
│   ├── Info.plist                 # App configuration
│   └── Assets.xcassets/           # Icons and images
├── build.sh                       # Build the application
├── setup_signing.sh               # Certificate setup helper
├── complete_dmg_distribution.sh   # Full distribution pipeline
└── README.md                      # This file
```

## 🚀 Distribution Workflow

### For Development/Testing
```bash
./build.sh                    # Build app
open build/PortList.app       # Test locally
```

### For Public Distribution
```bash
./build.sh                           # 1. Build the app
./setup_signing.sh                   # 2. Setup certificates (first time only)
./complete_dmg_distribution.sh       # 3. Create signed, notarized DMG
```

**Result**: Professional DMG with no security warnings on any macOS version.

## 🔧 Advanced Configuration

### Environment Variables

```bash
# Specify signing identity explicitly
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Use custom bundle ID
export BUNDLE_ID="com.yourcompany.portlist"
```

### Manual Signing (Advanced)

```bash
# Sign app manually
codesign --force --sign "Developer ID Application: Your Name" build/PortList.app/

# Verify signature
codesign -dv build/PortList.app/

# Check signature details
spctl -a -t exec -vv build/PortList.app/
```

## 🐛 Troubleshooting

### Build Issues

**"Swift compiler not found"**
```bash
xcode-select --install
```

**"Permission denied"**
```bash
chmod +x build.sh setup_signing.sh complete_dmg_distribution.sh
```

### Code Signing Issues

**"No signing identity found"**
- Run `./setup_signing.sh` to setup certificates
- Verify Apple Developer account is active

**"Certificate doesn't match private key"**
- Use Keychain Access to create certificate request
- Download certificate directly from Apple Developer Portal

### Notarization Issues

**"Invalid credentials"**
- Use app-specific password from https://appleid.apple.com/
- Not your regular Apple ID password

**"Notarization failed"**
```bash
# Check notarization log
xcrun notarytool log <submission-id> --keychain-profile portlist-notary
```

### Runtime Issues

**App won't open**
- Right-click → "Open" for first launch
- Check Console.app for error messages

**No ports showing**
- Grant network access permissions
- Run from Terminal to see debug output:
```bash
./build/PortList.app/Contents/MacOS/PortList
```

## 📋 Version Control Best Practices

### What's Ignored (via .gitignore)
- ✅ Build artifacts (`build/`, `*.dmg`, `*.zip`)
- ✅ Certificates and private keys (`certificates/`, `*.p12`)
- ✅ System files (`.DS_Store`, etc.)
- ✅ Temporary files (`dmg_temp/`, `*.log`)

### What Should Be Committed
- ✅ Source code (`Sources/`)
- ✅ Resources (`Resources/`)
- ✅ Build scripts (`*.sh`)
- ✅ Documentation (`README.md`, `LICENSE`)

## 🔒 Security Notes

### Certificate Management
- **Never commit** private keys (`.key` files) to version control
- **Store certificates securely** in your keychain
- **Use app-specific passwords** for notarization, not your Apple ID password

### Distribution Security
- **Always sign apps** before distribution
- **Use notarization** for public distribution
- **Provide checksums** (SHA256) with releases

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly: `./build.sh && open build/PortList.app`
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Create a Pull Request

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Open a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check this README for comprehensive guides

---

**Ready to build professional macOS apps?** Start with `./build.sh` and work your way up to `./complete_dmg_distribution.sh` for production-ready distribution! 🚀