# Reparse - HTML Server Side Templating Super Powers in Swift (Experimental)

NOTE: The master branch is way ahead of the latest release as it includes many fixes and additional features. Please use it while I am preparing for the next release.

## Three Core Concepts

1. Super Powerful and Flexible Syntax
2. HTML Templating (and not a text templating)
3. Templates are Compiled into the Swift Code

## How to Use

If you would like to use it in your own project, you would need to add the `ReparseRuntime` as a dependency to your project.

Here is the help for the tool when it is run on it own:

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
                          List of shared parameters (parameters to be added to every 'include' function) in a form of '[?][label:]name:type[=default]' where the optional parts are in square brackets. The question mark at the beginning indicates
                          that the parameter will be overriden by a local requirement if it is present.
  --protocols <protocols> A list of protocols to apply to enums with render functions in them in a form of 'name[:associatedName:associatedType]' where the optional parts are in square brackets. Optional part can be repeated any number of times.
  --dry-run               Write the output to the console instead of file
  -h, --help              Show help information.
```

## Syntax

All special attributes and tags will be removed by the compilation and must not appear in the output of the render function. If they do, then it is a bug.

### Control Attributes

There are a few types of control attributes and can be separated in 3 groups:

#### Conditionals

Most html tags can be equipped with one of the conditional control attributes:

-   **r-if="condition"**
-   **r-else-if="condition"**
-   **r-else**

If the condition (which must be a valid Swift expression) is satisfied than the html tag and its contents are rendered.

If the condition is satisfied, then a special variable called `previousUnnamedIfTaken` will be set to true. Otherwise, it will be set to false.

Optionally, you can save the result of the condition to a different variable using an additional attribute:

-   **r-tag="tag-name"**

#### Loops

-   **r-for-every="sequence"**

#### Slots

-   **r-add-to-slot="slot-name"**
-   **r-replace-slot="slot-name"**

### Control Tags

-   **`<r-extend name="template-name" />`** (must be before any tag other than r-require) to wrap the current template into a default slot of the specified template
-   **`<r-require label="optional-label" name="var-name" type="var-type" default="optional-default" />`** (must be before any tag other than r-extend) to define a variable that must be passed into the template from the caller
-   **`<r-include name="template-name" />`** to include another template or
-   **`<r-include name="template-name"> default slot </r-include>`** to include a template with a default slot provided
-   **`<r-block> some data </r-block>`** to group some part of template, e.g. wrap some text with it and now you can apply control attributes to it.
-   **`<r-set name="attr-name" value="attr-value" />`** to replace an attribute in a preceding tag (skipping other set/unset tags) or
-   **`<r-set name="attr-name" value="attr-value" append />`** to append to it instead
-   **`<r-unset name="attr-name" />`** to remove an atttribute from a preceding tag (skipping other set/unset tags)
-   **`<r-var name="var-name" line="expression" />`** to assign the result of an expression to a variable
-   **`<r-value of="name" default="optional-val" />`** to paste the value of the specified variable or the provided default value if the value was `nil`
-   **`<r-eval line="expression" />`** evaluate the expression and paste its result
-   **`<r-slot name="optional-name" />`** to mark an area to be filled by the incoming outer slot. If no name is provided, it will be known as 'default' or
-   **`<r-slot name="optional-name"> default slot </r-slot>`** to declare a slot and provide the default contents if no matching slot found in the incoming outer slots
-   **`<r-index />`** (inside the loops only) to paste the index of the current iteration of the innermost loop
-   **`<r-value />`** (inside the loops only) to paste the value of the current iteration of the innermost loop

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
