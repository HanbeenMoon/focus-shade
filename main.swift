import AppKit

private let fillLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) - 1)

private struct WindowBehindShade {
    let number: Int
    let level: NSWindow.Level
    let frame: NSRect

    static func at(_ point: NSPoint, below shade: NSWindow) -> Self? {
        guard let primary = NSScreen.screens.first?.frame else { return nil }
        let location = CGPoint(x: point.x - primary.minX, y: primary.maxY - point.y)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let candidates = CGWindowListCopyWindowInfo([.optionOnScreenBelowWindow, .excludeDesktopElements],
                                                    CGWindowID(shade.windowNumber)) as? [[String: Any]] ?? []
        for candidate in candidates {
            guard let number = candidate[kCGWindowNumber as String] as? Int,
                  let pid = candidate[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let layer = candidate[kCGWindowLayer as String] as? Int,
                  layer >= NSWindow.Level.normal.rawValue, layer <= NSWindow.Level.modalPanel.rawValue,
                  (candidate[kCGWindowAlpha as String] as? Double ?? 0) > 0.01,
                  let rawBounds = candidate[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: rawBounds as CFDictionary),
                  bounds.contains(location),
                  let application = NSRunningApplication(processIdentifier: pid),
                  application.activationPolicy != .prohibited else { continue }
            let frame = NSRect(x: primary.minX + bounds.minX, y: primary.maxY - bounds.maxY,
                               width: bounds.width, height: bounds.height)
            return Self(number: number, level: NSWindow.Level(rawValue: layer), frame: frame)
        }
        return nil
    }
}

@discardableResult
private func trackMouse(_ down: NSEvent, update: (NSEvent) -> Void) -> NSEvent? {
    let drag: NSEvent.EventType = down.type == .rightMouseDown ? .rightMouseDragged : .leftMouseDragged
    let release: NSEvent.EventType = down.type == .rightMouseDown ? .rightMouseUp : .leftMouseUp
    let mask: NSEvent.EventTypeMask = down.type == .rightMouseDown
        ? [.rightMouseDragged, .rightMouseUp] : [.leftMouseDragged, .leftMouseUp]
    while let event = NSApp.nextEvent(matching: mask, until: .distantFuture, inMode: .eventTracking, dequeue: true) {
        if event.type == drag { update(event) }
        if event.type == release { return event }
    }
    return nil
}

private func windowPoint(for event: NSEvent, in window: NSWindow) -> NSPoint {
    if event.window === window { return event.locationInWindow }
    if let origin = event.window {
        return window.convertPoint(fromScreen: origin.convertPoint(toScreen: event.locationInWindow))
    }
    return window.mouseLocationOutsideOfEventStream
}

private class RightClickableButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func rightMouseDown(with event: NSEvent) {
        if let released = trackMouse(event, update: { _ in }), let window,
           bounds.contains(convert(windowPoint(for: released, in: window), from: nil)) {
            performClick(nil)
        }
    }
}

private final class SettingsActionButton: RightClickableButton {
    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 1), xRadius: 8, yRadius: 8)
        NSColor.labelColor.withAlphaComponent(cell?.isHighlighted == true ? 0.20 : 0.10).setFill()
        background.fill()

        let label = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ])
        let size = label.size()
        label.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
    }
}

private final class SettingsDot: RightClickableButton {
    var ink = NSColor.white { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        ink.withAlphaComponent(0.78).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 3, y: bounds.midY - 3, width: 6, height: 6)).fill()
    }
}

private final class TransparencyBar: NSSlider {
    var ink = NSColor.white { didSet { needsDisplay = true } }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSRect(x: 1, y: bounds.midY - 1.5, width: bounds.width - 2, height: 3)
        ink.withAlphaComponent(0.24).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()
        let fraction = TransparencyScale.position(for: doubleValue)
        let progress = NSRect(x: track.minX, y: track.minY, width: max(3, track.width * fraction), height: track.height)
        ink.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: progress, xRadius: 1.5, yRadius: 1.5).fill()
    }

    override func mouseDown(with event: NSEvent) { scrub(with: event) }
    override func rightMouseDown(with event: NSEvent) { scrub(with: event) }

    private func scrub(with event: NSEvent) {
        guard let window else { return }
        func update(_ event: NSEvent) {
            let point = convert(windowPoint(for: event, in: window), from: nil)
            doubleValue = TransparencyScale.percentage(at: (point.x - 1) / (bounds.width - 2))
            sendAction(action, to: target)
            needsDisplay = true
        }
        update(event)
        trackMouse(event, update: update)
    }
}

private final class ShadeColorWell: NSColorWell {
    var panelLevel = NSWindow.Level.floating
    var colorPanelIsVisible: Bool { NSColorPanel.sharedColorPanelExists && NSColorPanel.shared.isVisible }

    override func activate(_ exclusive: Bool) {
        NSColorPanel.shared.level = panelLevel
        super.activate(exclusive)
        NSColorPanel.shared.level = panelLevel
        NSColorPanel.shared.orderFrontRegardless()
    }

    override func deactivate() {
        super.deactivate()
        if colorPanelIsVisible { NSColorPanel.shared.orderOut(nil) }
    }

    override func performClick(_ sender: Any?) {
        if colorPanelIsVisible {
            deactivate()
        } else {
            activate(true)
        }
    }

    override func mouseDown(with event: NSEvent) { clickWell(with: event) }
    override func rightMouseDown(with event: NSEvent) { clickWell(with: event) }

    private func clickWell(with event: NSEvent) {
        if let released = trackMouse(event, update: { _ in }), let window,
           bounds.contains(convert(windowPoint(for: released, in: window), from: nil)) {
            performClick(nil)
        }
    }
}

private final class ShadePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

private final class ShadeSurface: NSView {
    let dot = SettingsDot(frame: .zero)
    let bar = TransparencyBar(frame: .zero)
    private(set) var fillColor = NSColor.clear
    private var outline = NSRect.zero
    private var bordered = false
    private lazy var barWidth = bar.widthAnchor.constraint(equalToConstant: 66)
    weak var owner: ShadeApp?

    init(owner: ShadeApp) {
        self.owner = owner
        super.init(frame: .zero)
        dot.title = ""
        dot.isBordered = false
        dot.toolTip = "가림막 설정"
        dot.setAccessibilityLabel("가림막 설정")
        dot.target = owner
        dot.action = #selector(ShadeApp.toggleSettings(_:))
        bar.minValue = 0
        bar.maxValue = TransparencyScale.maximum
        bar.toolTip = "가림막 투명도"
        bar.setAccessibilityLabel("가림막 투명도")
        bar.target = owner
        bar.action = #selector(ShadeApp.changeTransparency(_:))
        bar.isContinuous = true

        for control in [dot, bar] {
            control.translatesAutoresizingMaskIntoConstraints = false
            addSubview(control)
        }
        NSLayoutConstraint.activate([
            dot.trailingAnchor.constraint(equalTo: trailingAnchor),
            dot.topAnchor.constraint(equalTo: topAnchor),
            dot.widthAnchor.constraint(equalToConstant: 26),
            dot.heightAnchor.constraint(equalToConstant: 26),
            bar.trailingAnchor.constraint(equalTo: dot.leadingAnchor, constant: -2),
            bar.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            barWidth,
            bar.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { owner?.handleMouseDown(event) }
    override func rightMouseDown(with event: NSEvent) { owner?.handleMouseDown(event) }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        guard bordered else {
            bounds.fill()
            return
        }
        let shape = NSBezierPath(roundedRect: outline.insetBy(dx: 0.5, dy: 0.5), xRadius: 15, yRadius: 15)
        shape.fill()
        dot.ink.withAlphaComponent(0.18).setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
        super.updateTrackingAreas()
    }

    override func cursorUpdate(with event: NSEvent) { refreshCursor() }
    override func mouseMoved(with event: NSEvent) { refreshCursor() }

    private func refreshCursor() {
        if let window {
            let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if !dot.isHidden && (dot.frame.contains(localPoint) || bar.frame.contains(localPoint)) {
                NSCursor.pointingHand.set()
                return
            }
        }
        let edges = owner?.resizeEdges(at: NSEvent.mouseLocation) ?? []
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition? = switch edges {
            case .left: .left
            case .right: .right
            case .top: .top
            case .bottom: .bottom
            case [.top, .left]: .topLeft
            case [.top, .right]: .topRight
            case [.bottom, .left]: .bottomLeft
            case [.bottom, .right]: .bottomRight
            default: nil
            }
            if let position {
                NSCursor.frameResize(position: position, directions: .all).set()
                return
            }
        }
        if !edges.intersection([.left, .right]).isEmpty {
            NSCursor.resizeLeftRight.set()
        } else if !edges.intersection([.top, .bottom]).isEmpty {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    func setControlsVisible(_ visible: Bool, width: CGFloat) {
        dot.isHidden = !visible
        bar.isHidden = !visible
        barWidth.constant = max(4, min(66, width - 34))
    }

    func refreshAppearance(ink: NSColor, opacity: CGFloat, outline: NSRect, bordered: Bool, color: NSColor) {
        dot.ink = ink
        bar.ink = ink
        bar.doubleValue = (1 - opacity) * 100
        self.outline = outline
        self.bordered = bordered
        fillColor = color.withAlphaComponent(opacity)
        needsDisplay = true
    }
}

private final class ShadeApp: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private let popover = NSPopover()
    private let colorWell = ShadeColorWell(frame: .zero)
    private lazy var fillButton = SettingsActionButton(title: "현재 화면 채우기", target: self, action: #selector(toggleFill))
    private var panels: [CGDirectDisplayID: ShadePanel] = [:]
    private var geometry = ShadeGeometry(normalFrame: .zero, filledFrame: nil)
    private var filledDisplay: CGDirectDisplayID?
    private var controlDisplay: CGDirectDisplayID?
    private var revealedWindow: WindowBehindShade?
    private var concealed = false
    private weak var settingsAnchor: NSView?
    private var settingsMonitor: Any?

    private var color: NSColor {
        if let rgb = defaults.array(forKey: "color") as? [Double], rgb.count == 3 {
            return NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
        }
        return NSColor(srgbRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)
    }
    private var opacity: CGFloat { min(1, max(0.2, defaults.double(forKey: "opacity"))) }
    private var level: NSWindow.Level {
        if filledDisplay != nil { return fillLevel }
        return defaults.bool(forKey: "floating") ? .floating : .normal
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["opacity": 1.0, "floating": true])
        configureMenu()
        configureSettings()
        geometry.normalFrame = NSRectFromString(defaults.string(forKey: "frame") ?? "")
        filledDisplay = (defaults.object(forKey: "filledDisplay") as? NSNumber)?.uint32Value
        screenLayoutChanged()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        closeSettings()
        revealedWindow = nil
        screenLayoutChanged()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let settingsMonitor { NSEvent.removeMonitor(settingsMonitor) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringShadeForward()
        return true
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "가림막 다시 앞으로", action: #selector(bringShadeForward), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "설정", action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "화면 채우기 또는 복원", action: #selector(toggleFill), keyEquivalent: "f").target = self
        appMenu.addItem(withTitle: "가림막 숨기기", action: #selector(hideShade), keyEquivalent: "m").target = self
        appMenu.addItem(withTitle: "가림막 닫기", action: #selector(hideShade), keyEquivalent: "w").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "가림막 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
    }

    private func configureSettings() {
        let width: CGFloat = 264
        let inset: CGFloat = 18
        let verticalInset: CGFloat = 16

        colorWell.color = color
        colorWell.target = self
        colorWell.action = #selector(changeColor(_:))
        colorWell.setAccessibilityLabel("가림막 색상")
        let colorLabel = NSTextField(labelWithString: "색상")
        colorLabel.setContentHuggingPriority(.required, for: .horizontal)
        let colorRow = NSStackView(views: [colorLabel, NSView(), colorWell])
        colorRow.alignment = .centerY
        colorRow.spacing = 8

        let floating = RightClickableButton(checkboxWithTitle: "항상 위에 표시", target: self,
                                             action: #selector(changeFloating(_:)))
        floating.state = defaults.bool(forKey: "floating") ? .on : .off
        let hide = SettingsActionButton(title: "가림막 숨기기", target: self, action: #selector(hideShade))
        let quit = SettingsActionButton(title: "가림막 종료", target: self, action: #selector(quitShade))
        for button in [fillButton, hide, quit] { button.isBordered = false }
        let bottomActions = NSStackView(views: [hide, quit])
        bottomActions.alignment = .centerY
        bottomActions.distribution = .fillEqually
        bottomActions.spacing = 8

        let divider = NSBox()
        divider.boxType = .separator
        let rows: [(NSView, CGFloat)] = [(colorRow, 32), (floating, 26), (divider, 5),
                                          (fillButton, 34), (bottomActions, 32)]
        let stack = NSStackView(views: rows.map(\.0))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        for (row, height) in rows {
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: stack.widthAnchor),
                row.heightAnchor.constraint(equalToConstant: height)
            ])
        }
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: width),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -inset),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: verticalInset),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -verticalInset),
            colorWell.widthAnchor.constraint(equalToConstant: 64),
            colorWell.heightAnchor.constraint(equalToConstant: 26),
            hide.heightAnchor.constraint(equalToConstant: 32),
            quit.heightAnchor.constraint(equalToConstant: 32)
        ])
        let controller = NSViewController()
        controller.view = content
        popover.contentViewController = controller
        popover.contentSize = content.fittingSize
        popover.behavior = .applicationDefined
        popover.animates = false
        settingsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if event.type == .keyDown {
                if event.keyCode != 53 { return event }
                self.closeSettings()
                return nil
            }
            if event.window === self.popover.contentViewController?.view.window { return event }
            if self.colorWell.colorPanelIsVisible && event.window === NSColorPanel.shared { return event }
            if let anchor = self.settingsAnchor, event.window === anchor.window,
               anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil)) { return event }
            self.closeSettings()
            return event
        }
    }

    private func makePanel(for screen: NSScreen) -> ShadePanel {
        let panel = ShadePanel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                               defer: false, screen: screen)
        panel.title = "가림막"
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = ShadeSurface(owner: self)
        return panel
    }

    private func screenLayoutChanged() {
        let screens = NSScreen.screens
        guard let defaultScreen = screens.dropFirst().first ?? screens.first else { return }
        let ids = Set(screens.map(\.shadeID))
        for id in panels.keys.filter({ !ids.contains($0) }) {
            panels.removeValue(forKey: id)?.close()
        }
        if let filledDisplay, let screen = screens.first(where: { $0.shadeID == filledDisplay }) {
            geometry.filledFrame = screen.frame
        } else {
            filledDisplay = nil
            geometry.filledFrame = nil
        }
        let stored = geometry.normalFrame
        let isReachable = screens.contains { screen in
            let visible = screen.frame.intersection(stored)
            return visible.width >= 86 && visible.height >= 32
        }
        if !isReachable || stored.width < ShadeGeometry.minimum.width || stored.height < ShadeGeometry.minimum.height {
            let visible = defaultScreen.visibleFrame
            let width = min(720, visible.width * 0.7)
            let height = min(480, visible.height * 0.67)
            geometry.normalFrame = NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2,
                                          width: width, height: height)
        }
        saveGeometry()
        refreshPanels()
    }

    private func refreshPanels() {
        if concealed {
            for panel in panels.values { panel.orderOut(nil) }
            return
        }

        let pieces = NSScreen.screens.compactMap { screen in
            geometry.clipped(to: screen.frame).map { (screen: screen, frame: $0) }
        }
        let controls = pieces.filter { $0.frame.width >= 98 && $0.frame.height >= 28 }
        controlDisplay = (controls.isEmpty ? pieces : controls).max {
            if $0.frame.maxX != $1.frame.maxX { return $0.frame.maxX < $1.frame.maxX }
            return $0.frame.maxY < $1.frame.maxY
        }?.screen.shadeID
        let liveIDs = Set(pieces.map { $0.screen.shadeID })
        for (id, panel) in panels where !liveIDs.contains(id) { panel.orderOut(nil) }

        let rgb = color
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        let ink: NSColor = luminance > 0.53 ? .black : .white
        let overlayLevel = level
        let logicalFrame = geometry.frame
        let bordered = filledDisplay == nil
        for (screen, frame) in pieces {
            let id = screen.shadeID
            let panel = panels[id] ?? makePanel(for: screen)
            panels[id] = panel
            let surface = panel.contentView as! ShadeSurface
            surface.setControlsVisible(id == controlDisplay, width: frame.width)
            let outline = logicalFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
            surface.refreshAppearance(ink: ink, opacity: opacity, outline: outline, bordered: bordered, color: rgb)
            let revealed = revealedWindow.flatMap { $0.frame.intersects(frame) ? $0 : nil }
            panel.level = revealed?.level ?? overlayLevel
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            if let revealed {
                panel.order(.below, relativeTo: revealed.number)
            } else if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
        if NSColorPanel.sharedColorPanelExists {
            NSColorPanel.shared.level = NSWindow.Level(rawValue: max(NSWindow.Level.floating.rawValue, overlayLevel.rawValue + 1))
        }
    }

    private func saveGeometry() {
        defaults.set(NSStringFromRect(geometry.normalFrame), forKey: "frame")
        if let filledDisplay {
            defaults.set(NSNumber(value: filledDisplay), forKey: "filledDisplay")
        } else {
            defaults.removeObject(forKey: "filledDisplay")
        }
    }

    func resizeEdges(at point: NSPoint) -> ResizeEdges {
        let edges = ResizeEdges.hit(at: point, in: geometry.frame)
        // In fill mode the whole surface is a move handle that restores the previous size.
        return filledDisplay == nil ? edges : []
    }

    func handleMouseDown(_ event: NSEvent) {
        guard let panel = event.window else { return }
        let point = panel.convertPoint(toScreen: event.locationInWindow)
        if event.clickCount == 2 {
            if geometry.isInTopBorder(point) {
                toggleFillOnDisplay(panel.screen?.shadeID ?? controlDisplay)
                return
            }
            guard let underneath = WindowBehindShade.at(point, below: panel) else { return }
            closeSettings()
            revealedWindow = underneath
            refreshPanels()
            return
        }
        if revealedWindow != nil { bringShadeForward() }
        drag(with: event, from: point)
    }

    private func drag(with event: NSEvent, from start: NSPoint) {
        let gesture = geometry
        let edges = resizeEdges(at: start)
        var changed = false
        trackMouse(event) { _ in
            let point = NSEvent.mouseLocation
            if !changed {
                guard hypot(point.x - start.x, point.y - start.y) >= 3 else { return }
                closeSettings()
                changed = true
                filledDisplay = nil
                if edges.isEmpty { NSCursor.closedHand.set() }
            }
            geometry = gesture.dragged(from: start, to: point, edges: edges)
            refreshPanels()
        }
        if changed { saveGeometry() }
    }

    @objc func toggleSettings(_ sender: NSView) {
        if popover.isShown {
            closeSettings()
            return
        }
        fillButton.title = filledDisplay == nil ? "현재 화면 채우기" : "원래 크기로 복원"
        colorWell.panelLevel = NSWindow.Level(rawValue: max(NSWindow.Level.floating.rawValue, level.rawValue + 1))
        settingsAnchor = sender
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        if let popoverWindow = popover.contentViewController?.view.window, popoverWindow.level.rawValue <= level.rawValue {
            popoverWindow.level = NSWindow.Level(rawValue: level.rawValue + 1)
        }
    }

    @objc private func openSettingsFromMenu() {
        if concealed { _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false) }
        guard let controlDisplay, let surface = panels[controlDisplay]?.contentView as? ShadeSurface else { return }
        toggleSettings(surface.dot)
    }

    private func closeSettings() {
        if colorWell.isActive || colorWell.colorPanelIsVisible { colorWell.deactivate() }
        popover.performClose(nil)
    }

    @objc private func bringShadeForward() {
        revealedWindow = nil
        concealed = false
        refreshPanels()
        for panel in panels.values where panel.isVisible { panel.orderFrontRegardless() }
    }

    @objc func changeTransparency(_ sender: NSSlider) {
        defaults.set(1 - sender.doubleValue / 100, forKey: "opacity")
        refreshPanels()
    }

    @objc private func changeColor(_ sender: NSColorWell) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        defaults.set([rgb.redComponent, rgb.greenComponent, rgb.blueComponent], forKey: "color")
        refreshPanels()
    }

    @objc private func changeFloating(_ sender: NSButton) {
        defaults.set(sender.state == .on, forKey: "floating")
        bringShadeForward()
    }

    @objc private func toggleFill() {
        toggleFillOnDisplay(controlDisplay)
    }

    private func toggleFillOnDisplay(_ display: CGDirectDisplayID?) {
        revealedWindow = nil
        if filledDisplay != nil {
            filledDisplay = nil
            geometry.filledFrame = nil
        } else {
            guard let display,
                  let screen = NSScreen.screens.first(where: { $0.shadeID == display }) else { return }
            filledDisplay = display
            geometry.filledFrame = screen.frame
        }
        concealed = false
        closeSettings()
        saveGeometry()
        refreshPanels()
    }

    @objc private func hideShade() {
        closeSettings()
        revealedWindow = nil
        concealed = true
        refreshPanels()
        NSApp.hide(nil)
    }

    @objc private func quitShade() {
        NSApp.terminate(nil)
    }
}

private extension NSScreen {
    var shadeID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
    }
}

let app = NSApplication.shared
private let delegate = ShadeApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
