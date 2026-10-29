//
//  LotsenApplication.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 19.11.2024.
//

import AppKit

class LotsenApplication: NSApplication {
    override open func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                if event.modifierFlags.contains(.shift) {
                    if event.charactersIgnoringModifiers?.lowercased() == "z" {
                        if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return }
                        if let manager = (delegate as? AppDelegate)?.settingsUndoManager, manager.canRedo {
                            manager.redo()
                            return
                        }
                    }
                }
                guard let key = event.charactersIgnoringModifiers else {
                    return super.sendEvent(event)
                }
                switch key {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return }
                case "z":
                    if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return }
                    if let manager = (delegate as? AppDelegate)?.settingsUndoManager, manager.canUndo {
                        manager.undo()
                        return
                    }
                case "a":
                    if NSApp.sendAction(
                        #selector(NSStandardKeyBindingResponding.selectAll(_:)), to: nil, from: self
                    ) {
                        return
                    }
                case "w":
                    // There is no main menu to supply Close, so handle it here for
                    // windows that can be closed (the settings window, not the selector).
                    if let window = keyWindow, window.styleMask.contains(.closable) {
                        window.performClose(self)
                        return
                    }
                default:
                    break
                }
            }
        }
        super.sendEvent(event)
    }
}
