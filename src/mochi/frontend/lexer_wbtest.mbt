///|
test "tokenize match snippet" {
  let lex = tokenize("match value { Point { x: inner } => inner }")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  let summary = kinds.join(",")
  inspect(
    summary,
    content="KeywordMatch,Ident,LBrace,Ident,LBrace,Ident,Colon,Ident,RBrace,Arrow,Ident,RBrace,EndOfFile",
  )
}

///|
test "tokenize switch snippet" {
  let lex = tokenize(
    "switch value { case Point { x: inner } => inner default => fallback }",
  )
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  let summary = kinds.join(",")
  inspect(
    summary,
    content="KeywordSwitch,Ident,LBrace,KeywordCase,Ident,LBrace,Ident,Colon,Ident,RBrace,Arrow,Ident,KeywordDefault,Arrow,Ident,RBrace,EndOfFile",
  )
}

///|
test "tokenize char literals" {
  let lex = tokenize("'a' '\\n' '\\u{1F600}'")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  let summary = kinds.join(",")
  inspect(summary, content="LiteralChar,LiteralChar,LiteralChar,EndOfFile")
}

///|
test "tokenize invalid char" {
  let lex = tokenize("'ab'")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Unterminated char literal.")
}

///|
test "tokenize empty char" {
  let lex = tokenize("''")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Char literal cannot be empty.")
}

///|
test "tokenize unicode char out of range" {
  let lex = tokenize("'\\u{110000}'")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Unicode escape out of range.")
}

///|
test "tokenize char surrogate" {
  let lex = tokenize("'\\u{D800}'")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(
    lex.errors[0].message,
    content="Unicode escape must not specify surrogate code point.",
  )
}

///|
test "tokenize string escape" {
  let lex = tokenize("\"hello\\n\\u{41}\"")
  inspect(lex.errors.length().to_string(), content="0")
  inspect(lex.tokens.length().to_string(), content="2")
  inspect(token_kind_name(lex.tokens[0].kind), content="LiteralString")
}

///|
test "tokenize invalid string escape" {
  let lex = tokenize("\"\\q\"")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Invalid escape sequence.")
}

///|
test "tokenize string newline" {
  let lex = tokenize("\"foo\nbar\"")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(
    lex.errors[0].message,
    content="String literal cannot contain newline.",
  )
}

///|
test "tokenize string carriage return" {
  let lex = tokenize("\"foo\r\nbar\"")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(
    lex.errors[0].message,
    content="String literal cannot contain newline.",
  )
}

///|
test "tokenize string surrogate" {
  let lex = tokenize("\"\\u{D834}\"")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(
    lex.errors[0].message,
    content="Unicode escape must not specify surrogate code point.",
  )
}

///|
test "tokenize comment with newline" {
  let source = "match // comment\nvalue"
  let lex = tokenize(source)
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  inspect(kinds.join(","), content="KeywordMatch,Ident,EndOfFile")
}

///|
test "tokenize numeric bases" {
  let lex = tokenize("0x1f 0b1010 0o77 123_456")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  let lexemes : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
    lexemes.push(token.lexeme)
  }
  inspect(
    kinds.join(","),
    content="LiteralInt,LiteralInt,LiteralInt,LiteralInt,EndOfFile",
  )
  inspect(lexemes.join(" "), content="0x1f 0b1010 0o77 123_456 ")
}

///|
test "tokenize invalid numeric underscore" {
  let lex = tokenize("123__456")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(
    lex.errors[0].message,
    content="Invalid underscore placement in number.",
  )
}

///|
test "tokenize floats" {
  let lex = tokenize("1.23e-4 10.0 0.5e+2")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  inspect(
    kinds.join(","),
    content="LiteralFloat,LiteralFloat,LiteralFloat,EndOfFile",
  )
}

///|
test "tokenize invalid float exponent" {
  let lex = tokenize("1.23e")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Invalid exponent in float literal.")
}

///|
test "tokenize invalid float fraction" {
  let lex = tokenize("1.")
  inspect(lex.errors.length().to_string(), content="1")
  inspect(lex.errors[0].message, content="Invalid float literal.")
}

///|
test "tokenize unexpected equals" {
  let lex = tokenize("=")
  inspect(lex.errors.length().to_string(), content="0")
  inspect(token_kind_name(lex.tokens[0].kind), content="Assign")
}

///|
test "tokenize boolean literals" {
  let lex = tokenize("true false")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  inspect(kinds.join(","), content="LiteralBool,LiteralBool,EndOfFile")
}

///|
test "tokenize pattern punctuation" {
  let lex = tokenize("Point(x, _) | Some(y)")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  inspect(
    kinds.join(","),
    content="Ident,LParen,Ident,Comma,Underscore,RParen,Pipe,Ident,LParen,Ident,RParen,EndOfFile",
  )
}

///|
test "tokenize qualified pattern" {
  let lex = tokenize("Module::Variant if check")
  inspect(lex.errors.length().to_string(), content="0")
  let kinds : Array[String] = Array::new()
  for token in lex.tokens {
    kinds.push(token_kind_name(token.kind))
  }
  inspect(
    kinds.join(","),
    content="Ident,DoubleColon,Ident,KeywordIf,Ident,EndOfFile",
  )
}

///|
fn token_kind_name(kind : TokenKind) -> String {
  match kind {
    TokenKind::Ident => "Ident"
    TokenKind::KeywordGuard => "KeywordGuard"
    TokenKind::KeywordElse => "KeywordElse"
    TokenKind::KeywordIs => "KeywordIs"
    TokenKind::KeywordIf => "KeywordIf"
    TokenKind::KeywordMatch => "KeywordMatch"
    TokenKind::KeywordSwitch => "KeywordSwitch"
    TokenKind::KeywordCase => "KeywordCase"
    TokenKind::KeywordDefault => "KeywordDefault"
    TokenKind::KeywordLet => "KeywordLet"
    TokenKind::KeywordMut => "KeywordMut"
    TokenKind::KeywordFn => "KeywordFn"
    TokenKind::KeywordReturn => "KeywordReturn"
    TokenKind::KeywordWhile => "KeywordWhile"
    TokenKind::KeywordStruct => "KeywordStruct"
    TokenKind::KeywordEnum => "KeywordEnum"
    TokenKind::LiteralBool => "LiteralBool"
    TokenKind::LiteralInt => "LiteralInt"
    TokenKind::LiteralString => "LiteralString"
    TokenKind::LiteralChar => "LiteralChar"
    TokenKind::LiteralFloat => "LiteralFloat"
    TokenKind::LBrace => "LBrace"
    TokenKind::RBrace => "RBrace"
    TokenKind::LParen => "LParen"
    TokenKind::RParen => "RParen"
    TokenKind::Comma => "Comma"
    TokenKind::Colon => "Colon"
    TokenKind::Semicolon => "Semicolon"
    TokenKind::Arrow => "Arrow"
    TokenKind::ThinArrow => "ThinArrow"
    TokenKind::DoubleColon => "DoubleColon"
    TokenKind::Pipe => "Pipe"
    TokenKind::PipePipe => "PipePipe"
    TokenKind::AmpAmp => "AmpAmp"
    TokenKind::Assign => "Assign"
    TokenKind::EqualEqual => "EqualEqual"
    TokenKind::Bang => "Bang"
    TokenKind::BangEqual => "BangEqual"
    TokenKind::Greater => "Greater"
    TokenKind::GreaterEqual => "GreaterEqual"
    TokenKind::Less => "Less"
    TokenKind::LessEqual => "LessEqual"
    TokenKind::Plus => "Plus"
    TokenKind::Minus => "Minus"
    TokenKind::Star => "Star"
    TokenKind::Slash => "Slash"
    TokenKind::Percent => "Percent"
    TokenKind::Dot => "Dot"
    TokenKind::LBracket => "LBracket"
    TokenKind::RBracket => "RBracket"
    TokenKind::Underscore => "Underscore"
    TokenKind::EndOfFile => "EndOfFile"
  }
}
