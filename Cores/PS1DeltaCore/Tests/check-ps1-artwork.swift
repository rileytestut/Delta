import Foundation

@main
struct CheckPS1Artwork
{
    static func main()
    {
        let catalog = PS1ArtworkCatalog(fileURL: URL(fileURLWithPath: "Resources/ps1-boxarts.txt"))
        let cover = catalog.metadata(forGameName: "Crash Bandicoot (USA)")
        assert(cover?.name == "Crash Bandicoot (USA)")
        assert(cover?.artworkURL?.absoluteString == "https://thumbnails.libretro.com/Sony%20-%20PlayStation/Named_Boxarts/Crash%20Bandicoot%20(USA).png")
        assert(catalog.metadata(forGameName: "Crash Bandicoot")?.name == "Crash Bandicoot (USA)")
        assert(!catalog.metadataResults(forGameName: "Metal Gear Solid").isEmpty)
        assert(catalog.metadata(forGameName: "There Is No Such PlayStation Game") == nil)
    }
}
