// main.swift

import Foundation

enum Constants {
    
    static let blogLink = "https://glassgow.tistory.com/rss"
    static let blogTitle = "## Tech Blog Posts"
    static let maxPostCount = 6
    static let readmeFileName = "README.md"
    
}

struct Post {

    let title: String
    let link: String

    init?(title: String?, link: String?) {
        guard let title, let link else { return nil }
        self.title = title
        self.link = link
    }

    func makeMarkdownContent() -> String {
        return "[\(title)](\(link))"
    }

}

final class TistoryUpdater {

    private enum Regex {
        static let item = "<item>\\s*(.*?)\\s*</item>"
        static let title = "<title>(.*?)</title>"
        static let link = "<link>(.*?)</link>"
    }

    func load(url urlString: String, completion: (([String]) -> Void)? = nil) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
            guard let data, let content = String(data: data, encoding: .utf8) else { return }
            let contents = self.makeMarkdownContents(content: content.replacingOccurrences(of: "\n", with: " "))
            completion?(contents)
        }.resume()
    }

    func makeMarkdownContents(content: String) -> [String] {
        return generateItems(content: content)
            .compactMap { Post(title: generateTitle(content: $0), link: generateLink(content: $0)) }
            .prefix(Constants.maxPostCount)
            .map { $0.makeMarkdownContent() }
    }

    func generateItems(content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: Regex.item) else { return [] }
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
        return matches
            .compactMap { Range($0.range(at: 1), in: content) }
            .map { String(content[$0]) }
    }

    private func generateTitle(content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: Regex.title, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.count)),
              let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        let title = String(content[range])
        return title
    }

    private func generateLink(content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: Regex.link, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.count)),
              let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        let link = String(content[range])
        return link
    }

}

let parser = TistoryUpdater()
parser.load(url: Constants.blogLink) { contents in
    let readmePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appending(component: Constants.readmeFileName)

    let data = try! Data(contentsOf: readmePath)
    let content = {
        let content = String(data: data, encoding: .utf8)!
        if content.contains(Constants.blogTitle) {
            return content
                .components(separatedBy: Constants.blogTitle)
                .dropLast()
                .joined()
        }
        return content
    }()
    
    
    let postContent = contents.map { "* \($0)" }
        .joined(separator: "\n")
    
    let newContent = content + Constants.blogTitle + "\n" + postContent
    let newData = newContent.data(using: .utf8)!
    try! FileManager.default.removeItem(at: readmePath)
    FileManager.default.createFile(atPath: readmePath.path, contents: newData)
}

sleep(5)
