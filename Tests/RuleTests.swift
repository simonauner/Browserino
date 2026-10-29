import Foundation
import Testing

struct RuleTests {
    @Test("routing follows priority and skips invalid rules")
    func priority() {
        let broad = Rule(regex: "https://example.com/*", app: URL(fileURLWithPath: "/Applications/A.app"), kind: .pattern)
        let specific = Rule(regex: "https://example.com/work/*", app: URL(fileURLWithPath: "/Applications/B.app"), kind: .pattern)
        let invalid = Rule(regex: "[", app: broad.app)
        let url = "https://example.com/work/task"
        #expect(Rule.firstMatch(in: [invalid, broad, specific], for: url) == broad)
        #expect(Rule.firstMatch(in: [specific, broad], for: url) == specific)
        #expect(Rule.firstMatch(in: [specific], for: "https://other.com/") == nil)
    }
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

    @Test("picker suggests a pattern for the link's whole host")
    func hostPattern() throws {
        let pattern = Rule.hostPattern(for: try #require(URL(string: "https://user@github.com/AlexStrNik/Browserino/pull/1?tab=files#diff")))
        let rule = try #require(Rule.addingPattern(pattern, target: chrome, to: []).first)
        let matches = { (url: String) in rule.compiledRegex.map { url.firstMatch(of: $0) != nil } == true }

        #expect(pattern == "https://github.com/*")
        #expect(matches("https://github.com/simonauner/Lotsen/issues"), "other pages on the host match")
        #expect(matches("https://github.com"), "the bare host the pattern was made from matches")
        #expect(!matches("https://github.community"), "a longer host does not match")
        #expect(!matches("https://github.com.example.com/"), "a host that only starts with it does not match")
        #expect(!matches("http://github.com/"), "another scheme does not match")
        #expect(Rule.hostPattern(for: try #require(URL(string: "http://localhost:8080/a"))) == "http://localhost:8080/*", "the port is kept")
        #expect(Rule.hostPattern(for: try #require(URL(string: "mailto:someone@example.com"))) == "mailto:someone@example.com", "a link without a host is matched exactly")
    }

    @Test("exact picker URL matches itself")
    func exactURLMatchesItself() {
        let rule = Rule.addingPattern("https://example.com/a?b=1", target: chrome, to: []).first
        #expect(rule?.compiledRegex.map { "https://example.com/a?b=1".firstMatch(of: $0) != nil } == true)
    }
}
