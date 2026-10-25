struct Deinitializer: Token, HasAttributes {
    var parent: Reference<any Token>?

    var attributes: [Attribute]
}
