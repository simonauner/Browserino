//
//  AboutTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct AboutTab: View {
    private let repository = URL(string: "https://github.com/simonauner/Browserino")!
    private let browserino = URL(string: "https://github.com/AlexStrNik/Browserino")!
    private let license = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!

    var body: some View {
        VStack {
            Spacer()

            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 128, height: 128)

            Text(verbatim:
                "Lotsen v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
            )
            .font(.title)
            .frame(maxWidth: .infinity)

            Spacer()
                .frame(height: 16)

            Link(destination: repository) {
                Text(verbatim: repository.absoluteString)
            }

            Spacer()
                .frame(height: 24)

            // Lotsen began as a fork of Browserino; keep its author credited here.
            Text(verbatim: L10n.text("about.based_on"))

            Link(destination: browserino) {
                Text(verbatim: browserino.absoluteString)
            }

            Spacer()
                .frame(height: 16)

            Text(verbatim: L10n.text("about.contributors"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 16)

            Link(destination: license) {
                Text(verbatim: L10n.text("about.license"))
            }

            Spacer()
        }
    }
}

#Preview {
    AboutTab()
}
