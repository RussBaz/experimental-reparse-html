import LeafKit
@testable import ReparseExample
import XCTVapor

final class ExampleTests: XCTestCase {
    func testHelloWorld() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try await configure(app)

        let pathToViews = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Views")
            .relativePath

        app.leaf.sources = LeafSources.singleSource(
            NIOLeafFiles(
                fileio: app.fileio,
                limits: .default,
                sandboxDirectory: pathToViews,
                viewDirectory: pathToViews
            )
        )

        try app.test(.GET, "hello", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
}
