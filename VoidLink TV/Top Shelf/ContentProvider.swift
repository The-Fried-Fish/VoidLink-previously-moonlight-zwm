import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        let items = TopShelfStore.content().map { entry in
            let item = TVTopShelfSectionedItem(identifier: entry.item.url.absoluteString)
            item.title = entry.item.title
            item.imageShape = TopShelfStore.imageShape
            item.setImageURL(entry.image, for: .screenScale1x)
            item.setImageURL(entry.image, for: .screenScale2x)
            let action = TVTopShelfAction(url: entry.item.url)
            item.displayAction = action
            item.playAction = action
            return item
        }
        NSLog("Top Shelf provider loaded %ld items", items.count)
        guard !items.isEmpty else {
            completionHandler(nil)
            return
        }
        let section = TVTopShelfItemCollection(items: items)
        section.title = "VoidLink"
        completionHandler(TVTopShelfSectionedContent(sections: [section]))
    }
}
