//
// ------------------------------
// reparse version: 0.0.4
// ------------------------------
// This is an auto-generated file
// ------------------------------
//

import ReparseRuntime
import Vapor

enum Pages {
    enum Components {
        enum World {
            static var path: String {
                """
                /Users/russ/Projects/GitHub/ReparseHtml/Resources/Pages/Components/world.html
                """
            }

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
            static var path: String {
                """
                /Users/russ/Projects/GitHub/ReparseHtml/Resources/Pages/Components/hello-me.html
                """
            }

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
        static var path: String {
            """
            /Users/russ/Projects/GitHub/ReparseHtml/Resources/Pages/index.html
            """
        }

        static func render(req: Request, superheroes names: [String]? = nil, value: Bool? = nil) -> String {
            include(req: req, superheroes: names, value: value).render()
        }

        static func include(req: Request, superheroes names: [String]? = nil, value: Bool? = nil) -> SwiftLineStorage {
            let lines = SwiftLineStorage()
            var previousUnnamedIfTaken = false

            lines.extend(Pages.Base.include(req: req))
            lines.extend(Pages.Body.include(req: req, value: value))
            lines.append("""


            <main>
                <h1>
                    Hello

            """)
            if !(names?.isEmpty ?? true) {
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
            } else {
                previousUnnamedIfTaken = false
            }
            lines.append("""

                </h1>
                <ol>

            """)
            if let names {
                for (index, item) in names.enumerated() {
                    lines.append("""
                    <li>
                                <p>

                    """)
                    lines.include(Pages.Components.HelloMe.include(req: req)) { lines in
                        lines.append("\(item)")
                    }
                    lines.append("""

                                </p>
                                <p>
                                    Index: 
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
                }
                previousUnnamedIfTaken = if names.isEmpty { false } else { true }
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                lines.append("""
                <li>No more heroes...</li>
                """)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            lines.append("""

                </ol>

                <p>
            """)
            lines.append("\(req.url.string)")
            lines.append("""
            </p>
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
        static var path: String {
            """
            /Users/russ/Projects/GitHub/ReparseHtml/Resources/Pages/base.html
            """
        }

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
        static var path: String {
            """
            /Users/russ/Projects/GitHub/ReparseHtml/Resources/Pages/body.html
            """
        }

        static func render(req: Request, value: Bool? = nil) -> String {
            include(req: req, value: value).render()
        }

        static func include(req _: Request, value: Bool? = nil) -> SwiftLineStorage {
            let value = value ?? false
            let lines = SwiftLineStorage()
            var attributes: SwiftAttributeStorage
            var previousUnnamedIfTaken = false

            attributes = SwiftAttributeStorage.from(attributes: [:])
            if value {
                attributes.update(key: "class", with: .string("blue"), replacing: false)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
            }
            if !previousUnnamedIfTaken {
                attributes.update(key: "class", with: .string("red"), replacing: false)
                previousUnnamedIfTaken = true
            } else {
                previousUnnamedIfTaken = false
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
