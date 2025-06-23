import Cocoa

// MARK: - Port Range Structure
struct PortRange {
    let min: Int
    let max: Int
    
    func contains(_ port: Int) -> Bool {
        return port >= min && port <= max
    }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var portMonitor: PortMonitor!
    private var isPaused = false
    private var refreshTimer: Timer?
    private var showAllPorts = false
    private var isLoading = false
    private var loadingStartTime: Date?
    private var portRanges: [PortRange] = [] // Empty means show all ports
    private var menuDelegates: [LazyParentMenuDelegate] = [] // Keep strong references to delegates
    private var cachedPorts: [PortInfo] = [] // Store last known ports for stale-while-revalidate
    
    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        setupPortMonitor()
        startRefreshTimer()
        
        // Trigger initial port refresh (this will set loading state)
        refreshPorts()
    }
    
    private func setupStatusItem() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the icon (try custom icon first, fallback to emoji)
        if let statusButton = statusItem.button {
            // Try to load custom menu bar template icon
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let customIcon = NSImage(contentsOfFile: iconPath) {
                // Configure the icon for menu bar display
                customIcon.size = NSSize(width: 18, height: 18)
                customIcon.isTemplate = true  // Enable template mode for proper menu bar appearance
                statusButton.image = customIcon
                statusButton.imagePosition = .imageOnly
            } else {
                // Fallback to lightning emoji if custom icon not available
                statusButton.title = "⚡"
            }
            statusButton.toolTip = "PortList - Network Monitor"
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
        
        // Add port filter configuration
        let filterItem = NSMenuItem(title: "🎯 Configure Port Ranges", action: #selector(configurePortRanges), keyEquivalent: "")
        filterItem.target = self
        menu.addItem(filterItem)
        
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
            // Clear loading state if paused
            isLoading = false
            loadingStartTime = nil
        } else {
            startRefreshTimer()
            // Show cached ports immediately while refreshing in background
            if !cachedPorts.isEmpty {
                updatePortsList(ports: cachedPorts)
            }
            refreshPorts()
        }
    }
    
    @objc private func refreshPorts() {
        if !isPaused {
            isLoading = true
            loadingStartTime = Date()
            
            // Only show loading state if we don't have cached ports (first launch)
            if cachedPorts.isEmpty {
                updateLoadingState()
            }
            
            portMonitor.refreshPorts()
        }
    }
    
    @objc private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func toggleShowAllPorts() {
        showAllPorts.toggle()
        // Use cached ports to update the display without refreshing
        if !cachedPorts.isEmpty {
            updatePortsList(ports: cachedPorts)
        } else {
            // Fallback to refresh if no cached ports
            refreshPorts()
        }
    }
    
    @objc private func configurePortRanges() {
        let alert = NSAlert()
        alert.messageText = "Configure Port Ranges"
        alert.informativeText = """
        Enter port ranges to filter (leave empty to show all ports).
        Format: single ports (80) or ranges (8000-9000)
        Multiple ranges separated by commas: 80,443,8000-9000,3000-4000
        
        Current ranges: \(portRanges.isEmpty ? "All ports" : portRangesToString())
        """
        
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Clear Filters")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = portRangesToString()
        inputField.placeholderString = "e.g., 80,443,8000-9000,3000-4000"
        
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Apply
            let rangeString = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if rangeString.isEmpty {
                portRanges = []
            } else {
                portRanges = parsePortRanges(rangeString)
            }
            updateMenuItems() // Update header to show filtering status
            // Use cached ports to apply filter without refreshing
            if !cachedPorts.isEmpty {
                updatePortsList(ports: cachedPorts)
            } else {
                refreshPorts() // Fallback to refresh if no cached ports
            }
            
        case .alertSecondButtonReturn: // Clear Filters
            portRanges = []
            updateMenuItems() // Update header to show filtering status
            // Use cached ports to show all ports without refreshing
            if !cachedPorts.isEmpty {
                updatePortsList(ports: cachedPorts)
            } else {
                refreshPorts() // Fallback to refresh if no cached ports
            }
            
        default: // Cancel
            break
        }
    }
    
    private func portRangesToString() -> String {
        return portRanges.map { range in
            return range.min == range.max ? "\(range.min)" : "\(range.min)-\(range.max)"
        }.joined(separator: ",")
    }
    
    private func parsePortRanges(_ input: String) -> [PortRange] {
        var ranges: [PortRange] = []
        let components = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for component in components {
            if component.contains("-") {
                // Range format: 8000-9000
                let rangeParts = component.split(separator: "-")
                if rangeParts.count == 2,
                   let min = Int(rangeParts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                   let max = Int(rangeParts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                   min <= max, min > 0, max <= 65535 {
                    ranges.append(PortRange(min: min, max: max))
                }
            } else {
                // Single port: 80
                if let port = Int(component), port > 0, port <= 65535 {
                    ranges.append(PortRange(min: port, max: port))
                }
            }
        }
        
        return ranges
    }
    
    private func shouldShowPort(_ port: PortInfo) -> Bool {
        // If no ranges are defined, show all ports
        if portRanges.isEmpty {
            return true
        }
        
        // Check if port falls within any of the defined ranges
        return portRanges.contains { range in
            range.contains(port.port)
        }
    }
    
    private func updateMenuItems() {
        guard let pauseItem = menu.item(withTitle: isPaused ? "⏸ Pause" : "▶️ Resume") ??
                               menu.item(withTitle: isPaused ? "▶️ Resume" : "⏸ Pause") else { return }
        
        pauseItem.title = isPaused ? "▶️ Resume" : "⏸ Pause"
        
        // Update header to show filtering status
        if let headerItem = menu.items.first {
            let baseTitle = "PortList - Network Monitor"
            headerItem.title = portRanges.isEmpty ? baseTitle : "\(baseTitle) (Filtered)"
        }
        
        // Update status bar tooltip to show filtering status
        if let statusButton = statusItem.button {
            let baseTooltip = "PortList - Network Monitor"
            if portRanges.isEmpty {
                statusButton.toolTip = baseTooltip
            } else {
                statusButton.toolTip = "\(baseTooltip)\nFiltering: \(portRangesToString())"
            }
        }
    }
    
    func cleanup() {
        refreshTimer?.invalidate()
        portMonitor?.cleanup()
    }
    
    // Method to add delegates from external classes
    func addMenuDelegate(_ delegate: LazyParentMenuDelegate) {
        menuDelegates.append(delegate)
    }
}

// MARK: - PortMonitorDelegate
extension StatusBarController: PortMonitorDelegate {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [PortInfo]) {
        DispatchQueue.main.async {
            self.updatePortsList(ports: ports)
        }
    }
    
    private func updateLoadingState() {
        // Clear delegates to prevent memory leaks
        menuDelegates.removeAll()
        
        // Remove existing port items AND loading/empty state items
        let itemsToRemove = menu.items.filter { item in
            // Remove port items
            if item.representedObject is PortInfo {
                return true
            }
            
            // Remove status/info items
            let title = item.title
            return title == "No active ports found" ||
                   title == "No ports found in specified ranges" ||
                   title.contains("ports total") ||
                   title.contains("ports (filtered)") ||
                   title.contains("Show More") ||
                   title.contains("Show Less") ||
                   title.contains("Loading") ||
                   title.contains("Scanning") ||
                   title.hasPrefix("📊") // Remove any count items that start with the chart emoji
        }
        
        // Remove items in reverse order to avoid index issues
        for item in itemsToRemove.reversed() {
            if let index = menu.items.firstIndex(of: item) {
                menu.removeItem(at: index)
            }
        }
        
        // Find insertion point (after the second separator)
        var separatorCount = 0
        var insertionIndex = 3 // Default fallback
        
        for (index, item) in menu.items.enumerated() {
            if item.isSeparatorItem {
                separatorCount += 1
                if separatorCount == 2 {
                    insertionIndex = index + 1
                    break
                }
            }
        }
        
        if isLoading {
            let loadingItem = NSMenuItem(title: "🔄 Scanning for active ports...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.insertItem(loadingItem, at: insertionIndex)
        }
    }
    
    private func updatePortsList(ports: [PortInfo]) {
        // Clear loading state immediately to prevent multiple calls
        isLoading = false
        loadingStartTime = nil
        
        // Cache the new ports for stale-while-revalidate
        cachedPorts = ports
        
        // Clear delegates to prevent memory leaks
        menuDelegates.removeAll()
        
        // Remove existing port items AND any loading/empty state items
        // Use a more comprehensive removal approach to prevent duplicates
        let itemsToRemove = menu.items.filter { item in
            // Remove port items
            if item.representedObject is PortInfo {
                return true
            }
            
            // Remove status/info items
            let title = item.title
            return title == "No active ports found" ||
                   title == "No ports found in specified ranges" ||
                   title.contains("ports total") ||
                   title.contains("ports (filtered)") ||
                   title.contains("Show More") ||
                   title.contains("Show Less") ||
                   title.contains("Loading") ||
                   title.contains("Scanning") ||
                   title.hasPrefix("📊") // Remove any count items that start with the chart emoji
        }
        
        // Remove items in reverse order to avoid index issues
        for item in itemsToRemove.reversed() {
            if let index = menu.items.firstIndex(of: item) {
                menu.removeItem(at: index)
            }
        }
        
        // Find insertion point (after the second separator)
        var separatorCount = 0
        var insertionIndex = 3 // Default fallback
        
        for (index, item) in menu.items.enumerated() {
            if item.isSeparatorItem {
                separatorCount += 1
                if separatorCount == 2 {
                    insertionIndex = index + 1
                    break
                }
            }
        }
        
        // Apply port range filtering first
        let filteredPorts = ports.filter { shouldShowPort($0) }
        
        // Add ports with height limit
        if filteredPorts.isEmpty {
            let noPortsItem = NSMenuItem(title: portRanges.isEmpty ? "No active ports found" : "No ports found in specified ranges", action: nil, keyEquivalent: "")
            noPortsItem.isEnabled = false
            menu.insertItem(noPortsItem, at: insertionIndex)
        } else {
            // Add port count info
            let countText = portRanges.isEmpty ? 
                "📊 \(filteredPorts.count) ports total" : 
                "📊 \(filteredPorts.count) of \(ports.count) ports (filtered)"
            let countItem = NSMenuItem(title: countText, action: nil, keyEquivalent: "")
            countItem.isEnabled = false
            menu.insertItem(countItem, at: insertionIndex)
            
            let maxVisiblePorts = 15
            let portsToShow = showAllPorts ? filteredPorts : Array(filteredPorts.prefix(maxVisiblePorts))
            
            // Add the ports
            for (index, port) in portsToShow.enumerated() {
                let portItem = createPortMenuItem(for: port)
                menu.insertItem(portItem, at: insertionIndex + 1 + index)
            }
            
            // Add Show More/Less button if needed
            if filteredPorts.count > maxVisiblePorts {
                let toggleItem = NSMenuItem(
                    title: showAllPorts ? "📋 Show Less..." : "📋 Show More (\(filteredPorts.count - maxVisiblePorts) hidden)...",
                    action: #selector(toggleShowAllPorts),
                    keyEquivalent: ""
                )
                toggleItem.target = self
                menu.insertItem(toggleItem, at: insertionIndex + 1 + portsToShow.count)
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
        
        // Show program name
        let executableItem = NSMenuItem(title: "Executable: \(port.executablePath)", action: nil, keyEquivalent: "")
        executableItem.isEnabled = false
        submenu.addItem(executableItem)
        
        // Show full command line (always show this as it contains the actual CLI command)
        if !port.fullCommandLine.isEmpty && port.fullCommandLine != "Unknown" {
            let wrappedCommand = wrapText(port.fullCommandLine, maxWidth: 80, prefix: "CLI Command: ")
            for line in wrappedCommand {
                let commandItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                commandItem.isEnabled = false
                submenu.addItem(commandItem)
            }
        }
        
        // Show memory usage with both percentage and raw amount
        let memoryText = port.rawMemoryUsage != "N/A" ? 
            "Memory: \(port.memoryUsage) (\(port.rawMemoryUsage))" : 
            "Memory: \(port.memoryUsage)"
        let memoryItem = NSMenuItem(title: memoryText, action: nil, keyEquivalent: "")
        memoryItem.isEnabled = false
        submenu.addItem(memoryItem)
        
        let cpuItem = NSMenuItem(title: "CPU: \(port.cpuUsage)", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        submenu.addItem(cpuItem)
        
        if !port.parentProcess.isEmpty && port.parentProcess != "N/A" && port.parentProcess != "Unknown" {
            let parentItem = createLazyParentMenuItem(for: port)
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
    
    private func wrapText(_ text: String, maxWidth: Int, prefix: String) -> [String] {
        if text.isEmpty || text == "Unknown" {
            return ["\(prefix)Unknown"]
        }
        
        let fullText = "\(prefix)\(text)"
        
        // If the text fits on one line, return it as is
        if fullText.count <= maxWidth {
            return [fullText]
        }
        
        var lines: [String] = []
        var currentLine = prefix
        let words = text.components(separatedBy: .whitespaces)
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            
            if testLine.count <= maxWidth {
                currentLine = testLine
            } else {
                // If current line is not empty, add it to lines
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                
                // If the word itself is too long, break it
                if word.count > maxWidth - 2 { // Leave space for indentation
                    let chunks = word.chunked(into: maxWidth - 2)
                    for (index, chunk) in chunks.enumerated() {
                        lines.append(index == 0 ? "  \(chunk)" : "  \(chunk)")
                    }
                    currentLine = ""
                } else {
                    currentLine = "  \(word)" // Indent continuation lines
                }
            }
        }
        
        // Add the last line if it's not empty
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.isEmpty ? ["\(prefix)Unknown"] : lines
    }
    
    private func createParentProcessMenuItem(for port: PortInfo, depth: Int, visitedPIDs: Set<Int>) -> NSMenuItem {
        let maxDepth = 3 // Reduced max depth to prevent crashes
        
        let parentItem = NSMenuItem(title: "Parent: \(port.parentProcess)", action: nil, keyEquivalent: "")
        
        // Safety checks: depth limit, PID validation, circular reference detection
        guard depth < maxDepth,
              port.pid > 1,
              !visitedPIDs.contains(port.pid) else {
            return parentItem
        }
        
        // Add current PID to visited set to prevent circular references
        var newVisitedPIDs = visitedPIDs
        newVisitedPIDs.insert(port.pid)
        
        // Get parent PID from the port monitor
        let parentPID = portMonitor.getParentPIDFromPID(pid: port.pid)
        
        // Validate parent PID and check for circular reference
        guard parentPID > 1,
              parentPID != port.pid, // Prevent self-reference
              !newVisitedPIDs.contains(parentPID) else {
            return parentItem
        }
        
        // Get detailed info about the parent process
        let parentInfo = portMonitor.getDetailedProcessInfo(pid: parentPID)
        
        guard parentInfo.processName != "Unknown" && !parentInfo.processName.isEmpty else {
            return parentItem
        }
        
        let parentSubmenu = NSMenu()
        
        // Parent process info header
        let infoHeader = NSMenuItem(title: "📋 Parent Process Info", action: nil, keyEquivalent: "")
        infoHeader.isEnabled = false
        parentSubmenu.addItem(infoHeader)
        
        // PID info
        let pidItem = NSMenuItem(title: "PID: \(parentPID)", action: nil, keyEquivalent: "")
        pidItem.isEnabled = false
        parentSubmenu.addItem(pidItem)
        
        // Executable name
        let executableItem = NSMenuItem(title: "Executable: \(parentInfo.processName)", action: nil, keyEquivalent: "")
        executableItem.isEnabled = false
        parentSubmenu.addItem(executableItem)
        
        // Command line (if available and different)
        if !parentInfo.commandLine.isEmpty && parentInfo.commandLine != parentInfo.processName {
            let wrappedCommand = wrapText(parentInfo.commandLine, maxWidth: 80, prefix: "CLI Command: ")
            for line in wrappedCommand.prefix(5) { // Limit lines to prevent menu overflow
                let commandItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                commandItem.isEnabled = false
                parentSubmenu.addItem(commandItem)
            }
        }
        
        // Memory and CPU info
        let memoryText = parentInfo.rawMemoryUsage != "N/A" ? 
            "Memory: \(parentInfo.memoryUsage) (\(parentInfo.rawMemoryUsage))" : 
            "Memory: \(parentInfo.memoryUsage)"
        let memoryItem = NSMenuItem(title: memoryText, action: nil, keyEquivalent: "")
        memoryItem.isEnabled = false
        parentSubmenu.addItem(memoryItem)
        
        let cpuItem = NSMenuItem(title: "CPU: \(parentInfo.cpuUsage)", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        parentSubmenu.addItem(cpuItem)
        
        // Recursively add grandparent if it exists and we haven't hit limits
        if !parentInfo.parentProcess.isEmpty && 
           parentInfo.parentProcess != "N/A" && 
           parentInfo.parentProcess != "Unknown" &&
           depth + 1 < maxDepth {
            
            parentSubmenu.addItem(NSMenuItem.separator())
            
            // Create a mock PortInfo for the parent to recurse
            let parentPortInfo = PortInfo(
                port: 0, // Not applicable for parent process
                pid: parentPID,
                processName: parentInfo.processName,
                user: "", // Not needed for parent display
                command: parentInfo.processName,
                memoryUsage: parentInfo.memoryUsage,
                cpuUsage: parentInfo.cpuUsage,
                parentProcess: parentInfo.parentProcess,
                executablePath: parentInfo.processName,
                rawMemoryUsage: parentInfo.rawMemoryUsage,
                fullCommandLine: parentInfo.commandLine
            )
            
            let grandparentItem = createParentProcessMenuItem(for: parentPortInfo, depth: depth + 1, visitedPIDs: newVisitedPIDs)
            parentSubmenu.addItem(grandparentItem)
        }
        
        parentItem.submenu = parentSubmenu
        
        return parentItem
    }
    
    private func createLazyParentMenuItem(for port: PortInfo) -> NSMenuItem {
        let parentItem = NSMenuItem(title: "Parent: \(port.parentProcess)", action: nil, keyEquivalent: "")
        
        // Create a placeholder submenu that will be populated on demand
        let placeholderSubmenu = NSMenu()
        let loadingItem = NSMenuItem(title: "Loading parent info...", action: nil, keyEquivalent: "")
        loadingItem.isEnabled = false
        placeholderSubmenu.addItem(loadingItem)
        
        // Create and store delegate to prevent deallocation
        let delegate = LazyParentMenuDelegate(port: port, portMonitor: portMonitor, statusBarController: self)
        menuDelegates.append(delegate)
        placeholderSubmenu.delegate = delegate
        parentItem.submenu = placeholderSubmenu
        
        return parentItem
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

// MARK: - Lazy Parent Menu Delegate
class LazyParentMenuDelegate: NSObject, NSMenuDelegate {
    private let port: PortInfo
    private let portMonitor: PortMonitor
    private weak var statusBarController: StatusBarController?
    private var isLoaded = false
    
    init(port: PortInfo, portMonitor: PortMonitor, statusBarController: StatusBarController? = nil) {
        self.port = port
        self.portMonitor = portMonitor
        self.statusBarController = statusBarController
        super.init()
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        // Only load once
        guard !isLoaded else { return }
        isLoaded = true
        
        // Clear placeholder items
        menu.removeAllItems()
        
        // Load parent process info asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let parentPID = self.portMonitor.getParentPIDFromPID(pid: self.port.pid)
            
            guard parentPID > 1, parentPID != self.port.pid else {
                DispatchQueue.main.async {
                    let errorItem = NSMenuItem(title: "No parent process info available", action: nil, keyEquivalent: "")
                    errorItem.isEnabled = false
                    menu.addItem(errorItem)
                }
                return
            }
            
            let parentInfo = self.portMonitor.getDetailedProcessInfo(pid: parentPID)
            
            DispatchQueue.main.async {
                self.populateParentMenu(menu: menu, parentPID: parentPID, parentInfo: parentInfo)
            }
        }
    }
    
    private func populateParentMenu(menu: NSMenu, parentPID: Int, parentInfo: (processName: String, commandLine: String, memoryUsage: String, cpuUsage: String, parentProcess: String, rawMemoryUsage: String)) {
        
        guard parentInfo.processName != "Unknown" && !parentInfo.processName.isEmpty else {
            let errorItem = NSMenuItem(title: "Parent process not found", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            return
        }
        
        // Parent process info header
        let infoHeader = NSMenuItem(title: "📋 Parent Process Info", action: nil, keyEquivalent: "")
        infoHeader.isEnabled = false
        menu.addItem(infoHeader)
        
        // PID info
        let pidItem = NSMenuItem(title: "PID: \(parentPID)", action: nil, keyEquivalent: "")
        pidItem.isEnabled = false
        menu.addItem(pidItem)
        
        // Executable name
        let executableItem = NSMenuItem(title: "Executable: \(parentInfo.processName)", action: nil, keyEquivalent: "")
        executableItem.isEnabled = false
        menu.addItem(executableItem)
        
        // Command line (if available and different)
        if !parentInfo.commandLine.isEmpty && parentInfo.commandLine != parentInfo.processName {
            let wrappedCommand = self.wrapText(parentInfo.commandLine, maxWidth: 80, prefix: "CLI Command: ")
            for line in wrappedCommand.prefix(5) { // Limit lines to prevent menu overflow
                let commandItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
                commandItem.isEnabled = false
                menu.addItem(commandItem)
            }
        }
        
        // Memory and CPU info
        let memoryText = parentInfo.rawMemoryUsage != "N/A" ? 
            "Memory: \(parentInfo.memoryUsage) (\(parentInfo.rawMemoryUsage))" : 
            "Memory: \(parentInfo.memoryUsage)"
        let memoryItem = NSMenuItem(title: memoryText, action: nil, keyEquivalent: "")
        memoryItem.isEnabled = false
        menu.addItem(memoryItem)
        
        let cpuItem = NSMenuItem(title: "CPU: \(parentInfo.cpuUsage)", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)
        
        // Add grandparent if it exists (but keep it lazy too)
        if !parentInfo.parentProcess.isEmpty && 
           parentInfo.parentProcess != "N/A" && 
           parentInfo.parentProcess != "Unknown" {
            
            menu.addItem(NSMenuItem.separator())
            
            // Create a lazy grandparent item
            let grandparentItem = NSMenuItem(title: "Parent: \(parentInfo.parentProcess)", action: nil, keyEquivalent: "")
            
            let grandparentSubmenu = NSMenu()
            let loadingItem = NSMenuItem(title: "Loading grandparent info...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            grandparentSubmenu.addItem(loadingItem)
            
            // Create a mock PortInfo for the grandparent
            let parentPortInfo = PortInfo(
                port: 0,
                pid: parentPID,
                processName: parentInfo.processName,
                user: "",
                command: parentInfo.processName,
                memoryUsage: parentInfo.memoryUsage,
                cpuUsage: parentInfo.cpuUsage,
                parentProcess: parentInfo.parentProcess,
                executablePath: parentInfo.processName,
                rawMemoryUsage: parentInfo.rawMemoryUsage,
                fullCommandLine: parentInfo.commandLine
            )
            
                         // Create and store grandparent delegate
             let grandparentDelegate = LazyParentMenuDelegate(port: parentPortInfo, portMonitor: self.portMonitor, statusBarController: self.statusBarController)
             self.statusBarController?.addMenuDelegate(grandparentDelegate)
             grandparentSubmenu.delegate = grandparentDelegate
             grandparentItem.submenu = grandparentSubmenu
             menu.addItem(grandparentItem)
        }
    }
    
    private func wrapText(_ text: String, maxWidth: Int, prefix: String) -> [String] {
        if text.isEmpty || text == "Unknown" {
            return ["\(prefix)Unknown"]
        }
        
        let fullText = "\(prefix)\(text)"
        
        // If the text fits on one line, return it as is
        if fullText.count <= maxWidth {
            return [fullText]
        }
        
        var lines: [String] = []
        var currentLine = prefix
        let words = text.components(separatedBy: .whitespaces)
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            
            if testLine.count <= maxWidth {
                currentLine = testLine
            } else {
                // If current line is not empty, add it to lines
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                
                // If the word itself is too long, break it
                if word.count > maxWidth - 2 { // Leave space for indentation
                    let chunks = word.chunked(into: maxWidth - 2)
                    for (index, chunk) in chunks.enumerated() {
                        lines.append(index == 0 ? "  \(chunk)" : "  \(chunk)")
                    }
                    currentLine = ""
                } else {
                    currentLine = "  \(word)" // Indent continuation lines
                }
            }
        }
        
        // Add the last line if it's not empty
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.isEmpty ? ["\(prefix)Unknown"] : lines
    }
}

// MARK: - String Extension
extension String {
    func chunked(into size: Int) -> [String] {
        guard size > 0 else { return [self] }
        
        var chunks: [String] = []
        var currentIndex = startIndex
        
        while currentIndex < endIndex {
            let nextIndex = index(currentIndex, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[currentIndex..<nextIndex]))
            currentIndex = nextIndex
        }
        
        return chunks
    }
}