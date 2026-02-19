import Foundation
import os

@Observable
final class FilterListStore {
    private(set) var rules: [RemoveParamRule] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    private(set) var error: String?

    private(set) var sources: [FilterSource] = []
    var customRulesText: String = ""

    private let parser = FilterListParser()
    private let logger = Logger(subsystem: "dev.sweet.diva.nutcracker", category: "FilterListStore")

    // MARK: - Cache paths

    private var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("nutcracker", isDirectory: true)
    }

    private var sourcesFileURL: URL {
        cacheDirectory.appendingPathComponent("sources.json")
    }

    private var customRulesFileURL: URL {
        cacheDirectory.appendingPathComponent("customRules.txt")
    }

    private var metadataURL: URL {
        cacheDirectory.appendingPathComponent("metadata.json")
    }

    private func cacheFileURL(for source: FilterSource) -> URL {
        cacheDirectory.appendingPathComponent("cache_\(source.id.uuidString).txt")
    }

    // MARK: - Public API

    func loadOrFetch() async {
        loadSavedState()

        if sources.isEmpty {
            sources.append(.defaultSource)
            saveSources()
        }

        reparseRules()
        logger.info("Loaded \(self.rules.count) rules from cache")

        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 86400 {
            return
        }

        await refreshAllSources()
    }

    func refreshAllSources() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        for source in sources where source.isEnabled {
            do {
                try await fetchSource(source)
            } catch {
                self.error = "Some lists failed to update"
                logger.error("Failed to fetch \(source.name): \(error.localizedDescription)")
            }
        }

        lastUpdated = Date()
        saveMetadata()
        reparseRules()
        logger.info("Refreshed all sources, \(self.rules.count) total rules")
    }

    func addSource(name: String, url: String) {
        let source = FilterSource(name: name, url: url)
        sources.append(source)
        saveSources()

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await fetchSource(source)
                reparseRules()
            } catch {
                logger.error("Failed to fetch new source \(name): \(error.localizedDescription)")
            }
        }
    }

    func removeSource(id: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        let source = sources[index]
        try? FileManager.default.removeItem(at: cacheFileURL(for: source))
        sources.remove(at: index)
        saveSources()
        reparseRules()
    }

    func toggleSource(id: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].isEnabled.toggle()
        saveSources()
        reparseRules()
    }

    func applyCustomRules() {
        saveCustomRules()
        reparseRules()
    }

    // MARK: - Parsing

    private func reparseRules() {
        var allRules: [RemoveParamRule] = []

        for source in sources where source.isEnabled {
            if let cached = try? String(contentsOf: cacheFileURL(for: source), encoding: .utf8) {
                allRules.append(contentsOf: parser.parse(cached))
            }
        }

        let trimmed = customRulesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            allRules.append(contentsOf: parser.parse(customRulesText))
        }

        rules = allRules
    }

    // MARK: - Networking

    private func fetchSource(_ source: FilterSource) async throws {
        guard let url = URL(string: source.url) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        try ensureCacheDirectory()
        try text.write(to: cacheFileURL(for: source), atomically: true, encoding: .utf8)
    }

    // MARK: - Persistence

    private func ensureCacheDirectory() throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func loadSavedState() {
        loadMetadata()
        loadSources()
        loadCustomRules()
    }

    private func loadSources() {
        guard let data = try? Data(contentsOf: sourcesFileURL),
              let decoded = try? JSONDecoder().decode([FilterSource].self, from: data)
        else { return }
        sources = decoded
    }

    private func saveSources() {
        do {
            try ensureCacheDirectory()
            let data = try JSONEncoder().encode(sources)
            try data.write(to: sourcesFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save sources: \(error.localizedDescription)")
        }
    }

    private func loadCustomRules() {
        customRulesText = (try? String(contentsOf: customRulesFileURL, encoding: .utf8)) ?? ""
    }

    private func saveCustomRules() {
        do {
            try ensureCacheDirectory()
            try customRulesText.write(to: customRulesFileURL, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to save custom rules: \(error.localizedDescription)")
        }
    }

    private func saveMetadata() {
        let meta: [String: String] = [
            "lastUpdated": ISO8601DateFormatter().string(from: lastUpdated ?? Date())
        ]
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: metadataURL)
        }
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let meta = try? JSONDecoder().decode([String: String].self, from: data),
              let dateStr = meta["lastUpdated"],
              let date = ISO8601DateFormatter().date(from: dateStr)
        else { return }
        lastUpdated = date
    }
}
