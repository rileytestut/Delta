import Foundation

final class PS1ArtworkCatalog
{
    static let shared = PS1ArtworkCatalog(fileURL: Bundle.main.url(forResource: "ps1-boxarts", withExtension: "txt"))

    private let titles: [(name: String, normalized: String)]

    init(fileURL: URL?)
    {
        let contents = fileURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        self.titles = contents.split(separator: "\n").map { title in
            let name = String(title)
            return (name, Self.normalized(name))
        }
    }

    func metadataResults(forGameName name: String) -> [GameMetadata]
    {
        let query = Self.normalized(name)
        guard !query.isEmpty else { return [] }

        return self.titles.enumerated()
            .filter { $0.element.normalized.contains(query) }
            .sorted { left, right in
                let leftStarts = left.element.normalized.hasPrefix(query)
                let rightStarts = right.element.normalized.hasPrefix(query)
                return leftStarts == rightStarts ? left.element.name < right.element.name : leftStarts
            }
            .prefix(100)
            .compactMap { self.metadata(index: $0.offset, title: $0.element.name) }
    }

    func metadata(forGameName name: String) -> GameMetadata?
    {
        let exact = self.titles.enumerated().first { $0.element.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if let exact { return self.metadata(index: exact.offset, title: exact.element.name) }

        let query = Self.normalized(name)
        guard !query.isEmpty else { return nil }
        let matches = self.titles.enumerated().filter { $0.element.normalized == query }
        let preferred = matches.first { $0.element.name.contains("(USA)") } ?? matches.first
        return preferred.flatMap { self.metadata(index: $0.offset, title: $0.element.name) }
    }

    private func metadata(index: Int, title: String) -> GameMetadata?
    {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "thumbnails.libretro.com"
        url.path = "/Sony - PlayStation/Named_Boxarts/\(title).png"
        guard let artworkURL = url.url else { return nil }
        return GameMetadata(releaseID: -index - 1, romID: -1, name: title, artworkURL: artworkURL)
    }

    private static func normalized(_ title: String) -> String
    {
        return title.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
