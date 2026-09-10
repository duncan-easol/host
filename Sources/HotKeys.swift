import Cocoa
import Carbon.HIToolbox

enum CommandTabOverride {
    private static let key = "ReplaceCommandTab"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Filters Command-Tab before Dock opens the system app switcher.
///
/// This requires Accessibility permission. Failure leaves the normal macOS
/// switcher untouched and Host's Option-Shift shortcuts remain available.
private final class CommandTabInterceptor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gesture = CommandTabGesture()
    private var previous: (() -> Void)?
    private var next: (() -> Void)?
    private var commit: (() -> Void)?

    func start(previous: @escaping () -> Void,
               next: @escaping () -> Void,
               commit: @escaping () -> Void) -> Bool {
        stop()
        self.previous = previous
        self.next = next
        self.commit = commit

        let events = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: events,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<CommandTabInterceptor>
                    .fromOpaque(context).takeUnretainedValue()
                return interceptor.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            self.previous = nil
            self.next = nil
            self.commit = nil
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        previous = nil
        next = nil
        commit = nil
        gesture.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            gesture.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Log.line("command-tab event tap was disabled; re-enabled it")
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let commandDown = flags.contains(.maskCommand)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let tabKeyCode: Int64 = 48

        if type == .keyDown, commandDown, keyCode == tabKeyCode {
            let offset = gesture.tabPressed(reverse: flags.contains(.maskShift))
            DispatchQueue.main.async { [weak self] in
                (offset < 0 ? self?.previous : self?.next)?()
            }
            return nil
        }

        if type == .keyUp, keyCode == tabKeyCode, gesture.isActive {
            return nil
        }

        if type == .flagsChanged, gesture.commandChanged(isDown: commandDown) {
            DispatchQueue.main.async { [weak self] in self?.commit?() }
        }
        return Unmanaged.passUnretained(event)
    }
}

/// Global hotkeys via Carbon's RegisterEventHotKey.
///
/// This is deliberately not NSEvent.addGlobalMonitorForEvents: a global monitor
/// can observe a key press but cannot consume it, so the frontmost app would
/// also receive the keystroke. RegisterEventHotKey swallows the event, and it
/// works from an accessory app that never becomes active.
///
/// Host only claims Option-Shift-[ and Option-Shift-]. Option-digit combinations
/// remain available for text input, including Option-3 for `#`.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var handlerInstalled = false
    private var globalModifierMonitor: Any?
    private var localModifierMonitor: Any?
    private let commandTabInterceptor = CommandTabInterceptor()
    private var bracketGestureActive = false

    private init() {}

    func registerOptionShiftBrackets(previous: @escaping () -> Void,
                                     next: @escaping () -> Void,
                                     commit: @escaping () -> Void) {
        let modifiers = UInt32(optionKey | shiftKey)
        register(keyCode: UInt32(kVK_ANSI_LeftBracket), modifiers: modifiers,
                 id: 100, handler: { [weak self] in
                    self?.bracketGestureActive = true
                    previous()
                 })
        register(keyCode: UInt32(kVK_ANSI_RightBracket), modifiers: modifiers,
                 id: 101, handler: { [weak self] in
                    self?.bracketGestureActive = true
                    next()
                 })

        let modifierChanged: (NSEvent) -> Void = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard self?.bracketGestureActive == true,
                  !flags.contains([.option, .shift]) else { return }
            self?.bracketGestureActive = false
            DispatchQueue.main.async(execute: commit)
        }
        globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged,
            handler: modifierChanged
        )
        localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            modifierChanged(event)
            return event
        }
    }

    func registerControlP(handler: @escaping () -> Void) {
        register(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey), id: 102, handler: handler)
    }

    func replaceCommandTab(previous: @escaping () -> Void,
                           next: @escaping () -> Void,
                           commit: @escaping () -> Void) -> Bool {
        commandTabInterceptor.start(previous: previous, next: next, commit: commit)
    }

    func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, handler: @escaping () -> Void) {
        installHandlerIfNeeded()
        handlers[id] = handler

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x54424853) /* 'TBHS' */, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            refs.append(ref)
        } else {
            Log.line("hotkey \(id) failed to register (status \(status)) -- probably taken by another app")
        }
    }

    func unregisterAll() {
        bracketGestureActive = false
        for ref in refs where ref != nil { UnregisterEventHotKey(ref!) }
        refs.removeAll()
        handlers.removeAll()
        if let monitor = globalModifierMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localModifierMonitor { NSEvent.removeMonitor(monitor) }
        globalModifierMonitor = nil
        localModifierMonitor = nil
        commandTabInterceptor.stop()
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID), nil,
                                        MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard err == noErr else { return err }
            DispatchQueue.main.async { HotKeyCenter.shared.fire(hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
