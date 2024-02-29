import Vapor

func routes(_ app: Application) throws {
    app.get("hello") { req async throws in
        try await req.view.render("index")
    }

    try app.register(collection: SampleController())
}
