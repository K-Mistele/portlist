import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize the status bar controller
        statusBarController = StatusBarController()
        
        // Hide the app from the dock since it's a menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Prevent the app from terminating when all windows are closed
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources
        statusBarController?.cleanup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate the app when windows are closed
        return false
    }
}