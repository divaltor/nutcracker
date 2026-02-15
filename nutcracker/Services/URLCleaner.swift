import Foundation

struct URLCleaner {
    let rules: [RemoveParamRule]
    
    func clean(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        
        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return nil
        }
        
        let host = url.host?.lowercased() ?? ""
        
        // Separate applicable rules
        let exceptions = rules.filter { $0.isException && $0.domainApplies(to: host) }
        let removals = rules.filter { !$0.isException && $0.domainApplies(to: host) }
        
        var cleaned: [URLQueryItem] = []
        var didRemove = false
        
        for item in queryItems {
            let shouldRemove = removals.contains { rule in
                rule.matcher.matches(item.name, value: item.value)
            }
            
            let isExcepted = exceptions.contains { rule in
                rule.matcher.matches(item.name, value: item.value)
            }
            
            if shouldRemove && !isExcepted {
                didRemove = true
            } else {
                cleaned.append(item)
            }
        }
        
        guard didRemove else { return nil }
        
        components.queryItems = cleaned.isEmpty ? nil : cleaned
        return components.url?.absoluteString ?? components.string
    }
}
