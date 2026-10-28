//
//  BrowserTargetIcon.swift
//  Browserino
//

import SwiftUI

/// The browser's icon, badged with the profile picture when there is one, so that
/// several profiles of the same browser stay distinguishable at a glance.
struct BrowserTargetIcon: View {
    let icon: NSImage
    let avatar: NSImage?
    var badgeSize: CGFloat = 14

    init(target: BrowserTarget, badgeSize: CGFloat = 14) {
        self.icon = target.icon
        self.avatar = target.avatarImage
        self.badgeSize = badgeSize
    }

    init(_ presentation: BrowserTargetPresentation, badgeSize: CGFloat = 14) {
        self.icon = presentation.icon
        self.avatar = presentation.avatar
        self.badgeSize = badgeSize
    }

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .overlay(alignment: .bottomTrailing) {
                if let avatar {
                    Image(nsImage: avatar)
                        .resizable()
                        .clipShape(.circle)
                        .frame(width: badgeSize, height: badgeSize)
                        .overlay {
                            Circle().strokeBorder(.background, lineWidth: 1.5)
                        }
                        .offset(x: badgeSize / 4, y: badgeSize / 4)
                }
            }
    }
}
