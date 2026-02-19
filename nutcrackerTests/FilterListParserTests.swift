import Testing
import Foundation
@testable import nutcracker

struct FilterListParserTests {
    let parser = FilterListParser()

    // MARK: - Basic parsing

    @Test func emptyInput() {
        let rules = parser.parse("")
        #expect(rules.isEmpty)
    }

    @Test func skipsComments() {
        let input = """
        ! This is a comment
        ! Another comment
        """
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    @Test func skipsEmptyLines() {
        let input = "\n\n\n"
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    @Test func skipsCosmeticFilters() {
        let input = """
        example.com##.ad-banner
        example.com#@#.ad-banner
        example.com##+js(abort-on-property-read.js)
        """
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    @Test func skipsNonRemoveParamRules() {
        let input = "||example.com^$third-party"
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    // MARK: - Exact param matching

    @Test func parsesExactParamRule() {
        let input = "||example.com^$removeparam=fbclid"
        let rules = parser.parse(input)
        #expect(rules.count == 1)

        let rule = rules[0]
        #expect(!rule.isException)
        #expect(rule.domains == ["example.com"])

        if case .exact(let name) = rule.matcher {
            #expect(name == "fbclid")
        } else {
            Issue.record("Expected exact matcher")
        }
    }

    @Test func parsesGlobalRule() {
        let input = "*$removeparam=utm_source"
        let rules = parser.parse(input)
        #expect(rules.count == 1)
        #expect(rules[0].domains.isEmpty)

        if case .exact(let name) = rules[0].matcher {
            #expect(name == "utm_source")
        } else {
            Issue.record("Expected exact matcher")
        }
    }

    // MARK: - Exception rules

    @Test func parsesExceptionRule() {
        let input = "@@||example.com^$removeparam=fbclid"
        let rules = parser.parse(input)
        #expect(rules.count == 1)
        #expect(rules[0].isException)
        #expect(rules[0].domains == ["example.com"])
    }

    // MARK: - Regex param matching

    @Test func parsesRegexParamRule() {
        let input = "||example.com^$removeparam=/^utm_/"
        let rules = parser.parse(input)
        #expect(rules.count == 1)

        if case .regex(let regex) = rules[0].matcher {
            let range = NSRange("utm_source=test".startIndex..., in: "utm_source=test")
            #expect(regex.firstMatch(in: "utm_source=test", range: range) != nil)
        } else {
            Issue.record("Expected regex matcher")
        }
    }

    @Test func parsesRegexCaseInsensitive() {
        let input = "||example.com^$removeparam=/^from=rss$/i"
        let rules = parser.parse(input)
        #expect(rules.count == 1)

        if case .regex(let regex) = rules[0].matcher {
            let test = "from=RSS"
            let range = NSRange(test.startIndex..., in: test)
            #expect(regex.firstMatch(in: test, range: range) != nil)
        } else {
            Issue.record("Expected regex matcher")
        }
    }

    // MARK: - Domain parsing

    @Test func parsesWildcardTLD() {
        let input = "||bing.*$removeparam=cvid"
        let rules = parser.parse(input)
        #expect(rules.count == 1)
        #expect(rules[0].domains == ["bing"])
    }

    @Test func parsesDomainOption() {
        let input = "*$removeparam=ref,domain=example.com|test.org"
        let rules = parser.parse(input)
        #expect(rules.count == 1)
        #expect(rules[0].domains.contains("example.com"))
        #expect(rules[0].domains.contains("test.org"))
    }

    @Test func excludesNegatedDomains() {
        let input = "*$removeparam=ref,domain=example.com|~excluded.com"
        let rules = parser.parse(input)
        #expect(rules.count == 1)
        #expect(rules[0].domains.contains("example.com"))
        #expect(!rules[0].domains.contains("~excluded.com"))
    }

    // MARK: - Bare removeparam (no value)

    @Test func skipsRemoveParamWithoutValue() {
        let input = "||example.com^$removeparam"
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    @Test func skipsRemoveParamWithEmptyValue() {
        let input = "||example.com^$removeparam="
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }

    // MARK: - Multiple rules

    @Test func parsesMultipleRules() {
        let input = """
        ! Tracking params
        ||example.com^$removeparam=fbclid
        ||example.com^$removeparam=gclid

        ! Exception
        @@||safe.com^$removeparam=fbclid
        """
        let rules = parser.parse(input)
        #expect(rules.count == 3)

        #expect(!rules[0].isException)
        #expect(!rules[1].isException)
        #expect(rules[2].isException)
    }

    // MARK: - Combined options

    @Test func parsesRemoveParamWithOtherOptions() {
        let input = "||example.com^$third-party,removeparam=click_id"
        let rules = parser.parse(input)
        #expect(rules.count == 1)

        if case .exact(let name) = rules[0].matcher {
            #expect(name == "click_id")
        } else {
            Issue.record("Expected exact matcher")
        }
    }

    // MARK: - Invalid input

    @Test func returnsNilForLineWithoutDollarSeparator() {
        let input = "removeparam"
        let rules = parser.parse(input)
        #expect(rules.isEmpty)
    }
}
