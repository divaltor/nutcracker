import AppKit
import os

@Observable
final class ClipboardMonitor {
    private(set) var lastCleanedURL: String?
    private(set) var cleanCount = 0
    
    private var lastChangeCount: Int = 0
    private var lastWrittenString: String?
    private var monitorTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "dev.sweet.diva.nutcracker", category: "ClipboardMonitor")
    
    var isEnabled = true {
        didSet {
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    
    var filterListStore: FilterListStore?
    
    func start() {
        guard monitorTask == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                self?.pollClipboard()
            }
        }
        logger.info("Clipboard monitor started")
    }
    
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("Clipboard monitor stopped")
    }
    
    private func pollClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard isEnabled else { return }
        
        guard let string = pasteboard.string(forType: .string) else { return }
        
        // Skip if this is our own write
        if string == lastWrittenString {
            lastWrittenString = nil
            return
        }
        
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        guard let rules = filterListStore?.rules, !rules.isEmpty else { return }
        
        let cleaner = URLCleaner(rules: rules)
        guard let cleaned = cleaner.clean(trimmed) else { return }
        
        // Write cleaned URL back to clipboard
        lastWrittenString = cleaned
        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)
        lastChangeCount = pasteboard.changeCount
        
        lastCleanedURL = cleaned
        cleanCount += 1
        logger.info("Cleaned URL: \(trimmed) -> \(cleaned)")
    }
}
