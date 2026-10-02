import Foundation

enum CatalogPresentation {
    static func sections(_ source: [ContentSection], destination: ContentItem? = nil) -> [ContentSection] {
        var result = [ContentSection](), index = 0
        while index < source.count {
            let section = source[index]
            guard [.Title, .Subtitle].contains(section.layoutType) else { result.append(section); index += 1; continue }
            var labels = [String](), grouped = section
            while index < source.count, [.Title, .Subtitle].contains(source[index].layoutType) {
                let label = source[index].title
                if !label.isEmpty && !labels.contains(where: { normalized($0) == normalized(label) }) { labels.append(label) }
                index += 1
            }
            grouped.title = labels.first ?? ""; grouped.subtitle = labels.dropFirst().joined(separator: "\n"); result.append(grouped)
        }
        guard var destination else { return result }
        let firstContent = result.first(where: { ![.Title, .Subtitle].contains($0.layoutType) })
        if firstContent?.layoutType == .Hero || firstContent?.layoutType == .GpBanner {
            if let first = result.first, [.Title, .Subtitle].contains(first.layoutType), let item = firstContent?.items.first,
               let title = item.title, normalized(first.title) == normalized(title) {
                let remaining = first.subtitle.components(separatedBy: "\n").filter { !$0.isEmpty && normalized($0) != normalized(item.longDescription ?? "") }
                if remaining.isEmpty { result.removeFirst() }
                else { result[0].title = remaining[0]; result[0].layoutType = .Subtitle; result[0].subtitle = remaining.dropFirst().joined(separator: "\n") }
            }
            return result
        }
        let heading = result.first.flatMap { [.Title, .Subtitle].contains($0.layoutType) ? $0 : nil }
        destination.title = heading?.title ?? destination.title ?? destination.label ?? ""
        if let picture = heading?.artwork, !picture.isEmpty { destination.pictureUrl = picture }
        destination.label = heading?.subtitle
        if heading != nil { result.removeFirst() }
        var header = ContentSection(); header.id = "header:\(destination.id)"; header.layoutType = .PageHeader; header.content = .destination(destination)
        result.insert(header, at: 0); return result
    }
    static func normalized(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased() }
    static func verticallyAligned(source: CGRect, action: CGRect) -> Bool { source.maxX > action.minX && source.minX < action.maxX }
    static func cardWidth(layout: ContainerLayoutType, availableWidth: CGFloat) -> CGFloat {
        let columns: CGFloat = layout.isPoster ? 4 : 3
        return layout.isHorizontal ? min(layout.isPoster ? 240 : 380, availableWidth * (layout.isPoster ? 0.28 : 0.36)) : floor((availableWidth - (columns - 1) * 24) / columns)
    }
    static func showsViewAll(_ section: ContentSection, availableWidth: CGFloat, availableHeight: CGFloat) -> Bool {
        guard section.viewAllAction != nil, !section.items.isEmpty else { return false }
        if (section.total ?? section.items.count) > section.items.count { return true }
        let width = cardWidth(layout: section.layoutType, availableWidth: availableWidth)
        if section.layoutType.isHorizontal { return CGFloat(section.items.count) * width + CGFloat(section.items.count - 1) * 24 > availableWidth }
        let columns = section.layoutType.isPoster ? 4 : 3, rows = (section.items.count + columns - 1) / columns
        let height = width * (section.layoutType.isPoster ? 1.5 : 9 / 16) + (section.layoutType == .VerticalSimplePoster ? 0 : section.layoutType.isPoster ? 144 : 160)
        return CGFloat(rows) * height + CGFloat(rows - 1) * 24 + 72 > availableHeight
    }
    static func isEventDestination(_ destination: ContentItem?, sections: [ContentSection]) -> Bool {
        guard let destination else { return false }
        return sections.contains { $0.layoutType == .GpBanner } || destination.race?.meetingKey.isEmpty == false
    }
    static func eventArtwork(_ destination: ContentItem?, sections: [ContentSection]) -> String? {
        guard isEventDestination(destination, sections: sections) else { return nil }
        let pictures = [destination?.pictureUrl] + sections.filter { [.GpBanner, .PageHeader].contains($0.layoutType) }.map { $0.items.first?.pictureUrl }
        return pictures.compactMap { $0 }.first { !$0.isEmpty }
    }
}
