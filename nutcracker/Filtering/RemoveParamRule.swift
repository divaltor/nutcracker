import Foundation

struct RemoveParamRule {
    enum ParamMatcher {
        case exact(String)
        case regex(NSRegularExpression)

        func matches(_ paramName: String, value: String?) -> Bool {
            switch self {
            case .exact(let name):
                return paramName.lowercased() == name.lowercased()
            case .regex(let regex):
                // uBO tests regex against "name=value" pair
                let testString: String
                if let value {
                    testString = "\(paramName)=\(value)"
                } else {
                    testString = paramName
                }
                let range = NSRange(testString.startIndex..., in: testString)
                return regex.firstMatch(in: testString, range: range) != nil
            }
        }
    }

    let isException: Bool
    let domains: [String]
    let matcher: ParamMatcher

    func domainApplies(to host: String) -> Bool {
        if domains.isEmpty { return true }
        let lowerHost = host.lowercased()
        return domains.contains { domain in
            let d = domain.lowercased()
            if d.contains(".") {
                return lowerHost == d || lowerHost.hasSuffix(".\(d)")
            } else {
                // Wildcard TLD: "bing" matches "bing.com", "bing.de", etc.
                return lowerHost == d || lowerHost.hasPrefix("\(d).") || lowerHost.contains(".\(d).")
            }
        }
    }
}
