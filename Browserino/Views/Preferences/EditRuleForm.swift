//
//  EditRuleForm.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

struct EditRuleForm: View {
    @Binding var rule: Rule
    @Binding var isPresented: Bool
    
    @Setting(\.rules) private var rules
    
    var body: some View {
        RuleForm(
            rule: rule,
            onCancel: {
                isPresented.toggle()
            },
            onSave: {
                rule = $0
                isPresented.toggle()
            },
            onDelete: {
                rules.removeAll {
                    $0 == rule
                }
                isPresented.toggle()
            }
        )
    }
}

struct NewRuleForm: View {
    @Binding var isPresented: Bool
    
    @Setting(\.rules) private var rules
    
    var body: some View {
        RuleForm(
            rule: nil,
            onCancel: {
                isPresented.toggle()
            },
            onSave: {
                rules.append($0)
                isPresented.toggle()
            },
            onDelete: {
                isPresented.toggle()
            }
        )
    }
}

struct RuleForm: View {
    var rule: Rule?
    
    var onCancel: () -> Void
    var onSave: (Rule) -> Void
    var onDelete: () -> Void

    @State private var regex: String = ""
    @State private var kind: Rule.Kind = .regex
    @State private var testUrls: String = ""
    @State private var url: URL?
    @State private var profile: String?
    
    private var compiledRegex: Regex<AnyRegexOutput>? {
        return Rule.compile(regex, kind: kind)
    }
    
    private var generatedRegex: String? {
        return RegexGenerator.regex(from: testUrls.components(separatedBy: .newlines))
    }
    
    private var testLines: [(line: String, matches: Bool)] {
        testUrls.split(separator: "\n").map { line in
            (String(line), compiledRegex.map { line.firstMatch(of: $0) != nil } ?? false)
        }
    }
    
    var body: some View {
        Form {
            Section(
                header: Text(verbatim: L10n.text("settings.tabs.general"))
                    .font(.headline)
            ) {
                Picker(L10n.text("rules.editor.type"), selection: $kind) {
                    Text(verbatim: L10n.text("rules.kind.regex")).tag(Rule.Kind.regex)
                    Text(verbatim: L10n.text("rules.kind.pattern")).tag(Rule.Kind.pattern)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                
                TextField(L10n.text(kind == .regex ? "rules.editor.regex" : "rules.editor.pattern"), text: $regex)
                    .font(
                        .system(size: 14)
                    )
                
                if kind == .pattern {
                    Text(verbatim: L10n.text("rules.editor.pattern_help"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent(L10n.text("rules.editor.test_urls")) {
                    TextEditor(text: $testUrls)
                        .font(
                            .system(size: 14)
                        )
                }
                
                Button(action: {
                    kind = .regex
                    regex = generatedRegex ?? regex
                }) {
                    Text(verbatim: L10n.text("rules.editor.generate_regex"))
                }
                .disabled(generatedRegex == nil)
                
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(testLines.enumerated()), id: \.offset) { _, testLine in
                        HStack(spacing: 6) {
                            // Hidden rather than removed, so all URLs stay aligned.
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                                .opacity(testLine.matches ? 1 : 0)
                            Text(verbatim: testLine.line)
                        }
                    }
                }
                .font(
                    .system(size: 14)
                )
            }
            
            Spacer()
                .frame(height: 32)
            
            
            LabeledContent(L10n.text("browsers.target.open_in")) {
                BrowserTargetPicker(app: $url, profile: $profile)
            }
            
            Spacer()
                .frame(height: 32)
            
            HStack {
                Button(role: .cancel, action: onCancel) {
                    Text(verbatim: L10n.text("common.cancel"))
                }
                
                if rule != nil {
                    Button(role: .destructive, action: onDelete) {
                        Text(verbatim: L10n.text("common.delete"))
                    }
                }
                
                Spacer()
                
                Button(action: {
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
                }) {
                    Text(verbatim: L10n.text("common.save"))
                }
                .disabled(compiledRegex == nil || url == nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(minWidth: 500)
        .onAppear {
            regex = rule?.regex ?? ""
            kind = rule?.kind ?? .regex
            url = rule?.app
            profile = rule?.profile
        }
    }
}
