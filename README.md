# Reparse - HTML Server Side Templating Super Powers in Swift (Experimental)

## Three Core Concepts

1. Super Powerful and Flexible Syntax
2. HTML Templating (and not a text templating)
3. Templates are Compiled into the Swift Code

## Example

Here is an example of the `Reparse` syntax as used in the bundled `Example` project (with few lines removed for brevity):

```html
<r-require name="context" type="[String]" label="superheroes" />
<r-extend name="base" />
<r-extend name="body" />

<r-eval line='req.logger.info("Index Debug Message")' />

<main>
  <h1>
    Hello
    <r-include name="components.world" r-if="!context.isEmpty">
      Ultra Heroes!
    </r-include>
    <r-block r-else> World?</r-block>
  </h1>
  <ol>
    <li r-for-every="context">
      <p>
        <r-include name="components.hello-me"><r-item /></r-include>
      </p>
      <p>Index: <r-index /> or +1 = \(index+1)</p>
    </li>
    <li r-else>No more heroes...</li>
  </ol>

  <p><r-value of="req.url.string" /></p>
</main>
<title r-add-to-slot="head">Hero List</title>
```

## How to Use

### Installation

If you would like to use it in your own project, firstly, add it to your package dependencies like this:

```swift
.package(url: "https://github.com/RussBaz/experimental-reparse-html.git", from: "0.0.15"),
```

Then add the `ReparseRuntime` as a dependency to your target like this:

```swift
.product(name: "ReparseRuntime", package: "experimental-reparse-html"),
```

### As a Standalone Tool

To use it as a standalone tool, you would need to `git clone` this repo and then compile the tool like this: `swift build -c release`. Then copy the built tool form the build folder to anywhere you want and run. Otherwise, you can just call `swift run reparse` from inside this project folder, providing valid arguments and options.

Here is the help page for the tool:

```
USAGE: reparse <location> <destination> [--file-name <file-name>] [--file-extension <file-extension>] [--enum-name <enum-name>] [--imports <imports> ...] [--parameters <parameters> ...] [--protocols <protocols> ...] [--dry-run]

ARGUMENTS:
  <location>              The target data folder location.
  <destination>           The destination folder for the output file.

OPTIONS:
  --file-name <file-name> Output file name (default: pages.swift)
  --file-extension <file-extension>
                          The file extension to be searched for (default: html)
  --enum-name <enum-name> The name of the generated enum (default: Pages)
  --imports <imports>     List of global imports
  --parameters <parameters>
                          List of shared parameters (parameters to be added to
                          every 'include' function) in a form of
                          '[?][label:]name:type[=default]' where the optional
                          parts are in square brackets. The question mark at the
                          beginning indicates that the parameter will be
                          overriden by a local requirement if it is present.
  --protocols <protocols> A list of protocols to apply to enums with render
                          functions in them in a form of
                          'name[:associatedName:associatedType]' where the
                          optional parts are in square brackets. Optional part
                          can be repeated any number of times.
  --dry-run               Write the output to the console instead of file
  -h, --help              Show help information.
```

### Command Plugin

You can also run it as a command plugin from the terminal. You only have to follow the installation instructions for it to be automatically available.

To list available plugins:

```
swift package plugin --list
```

To use an automatic Vapor settings, use:

```
swift package plugin reparse --preset vapor
```

NOTE: Every Vapor based preset adds 'req: Request' as a first parameter to the generated functions.

of if you are using `VaporHX`:

```
swift package plugin reparse --preset vaporhx
```

NOTE: If you are to use it with VaporHX, then you can only 'require' `context` variables because otherwise the genrated code will no longer conform to the `HXTemplateable` protocol, required for automatic use of generated templates.

In addition to to 'req: Request' coming from a Vapor preset, it also adds 'isPage: Bool' and 'context: Context' parameters. 'isPage' is true when the template is expected to return the whole page and it is false when a fragment of the page is expected (in-place update). Then 'Context' type is `EmptyContext` struct by default, provided by the VaporHX. However, if you specify the 'context' using a 'r-require' tag, then it will be replaced with your own type without breaking compatibility with the VaporHX.

If you do not use any preset, then all the relative routes would be pointing at the project root folder.

All the options you can pass are the same except the location and destination arguments are replaced by the following options:

`--source` to specify a different root folder other than than the project root

`--target` to pick a target from the package targets as a destination for the generated file

`--destination` as a list of path components to provide a different output folder relative to the source root folder for the target (or project root if none selected)

## Syntax

All special attributes and tags will be removed by the compilation and must not appear in the output of the render function. If they do, then it is a bug.

### String Interpolation

You can use the standard swift syntax for string interpolation `\(expression)` to insert any swift expression into a text part of the html template - inside the attribute values and the text between tags.

### Control Attributes

There are a few types of control attributes and can be separated in 3 groups:

#### Conditionals

Most html tags can be equipped with one of the conditional control attributes:

- **r-if="condition"**
- **r-else-if="condition"**
- **r-else**

If the condition (which must be a valid Swift expression) is satisfied than the html tag and its contents are rendered.

If the condition is satisfied, then a special variable called `previousUnnamedIfTaken` will be set to true. Otherwise, it will be set to false.

Optionally, you can save the result of the condition to a different variable using an additional attribute:

- **r-tag="tag-name"**

#### Loops

- **r-for-every="sequence"**

#### Slots

- **r-add-to-slot="slot-name"**
- **r-replace-slot="slot-name"**

### Control Tags

- **`<r-extend name="template-name" />`** (must be before any tag other than r-require) to wrap the current template into a default slot of the specified template
- **`<r-require label="optional-label" name="var-name" type="var-type" default="optional-default" />`** (must be before any tag other than r-extend) to define a variable that must be passed into the template from the caller
- **`<r-require label="optional-label" name="var-name" type="var-type" default="optional-default" mutable />`** or if you need to remap it to a mutable variable of the same name
- **`<r-include name="template-name" />`** to include another template or
- **`<r-include name="template-name"> default slot </r-include>`** to include a template with a default slot provided
- **`<r-block> some data </r-block>`** to group some part of template, e.g. wrap some text with it and now you can apply control attributes to it.
- **`<r-set name="attr-name" value="attr-value" />`** to replace an attribute in a preceding tag (skipping other set/unset tags) or
- **`<r-set name="attr-name" value="attr-value" append />`** to append to it instead
- **`<r-unset name="attr-name" />`** to remove an atttribute from a preceding tag (skipping other set/unset tags)
- **`<r-var name="var-name" line="expression" />`** to assign the result of an expression to a variable
- **`<r-value of="name" default="optional-val" />`** to paste the value of the specified variable or the provided default value if the value was `nil`
- **`<r-eval line="expression" />`** to paste the expression as is into the generated code
- **`<r-slot name="optional-name" />`** to mark an area to be filled by the incoming outer slot. If no name is provided, it will be known as 'default' or
- **`<r-slot name="optional-name"> default slot </r-slot>`** to declare a slot and provide the default contents if no matching slot found in the incoming outer slots
- **`<r-index />`** (inside the loops only) to paste the index of the current iteration of the innermost loop
- **`<r-value />`** (inside the loops only) to paste the value of the current iteration of the innermost loop

## How does it work?

It operates in two stages. There is the compilation stage and the runtime stage.

### Compilation Stage

1. All the templates are discovered, and their names and full paths are recorded. The names are derived from the relative path to the root folder and the name of file.
2. For each template, a tokeniser converts a stream of characters into a stream of tokens.
3. The tokens are now parsed into an abstract syntax tree.
4. The syntax tree is flattened and transpiled into a series of commands for a file builder. References between files and other meta data are recorded.
5. Function signatures are resolved for every template
6. All individual command sequences for every template are combined into a single one based and executed.
7. The final string is saved into the specified location.

### Runtime Stage

#### Rendering the Template

1. The caller passes the paremters to the render function.
2. The render function passes them to the include function of the specified template.
3. The include function returns the line storage object with a render method.
4. Then the render method is called and it will call its resolve method with empty outer slots.
5. The returned sequence of text constants is then merged into a string and returned to the caller.

#### Resolving the Template

1. Calling the template will call an auto generated function that builds a simple internal model for each template by calling a very limited number of its commands. (done when the include method is called)
2. The slots are passed into the template and the default slot is resolved. The slots passed into the template are referred as outer slots. (done when the resolve method is called)
3. All slot declaration sites (including the inside of include commands) are recuresively replaced with either contents of outer slots (if found) and mark them for deletion, or replaces with the defaults. It does nothing if neither are found. Nested declarations are allowed but if the parent 'comsumes' the slot, then it will no longer appear to the nested declarations. Sibling declarations do not have this restriction.
4. Inner slots are computed - the slots to be passed to included templates. All the commands affecting the slots are resolved.
5. Default inner slots are computed for every include command and passed into the specified templates. Nested includes are allowed.
6. Resolved inner templates are merged into the current template
7. The contents, now consisting of text constant commands only, are returned to the caller.
