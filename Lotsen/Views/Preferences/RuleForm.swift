//
//  RuleForm.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

struct RuleForm: View {
    var isNew: Bool
    var onSave: (Rule) -> Void
    /// Nil for a rule that isn't saved yet, which has nothing to delete.
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var regex: String
    @State private var kind: Rule.Kind
    @State private var testUrls: String = ""
    @State private var url: URL?
    @State private var profile: String?
    @State private var deletePresented = false

    init(rule: Rule?, onSave: @escaping (Rule) -> Void, onDelete: (() -> Void)? = nil) {
        isNew = rule == nil
        self.onSave = onSave
        self.onDelete = onDelete
        _regex = State(initialValue: rule?.regex ?? "")
        _kind = State(initialValue: rule?.kind ?? .regex)
        _url = State(initialValue: rule?.app)
        _profile = State(initialValue: rule?.profile)
    }

    private var compiledRegex: Regex<AnyRegexOutput>? {
        regex.isEmpty ? nil : Rule.compile(regex, kind: kind)
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

    private var generatedRegex: String? {
        RegexGenerator.regex(from: testLines)
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.text("rules.editor.type"), selection: $kind) {
                    Text(verbatim: L10n.text("rules.kind.regex")).tag(Rule.Kind.regex)
                    Text(verbatim: L10n.text("rules.kind.pattern")).tag(Rule.Kind.pattern)
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
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: L10n.text("rules.editor.generate_regex_help"))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(L10n.text("rules.editor.generate_regex")) {
                        kind = .regex
                        regex = generatedRegex ?? regex
                    }
                    .disabled(generatedRegex == nil)
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
                        deletePresented = true
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("common.cancel"), role: .cancel) {
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
                            regex: regex,
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
        .confirmationDialog(
            L10n.text("rules.editor.delete_confirmation"),
            isPresented: $deletePresented
        ) {
            Button(L10n.text("common.delete"), role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var expressionFooter: some View {
        if !regex.isEmpty && compiledRegex == nil {
            Label(L10n.text("rules.editor.invalid_regex"), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if kind == .pattern {
            Text(verbatim: L10n.text("rules.editor.pattern_help"))
                .foregroundStyle(.secondary)
        }
    }
}
