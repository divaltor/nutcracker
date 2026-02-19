import Foundation

struct FilterSource: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, url: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
    }

    static let defaultSource = FilterSource(
        name: "LegitimateURLShortener",
        url: "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt"
    )
}
