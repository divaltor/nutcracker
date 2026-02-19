import SwiftUI

@main
struct NutcrackerApp: App {
    @State private var filterListStore = FilterListStore()
    @State private var clipboardMonitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                clipboardMonitor: clipboardMonitor,
                filterListStore: filterListStore
            )
        } label: {
            Image(systemName: clipboardMonitor.isEnabled ? "shield.checkered" : "shield.slash")
        }

        Settings {
            SettingsView(filterListStore: filterListStore)
        }
    }

    init() {
        clipboardMonitor.filterListStore = filterListStore
        clipboardMonitor.start()

        let store = filterListStore
        Task {
            await store.loadOrFetch()
        }
    }
}
