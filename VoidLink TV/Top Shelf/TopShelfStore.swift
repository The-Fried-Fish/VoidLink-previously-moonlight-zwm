import UIKit
import ImageIO
import TVServices

enum TopShelfStore {
    static let imageShape: TVTopShelfSectionedItem.ImageShape = .poster

    struct Item: Codable {
        let title: String
        let url: URL
        let imageName: String
    }

    private static var container: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "TopShelfAppGroup") as? String,
              !group.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    private static func cacheDirectory(in container: URL) -> URL {
        container.appendingPathComponent("Library/Caches/VoidLinkTopShelf", isDirectory: true)
    }

    static func content() -> [(item: Item, image: URL)] {
        guard let container else {
            NSLog("Top Shelf provider cannot open the App Group container")
            return []
        }
        let items: [Item]
        do {
            items = try read(from: container)
        } catch {
            NSLog("Top Shelf provider could not read its index: %@", String(describing: error))
            return []
        }
        let directory = cacheDirectory(in: container)
        return items.map { item in
            let cached = directory.appendingPathComponent(item.imageName)
            let image = FileManager.default.fileExists(atPath: cached.path)
                ? cached : container.appendingPathComponent(item.imageName)
            return (item, image)
        }
    }

    static func add(title: String, url: URL, isApp: Bool, artworkPath: String?) throws {
        guard let container else { throw CocoaError(.fileNoSuchFile) }
        let directory = cacheDirectory(in: container)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var items = try read(from: container)
        let imageName = items.first(where: { $0.url == url })?.imageName ?? UUID().uuidString + ".jpg"
        let item = Item(title: title, url: url, imageName: imageName)
        let artwork = artworkPath.flatMap { loadArtwork(at: $0) }
        guard let imageData = makeImage(title: title, isApp: isApp, artwork: artwork).jpegData(compressionQuality: 0.9) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try imageData.write(to: directory.appendingPathComponent(imageName), options: .atomic)
        items.removeAll { $0.url == url }
        items.insert(item, at: 0)
        try JSONEncoder().encode(items).write(to: directory.appendingPathComponent("TopShelf.json"), options: .atomic)
    }

    static func contains(_ url: URL) -> Bool {
        guard let container, let items = try? read(from: container) else { return false }
        return items.contains { $0.url == url }
    }

    static func removeIfPresent(_ url: URL) throws -> Bool {
        guard let container else { throw CocoaError(.fileNoSuchFile) }
        let items = try read(from: container)
        let removed = items.filter { $0.url == url }
        guard !removed.isEmpty else { return false }

        let remaining = items.filter { $0.url != url }
        let directory = cacheDirectory(in: container)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(remaining).write(to: directory.appendingPathComponent("TopShelf.json"), options: .atomic)

        let remainingImages = Set(remaining.map(\.imageName))
        for item in removed where !remainingImages.contains(item.imageName) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(item.imageName))
        }
        return true
    }

    private static func read(from container: URL) throws -> [Item] {
        let directory = cacheDirectory(in: container)
        // Read entries written by earlier builds until the next save moves the index.
        for location in [directory, container] {
            let file = location.appendingPathComponent("TopShelf.json")
            if FileManager.default.fileExists(atPath: file.path) {
                return try JSONDecoder().decode([Item].self, from: Data(contentsOf: file))
            }
        }
        return []
    }

    // Decode a bounded thumbnail before the poster renderer performs aspect-fill
    // cropping. Drawing the original image here would still decode its full bitmap.
    private static func loadArtwork(at path: String) -> UIImage? {
        let maxFileBytes: UInt64 = 6 * 1024 * 1024
        let maxPixelSize = 600
        let maxBitmapBytes = maxPixelSize * maxPixelSize * 4
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.uint64Value > 0, fileSize.uint64Value <= maxFileBytes,
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                  [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              image.width > 0, image.height > 0,
              image.width <= maxPixelSize, image.height <= maxPixelSize,
              image.bytesPerRow > 0, image.bytesPerRow <= maxBitmapBytes / image.height else { return nil }
        return UIImage(cgImage: image)
    }

    private static func makeImage(title: String, isApp: Bool, artwork: UIImage?) -> UIImage {
        let size = CGSize(width: 240, height: 360)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.10, green: 0.15, blue: 0.23, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            if let artwork, artwork.size.width > 0, artwork.size.height > 0 {
                let scale = max(size.width / artwork.size.width, size.height / artwork.size.height)
                let width = artwork.size.width * scale
                let height = artwork.size.height * scale
                artwork.draw(in: CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                                        width: width, height: height))
                return
            }

            let configuration = UIImage.SymbolConfiguration(pointSize: 85, weight: .medium)
            let symbol = isApp ? UIImage(systemName: "gamecontroller.fill", withConfiguration: configuration)
                               : UIImage(named: "display")
            if let icon = symbol, icon.size.width > 0, icon.size.height > 0 {
                let scale = isApp ? 1 : 116 / max(icon.size.width, icon.size.height)
                let width = icon.size.width * scale
                let height = icon.size.height * scale
                let top = isApp ? 82.0 : 100.0
                let rect = CGRect(x: (size.width - width) / 2, y: top, width: width, height: height)
                icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: rect)
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail
            let titleInset: CGFloat = 16
            (title as NSString).draw(in: CGRect(x: titleInset, y: 225, width: size.width - 2 * titleInset, height: 52),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                                                      .foregroundColor: UIColor.white, .paragraphStyle: paragraph])
        }
    }
}
