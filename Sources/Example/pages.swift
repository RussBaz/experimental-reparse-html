//
// ------------------------------
// reparse version: 0.0.13
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
            static func render(req: Request) -> String {
                include(req: req).render()
            }

            static func include(req _: Request) -> SwiftLineStorage {
                let lines = SwiftLineStorage()
                lines.append("""
                Hello, 
                """)
                lines.declare(slot: "default") { lines in
                    lines.append("""
                    Friend!
                    """)
                }

                return lines
            }
        }

        enum World {
            // Template: ./Components/world.html
            static func render(req: Request) -> String {
                include(req: req).render()
            }

            static func include(req _: Request) -> SwiftLineStorage {
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
                </span>
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
        static func render(req: Request, superheroes context: [String], value: Bool = false) -> String {
            include(req: req, superheroes: context, value: value).render()
        }

        static func include(req: Request, superheroes context: [String], value: Bool = false) -> SwiftLineStorage {
            let lines = SwiftLineStorage()
            var attributes: SwiftAttributeStorage
            var previousUnnamedIfTaken = false

            lines.extend(Pages.Base.include(req: req))
            if context.isEmpty {
                lines.extend(Pages.Body.include(req: req, value: value))
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken, context.count < 3 {
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
            if !context.isEmpty {
                lines.include(Pages.Components.World.include(req: req)) { lines in
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
            if context.isEmpty { previousUnnamedIfTaken = false }
            for (index, item) in context.enumerated() {
                lines.append("""
                <li>

                """)
                attributes = SwiftAttributeStorage.from(attributes: ["class": .string("base", wrapper: .double)])
                attributes.append(to: "class", value: .string(" rose", wrapper: .double))
                lines.append("<p\(attributes)>")
                lines.include(Pages.Components.HelloMe.include(req: req)) { lines in
                    lines.append("\(item)")
                }
                lines.append("""

                            </p>
                            <p>Index: 
                """)
                lines.append("\(index)")
                lines.append("""
                 or +1 = \(index + 1)</p>
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
            if context.isEmpty {
                lines.append("""
                empty
                """)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                lines.append("\(context.count)")
            }
            lines.append("""

                </p>

            """)
            attributes = SwiftAttributeStorage.from(attributes: ["class": .string("button", wrapper: .double), "hx-post": .string("/auth/logout?next=/", wrapper: .double), "hx-target": .string("body", wrapper: .double), "hx-vals": .string("{\"key\": \"\(key)\"}", wrapper: .single), "on-click": .string("console.log('?')", wrapper: .double), "onfocus": .string("console.log('?'); console.log('This is drastic?');         console.log('too many');", wrapper: .double), "data-loading-delay": .flag, "data-loading-disable": .flag])
            if !context.isEmpty {
                attributes.replace(key: "disabled", with: .flag)
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
