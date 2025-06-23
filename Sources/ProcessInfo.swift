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
    let executablePath: String
    let rawMemoryUsage: String
    let fullCommandLine: String
    
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
        // For maximum compatibility, return nil and let the system handle it
        // System symbols may not be available on older macOS versions
        return nil
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