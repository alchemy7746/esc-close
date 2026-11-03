// EscClose
// Press Escape to close the current WeChat window on macOS.
// SPDX-License-Identifier: MIT

import AppKit
import ApplicationServices
import CoreGraphics

private let targetBundleIdentifier = "com.tencent.xinWeChat"
private let escapeKeyCode: Int64 = 53
private let defaults = UserDefaults.standard
private let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/EscClose.log")

private func writeLog(_ message: String) {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let line = "[\(formatter.string(from: Date()))] \(message)\n"

    do {
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: logURL.path) {
            try line.write(to: logURL, atomically: true, encoding: .utf8)
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
        if let size = attributes[.size] as? NSNumber, size.intValue > 512_000 {
            try Data().write(to: logURL)
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
    } catch {
        NSLog("EscClose log error: %@", error.localizedDescription)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var globalKeyMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var lastHandledEscapeTime: TimeInterval = 0

    private lazy var statusInfoItem = NSMenuItem(title: "正在检测权限…", action: nil, keyEquivalent: "")
    private lazy var permissionItem = NSMenuItem(title: "检查并授予权限…", action: #selector(requestRequiredPermission), keyEquivalent: "")
    private lazy var toggleItem = NSMenuItem(title: "启用 Esc 关闭微信", action: #selector(toggleEnabled), keyEquivalent: "")
    private lazy var testItem = NSMenuItem(title: "测试：关闭微信当前窗口", action: #selector(testCloseWeChat), keyEquivalent: "")
    private lazy var retryItem = NSMenuItem(title: "重新检测权限", action: #selector(retryPermission), keyEquivalent: "")

    private var isEnabled: Bool {
        get {
            if defaults.object(forKey: "enabled") == nil {
                return true
            }
            return defaults.bool(forKey: "enabled")
        }
        set {
            defaults.set(newValue, forKey: "enabled")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        writeLog("App launched. accessibility=\(AXIsProcessTrusted()) listenPreflight=\(CGPreflightListenEventAccess())")
        setupStatusItem()
        setupMenu()
        refreshState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
        RunLoop.main.add(permissionTimer!, forMode: .common)

        if !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        removeKeyboardMonitors()
        writeLog("App terminated")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "escape", accessibilityDescription: "EscClose") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Esc"
            }
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        statusInfoItem.isEnabled = false
        menu.addItem(statusInfoItem)
        menu.addItem(.separator())

        toggleItem.target = self
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        testItem.target = self
        menu.addItem(testItem)
        menu.addItem(.separator())

        permissionItem.target = self
        menu.addItem(permissionItem)

        retryItem.target = self
        menu.addItem(retryItem)
        menu.addItem(.separator())

        let openLogItem = NSMenuItem(title: "打开诊断日志", action: #selector(openDiagnosticLog), keyEquivalent: "")
        openLogItem.target = self
        menu.addItem(openLogItem)

        let aboutItem = NSMenuItem(title: "关于EscClose", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        refreshState()
    }

    private func refreshState() {
        let trusted = AXIsProcessTrusted()

        if trusted {
            installKeyboardMonitorsIfNeeded()
        } else {
            removeKeyboardMonitors()
        }

        let weChatRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier).isEmpty
        let weChatFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == targetBundleIdentifier
        let monitorsReady = eventTap != nil || globalKeyMonitor != nil

        if !trusted {
            statusInfoItem.title = "需要授予辅助功能权限"
            permissionItem.title = "授予辅助功能权限…"
            permissionItem.isEnabled = true
        } else if !monitorsReady {
            statusInfoItem.title = "按键监听未启动，请检查权限"
            permissionItem.title = "检查并授予按键监听权限…"
            permissionItem.isEnabled = true
        } else if !isEnabled {
            statusInfoItem.title = "已暂停"
            permissionItem.title = "权限已就绪"
            permissionItem.isEnabled = false
        } else if !weChatRunning {
            statusInfoItem.title = "微信未运行"
            permissionItem.title = "权限已就绪"
            permissionItem.isEnabled = false
        } else if weChatFrontmost {
            statusInfoItem.title = "微信在前台：按 Esc 关闭当前窗口"
            permissionItem.title = "权限已就绪"
            permissionItem.isEnabled = false
        } else {
            statusInfoItem.title = "微信在前台时，按 Esc 关闭当前窗口"
            permissionItem.title = "权限已就绪"
            permissionItem.isEnabled = false
        }

        toggleItem.state = isEnabled ? .on : .off
        toggleItem.isEnabled = true
        testItem.isEnabled = trusted && weChatRunning
        statusItem.button?.appearsDisabled = !isEnabled
    }

    private func installKeyboardMonitorsIfNeeded() {
        installEventTapIfNeeded()
        installGlobalMonitorIfNeeded()
    }

    private func installEventTapIfNeeded() {
        guard eventTap == nil else { return }

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = delegate.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                writeLog("Event tap disabled by system; re-enabled")
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown,
               event.getIntegerValueField(.keyboardEventKeycode) == escapeKeyCode,
               event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
               delegate.handleEscape(source: "event-tap") {
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            writeLog("Event tap creation failed. accessibility=\(AXIsProcessTrusted()) listenPreflight=\(CGPreflightListenEventAccess())")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            writeLog("Event tap source creation failed")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
        writeLog("Event tap installed")
    }

    private func installGlobalMonitorIfNeeded() {
        guard globalKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(escapeKeyCode), !event.isARepeat else { return }
            _ = self?.handleEscape(source: "global-monitor")
        }

        if globalKeyMonitor == nil {
            writeLog("Global keyboard monitor creation failed")
        } else {
            writeLog("Global keyboard monitor installed")
        }
    }

    private func removeKeyboardMonitors() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }

        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        eventTapSource = nil
    }

    @discardableResult
    private func handleEscape(source: String) -> Bool {
        guard isEnabled else { return false }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost?.bundleIdentifier == targetBundleIdentifier else { return false }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHandledEscapeTime > 0.2 else { return false }
        lastHandledEscapeTime = now

        writeLog("Escape accepted from \(source): frontmost=\(targetBundleIdentifier) pid=\(frontmost?.processIdentifier ?? -1)")
        DispatchQueue.main.async { [weak self] in
            _ = self?.closeWeChatWindow(source: source)
        }
        return true
    }

    @discardableResult
    private func closeWeChatWindow(source: String) -> Bool {
        guard AXIsProcessTrusted() else {
            writeLog("Close failed from \(source): accessibility not trusted")
            return false
        }
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: targetBundleIdentifier)
            .first(where: { !$0.isTerminated }) else {
            writeLog("Close failed from \(source): WeChat not running")
            return false
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        let focusedWindow = copyAXElement(applicationElement, attribute: kAXFocusedWindowAttribute)
        let anyWindow = firstAXWindow(of: applicationElement)
        let window = focusedWindow ?? anyWindow

        if let window {
            if let closeButton = copyAXElement(window, attribute: kAXCloseButtonAttribute) {
                let result = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
                writeLog("AX close button result=\(result.rawValue) source=\(source)")
                if result == .success {
                    return true
                }
            } else {
                writeLog("AX close button missing source=\(source)")
            }
        } else {
            writeLog("AX window missing source=\(source)")
        }

        // WeChat sometimes uses custom window chrome. In that case,
        // send the app's standard Command-W shortcut as a fallback.
        let posted = sendCommandW()
        writeLog("Command-W fallback posted=\(posted) source=\(source)")
        return posted
    }

    private func firstAXWindow(of applicationElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &value
        )
        guard result == .success,
              let windows = value as? [AXUIElement],
              let firstWindow = windows.first else {
            writeLog("AX windows result=\(result.rawValue)")
            return nil
        }
        return firstWindow
    }

    private func copyAXElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            writeLog("AX attribute \(attribute) result=\(result.rawValue)")
            return nil
        }
        return (value as! AXUIElement)
    }

    private func sendCommandW() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 13, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 13, keyDown: false) else {
            writeLog("Unable to create Command-W event")
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        writeLog("Enabled changed to \(isEnabled)")
        refreshState()
    }

    @objc private func testCloseWeChat() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return
        }
        writeLog("Menu test requested")
        _ = closeWeChatWindow(source: "menu-test")
    }

    @objc private func requestRequiredPermission() {
        if !AXIsProcessTrusted() {
            requestAccessibilityPermission()
        } else if eventTap == nil {
            _ = CGRequestListenEventAccess()
            openInputMonitoringSettings()
        }
    }

    @objc private func requestAccessibilityPermission() {
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        openAccessibilitySettings()
    }

    @objc private func retryPermission() {
        removeKeyboardMonitors()
        refreshState()
        if !AXIsProcessTrusted() {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openDiagnosticLog() {
        if !FileManager.default.fileExists(atPath: logURL.path) {
            writeLog("Diagnostic log opened")
        }
        NSWorkspace.shared.open(logURL)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "EscClose"
        alert.informativeText = "微信在前台时按 Esc，关闭微信当前窗口，不退出微信。\n\n首次使用需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许本应用。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct EscCloseApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
