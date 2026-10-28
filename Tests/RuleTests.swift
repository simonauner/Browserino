import Foundation
import Testing

struct RuleTests {
    private let chrome = BrowserTarget(app: URL(fileURLWithPath: "/Applications/Google Chrome.app"), profile: "Profile 1")

    private func legacyRule() throws -> Rule {
        try JSONDecoder().decode(Rule.self, from: Data(#"{"regex":".*","app":"file:///Applications/Google Chrome.app","profileDirectory":"Profile 1"}"#.utf8))
    }

    @Test("legacy Chrome rule target retained")
    func legacyRuleTargetRetained() throws {
        #expect(try legacyRule().profile == "Profile 1")
    }

    @Test("picker rules from \"Always open links like this in…\"")
    func pickerRules() throws {
        let legacy = try legacyRule()
        let rules = Rule.addingPattern(" https://analytics.google.com/* ", target: chrome, to: [legacy])

        #expect(rules.count == 2 && rules[0] == legacy, "picker rule is appended after existing rules")
        #expect(rules[1].kind == .pattern && rules[1].regex == "https://analytics.google.com/*", "picker rule is a trimmed pattern")
        #expect(rules[1].target == chrome, "picker rule opens the chosen browser profile")
        #expect(rules[1].compiledRegex.map { "https://analytics.google.com/u/0/".firstMatch(of: $0) != nil } == true, "picker rule matches wildcard URLs")
        #expect(Rule.addingPattern("https://analytics.google.com/*", target: chrome, to: rules) == rules, "duplicate picker rule is not added")
        #expect(Rule.addingPattern("   ", target: chrome, to: [legacy]) == [legacy], "blank picker pattern adds no rule")
    }

    @Test("exact picker URL matches itself")
    func exactURLMatchesItself() {
        let rule = Rule.addingPattern("https://example.com/a?b=1", target: chrome, to: []).first
        #expect(rule?.compiledRegex.map { "https://example.com/a?b=1".firstMatch(of: $0) != nil } == true)
    }
}
