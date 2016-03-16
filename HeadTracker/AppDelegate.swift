import Cocoa
import XCGLogger

let log = XCGLogger.defaultInstance()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    
    var app:Application!
    var statusItem:NSStatusItem!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        log.setup(XCGLogger.LogLevel.Debug, showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: XCGLogger.LogLevel.Debug)
        
        let icon = NSImage(named: "statusIcon")
        icon?.template = true
        
        self.statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
        self.statusItem.image = icon
        self.statusItem.menu = statusMenu
        
        app = Application()
        app.run()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
}