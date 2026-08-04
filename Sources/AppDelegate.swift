import Cocoa
import Sparkle
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true,
                                                         updaterDelegate: nil,
                                                         userDriverDelegate: nil)
        buildMenu()

        let contentSize = NSSize(width: 672, height: 864)  // 224x288 arcade res x3
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PAC-MAN"
        window.center()

        let skView = SKView(frame: NSRect(origin: .zero, size: contentSize))
        let scene = GameScene(size: CGSize(width: 224, height: 288))
        scene.scaleMode = .aspectFit
        skView.ignoresSiblingOrder = true
        skView.presentScene(scene)
        window.contentView = skView

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Pac-Man",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let updateItem = NSMenuItem(title: "Check for Updates…",
                                    action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                    keyEquivalent: "")
        updateItem.target = updaterController
        appMenu.addItem(updateItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Pac-Man",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Pac-Man",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
