# The Cuckoofile

Tell the generator which files to read, which types to mock and what to import, in `Cuckoofile.toml`.

## Overview

`Cuckoofile.toml` sits at the root of the package or Xcode project, where the build plugin looks for it. It holds
one table per module of mocks, `[modules.<Name>]`, and an optional top-level `output`:

```toml
# The file a module without its own `output` writes to. The build plugin picks the output itself.
output = "Tests/Generated/GeneratedMocks.swift"

[modules.App]
imports = ["Foundation"]
testableImports = ["App"]
sources = ["Sources/App/**/*.swift"]
exclude = ["AppDelegate"]

[modules.App.options]
keepDocumentation = false
defaultIsolation = "MainActor"
```

A key Cuckoo doesn't read, such as a misspelled `testableImport` or an option outside the `options` table, is a
build warning that names the keys Cuckoo knows there.

The name of a module matters with the build plugin. `CuckooPlugin` generates one file per dependency of the test
target, from the entry with that dependency's name, plus one from the entry named after the test target. A
dependency without an entry gets an empty file, and an entry named after neither isn't generated for that target. A
target that gets no entry at all is a build warning. To mock files from several modules in one entry, name it after
the test target and list its `sources`. (The plugin works the same on a regular target, such as a module of mocks
that several test targets share.)

A dependency is a library or executable target the test target depends on directly, or a target of a package product
it depends on: the dependencies of those dependencies aren't mocked unless an entry lists their `sources`. Xcode
tells the plugin about a test target's package products, but not about the targets of its own project. So in an
Xcode project, name the entry after the test target and list its `sources`, as in Cuckoo 2; a test target that uses
the plugin with no entry of its own fails with a message saying so.

### Sources

- term `sources`: The files to read, relative to the Cuckoofile. `*` matches within a folder, `**` matches any
  number of folders except hidden ones such as `.build`, and `{A,B}` matches either name. A pattern that matches
  no file is a warning:

  ```toml
  [modules.App]
  sources = ["Sources/App/**/*.swift", "Sources/Shared/{Clock,Store}.swift"]
  ```

  Or a table of them by the Swift module the files belong to. The mocks then refer to each type by its module,
  so a type that another import also declares, such as SwiftUI's `Namespace`, isn't ambiguous in them:

  ```toml
  [modules.AppAndCore]
  sources = { App = ["Sources/App/**/*.swift"], Core = ["Sources/Core/**/*.swift"] }
  ```

  In a package, the build plugin lets you leave `sources` out to mock the files of the test target's dependency
  that has the entry's name, or of every dependency if none has it. The plugin lists the target's own files, so
  this follows the target's membership, and tells the generator which module the files belong to, as the table
  form does. An Xcode project's entries list their `sources`. An entry that sets `sources` is regenerated when any
  source file of the package or Xcode project changes, since its patterns may match any of them.
- term `exclude`: Names of types not to mock, such as `["AppDelegate", "LegacyService"]`.
- term `regex`: Mock only the protocols and classes whose name matches one of these regular expressions:
  `regex = ["Service$", "^Repository"]`. A single pattern needs no array: `regex = "Service$"`.
- term `globalActors`: Global actors declared in other modules, such as `["DatabaseActor"]`. The generator
  knows `MainActor` and the global actors declared in `sources`; a type marked with another one, `@DatabaseActor`,
  gets a mock that isn't isolated to it, with a warning, unless it's listed here.

Cuckoo 2's `xcodeproj` table, which read a target's files from the project, is gone. A Cuckoofile that still has
one fails with a message that says which `sources` to write instead. Replace it with globs that cover the
target's folders:

```toml
# Cuckoo 2
[modules.MyApp]
output = "MyAppTests/GeneratedMocks.swift"
testableImports = ["MyApp"]

[modules.MyApp.xcodeproj]
target = "MyApp"
```

```toml
# Cuckoo 3
[modules.MyApp]
output = "MyAppTests/GeneratedMocks.swift"
testableImports = ["MyApp"]
sources = ["MyApp/**/*.swift", "Shared/**/*.swift"]
```

This is the form for running the generator yourself. With the build plugin in an Xcode project, which only
generates the entry named after the test target, name it `[modules.MyAppTests]`; the plugin writes the file
itself, so it needs no `output`:

```toml
# Cuckoo 3, with the build plugin in an Xcode project
[modules.MyAppTests]
testableImports = ["MyApp"]
sources = ["MyApp/**/*.swift", "Shared/**/*.swift"]
```

Globs select files by folder, not by target membership. If a folder also holds files the target doesn't compile,
narrow the glob or list those types in `exclude`. In a package, the build plugin can leave `sources` out instead,
to mock the files of the target.

### Imports

- term `imports`: Modules the generated file imports, such as `["Foundation"]`.
- term `publicImports`: Modules imported with `public import`, for mocks whose public API uses their types.
  Imports are internal by default in Swift 6.
- term `testableImports`: Modules imported with `@testable import`, which mocks of internal types need. If the
  mocked declarations use `@_spi(Group)`, these imports get the same groups, since a testable import doesn't make
  SPI visible.

The generated file always imports `Cuckoo`.

### Output

- term `output`: Where to write the module's mocks. A path with a file extension is one file; modules with the
  same `output` are joined into it. An existing directory, or a path with no extension, gets one file per source
  file, named after it; source files that share a name get their parent directories in front, such as `A_User`
  and `B_User` for `A/User.swift` and `B/User.swift`. The build plugin replaces `output` with a file in the build
  directory.
- term `filenameFormat`: For a directory `output`, the name of each file, with `{}` where the source file's name
  goes, such as `"{}Mocks"`. It must contain `{}`.

A mock also overrides the members its type inherits from the other protocols and classes in `sources`. A parent is
found as Swift finds it: in the type's own scope and the enclosing ones, written qualified or through a typealias in
`sources`. A parent found nowhere in `sources`, such as Swift's `Error`, or one named through a typealias declared
in another module, is declared outside them: the mock implements only the requirements that have default
implementations, and says so in a comment.

### Options

The `[modules.<Name>.options]` table:

- term `glob`: Whether `sources` are globs, `true` by default. Set it to `false` to read the paths as they are.
- term `keepDocumentation`: Whether mocks keep the mocked declarations' doc comments, `true` by default. Other
  comments are always left out.
- term `protocolsOnly`: Mock protocols only, not classes. `false` by default.
- term `omitHeaders`: Leave out the comment at the top of each source file's mocks, which names the file. `false`
  by default.
- term `mockPrefix`, `mockSuffix`: Mocks are named `<mockPrefix><Type><mockSuffix>`, `MockGreeter` by default
  (`"Mock"` and `""`). Each may hold letters, digits and underscores; they can't both be empty, and the prefix
  can't start with a digit. `mockSuffix = "Stub"` with no prefix is refused, because the generated
  `<Type>Stub` classes already have those names.
- term `defaultIsolation`: The module's default actor isolation, `"MainActor"` or `"nonisolated"` (the default).
  The generator can't read build settings, so set this when the module builds with
  `.defaultIsolation(MainActor.self)` in SwiftPM, or Xcode's Default Actor Isolation setting: the mocks of types
  that state no isolation are then `@MainActor`, as the types are.

### Running the generator yourself

The build plugin is the way to run the generator. To run it from the command line, as a pre-build script or
to look at what it writes, build `CuckooGenerator` from a clone of the repository and pass the Cuckoofile:

```sh
swift run --package-path path/to/Cuckoo CuckooGenerator --configuration Cuckoofile.toml --verbose
```

`CuckooGenerator` is an executable target, not a product, so it runs from a clone of a branch, such as `master`;
a release's own manifest declares no generator target, so for a release run the generator inside its
`CuckooGenerator.artifactbundle.zip`.

Outside the plugin nothing passes the generator a target's files, so each module needs its own `sources`, and an
`output`, its own or the top-level one, to write to. `--verbose` prints each module's settings as the generator reads
them.
