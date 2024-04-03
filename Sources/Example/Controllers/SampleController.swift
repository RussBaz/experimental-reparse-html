import Vapor

protocol ExampleProtocol {
    var example: Bool { get }
}

struct SampleController: RouteCollection {
    struct HeroQuery: Content {
        let flag: Bool?
        let heroes: [String]?
    }

    struct HeroContext: ExampleProtocol {
        let flag: Bool
        let heroes: [String]
        let example: Bool
    }

    func boot(routes: Vapor.RoutesBuilder) throws {
        let test = routes.grouped("test")

        test.get("hello", use: hello(req:))
    }

    func hello(req: Request) throws -> View {
        let queries = try req.query.decode(HeroQuery.self)

        return View(data: ByteBuffer(string: Pages.Index.render(req: req, superheroes: .init(from: queries, isExample: true), value: queries.flag ?? false)))
    }
}

extension SampleController.HeroContext {
    init(from query: SampleController.HeroQuery, isExample: Bool) {
        flag = query.flag ?? false
        heroes = query.heroes ?? []
        example = isExample
    }
}
