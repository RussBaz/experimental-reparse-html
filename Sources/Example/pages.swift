//
// ------------------------------
// reparse version: 0.0.18
// ------------------------------
// This is an auto-generated file
// ------------------------------
//

import ReparseRuntime
import Vapor

enum Pages {
    // Nested pages
    enum Components {
        // Nested pages
        enum Special {
            // Own pages
            enum Hi {
                // Template: ./Components/Special/hi.html
                static func render(req: Request) -> String {
                    include(req: req).render()
                }

                static func include(req _: Request) -> SwiftLineStorage {
                    let lines = SwiftLineStorage()
                    lines.append("""
                    <span>Hi!</span>
                    """)

                    return lines
                }
            }
        }

        // Own pages
        enum HelloMe {
            // Template: ./Components/hello-me.html
            static func render(req: Request, name: String = "no-name") -> String {
                include(req: req, name: name).render()
            }

            static func include(req _: Request, name: String = "no-name") -> SwiftLineStorage {
                let lines = SwiftLineStorage()
                lines.append("""


                Hello, 
                """)
                lines.declare(slot: "default") { lines in
                    lines.append("""
                    Friend!
                    """)
                }
                lines.append("""
                 [extra name: \(name)]
                """)

                return lines
            }
        }

        enum World {
            // Template: ./Components/world.html
            static func render(req: Request, superheroes context: ExampleProtocol) -> String {
                include(req: req, superheroes: context).render()
            }

            static func include(req _: Request, superheroes context: ExampleProtocol) -> SwiftLineStorage {
                let lines = SwiftLineStorage()
                lines.append("""


                <span>
                """)
                lines.declare(slot: "default") { lines in
                    lines.append("""
                    Heroes!
                    """)
                }
                lines.append("""
                 [context: \(context.example)]</span>
                """)

                return lines
            }
        }
    }

    enum Layouts {
        // Own pages
        enum Shared {
            // Template: ./Layouts/shared.html
            static func render(req: Request) -> String {
                include(req: req).render()
            }

            static func include(req _: Request) -> SwiftLineStorage {
                let lines = SwiftLineStorage()
                lines.declare(slot: "default")

                return lines
            }
        }
    }

    // Own pages
    enum Base {
        // Template: ./base.html
        static func render(req: Request) -> String {
            include(req: req).render()
        }

        static func include(req _: Request) -> SwiftLineStorage {
            let lines = SwiftLineStorage()
            lines.append("""
            <!DOCTYPE html>
            <html lang="en">
                <head>
                    <meta charset="utf-8"/>

            """)
            lines.declare(slot: "head")
            lines.append("""

                </head>


            """)
            lines.declare(slot: "default")
            lines.append("""

            </html>
            """)

            return lines
        }
    }

    enum Body {
        // Template: ./body.html
        static func render(req: Request, value: Bool = false) -> String {
            include(req: req, value: value).render()
        }

        static func include(req _: Request, value: Bool = false) -> SwiftLineStorage {
            let lines = SwiftLineStorage()
            var attributes: SwiftAttributeStorage
            var previousUnnamedIfTaken = false

            attributes = SwiftAttributeStorage.from(attributes: [:])
            if value {
                attributes.append(to: "class", value: .string("blue", wrapper: .double))
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                attributes.append(to: "class", value: .string("red", wrapper: .double))
            }
            lines.append("<body\(attributes)>")
            lines.declare(slot: "default")
            lines.append("""

            </body>
            """)

            return lines
        }
    }

    enum Index {
        // Template: ./index.html
        static func render(req: Request, superheroes context: SampleController.HeroContext, value: Bool = false) -> String {
            include(req: req, superheroes: context, value: value).render()
        }

        static func include(req: Request, superheroes context: SampleController.HeroContext, value: Bool = false) -> SwiftLineStorage {
            let lines = SwiftLineStorage()
            var attributes: SwiftAttributeStorage
            var previousUnnamedIfTaken = false

            lines.extend(Pages.Base.include(req: req))
            if context.heroes.isEmpty {
                lines.extend(Pages.Body.include(req: req, value: value))
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken, context.heroes.count < 3 {
                print("debug 0")
                print("debug 1")
                previousUnnamedIfTaken = true
            }
            if !previousUnnamedIfTaken {
                print("debug 2")
            }
            let key = "1984"
            lines.append("""


            <main>

            """)
            req.logger.info("Index Debug Message")
            lines.append("""

                <h1>
                    Hello

            """)
            if !context.heroes.isEmpty {
                lines.include(Pages.Components.World.include(req: req, superheroes: context)) { lines in
                    lines.append("""

                                Ultra Heroes!

                    """)
                }
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                lines.append("""
                 World?
                """)
            }
            if !previousUnnamedIfTaken {
                lines.append("""
                <span>_!_</span>
                """)
            }
            lines.append("""

                </h1>
                <ol>

            """)
            if context.heroes.isEmpty { previousUnnamedIfTaken = false }
            for (index, hero) in context.heroes.enumerated() {
                lines.append("""
                <li>

                """)
                attributes = SwiftAttributeStorage.from(attributes: ["class": .string("base", wrapper: .double)])
                attributes.append(to: "class", value: .string(" rose", wrapper: .double))
                lines.append("<p\(attributes)>")
                lines.include(Pages.Components.HelloMe.include(req: req, name: "very sad")) { lines in
                    lines.append("""
                    \(hero)
                    """)
                }
                lines.append("""

                            </p>
                            <p>Index: \(index)</p>
                        </li>
                """)
                previousUnnamedIfTaken = true
            }
            if !previousUnnamedIfTaken {
                lines.append("""
                <li>No more heroes...</li>
                """)
            }
            lines.append("""

                </ol>

                <p>

            """)
            lines.append("\(req.url.string)")
            if context.heroes.isEmpty {
                lines.append("""
                empty
                """)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                lines.append("\(context.heroes.count)")
            }
            lines.append("""

                </p>

            """)
            attributes = SwiftAttributeStorage.from(attributes: ["class": .string("button", wrapper: .double), "disabled": .string("""
            \(context.heroes.count < 6 ? "true" : "false")
            """, wrapper: .single), "hx-post": .string("/auth/logout?next=/", wrapper: .double), "hx-target": .string("body", wrapper: .double), "hx-vals": .string("""
            {"key": "\(key)"}
            """, wrapper: .single), "onclick": .string("console.log('?')", wrapper: .double), "onfocus": .string("console.log('?'); console.log('This is drastic?');         console.log('too many');", wrapper: .double), "data-loading-delay": .flag, "data-loading-disable": .flag])
            if !context.heroes.isEmpty {
                attributes.replace(key: "requried", with: .flag)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            lines.append("<button\(attributes)>")
            lines.append("""

                    What's up?
                </button>
            </main>
            """)
            lines.add(slot: "head") { lines in
                lines.append("""
                <title>Hero List</title>
                """)
            }

            return lines
        }
    }
}
