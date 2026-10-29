//
//  LotsenWindow.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import Foundation
import AppKit

class LotsenWindow: NSPanel {
    var presentingAlert = false
    /// Wide enough for "Always open … in …" and its Edit Rule button on one line.
    static let selectorWidth: CGFloat = 360
    /// A starting height only: the picker's content sets the real one.
    static let selectorHeight: CGFloat = 200

    /// .nonactivatingPanel would otherwise refuse key status, which the
    /// keyboard-driven picker depends on.
    override var canBecomeKey: Bool { true }

    public convenience init() {
        self.init(
            contentRect: .init(x: 0, y: 0, width: Self.selectorWidth, height: Self.selectorHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.minSize = NSSize(width: Self.selectorWidth, height: 0)
        
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.setFrameAutosaveName("prompt_Size")
        
        self.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.isMovable = false
    }
    
    /// Fits the window to the picker's height, keeping its top edge in place
    /// and the whole window on screen.
    func fitContentHeight(_ height: CGFloat) {
        // The content runs under the hidden title bar, so it fills the whole frame.
        guard abs(height - self.frame.height) >= 1 else { return }
        var frame = self.frame
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        if let visible = screen?.visibleFrame, frame.minY < visible.minY + 20 {
            frame.origin.y = visible.minY + 20
        }
        setFrame(frame, display: true)
    }

    func deactivateDelay() {
        self.hidesOnDeactivate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            NSApplication.shared.activate()
            self.makeKeyAndOrderFront(nil)
            self.hidesOnDeactivate = true
        }
    }
}
