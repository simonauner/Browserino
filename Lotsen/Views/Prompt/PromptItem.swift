//
//  PromptItem.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct PromptItem: View {
    var presentation: BrowserTargetPresentation
    var shortcut: String?
    var supportsPrivate: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(presentation.displayName)
                    .font(
                        .system(size: 12, weight: .bold)
                    )
                
                Spacer()

                Image(systemName: supportsPrivate ? "lock" : "lock.slash")
                    .foregroundStyle(.secondary)
                    .help(L10n.text(supportsPrivate ? "picker.private.available" : "picker.private.unavailable"))
                    .accessibilityLabel(L10n.text(supportsPrivate ? "picker.private.available" : "picker.private.unavailable"))
                
                if let shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .frame(minWidth: 4)
                        .opacity(0.5)
                        .padding(5)
                        .background(
                            Color.secondary.opacity(0.2)
                        )
                        .clipShape(.rect(cornerRadius: 4))
                }
                
                Spacer()
                    .frame(width: 8)
                
                BrowserTargetIcon(presentation, badgeSize: 11)
                    .frame(width: 24, height: 24)
            }
            .padding(8)
        }
    }
}
