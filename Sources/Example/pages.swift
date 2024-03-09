//
// ------------------------------
// reparse version: 0.0.8
// ------------------------------
// This is an auto-generated file
// ------------------------------
//

import ReparseRuntime
import Vapor

enum Pages {
    enum Components {
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
            lines.extend(Pages.Body.include(req: req, value: value))
            lines.append("""


            <main>
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
                previousUnnamedIfTaken = true
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
                 or +1 = 
                """)
                lines.append("\(index + 1)")
                lines.append("""
                </p>
                    </li>
                """)
                previousUnnamedIfTaken = true
            }
            if !previousUnnamedIfTaken {
                lines.append("""
                <li>No more heroes...</li>
                """)
                previousUnnamedIfTaken = true
            }
            lines.append("""

              </ol>

              <p>
            """)
            lines.append("\(req.url.string)")
            lines.append("""
            </p>
              <button hx-target="body" hx-post="/auth/logout?next=/" data-loading-delay data-loading-disable class="button">
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
                previousUnnamedIfTaken = true
            }
            lines.append("<body\(attributes)>")
            lines.declare(slot: "default")
            lines.append("""

            </body>
            """)

            return lines
        }
    }
}
