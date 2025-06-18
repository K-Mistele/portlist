# PortList - Quick Start Guide

Get your macOS port monitoring app running in minutes!

## 🚀 For macOS Users (Recommended Path)

### Prerequisites
- macOS 11.0+
- Xcode or Command Line Tools (`xcode-select --install`)

### Build & Run (30 seconds)
```bash
# 1. Test environment
./test_environment.sh

# 2. Create icon (optional)
./create_simple_icon.sh

# 3. Build app
./build.sh

# 4. Launch app
open build/PortList.app
```

### Install
```bash
# Copy to Applications folder
cp -r build/PortList.app /Applications/

# Launch from Applications
open /Applications/PortList.app
```

## 🛠️ What You Get

**Menu Bar App**: Network icon in your menu bar
- **Click** → View all active ports
- **Hover** → See detailed process info (CPU, memory, command line)
- **Actions** → Terminate or force-kill processes
- **Controls** → Pause/resume monitoring, refresh, exit

**Features**:
- ✅ Real-time port monitoring
- ✅ Process information display
- ✅ Process management (terminate/force-kill)
- ✅ Native macOS integration
- ✅ Clean, intuitive interface

## 📦 For Distribution

```bash
# Create distributable package
./package.sh

# Result: PortList.app.zip ready for sharing
```

## 🔧 Troubleshooting

**App won't open?**
- Right-click → Open (first launch only)
- Grant network permissions when prompted

**No ports showing?**
- Try: `python3 -m http.server 8000` (creates a test server)
- Ensure you have active network connections

**Build fails?**
- Run: `./test_environment.sh` to check setup
- Install missing dependencies shown in output

## 📚 More Information

- **Detailed Instructions**: `build_instructions.md`
- **Full Documentation**: `README.md`
- **Environment Testing**: `./test_environment.sh`

## 🎯 Next Steps to Consider

After you have the app running:

1. **Security Review**: Monitor which processes have network access
2. **Performance**: Use pause feature during intensive work
3. **Automation**: Set up monitoring alerts for specific ports
4. **Distribution**: Code sign for sharing with others
5. **Development**: Explore adding custom port filters

---

**Need Help?** Check the troubleshooting section in README.md or run `./test_environment.sh` for diagnostic information.