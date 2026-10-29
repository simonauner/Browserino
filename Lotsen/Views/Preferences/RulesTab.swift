//
//  RulesTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

struct RuleRow: View {
    let rule: Rule

    var body: some View {
        let bundle = Bundle(url: rule.app)

        HStack {
            Text(verbatim: rule.regex)
                .monospaced()
                .lineLimit(1)
                .truncationMode(.middle)

            if rule.kind == .pattern {
                Text(verbatim: L10n.text("rules.kind.pattern"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(bundle == nil
                 ? L10n.format("browsers.status.not_installed", rule.app.appDisplayName)
                 : rule.target.displayName)
                .foregroundStyle(
                    bundle == nil || rule.target.hasMissingProfile ? .secondary : .primary
                )

            if bundle != nil {
                BrowserTargetIcon(target: rule.target)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RulesTab: View {
    @Setting(\.rules) private var rules
    @AppStorage("rules_showInPicker") private var showInPicker: Bool = true
    @State private var addPresented = false
    @State private var editing: EditedRow<Rule>?
    /// Owned by the settings window, so the draft shows once rather than every
    /// time the Rules pane is reopened.
    @Binding var draft: RuleDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $showInPicker) {
                Text(verbatim: L10n.text("rules.picker.show_option"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            EditableList(
                count: rules.count,
                add: {
                    addPresented = true
                },
                edit: { index in
                    editing = EditedRow(id: index, value: rules[index])
                },
                remove: { rows in
                    rules.remove(atOffsets: rows)
                },
                move: { rows, destination in
                    rules.move(fromOffsets: rows, toOffset: destination)
                }
            ) { index in
                RuleRow(rule: rules[index])
            }
            
            Text(verbatim: L10n.text("rules.list.instructions"))
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.text("rules.list.priority"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $addPresented) {
            RuleForm(rule: nil, precedingRules: rules) {
                rules.append($0)
            }
        }
        .sheet(item: $draft) { draft in
            // The picker closed without opening the link, so it opens now: in the
            // saved rule's browser, or the one picked there.
            RuleForm(
                draft: draft,
                precedingRules: rules,
                onSave: { rule in
                    rules.append(rule)
                    draft.open(with: rule)
                },
                onCancel: {
                    draft.open(with: draft.rule)
                }
            )
        }
        .sheet(item: $editing) { row in
            RuleForm(
                rule: row.value,
                precedingRules: Array(rules.prefix(row.id)),
                onSave: { rule in
                    if rules.indices.contains(row.id) {
                        rules[row.id] = rule
                    }
                },
                onDelete: {
                    rules.removeAll {
                        $0 == row.value
                    }
                }
            )
        }
    }
}

#Preview {
    RulesTab(draft: .constant(nil))
}
