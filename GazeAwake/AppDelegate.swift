import AppKit
import Foundation
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let cameraManager = CameraManager()
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var toggleItem: NSMenuItem!
    private var stateItem: NSMenuItem!
    private var errorItem: NSMenuItem!
    private var wakeOnGazeItem: NSMenuItem!
    private let wakePreferenceKey = "wakeDisplayOnGaze"
    private let powerQueue = DispatchQueue(label: "net.xgxgx.gazeawake.display-wake", qos: .utility)
    private var userActivityAssertionID = IOPMAssertionID(0)
    private var displaySleepAssertionID = IOPMAssertionID(0)
    private var isLookingAtScreen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [wakePreferenceKey: true])
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()
        wireCameraCallbacks()
        cameraManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cameraManager.stop()
        powerQueue.sync { releaseUserActivityAssertion() }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "GazeAwake MacBook 注视感知")
            button.image?.isTemplate = true
            button.toolTip = "GazeAwake · MacBook 注视感知"
        }

        statusMenu = NSMenu()
        stateItem = NSMenuItem(title: "状态：初始化…", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        statusMenu.addItem(stateItem)
        toggleItem = NSMenuItem(title: "暂停检测", action: #selector(toggleDetection), keyEquivalent: "p")
        toggleItem.target = self
        statusMenu.addItem(toggleItem)
        wakeOnGazeItem = NSMenuItem(title: "注视时唤醒并保持亮屏",
                                    action: #selector(toggleWakeOnGaze),
                                    keyEquivalent: "w")
        wakeOnGazeItem.target = self
        wakeOnGazeItem.state = wakeOnGazeEnabled ? .on : .off
        statusMenu.addItem(wakeOnGazeItem)
        errorItem = NSMenuItem(title: "", action: #selector(openCameraPrivacy), keyEquivalent: "")
        errorItem.target = self
        errorItem.isHidden = true
        statusMenu.addItem(errorItem)
        statusMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
    }

    private func wireCameraCallbacks() {
        cameraManager.onRunningChanged = { [weak self] running in
            guard let self else { return }
            self.toggleItem.title = running ? "暂停检测" : "开始检测"
            if !running {
                self.powerQueue.async { [weak self] in self?.releaseUserActivityAssertion() }
            }
            if !running && self.stateItem.title == "状态：注视屏幕" {
                self.stateItem.title = "状态：已暂停"
            } else if running {
                self.stateItem.title = "状态：检测中…"
            }
        }
        cameraManager.onStateChanged = { [weak self] looking in
            guard let self else { return }
            self.isLookingAtScreen = looking
            self.stateItem.title = looking ? "状态：注视屏幕" : "状态：未注视"
            self.errorItem.isHidden = true
            if looking && self.wakeOnGazeEnabled {
                self.wakeAndKeepDisplayAwake()
            } else if !looking {
                self.powerQueue.async { [weak self] in self?.releaseUserActivityAssertion() }
            }
        }
        cameraManager.onError = { [weak self] error in
            guard let self else { return }
            self.stateItem.title = "状态：无法访问摄像头"
            self.toggleItem.title = "重试检测"
            self.errorItem.title = "打开摄像头隐私设置…"
            self.errorItem.isHidden = false
            NSLog("GazeAwake: %@", error.localizedDescription)
        }
    }

    private var wakeOnGazeEnabled: Bool {
        UserDefaults.standard.bool(forKey: wakePreferenceKey)
    }

    private func wakeAndKeepDisplayAwake() {
        powerQueue.async { [weak self] in
            guard let self else { return }
            var assertionID = self.userActivityAssertionID
            let result = IOPMAssertionDeclareUserActivity(
                "GazeAwake detected the local user" as CFString,
                kIOPMUserActiveLocal,
                &assertionID
            )
            if result == kIOReturnSuccess {
                self.userActivityAssertionID = assertionID
            } else {
                NSLog("GazeAwake: display wake failed (0x%x)", result)
            }

            if self.displaySleepAssertionID == 0 {
                var displayAssertionID = IOPMAssertionID(0)
                let holdResult = IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "GazeAwake: user is looking at the screen" as CFString,
                    &displayAssertionID
                )
                if holdResult == kIOReturnSuccess {
                    self.displaySleepAssertionID = displayAssertionID
                } else {
                    NSLog("GazeAwake: keep-display-awake failed (0x%x)", holdResult)
                }
            }
        }
    }

    private func releaseUserActivityAssertion() {
        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
        if userActivityAssertionID != 0 {
            IOPMAssertionRelease(userActivityAssertionID)
            userActivityAssertionID = 0
        }
    }

    @objc private func toggleDetection() {
        errorItem.isHidden = true
        cameraManager.toggle()
    }

    @objc private func toggleWakeOnGaze() {
        let enabled = !wakeOnGazeEnabled
        UserDefaults.standard.set(enabled, forKey: wakePreferenceKey)
        wakeOnGazeItem.state = enabled ? .on : .off
        if enabled && isLookingAtScreen {
            wakeAndKeepDisplayAwake()
        } else if !enabled {
            powerQueue.async { [weak self] in self?.releaseUserActivityAssertion() }
        }
    }

    @objc private func openCameraPrivacy() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
