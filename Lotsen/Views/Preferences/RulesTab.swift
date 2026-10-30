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

            if rule.isIncognito {
                Image(systemName: "lock")
                    .help(L10n.text("picker.private.open"))
                    .accessibilityLabel(L10n.text("picker.private.open"))
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
    @AppStorage("rules_paused") private var rulesPaused = false
    @AppStorage("rules_showInPicker") private var showInPicker: Bool = true
    @State private var addPresented = false
    @State private var editing: EditedRow<Rule>?
    private var undoManager: UndoManager? { (NSApp.delegate as? AppDelegate)?.settingsUndoManager }
    /// Owned by the settings window, so the draft shows once rather than every
    /// time the Rules pane is reopened.
    @Binding var draft: RuleDraft?

    private func update(_ value: [Rule], action: String) {
        AppSettings.shared.replace(\.rules, with: value, undoManager: undoManager, actionName: L10n.text(action))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(L10n.text("rules.pause"), isOn: $rulesPaused)
            Text(verbatim: L10n.text("rules.bypass_hint"))
                .foregroundStyle(.secondary)

            Toggle(isOn: $showInPicker) {
                Text(verbatim: L10n.text("rules.picker.show_option"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            EditableList(
                items: rules,
                add: {
                    addPresented = true
                },
                edit: { index in
                    if rules.indices.contains(index) {
                        editing = EditedRow(id: index, value: rules[index])
                    }
                },
                remove: { rows in
                    var value = rules
                    value.remove(atOffsets: rows)
                    update(value, action: "common.delete")
                },
                move: { rows, destination in
                    var value = rules
                    value.move(fromOffsets: rows, toOffset: destination)
                    update(value, action: "rules.list.reorder")
                }
            ) { rule in
                RuleRow(rule: rule)
            }
            .overlay {
                if rules.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.text("rules.empty.title"), systemImage: "arrow.triangle.branch")
                    } description: {
                        Text(verbatim: L10n.text("rules.empty.description"))
                    } actions: {
                        Button(L10n.text("rules.empty.add")) { addPresented = true }
                    }
                    .padding(.bottom, 30)
                }
            }
            
            Text(verbatim: L10n.text("rules.list.instructions"))
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.text("rules.list.priority"))
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.text("settings.list.undo_hint"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $addPresented) {
            RuleForm(rule: nil, precedingRules: rules) {
                update(rules + [$0], action: "common.add")
            }
        }
        .sheet(item: $draft) { draft in
            // The picker closed without opening the link, so it opens now: in the
            // saved rule's browser, or the one picked there.
            RuleForm(
                draft: draft,
                precedingRules: rules,
                onSave: { rule in
                    update(rules + [rule], action: "common.add")
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
                        var value = rules
                        value[row.id] = rule
                        update(value, action: "common.edit")
                    }
                },
                onDelete: {
                    if rules.indices.contains(row.id), rules[row.id] == row.value {
                        var value = rules
                        value.remove(at: row.id)
                        update(value, action: "common.delete")
                    }
                }
            )
        }
    }
}

#Preview {
    RulesTab(draft: .constant(nil))
}
