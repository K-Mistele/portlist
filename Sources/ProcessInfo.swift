import Foundation
import Cocoa

struct PortInfo {
    let port: Int
    let pid: Int
    let processName: String
    let user: String
    let command: String
    let memoryUsage: String
    let cpuUsage: String
    let parentProcess: String
    
    var icon: NSImage? {
        return getProcessIcon()
    }
    
    private func getProcessIcon() -> NSImage? {
        // Try to get the app icon from the running application
        let runningApps = NSWorkspace.shared.runningApplications
        
        // First try to match by process identifier
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            return app.icon
        }
        
        // Try to match by bundle identifier or name
        let bundleId = getBundleIdentifier()
        if !bundleId.isEmpty,
           let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
            return app.icon
        }
        
        // Try to get icon from executable path
        if let iconFromPath = getIconFromExecutablePath() {
            return iconFromPath
        }
        
        // Fallback to system icons based on process type
        return getSystemIcon()
    }
    
    private func getBundleIdentifier() -> String {
        // Try to extract bundle identifier from command
        if command.contains(".app/") {
            let components = command.components(separatedBy: ".app/")
            if let appPath = components.first {
                let appName = (appPath as NSString).lastPathComponent
                return "com.\(appName.lowercased()).app"
            }
        }
        return ""
    }
    
    private func getIconFromExecutablePath() -> NSImage? {
        // If the command contains a path to an app, try to get its icon
        if command.contains(".app/") {
            let components = command.components(separatedBy: " ")
            for component in components {
                if component.contains(".app/") {
                    let appPath = component.components(separatedBy: ".app/").first! + ".app"
                    return NSWorkspace.shared.icon(forFile: appPath)
                }
            }
        }
        
        // Try to get icon for the executable itself
        let executablePath = command.components(separatedBy: " ").first ?? ""
        if !executablePath.isEmpty && FileManager.default.fileExists(atPath: executablePath) {
            return NSWorkspace.shared.icon(forFile: executablePath)
        }
        
        return nil
    }
    
    private func getSystemIcon() -> NSImage? {
        let lowerProcessName = processName.lowercased()
        
        // Map common process names to system icons
        switch lowerProcessName {
        case let name where name.contains("python"):
            return NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Python")
        case let name where name.contains("node"):
            return NSImage(systemSymbolName: "globe.americas.fill", accessibilityDescription: "Node.js")
        case let name where name.contains("java"):
            return NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Java")
        case let name where name.contains("docker"):
            return NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "Docker")
        case let name where name.contains("nginx"), let name where name.contains("apache"):
            return NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Web Server")
        case let name where name.contains("postgres"), let name where name.contains("mysql"):
            return NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: "Database")
        case let name where name.contains("ssh"):
            return NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "SSH")
        case let name where name.contains("chrome"), let name where name.contains("safari"), let name where name.contains("firefox"):
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser")
        default:
            return NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Application")
        }
    }
}

extension PortInfo: Equatable {
    static func == (lhs: PortInfo, rhs: PortInfo) -> Bool {
        return lhs.port == rhs.port && lhs.pid == rhs.pid
    }
}

extension PortInfo: CustomStringConvertible {
    var description: String {
        return "Port \(port): \(processName) (PID: \(pid)) - \(command)"
    }
}