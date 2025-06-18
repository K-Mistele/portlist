import Foundation
import Cocoa

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
        task.launchPath = "/usr/bin/lsof"
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
            let name = components.last ?? ""
            
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
                    parentProcess: processInfo.parentProcess
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
    
    private func getProcessInfo(pid: Int) -> (command: String, memoryUsage: String, cpuUsage: String, parentProcess: String) {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "pid,ppid,command,%cpu,%mem", "-h"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let line = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = line.components(separatedBy: .whitespaces)
            
            if components.count >= 5 {
                let ppid = components[1]
                let cpu = components[3]
                let memory = components[4]
                let command = components.dropFirst(5).joined(separator: " ")
                
                let parentProcess = getParentProcessName(ppid: ppid)
                
                return (
                    command: command.isEmpty ? "Unknown" : command,
                    memoryUsage: "\(memory)%",
                    cpuUsage: "\(cpu)%",
                    parentProcess: parentProcess
                )
            }
        } catch {
            print("Error getting process info for PID \(pid): \(error)")
        }
        
        return (command: "Unknown", memoryUsage: "N/A", cpuUsage: "N/A", parentProcess: "Unknown")
    }
    
    private func getParentProcessName(ppid: String) -> String {
        guard let parentPid = Int(ppid), parentPid > 1 else { return "N/A" }
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", ppid, "-o", "comm="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let parentName = output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return parentName.isEmpty ? "Unknown" : parentName
        } catch {
            return "Unknown"
        }
    }
    
    func terminateProcess(pid: Int, force: Bool) {
        let signal = force ? "KILL" : "TERM"
        
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
}