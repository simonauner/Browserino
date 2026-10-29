//
//  ShortcutButton.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct ShortcutButton: View {
    let shortcutKey: String
    
    @Setting(\.shortcuts) private var shortcuts
    
    @State private var isRecording: Bool = false
    @FocusState private var focus: Bool
    
    var body: some View {
        if isRecording {
            Text(verbatim: L10n.text("shortcuts.recorder.press_key"))
                .padding(5)
                .contentShape(.rect)
                .focusable()
                .focused($focus)
                .onChange(of: focus) { _, newFocus in
                    isRecording = newFocus
                }
                .onKeyPress { press in
                    let character = press.key.character
                    isRecording = false
                    // Esc, Return and the like cancel: the picker uses them itself.
                    guard character.isLetter || character.isNumber else { return .handled }
                    let key = character.uppercased()

                    if let shortcut = shortcuts.first(where: { $0.value == key }) {
                        shortcuts[shortcut.key] = nil
                    }
                    shortcuts[shortcutKey] = key

                    return .handled
                }
        } else if let recordedKey = shortcuts[shortcutKey] {
            // Key and clear button joined as one control, like the system's own
            // shortcut fields.
            ControlGroup {
                Button(recordedKey, action: startRecording)

                Button(action: { shortcuts[shortcutKey] = nil }) {
                    Image(systemName: "xmark")
                }
                .help(L10n.text("shortcuts.recorder.clear"))
                .accessibilityLabel(L10n.text("shortcuts.recorder.clear"))
            }
            .fixedSize()
        } else {
            Button(L10n.text("shortcuts.recorder.assign"), action: startRecording)
        }
    }

    private func startRecording() {
        isRecording = true
        focus = true
    }
}
