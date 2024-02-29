import Vapor

struct SampleController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let test = routes.grouped("test")

        test.get("hello", use: hello(req:))
    }

    func hello(req: Request) -> View {
        View(data: ByteBuffer(string: Pages.Index.render(req: req)))
    }
}
