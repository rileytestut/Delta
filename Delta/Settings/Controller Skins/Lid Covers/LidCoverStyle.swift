// Original companion designs for DuoDS. No third-party artwork is bundled.
import Foundation

enum LidCoverStyle: String, CaseIterable
{
    case graphite, snow, frost, navy, blossom

    var name: String { self.rawValue.capitalized }

    var assetName: String { "LidCover-" + self.name }

    static func matching(skinIdentifier: String) -> LidCoverStyle?
    {
        // Use the verified official identifiers, never a fuzzy match on a user's skin name.
        let components = skinIdentifier.split(separator: ".")
        guard components.count == 6, components.prefix(4).joined(separator: ".") == "com.duods.delta.ds",
              ["inner-book", "cover", "split-view"].contains(String(components[5])) else { return nil }
        return Self(rawValue: String(components[4]))
    }
}

enum LidCoverSelection: Equatable
{
    case builtIn(LidCoverStyle)
    case imported(UUID)

    init?(storedValue: String)
    {
        if let style = LidCoverStyle(rawValue: storedValue)
        {
            self = .builtIn(style)
        }
        else if let identifier = UUID(uuidString: storedValue)
        {
            self = .imported(identifier)
        }
        else
        {
            return nil
        }
    }

    var storedValue: String {
        switch self
        {
        case .builtIn(let style): return style.rawValue
        case .imported(let identifier): return identifier.uuidString
        }
    }
}
