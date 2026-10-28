import Foundation
import Testing

/// Hiding has to survive a browser switching between one row and a row per profile.
struct TargetPolicyTests {
    private let base = BrowserTarget(app: URL(string: "file:///Applications/A.app/")!)
    private var p1: BrowserTarget { BrowserTarget(app: base.app, profile: "Profile 1") }
    private var p2: BrowserTarget { BrowserTarget(app: base.app, profile: "Profile 2") }

    @Test("legacy hidden browser stays hidden after expansion")
    func hiddenAfterExpansion() {
        #expect(TargetPolicy.visible([p1, p2], hidden: [base], profilesEnabled: true).isEmpty)
    }

    @Test("disabled profiles honor app-level hide")
    func disabledProfilesHonorHide() {
        #expect(TargetPolicy.visible([p1, p2], hidden: [base], profilesEnabled: false).isEmpty)
    }

    @Test("app-level unhide restores collapsed row")
    func unhideRestoresCollapsedRow() {
        let unhidden = TargetPolicy.toggle(base, targets: [p1, p2], hidden: [p1, p2])
        #expect(TargetPolicy.visible([p1, p2], hidden: unhidden, profilesEnabled: false).count == 1)
    }

    @Test("unhide one profile preserves other hidden profile")
    func unhideOneProfile() {
        #expect(TargetPolicy.toggle(p1, targets: [p1, p2], hidden: [base]) == [p2])
    }

    @Test("all-hidden profiles stay hidden after collapse")
    func allHiddenStayHidden() {
        #expect(TargetPolicy.isHidden(base, hidden: TargetPolicy.preserveHidden(oldTargets: [p1, p2], newTargets: [base], hidden: [p1, p2])))
    }

    @Test("partially visible browser stays visible after collapse")
    func partiallyVisibleStaysVisible() {
        #expect(!TargetPolicy.isHidden(base, hidden: TargetPolicy.preserveHidden(oldTargets: [p1, p2], newTargets: [base], hidden: [p1])))
    }
}
