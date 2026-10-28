//
//  AboutTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct AboutTab: View {
    private let repository = URL(string: "https://github.com/simonauner/lotsen")!
    private let browserino = URL(string: "https://github.com/AlexStrNik/Browserino")!
    private let license = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!

    var body: some View {
        VStack {
            Spacer()

            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 128, height: 128)

            Text(verbatim:
                "Lotsen v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)"
            )
            .font(.title)
            .frame(maxWidth: .infinity)

            Spacer()
                .frame(height: 16)

            Button(action: {
                NSWorkspace.shared.open(repository)
            }) {
                Text(verbatim: repository.absoluteString)
            }
            .buttonStyle(.link)

            Spacer()
                .frame(height: 24)

            // Lotsen began as a fork of Browserino; keep its author credited here.
            Text(verbatim: L10n.text("about.based_on"))

            Button(action: {
                NSWorkspace.shared.open(browserino)
            }) {
                Text(verbatim: browserino.absoluteString)
            }
            .buttonStyle(.link)

            Spacer()
                .frame(height: 16)

            Text(verbatim: L10n.text("about.contributors"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 16)

            Button(action: {
                NSWorkspace.shared.open(license)
            }) {
                Text(verbatim: L10n.text("about.license"))
            }
            .buttonStyle(.link)

            Spacer()
        }
    }
}

#Preview {
    AboutTab()
}
