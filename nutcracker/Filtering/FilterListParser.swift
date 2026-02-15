import Foundation

struct FilterListParser {
    func parse(_ text: String) -> [RemoveParamRule] {
        var rules: [RemoveParamRule] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("!") { continue }

            // Skip cosmetic filters and scriptlet injections
            if trimmed.contains("##") || trimmed.contains("#@#") || trimmed.contains("##+js") { continue }

            // Skip blocking rules (lines that don't contain removeparam)
            guard trimmed.contains("removeparam") else { continue }

            if let rule = parseLine(trimmed) {
                rules.append(rule)
            }
        }

        return rules
    }

    private func parseLine(_ line: String) -> RemoveParamRule? {
        var working = line

        // Detect exception
        let isException = working.hasPrefix("@@")
        if isException {
            working = String(working.dropFirst(2))
        }

        // Split into pattern and modifiers at first unescaped $
        // Need to handle $ inside regex values carefully
        guard let dollarIndex = findOptionsSeparator(in: working) else { return nil }

        let pattern = String(working[working.startIndex..<dollarIndex])
        let optionsString = String(working[working.index(after: dollarIndex)...])

        // Parse domain from pattern
        let domains = parseDomains(from: pattern, options: optionsString)

        // Parse removeparam value from options
        let options = splitOptions(optionsString)

        for option in options {
            if option == "removeparam" {
                // removeparam with no value - remove ALL params (skip for safety in PoC)
                continue
            }

            if option.hasPrefix("removeparam=") {
                let value = String(option.dropFirst("removeparam=".count))
                if value.isEmpty { continue }

                if let matcher = parseParamMatcher(value) {
                    return RemoveParamRule(isException: isException, domains: domains, matcher: matcher)
                }
            }
        }

        return nil
    }

    private func findOptionsSeparator(in text: String) -> String.Index? {
        // Find the $ that separates the URL pattern from options
        // But skip $ inside regex patterns like /^foo$/
        var inRegex = false
        for i in text.indices {
            let ch = text[i]
            if ch == "/" {
                inRegex.toggle()
            }
            if ch == "$" && !inRegex {
                return i
            }
        }
        return nil
    }

    private func splitOptions(_ optionsString: String) -> [String] {
        // Split by comma, but be careful with regex values that may contain commas
        var result: [String] = []
        var current = ""
        var inRegex = false

        for ch in optionsString {
            if ch == "/" {
                inRegex.toggle()
                current.append(ch)
            } else if ch == "," && !inRegex {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    result.append(trimmed)
                }
                current = ""
            } else {
                current.append(ch)
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result.append(trimmed)
        }

        return result
    }

    private func parseDomains(from pattern: String, options: String) -> [String] {
        var domains: [String] = []

        // Extract from URL pattern: ||domain.com^
        if pattern.hasPrefix("||") {
            let rest = pattern.dropFirst(2)
            // Domain ends at ^ or / or end of string
            var domain = ""
            for ch in rest {
                if ch == "^" || ch == "/" || ch == "$" {
                    break
                }
                domain.append(ch)
            }
            // Handle wildcard domains like bing.* - convert to bing.com etc (skip for PoC, treat as bing.)
            if !domain.isEmpty {
                // Replace trailing .* with empty to match any TLD - we'll use prefix matching
                if domain.hasSuffix(".*") {
                    domains.append(String(domain.dropLast(2)))
                } else {
                    domains.append(domain)
                }
            }
        }

        // Also check for domain= option in modifiers
        let opts = splitOptions(options)
        for opt in opts {
            if opt.hasPrefix("domain=") {
                let domainList = String(opt.dropFirst("domain=".count))
                for d in domainList.split(separator: "|") {
                    let ds = String(d).trimmingCharacters(in: .whitespaces)
                    if !ds.hasPrefix("~") && !ds.isEmpty {
                        domains.append(ds)
                    }
                }
            }
        }

        return domains
    }

    private func parseParamMatcher(_ value: String) -> RemoveParamRule.ParamMatcher? {
        // Check if it's a regex pattern: /pattern/ or /pattern/i
        if value.hasPrefix("/") {
            var regexStr = value

            // Remove leading /
            regexStr = String(regexStr.dropFirst())

            var options: NSRegularExpression.Options = []

            // Check for trailing /i or /
            if regexStr.hasSuffix("/i") {
                regexStr = String(regexStr.dropLast(2))
                options.insert(.caseInsensitive)
            } else if regexStr.hasSuffix("/") {
                regexStr = String(regexStr.dropLast())
            }

            // Some rules have additional suffix like $/i or just $/
            // The regex itself may contain $ as regex anchor, that's fine

            do {
                let regex = try NSRegularExpression(pattern: regexStr, options: options)
                return .regex(regex)
            } catch {
                return nil
            }
        }

        // Check for exact match with constraints like ^param=value$
        // For simple param names, just use exact
        // Handle rules like /^from=rss$/i - already handled above
        // Handle rules like ref=rss^ - parameter with specific value constraint
        // For PoC, treat plain text as exact param name match
        return .exact(value)
    }
}
