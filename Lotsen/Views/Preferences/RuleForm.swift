//
//  RuleForm.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

/// A new rule the picker hands to Settings, filled in from the link it was opening.
struct RuleDraft: Identifiable {
    let id = UUID()
    /// The suggested rule, for the browser highlighted in the picker.
    var rule: Rule
    var link: URL

    /// Opens the link the picker was showing, in `rule`'s browser.
    func open(with rule: Rule) {
        BrowserUtil.openURL([link], target: rule.target, isIncognito: false) { _, error in
            if let error { BrowserSwitchService.shared.presentOpenFailedAlert(error) }
        }
    }
}

struct RuleForm: View {
    var isNew: Bool
    var onSave: (Rule) -> Void
    /// Nil for a rule that isn't saved yet, which has nothing to delete.
    var onDelete: (() -> Void)?
    var onCancel: (() -> Void)?
    var precedingRules: [Rule]

    @Environment(\.dismiss) private var dismiss

    @State private var regex: String
    @State private var kind: Rule.Kind
    @State private var testUrls: String = ""
    @State private var url: URL?
    @State private var profile: String?

    init(rule: Rule?, precedingRules: [Rule] = [], onSave: @escaping (Rule) -> Void, onDelete: (() -> Void)? = nil) {
        self.precedingRules = precedingRules
        isNew = rule == nil
        self.onSave = onSave
        self.onDelete = onDelete
        _regex = State(initialValue: rule?.regex ?? "")
        _kind = State(initialValue: rule?.kind ?? .pattern)
        _url = State(initialValue: rule?.app)
        _profile = State(initialValue: rule?.profile)
    }

    init(draft: RuleDraft, precedingRules: [Rule] = [], onSave: @escaping (Rule) -> Void, onCancel: @escaping () -> Void) {
        self.init(rule: draft.rule, precedingRules: precedingRules, onSave: onSave)
        self.onCancel = onCancel
        isNew = true
        _testUrls = State(initialValue: draft.link.absoluteString)
    }

    /// A link never contains spaces, so a pasted one at either end would only
    /// make the rule match nothing.
    private var expression: String {
        regex.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compiledRegex: Regex<AnyRegexOutput>? {
        expression.isEmpty ? nil : Rule.compile(expression, kind: kind)
    }

    private var testLines: [String] {
        testUrls
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var testResults: [(line: String, matches: Bool)] {
        testLines.map { line in
            (line, compiledRegex.map { line.firstMatch(of: $0) != nil } ?? false)
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.text("rules.editor.type"), selection: $kind) {
                    Text(verbatim: L10n.text("rules.kind.pattern")).tag(Rule.Kind.pattern)
                    Text(verbatim: L10n.text("rules.kind.regex_advanced")).tag(Rule.Kind.regex)
                }
                .pickerStyle(.segmented)

                LabeledContent(L10n.text(kind == .regex ? "rules.editor.regex" : "rules.editor.pattern")) {
                    TextField(
                        L10n.text(kind == .regex ? "rules.editor.regex" : "rules.editor.pattern"),
                        text: $regex,
                        prompt: Text(verbatim: kind == .regex ? #"https?://(www\.)?example\.com/.*"# : "https://example.com/*")
                    )
                        .labelsHidden()
                        .monospaced()
                        .autocorrectionDisabled()
                }
            } header: {
                Text(verbatim: L10n.text(isNew ? "rules.editor.new_title" : "rules.editor.edit_title"))
            } footer: {
                expressionFooter
            }

            Section {
                TextEditor(text: $testUrls)
                    .monospaced()
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .overlay(alignment: .topLeading) {
                        if testUrls.isEmpty {
                            Text(verbatim: L10n.text("rules.editor.test_urls_placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(L10n.text("rules.editor.test_urls"))

                ForEach(Array(testResults.enumerated()), id: \.offset) { _, result in
                    Label {
                        Text(verbatim: result.line)
                            .monospaced()
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: result.matches ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(result.matches ? .green : .secondary)
                    }
                    .accessibilityValue(L10n.text(result.matches ? "rules.editor.matches" : "rules.editor.no_match"))
                    if result.matches, let winner = Rule.firstMatch(in: precedingRules, for: result.line) {
                        Label(L10n.format("rules.editor.shadowed", winner.target.displayName), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text(verbatim: L10n.text("rules.editor.test_urls"))

                    Spacer()

                    if !testResults.isEmpty {
                        Text(verbatim: L10n.format(
                            "rules.editor.match_count",
                            String(testResults.filter(\.matches).count),
                            String(testResults.count)
                        ))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent(L10n.text("browsers.target.open_in")) {
                    BrowserTargetPicker(app: $url, profile: $profile)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button(L10n.text("common.delete"), role: .destructive) {
                        onDelete?()
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("common.cancel"), role: .cancel) {
                    onCancel?()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.text("common.save")) {
                    guard let url else {
                        return
                    }

                    onSave(
                        Rule(
                            regex: expression,
                            app: url,
                            profile: profile,
                            kind: kind
                        )
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(compiledRegex == nil || url == nil)
            }
        }
    }

    @ViewBuilder
    private var expressionFooter: some View {
        if !expression.isEmpty && compiledRegex == nil {
            Label(L10n.text("rules.editor.invalid_regex"), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if kind == .pattern {
            Text(verbatim: L10n.text("rules.editor.pattern_help"))
                .foregroundStyle(.secondary)
        }
    }
}
