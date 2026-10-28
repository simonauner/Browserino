//
//  Rule.swift
//  Lotsen
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
    var profile: String?
    var kind: Kind = .regex

    init(regex: String, app: URL, profile: String? = nil, kind: Kind = .regex) {
        self.regex = regex; self.app = app; self.profile = profile; self.kind = kind
    }
    private enum CodingKeys: String, CodingKey { case regex, app, profile, profileDirectory, kind }
    // Rules saved before `kind` existed are regexes.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        regex = try values.decode(String.self, forKey: .regex)
        app = try values.decode(URL.self, forKey: .app)
        profile = try values.decodeIfPresent(String.self, forKey: .profile)
            ?? values.decodeIfPresent(String.self, forKey: .profileDirectory)
        kind = try values.decodeIfPresent(Kind.self, forKey: .kind) ?? .regex
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(regex, forKey: .regex)
        try values.encode(app, forKey: .app)
        try values.encodeIfPresent(profile, forKey: .profile)
        try values.encode(kind, forKey: .kind)
    }

    var target: BrowserTarget {
        BrowserTarget(app: app, profile: profile)
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

    /// Appends the pattern rule the picker saves for "Always open links like this in…".
    /// A blank pattern, or a rule that already exists, leaves `rules` as it was.
    static func addingPattern(_ pattern: String, target: BrowserTarget, to rules: [Rule]) -> [Rule] {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = Rule(regex: pattern, app: target.app, profile: target.profile, kind: .pattern)
        guard !pattern.isEmpty, !rules.contains(rule) else { return rules }

        return rules + [rule]
    }
}
