import Cocoa

let CoreServiceBundle = CFBundleGetBundleWithIdentifier("com.apple.CoreServices" as CFString)

let GetRunningApplicationArray: () -> [CFTypeRef] = {
    let functionPtr = CFBundleGetFunctionPointerForName(CoreServiceBundle, "_LSCopyRunningApplicationArray" as CFString)
    return unsafeBitCast(functionPtr, to:(@convention(c)(UInt)->[CFTypeRef]).self)(0xfffffffe)
}

let GetApplicationInformation: (CFTypeRef) -> [String:CFTypeRef] = { app in
    let functionPtr = CFBundleGetFunctionPointerForName(CoreServiceBundle, "_LSCopyApplicationInformation" as CFString)
    return unsafeBitCast(functionPtr, to: (@convention(c)(UInt, Any, Any)->[String:CFTypeRef]).self)(0xffffffff, app, 0)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var preferencesWindow: NSWindow!
    
    var statusBarItem : NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer : Timer? = nil
    var menu: NSMenu = NSMenu()
    var menuOpen = false
    var hasShownPreferences = false
    var appStartTime = Date()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem.button?.title = "⊚"
        statusBarItem.menu = menu
        menu.delegate = self
        
        self.menu.addItem(NSMenuItem.init(title: "Preferences", action: #selector(self.preferences), keyEquivalent: ""))
        self.menu.addItem(NSMenuItem.init(title: "Quit", action: #selector(self.quit), keyEquivalent: ""))

        UserDefaults.standard.register(defaults: ["refresh_seconds": 10.0])

        var refresh_seconds = UserDefaults.standard.float(forKey: "refresh_seconds")
        if refresh_seconds <= 0 {
            refresh_seconds = 1
        }
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(refresh_seconds), target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
    }
    
    
    @objc
    func quit() {
        NSApplication.shared.terminate(self)
    }

    
    @objc
    func preferences() {
        self.preferencesWindow!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc
    func update() {
        if (Date().timeIntervalSince(appStartTime) > 60 * 5) {
            // The app badges API call leaks memory quite badly, so restart the app programmatically every 5 minutes
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            exit(0)
        }
        
        let badgeLabelKey = "StatusLabel"

        let apps = GetRunningApplicationArray()
        let appInfos = apps.map { GetApplicationInformation($0) }
        let appBadges = appInfos
            .filter{ $0.keys.contains(badgeLabelKey) }
            .reduce(into: [:]) { $0[$1[kCFBundleIdentifierKey as String] as! String] = ($1[badgeLabelKey] as! [String:CFTypeRef])["label"] as? NSString }
        
        for app in NSWorkspace.shared.runningApplications {
            if let bundleIdentifier = app.bundleIdentifier {
                if let badge = appBadges[bundleIdentifier] {
                    if app.isHidden && badge != "" {
                        app.unhide()
                    }
                }
            }
        }
    }
}
