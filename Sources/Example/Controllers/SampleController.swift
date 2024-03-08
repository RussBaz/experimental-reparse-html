import Vapor

struct SampleController: RouteCollection {
    struct HeroQuery: Content {
        let flag: Bool?
        let heroes: [String]?
    }

    func boot(routes: Vapor.RoutesBuilder) throws {
        let test = routes.grouped("test")

        test.get("hello", use: hello(req:))
    }

    func hello(req: Request) throws -> View {
        let queries = try req.query.decode(HeroQuery.self)
        return View(data: ByteBuffer(string: Pages.Index.render(req: req, superheroes: queries.heroes ?? [], value: queries.flag ?? false)))
    }
}
