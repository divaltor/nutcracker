import SwiftUI

struct MenuBarView: View {
    @Bindable var clipboardMonitor: ClipboardMonitor
    var filterListStore: FilterListStore

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Enabled", isOn: $clipboardMonitor.isEnabled)
            .toggleStyle(.checkbox)

        Divider()

        if filterListStore.isLoading {
            Label("Updating rules…", systemImage: "arrow.trianglehead.2.counterclockwise")
        } else if let error = filterListStore.error {
            Label("Error: \(error)", systemImage: "exclamationmark.triangle")
        } else {
            Label("\(filterListStore.rules.count) rules loaded", systemImage: "checkmark.circle")
        }

        if let lastUpdated = filterListStore.lastUpdated {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text("Updated: \(lastUpdated, format: .relative(presentation: .named))")
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        if clipboardMonitor.cleanCount > 0 {
            Label("\(clipboardMonitor.cleanCount) URLs cleaned", systemImage: "sparkles")

            if let last = clipboardMonitor.lastCleanedURL {
                Text(last)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            Divider()
        }

        Button("Refresh Rules") {
            Task {
                await filterListStore.refreshAllSources()
            }
        }
        .disabled(filterListStore.isLoading)

        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
