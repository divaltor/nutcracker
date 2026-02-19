import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var filterListStore: FilterListStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeneralSection()

            Divider()

            FilterListsSection(filterListStore: filterListStore)
        }
        .padding()
        .frame(minWidth: 520, idealWidth: 520, maxWidth: 520, minHeight: 440, idealHeight: 500)
    }
}

// MARK: - Filter Lists Section

private struct FilterListsSection: View {
    @Bindable var filterListStore: FilterListStore
    @State private var selectedSourceID: FilterSource.ID?
    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriptions")
                .font(.headline)

            List(filterListStore.sources, selection: $selectedSourceID) { source in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { source.isEnabled },
                        set: { _ in filterListStore.toggleSource(id: source.id) }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    VStack(alignment: .leading) {
                        Text(source.name)
                        Text(source.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .tag(source.id)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            HStack(spacing: 4) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }

                Button(action: {
                    guard let id = selectedSourceID else { return }
                    filterListStore.removeSource(id: id)
                    selectedSourceID = nil
                }) {
                    Image(systemName: "minus")
                }
                .disabled(selectedSourceID == nil)
            }

            Divider()

            Text("Custom Rules")
                .font(.headline)

            Text("uBlock Origin syntax, one rule per line")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $filterListStore.customRulesText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                .scrollContentBackground(.visible)

            HStack {
                Spacer()
                Button("Apply") {
                    filterListStore.applyCustomRules()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddFilterListSheet(filterListStore: filterListStore)
        }
    }
}

// MARK: - Add Filter List Sheet

private struct AddFilterListSheet: View {
    var filterListStore: FilterListStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: url) != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Filter List")
                .font(.headline)

            Form {
                TextField("Name:", text: $name)
                TextField("URL:", text: $url)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    filterListStore.addSource(
                        name: name.trimmingCharacters(in: .whitespaces),
                        url: url.trimmingCharacters(in: .whitespaces)
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

// MARK: - General Section

private struct GeneralSection: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.headline)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    do {
                        if launchAtLogin {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
    }
}
