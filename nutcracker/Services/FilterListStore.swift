import Foundation
import os

@Observable
final class FilterListStore {
    private(set) var rules: [RemoveParamRule] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    private(set) var error: String?
    
    private let listURL = URL(string: "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt")!
    private let parser = FilterListParser()
    private let logger = Logger(subsystem: "dev.sweet.diva.nutcracker", category: "FilterListStore")
    
    private var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("nutcracker", isDirectory: true)
    }
    
    private var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent("LegitimateURLShortener.txt")
    }
    
    private var metadataURL: URL {
        cacheDirectory.appendingPathComponent("metadata.json")
    }
    
    func loadOrFetch() async {
        // Try loading from cache first
        if let cached = loadFromCache() {
            rules = parser.parse(cached)
            logger.info("Loaded \(self.rules.count) rules from cache")
            
            // Check if refresh needed (older than 24h)
            if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 86400 {
                return
            }
        }
        
        await fetchFromRemote()
    }
    
    func fetchFromRemote() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: listURL)
            guard let text = String(data: data, encoding: .utf8) else {
                error = "Invalid encoding"
                return
            }
            
            // Save to cache
            try saveToCache(text)
            
            // Parse rules
            let newRules = parser.parse(text)
            rules = newRules
            lastUpdated = Date()
            saveMetadata()
            
            logger.info("Fetched and parsed \(newRules.count) rules from remote")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to fetch filter list: \(error.localizedDescription)")
        }
    }
    
    private func loadFromCache() -> String? {
        loadMetadata()
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return nil }
        return try? String(contentsOf: cacheFileURL, encoding: .utf8)
    }
    
    private func saveToCache(_ text: String) throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try text.write(to: cacheFileURL, atomically: true, encoding: .utf8)
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
