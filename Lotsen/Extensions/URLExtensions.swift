//
//  URLExtensions.swift
//  Lotsen
//
//  Created by Claude Code on 05.01.2026.
//

import Foundation

nonisolated extension URL {
    func matchesHost(_ configuredHost: String) -> Bool {
        if configuredHost.isEmpty {
            return true
        }

        guard let urlHost = self.host()?.lowercased() else { return false }
        let appHost = configuredHost.lowercased()
        return urlHost == appHost || urlHost.hasSuffix("." + appHost)
    }
}

// Validate external input before routing rules or application scheme overrides.
nonisolated extension URL {
    /// `browserino` is the scheme Lotsen had before the rename, kept so existing
    /// integrations still work.
    static let lotsenSchemes: Set<String> = ["lotsen", "browserino"]

    var lotsenIncomingURL: URL? {
        if let scheme = scheme?.lowercased(), Self.lotsenSchemes.contains(scheme) {
            guard host?.lowercased() == "open",
                  let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
                  let items = components.queryItems,
                  items.filter({ $0.name == "url" }).count == 1,
                  let encoded = items.first(where: { $0.name == "url" })?.value,
                  let data = Data(base64Encoded: encoded),
                  let string = String(data: data, encoding: .utf8),
                  let target = URL(string: string), target.isWebURL else { return nil }
            return target
        }
        // Local documents are supported through Finder, never through the web wrapper.
        if isFileURL { return self }
        return isWebURL ? self : nil
    }

    private var isWebURL: Bool {
        guard let scheme = scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = host, !host.isEmpty else { return false }
        return true
    }
}
