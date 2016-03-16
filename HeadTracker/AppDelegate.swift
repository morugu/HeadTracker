import Cocoa
import XCGLogger

let log = XCGLogger.defaultInstance()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    
    var app:Application!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        log.setup(XCGLogger.LogLevel.Debug, showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: XCGLogger.LogLevel.Debug)
        
        app = Application()
        app.run()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
}