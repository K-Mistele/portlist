import Foundation
import Cocoa
import Darwin

protocol PortMonitorDelegate: AnyObject {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [PortInfo])
}

// Structures for parsing sysctl network data
struct XinpGen {
    var xig_len: UInt32
    var xig_count: UInt32
    var xig_gen: UInt64
    var xig_sogen: UInt64
}

struct XTcpCb {
    var xt_len: UInt32
    var xt_inp: XInpCb
    var xt_tp: XTcpCb_tp
    var xt_socket: XSocket
}

struct XInpCb {
    var xi_len: UInt32
    var xi_inp: InpCb
    var xi_socket: XSocket
}

struct InpCb {
    var inp_fport: UInt16
    var inp_lport: UInt16
    var inp_faddr: in_addr
    var inp_laddr: in_addr
    var inp_gencnt: UInt64
    var inp_flags: UInt32
    var inp_vflag: UInt8
    var inp_ip_ttl: UInt8
    var inp_ip_p: UInt8
    var inp_ip_minttl: UInt8
    // Additional fields would go here but we only need the above
}

struct XTcpCb_tp {
    var t_segq: UInt64
    var t_dupacks: Int32
    var t_timer: [Int32]
    var t_state: Int32
    // Additional fields...
}

struct XSocket {
    var xso_len: UInt32
    var xso_so: UInt64
    var so_type: UInt16
    var so_options: UInt16
    var so_linger: UInt16
    var so_state: UInt16
    var so_pcb: UInt64
    var xso_protocol: Int32
    var xso_family: Int32
    var so_qlen: UInt16
    var so_incqlen: UInt16
    var so_qlimit: UInt16
    var so_timeo: Int16
    var so_error: UInt16
    var so_pgid: pid_t
    var so_oobmark: UInt32
    var so_rcv: XSockbuf
    var so_snd: XSockbuf
    var so_uid: uid_t
}

struct XSockbuf {
    var sb_cc: UInt32
    var sb_hiwat: UInt32
    var sb_mbcnt: UInt32
    var sb_mbmax: UInt32
    var sb_lowat: Int32
    var sb_flags: Int16
    var sb_timeo: Int16
}

class PortMonitor {
    weak var delegate: PortMonitorDelegate?
    private let processQueue = DispatchQueue(label: "com.portlist.monitor", qos: .utility)
    
    // Define TCP states
    private let TCPS_LISTEN: Int32 = 2
    
    // Define ephemeral port range (macOS typically uses 49152-65535, but we'll be conservative)
    private let EPHEMERAL_PORT_START: UInt16 = 32768
    
    func refreshPorts() {
        processQueue.async {
            let ports = self.scanListeningPorts()
            DispatchQueue.main.async {
                self.delegate?.portMonitor(self, didUpdatePorts: ports)
            }
        }
    }
    
    private func scanListeningPorts() -> [PortInfo] {
        var ports: [PortInfo] = []
        
        // Use lsof with specific filters for listening ports only
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", "-P", "-n", "-sTCP:LISTEN"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            ports = parseListeningPortsFromLsofOutput(output)
        } catch {
            print("Error running lsof: \(error)")
        }
        
        return ports.sorted { $0.port < $1.port }
    }
    
    private func parseListeningPortsFromLsofOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty || line.hasPrefix("COMMAND") { continue }
            
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count < 9 { continue }
            
            let pidString = components[1]
            let name = components[8] // The connection info is in the 9th field (index 8)
            
            guard let pid = Int(pidString) else { continue }
            
            // Extract port from the name field (format: *:port or host:port)
            if let port = extractPort(from: name) {
                // Only include non-ephemeral ports
                if port > 0 && port < Int(EPHEMERAL_PORT_START) {
                    let processInfo = getDetailedProcessInfoNative(pid: Int32(pid))
                    
                    let portInfo = PortInfo(
                        port: port,
                        pid: Int(processInfo.pid),
                        processName: processInfo.name,
                        user: processInfo.user,
                        command: processInfo.name,
                        memoryUsage: processInfo.memoryUsage,
                        cpuUsage: processInfo.cpuUsage,
                        parentProcess: processInfo.parentProcess,
                        executablePath: processInfo.executablePath,
                        rawMemoryUsage: processInfo.rawMemoryUsage,
                        fullCommandLine: processInfo.fullCommandLine
                    )
                    
                    // Avoid duplicates
                    if !ports.contains(where: { $0.port == portInfo.port && $0.pid == portInfo.pid }) {
                        ports.append(portInfo)
                    }
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
    
    private struct ProcessInfo {
        let pid: Int32
        let name: String
        let user: String
        let memoryUsage: String
        let cpuUsage: String
        let parentProcess: String
        let executablePath: String
        let rawMemoryUsage: String
        let fullCommandLine: String
    }
    
    private func getDetailedProcessInfoNative(pid: Int32) -> ProcessInfo {
        // Get process name using proc_name
        let maxPathSize = 4096 // Use a reasonable constant instead of PROC_PIDPATHINFO_MAXSIZE
        var processName = [CChar](repeating: 0, count: maxPathSize)
        let nameResult = proc_name(pid, &processName, UInt32(maxPathSize))
        let name = nameResult > 0 ? String(cString: processName) : "Unknown"
        
        // Get executable path using proc_pidpath
        var pathBuffer = [CChar](repeating: 0, count: maxPathSize)
        let pathResult = proc_pidpath(pid, &pathBuffer, UInt32(maxPathSize))
        let execPath = pathResult > 0 ? String(cString: pathBuffer) : name
        
        // Get process info using proc_pidinfo
        var procInfo = proc_taskinfo()
        let infoSize = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &procInfo, Int32(infoSize))
        
        var memoryUsage = "N/A"
        var rawMemoryUsage = "N/A"
        var cpuUsage = "0.0%"
        var userName = "Unknown"
        var parentName = "Unknown"
        
        if result == Int32(infoSize) {
            // Calculate memory usage
            let residentSize = procInfo.pti_resident_size
            let totalMemory = Foundation.ProcessInfo.processInfo.physicalMemory
            let memoryPercent = (Double(residentSize) / Double(totalMemory)) * 100.0
            
            memoryUsage = String(format: "%.1f%%", memoryPercent)
            rawMemoryUsage = formatMemorySize(bytes: residentSize)
            
            // CPU usage from task info (this is cumulative, not current)
            let totalTime = procInfo.pti_total_user + procInfo.pti_total_system
            cpuUsage = String(format: "%.1f%%", Double(totalTime) / 1000000.0) // Convert to percentage
        }
        
        // Get user info using getpwuid
        if result == Int32(infoSize) {
            // Use a simpler approach for getting user info
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-p", "\(pid)", "-o", "user="]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                userName = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if userName.isEmpty { userName = "Unknown" }
            } catch {
                userName = "Unknown"
            }
        }
        
        // Get parent process info
        let parentPid = getParentPIDFromPID(pid: Int(pid))
        if parentPid > 0 {
            var parentProcessName = [CChar](repeating: 0, count: maxPathSize)
            let parentResult = proc_name(Int32(parentPid), &parentProcessName, UInt32(maxPathSize))
            parentName = parentResult > 0 ? String(cString: parentProcessName) : "Unknown"
        }
        
        // Get command line (simplified - just use the executable name for now)
        let commandLine = (execPath as NSString).lastPathComponent
        
        return ProcessInfo(
            pid: pid,
            name: name,
            user: userName,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            parentProcess: parentName,
            executablePath: execPath,
            rawMemoryUsage: rawMemoryUsage,
            fullCommandLine: commandLine
        )
    }
    
    private func formatMemorySize(bytes: UInt64) -> String {
        if bytes == 0 {
            return "N/A"
        }
        
        if bytes < 1024 * 1024 {
            // Less than 1 MB, show in KB
            return "\(bytes / 1024) KB"
        } else if bytes < 1024 * 1024 * 1024 {
            // Less than 1 GB, show in MB
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        } else {
            // 1 GB or more, show in GB
            let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB", gb)
        }
    }
    
    func terminateProcess(pid: Int, force: Bool) {
        let signal = force ? SIGKILL : SIGTERM
        let result = kill(pid_t(pid), signal)
        
        if result == 0 {
            // Success - refresh ports after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshPorts()
            }
        } else {
            // Handle error
            let errorMessage = String(cString: strerror(errno))
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = "Failed to terminate process PID \(pid): \(errorMessage)"
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
        // Use proc_pidinfo with PROC_PIDTBSDINFO to get parent PID
        var bsdInfo = proc_bsdinfo()
        let infoSize = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(infoSize))
        
        if result == Int32(infoSize) {
            return Int(bsdInfo.pbi_ppid)
        }
        
        return 0
    }
    
    func getDetailedProcessInfo(pid: Int) -> (processName: String, commandLine: String, memoryUsage: String, cpuUsage: String, parentProcess: String, rawMemoryUsage: String) {
        let processInfo = getDetailedProcessInfoNative(pid: Int32(pid))
        
        return (
            processName: processInfo.name,
            commandLine: processInfo.fullCommandLine,
            memoryUsage: processInfo.memoryUsage,
            cpuUsage: processInfo.cpuUsage,
            parentProcess: processInfo.parentProcess,
            rawMemoryUsage: processInfo.rawMemoryUsage
        )
    }
}