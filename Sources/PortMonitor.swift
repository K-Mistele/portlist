import Foundation
import Cocoa
import Darwin

protocol PortMonitorDelegate: AnyObject {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [PortInfo])
}

class PortMonitor {
    weak var delegate: PortMonitorDelegate?
    private let processQueue = DispatchQueue(label: "com.portlist.monitor", qos: .utility)
    
    func refreshPorts() {
        processQueue.async {
            let ports = self.scanActivePorts()
            self.delegate?.portMonitor(self, didUpdatePorts: ports)
        }
    }
    
    private func scanActivePorts() -> [PortInfo] {
        var ports: [PortInfo] = []
        
        // Use lsof to get network connections
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            ports = parsePortsFromLsofOutput(output)
        } catch {
            print("Error running lsof: \(error)")
        }
        
        return ports.sorted { $0.port < $1.port }
    }
    
    private func parsePortsFromLsofOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty || line.hasPrefix("COMMAND") { continue }
            
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count < 9 { continue }
            
            let command = components[0]
            let pidString = components[1]
            let user = components[2]
            let name = components[8] // The connection info is in the 9th field (index 8)
            
            guard let pid = Int(pidString) else { continue }
            
            // Extract port from the name field (format: *:port or host:port)
            if let port = extractPort(from: name) {
                let processInfo = getProcessInfo(pid: pid)
                
                let portInfo = PortInfo(
                    port: port,
                    pid: pid,
                    processName: command,
                    user: user,
                    command: processInfo.command,
                    memoryUsage: processInfo.memoryUsage,
                    cpuUsage: processInfo.cpuUsage,
                    parentProcess: processInfo.parentProcess,
                    executablePath: processInfo.executablePath,
                    rawMemoryUsage: processInfo.rawMemoryUsage,
                    fullCommandLine: processInfo.fullCommandLine
                )
                
                // Avoid duplicates
                if !ports.contains(where: { $0.port == port && $0.pid == pid }) {
                    ports.append(portInfo)
                }
            }
        }
        
        return ports
    }
    
    private func extractPort(from name: String) -> Int? {
        // Handle various formats: *:8080, localhost:3000, 127.0.0.1:8080, etc.
        let components = name.components(separatedBy: ":")
        if let lastComponent = components.last {
            // Remove any protocol suffix (like (LISTEN))
            let portString = lastComponent.components(separatedBy: " ").first ?? lastComponent
            return Int(portString)
        }
        return nil
    }
    
    private func getProcessInfo(pid: Int) -> (command: String, memoryUsage: String, cpuUsage: String, parentProcess: String, executablePath: String, rawMemoryUsage: String, fullCommandLine: String) {
        
        // Get basic process info using NSRunningApplication
        let runningApps = NSWorkspace.shared.runningApplications
        let app = runningApps.first { $0.processIdentifier == pid }
        
        // Get process name - use app name if available, otherwise extract from path
        let processName = app?.localizedName ?? getProcessNameFromPID(pid: pid)
        
        // Get command line arguments using a simple ps call (just for args)
        let commandLine = getCommandLineFromPID(pid: pid)
        
        // Get memory and CPU info using basic system calls
        let memoryInfo = getMemoryInfoFromPID(pid: pid)
        let cpuUsage = getCPUUsageFromPID(pid: pid)
        
        // Get parent process
        let parentPID = self.getParentPIDFromPID(pid: pid)
        let parentName = parentPID > 0 ? getProcessNameFromPID(pid: parentPID) : "Unknown"
        
        return (
            command: processName,
            memoryUsage: String(format: "%.1f%%", memoryInfo.percentage),
            cpuUsage: String(format: "%.1f%%", cpuUsage),
            parentProcess: parentName,
            executablePath: processName,
            rawMemoryUsage: formatMemorySize(rssKB: Int(memoryInfo.rssKB)),
            fullCommandLine: commandLine.isEmpty ? processName : commandLine
        )
    }
    
    private func getProcessNameFromPID(pid: Int) -> String {
        // Use a simple approach - get from running applications first
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            return app.localizedName ?? "Unknown"
        }
        
        // Fallback to ps command for process name
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "comm="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return name.isEmpty ? "Unknown" : (name as NSString).lastPathComponent
        } catch {
            return "Unknown"
        }
    }
    
    private func getCommandLineFromPID(pid: Int) -> String {
        // Use ps to get command line arguments - this is more reliable than sysctl parsing
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "args="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let commandLine = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return commandLine
        } catch {
            return ""
        }
    }
    
    private func getMemoryInfoFromPID(pid: Int) -> (rssKB: Int, percentage: Double) {
        // Use ps to get memory info - more compatible than proc_pidinfo
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "rss=,%mem="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let line = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                let rssKB = Int(components[0]) ?? 0
                let percentage = Double(components[1]) ?? 0.0
                return (rssKB: rssKB, percentage: percentage)
            }
        } catch {
            print("Error getting memory info for PID \(pid): \(error)")
        }
        
        return (rssKB: 0, percentage: 0.0)
    }
    
    private func getCPUUsageFromPID(pid: Int) -> Double {
        // Use ps to get CPU usage
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "%cpu="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let cpuString = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Double(cpuString) ?? 0.0
        } catch {
            return 0.0
        }
    }
    

    
    private func formatMemorySize(rssKB: Int) -> String {
        if rssKB == 0 {
            return "N/A"
        }
        
        let rssBytes = rssKB * 1024
        
        if rssBytes < 1024 * 1024 {
            // Less than 1 MB, show in KB
            return "\(rssKB) KB"
        } else if rssBytes < 1024 * 1024 * 1024 {
            // Less than 1 GB, show in MB
            let mb = Double(rssBytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        } else {
            // 1 GB or more, show in GB
            let gb = Double(rssBytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB", gb)
        }
    }
    

    
    func terminateProcess(pid: Int, force: Bool) {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = force ? ["-9", "\(pid)"] : ["\(pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Refresh ports after terminating process
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshPorts()
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = "Failed to terminate process PID \(pid): \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    func cleanup() {
        // Any cleanup needed
    }
    
    // MARK: - Public methods for parent process hierarchy
    
    func getParentPIDFromPID(pid: Int) -> Int {
        // Use ps to get parent PID
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "ppid="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let ppidString = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Int(ppidString) ?? 0
        } catch {
            return 0
        }
    }
    
    func getDetailedProcessInfo(pid: Int) -> (processName: String, commandLine: String, memoryUsage: String, cpuUsage: String, parentProcess: String, rawMemoryUsage: String) {
        // Get basic process info using NSRunningApplication
        let runningApps = NSWorkspace.shared.runningApplications
        let app = runningApps.first { $0.processIdentifier == pid }
        
        // Get process name - use app name if available, otherwise extract from path
        let processName = app?.localizedName ?? getProcessNameFromPID(pid: pid)
        
        // Get command line arguments
        let commandLine = getCommandLineFromPID(pid: pid)
        
        // Get memory and CPU info
        let memoryInfo = getMemoryInfoFromPID(pid: pid)
        let cpuUsage = getCPUUsageFromPID(pid: pid)
        
        // Get parent process
        let parentPID = self.getParentPIDFromPID(pid: pid)
        let parentName = parentPID > 0 ? getProcessNameFromPID(pid: parentPID) : "Unknown"
        
        return (
            processName: processName,
            commandLine: commandLine.isEmpty ? processName : commandLine,
            memoryUsage: String(format: "%.1f%%", memoryInfo.percentage),
            cpuUsage: String(format: "%.1f%%", cpuUsage),
            parentProcess: parentName,
            rawMemoryUsage: formatMemorySize(rssKB: Int(memoryInfo.rssKB))
        )
    }
}