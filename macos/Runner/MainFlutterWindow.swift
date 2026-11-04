import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1280, height: 760)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = "IP Profile Switcher"
    self.appearance = NSAppearance(named: .darkAqua)
    if let icon = NSImage(named: "AppIcon") {
      NSApplication.shared.applicationIconImage = icon
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
