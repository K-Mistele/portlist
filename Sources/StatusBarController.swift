import Cocoa

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var portMonitor: PortMonitor!
    private var isPaused = false
    private var refreshTimer: Timer?
    
    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        setupPortMonitor()
        startRefreshTimer()
    }
    
    private func setupStatusItem() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the icon (using a system symbol)
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Network Ports")
            statusButton.image?.isTemplate = true
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Add header
        let headerItem = NSMenuItem()
        headerItem.title = "PortList - Network Monitor"
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add control buttons
        let pauseItem = NSMenuItem(title: "⏸ Pause", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        let refreshItem = NSMenuItem(title: "🔄 Refresh Now", action: #selector(refreshPorts), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Port list will be added here dynamically
        
        menu.addItem(NSMenuItem.separator())
        
        // Add exit button
        let exitItem = NSMenuItem(title: "❌ Exit", action: #selector(exitApp), keyEquivalent: "q")
        exitItem.target = self
        menu.addItem(exitItem)
        
        statusItem.menu = menu
    }
    
    private func setupPortMonitor() {
        portMonitor = PortMonitor()
        portMonitor.delegate = self
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            if !(self?.isPaused ?? true) {
                self?.refreshPorts()
            }
        }
    }
    
    @objc private func togglePause() {
        isPaused.toggle()
        updateMenuItems()
        
        if isPaused {
            refreshTimer?.invalidate()
        } else {
            startRefreshTimer()
            refreshPorts()
        }
    }
    
    @objc private func refreshPorts() {
        if !isPaused {
            portMonitor.refreshPorts()
        }
    }
    
    @objc private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func updateMenuItems() {
        guard let pauseItem = menu.item(withTitle: isPaused ? "⏸ Pause" : "▶️ Resume") ??
                               menu.item(withTitle: isPaused ? "▶️ Resume" : "⏸ Pause") else { return }
        
        pauseItem.title = isPaused ? "▶️ Resume" : "⏸ Pause"
    }
    
    func cleanup() {
        refreshTimer?.invalidate()
        portMonitor?.cleanup()
    }
}

// MARK: - PortMonitorDelegate
extension StatusBarController: PortMonitorDelegate {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [PortInfo]) {
        DispatchQueue.main.async {
            self.updatePortsList(ports: ports)
        }
    }
    
    private func updatePortsList(ports: [PortInfo]) {
        // Remove existing port items (keep control items)
        let itemsToRemove = menu.items.filter { item in
            item.representedObject is PortInfo
        }
        
        for item in itemsToRemove {
            menu.removeItem(item)
        }
        
        // Find insertion point (after the second separator)
        let separatorCount = menu.items.filter { $0.isSeparatorItem }.count
        let insertionIndex = menu.items.firstIndex { $0.isSeparatorItem && separatorCount >= 2 } ?? 3
        
        // Add new port items
        if ports.isEmpty {
            let noPortsItem = NSMenuItem(title: "No active ports found", action: nil, keyEquivalent: "")
            noPortsItem.isEnabled = false
            menu.insertItem(noPortsItem, at: insertionIndex + 1)
        } else {
            for (index, port) in ports.enumerated() {
                let portItem = createPortMenuItem(for: port)
                menu.insertItem(portItem, at: insertionIndex + 1 + index)
            }
        }
    }
    
    private func createPortMenuItem(for port: PortInfo) -> NSMenuItem {
        let title = "Port \(port.port): \(port.processName) (PID: \(port.pid))"
        let portItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        portItem.representedObject = port
        
        // Create submenu with actions
        let submenu = NSMenu()
        
        // Process info item
        let infoItem = NSMenuItem(title: "📋 Process Info", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        submenu.addItem(infoItem)
        
        let detailsItem = NSMenuItem(title: "Command: \(port.command)", action: nil, keyEquivalent: "")
        detailsItem.isEnabled = false
        submenu.addItem(detailsItem)
        
        let memoryItem = NSMenuItem(title: "Memory: \(port.memoryUsage)", action: nil, keyEquivalent: "")
        memoryItem.isEnabled = false
        submenu.addItem(memoryItem)
        
        let cpuItem = NSMenuItem(title: "CPU: \(port.cpuUsage)", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        submenu.addItem(cpuItem)
        
        if !port.parentProcess.isEmpty {
            let parentItem = NSMenuItem(title: "Parent: \(port.parentProcess)", action: nil, keyEquivalent: "")
            parentItem.isEnabled = false
            submenu.addItem(parentItem)
        }
        
        submenu.addItem(NSMenuItem.separator())
        
        // Action buttons
        let killItem = NSMenuItem(title: "🛑 Terminate Process", action: #selector(terminateProcess(_:)), keyEquivalent: "")
        killItem.target = self
        killItem.representedObject = port
        submenu.addItem(killItem)
        
        let forceKillItem = NSMenuItem(title: "☠️ Force Kill Process", action: #selector(forceKillProcess(_:)), keyEquivalent: "")
        forceKillItem.target = self
        forceKillItem.representedObject = port
        submenu.addItem(forceKillItem)
        
        portItem.submenu = submenu
        
        return portItem
    }
    
    @objc private func terminateProcess(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? PortInfo else { return }
        
        let alert = NSAlert()
        alert.messageText = "Terminate Process"
        alert.informativeText = "Are you sure you want to terminate \(port.processName) (PID: \(port.pid))?"
        alert.addButton(withTitle: "Terminate")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            portMonitor.terminateProcess(pid: port.pid, force: false)
        }
    }
    
    @objc private func forceKillProcess(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? PortInfo else { return }
        
        let alert = NSAlert()
        alert.messageText = "Force Kill Process"
        alert.informativeText = "Are you sure you want to force kill \(port.processName) (PID: \(port.pid))? This may cause data loss."
        alert.addButton(withTitle: "Force Kill")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            portMonitor.terminateProcess(pid: port.pid, force: true)
        }
    }
}