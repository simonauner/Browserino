import Foundation
import Testing

/// Links arrive from other apps, so only web pages and local documents may reach
/// a rule or a browser.
struct IncomingURLTests {
    private func wrapped(_ value: String) -> URL {
        var components = URLComponents(string: "browserino://open")!
        components.queryItems = [URLQueryItem(name: "url", value: Data(value.utf8).base64EncodedString())]
        return components.url!
    }

    private let web = URL(string: "https://example.com/path?q=1")!

    @Test("preserves HTTPS")
    func preservesHTTPS() {
        #expect(web.browserinoIncomingURL == web)
    }

    @Test("decodes wrapper")
    func decodesWrapper() {
        #expect(wrapped(web.absoluteString).browserinoIncomingURL == web)
    }

    @Test("rejects wrapped non-web URLs", arguments: [
        "javascript:alert(1)", "file:///etc/passwd", "data:text/html,test", "browserino://open", "https:", "https:///path",
    ])
    func rejectsWrapped(_ value: String) {
        #expect(wrapped(value).browserinoIncomingURL == nil)
    }

    @Test("preserves local HTML documents")
    func preservesLocalDocuments() {
        #expect(URL(string: "file:///tmp/page.html")!.browserinoIncomingURL != nil)
    }

    @Test("rejects unknown command")
    func rejectsUnknownCommand() {
        #expect(URL(string: "browserino://other")!.browserinoIncomingURL == nil)
    }

    @Test("rejects malformed base64")
    func rejectsMalformedBase64() {
        #expect(URL(string: "browserino://open?url=invalid")!.browserinoIncomingURL == nil)
    }

    @Test("matches domain")
    func matchesDomain() {
        #expect(URL(string: "https://example.com")!.matchesHost("example.com"))
    }

    @Test("rejects suffix spoof")
    func rejectsSuffixSpoof() {
        #expect(!URL(string: "https://evil-example.com")!.matchesHost("example.com"))
    }
}
