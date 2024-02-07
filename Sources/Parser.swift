import SwiftSoup

enum Parser {}

extension Parser {
    static func parseHtml(content: String) -> String {
        guard let doc = try? SwiftSoup.parseBodyFragment(content) else { return content }
        guard let text = try? doc.text() else { return content }
        
        if let c = doc.body()?.children().array() {
            for e in c {
                print("Tag: \(e.tagName()) - \(isControlTag(e)).")
                print("Contents: \(String(describing: try? e.html()))")
                if let attrs = e.getAttributes() {
                    print("Attrs: \(String(describing: try? attrs.html()))")
                }
                
                let children = e.children().array()
                if let first = children.first {
                    print("Child tag: \(first.tagName())")
                    print("Child contents: \(String(describing: try? first.html()))")
                    print("Outer contents: \(String(describing: try? first.outerHtml()))")
                    print("Inner Tag: \(first.tag().getNameNormal())")
                }
            }
        }

        return text
    }
    
    static func isControlTag(_ e: Element) -> Bool {
        let name = e.tagNameNormal()
        
        let controlTags = [
            "r-include",
            "r-set",
            "r-unset",
            "r-var",
            "r-value",
            "r-eval",
            "r-slot",
            "r-block",
            "r-index",
            "r-item"
        ]
        
        return controlTags.contains(name)
    }
}
