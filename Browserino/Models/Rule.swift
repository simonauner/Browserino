//
//  Rule.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import Foundation

struct Rule: Hashable, Codable {
    enum Kind: String, Codable, CaseIterable {
        case regex
        case pattern
    }

    /// The regex, or the pattern when `kind` is `.pattern`.
    var regex: String
    var app: URL
    var kind: Kind = .regex

    init(regex: String, app: URL, kind: Kind = .regex) {
        self.regex = regex
        self.app = app
        self.kind = kind
    }

    // Rules saved before `kind` existed are regexes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regex = try container.decode(String.self, forKey: .regex)
        app = try container.decode(URL.self, forKey: .app)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .regex
    }

    var compiledRegex: Regex<AnyRegexOutput>? {
        Rule.compile(regex, kind: kind)
    }

    static func compile(_ expression: String, kind: Kind) -> Regex<AnyRegexOutput>? {
        switch kind {
        case .regex:
            return try? Regex(expression).ignoresCase()
        case .pattern:
            return try? Regex(regex(fromPattern: expression)).ignoresCase()
        }
    }

    /// A pattern matches the whole URL, where `*` stands for any text.
    static func regex(fromPattern pattern: String) -> String {
        let parts = pattern
            .split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }

        return "^" + parts.joined(separator: ".*") + "$"
    }
}
