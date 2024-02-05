import SwiftSoup

enum Parser {}

extension Parser {
    func parseHtml(content: String) -> String {
        guard let doc = try? SwiftSoup.parseBodyFragment(content) else { return content }
        guard let text = try? doc.text() else { return content }

        return text
    }
}
