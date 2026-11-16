import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为后台常驻 Accessory 应用（不占 Dock）
        NSApp.setActivationPolicy(.accessory)
    }
    
    // 关键：当关闭窗口/点击外部隐藏弹窗时，严禁退出应用！
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct LivePowerFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = PowerModel()
    
    var body: some Scene {
        MenuBarExtra {
            PowerFlowPopoverView(model: model)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: menuBarIcon)
                Text(menuBarTitle)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private var menuBarIcon: String {
        if model.isCharging {
            return "bolt.fill"
        } else if model.isExternalConnected {
            return "powerplug.fill"
        } else {
            return "battery.75percent"
        }
    }
    
    private var menuBarTitle: String {
        let watts: Double
        if model.isExternalConnected && model.adapterWatts > 0 {
            watts = model.adapterWatts
        } else {
            watts = model.systemWatts
        }
        return String(format: "%.1fW", watts)
    }
}
