///|
test "analyze empty program" {
  let lex = tokenize("")
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
}

///|
test "analyze undefined identifier" {
  let lex = tokenize("foo")
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="1")
  inspect(tyck_result.errors[0].message, content="Undefined identifier.")
}

///|
test "analyze literal expression" {
  let lex = tokenize("1")
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
}

///|
test "analyze match pattern binding" {
  let lex = tokenize("match value { Some(inner) => inner }")
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="1")
  inspect(tyck_result.errors[0].message, content="Undefined identifier.")
}

///|
test "analyze struct pattern duplicate binding" {
  let source = "match value { Point { x: inner, y: inner } => inner }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="2")
  inspect(tyck_result.errors[0].message, content="Undefined identifier.")
  inspect(tyck_result.errors[1].message, content="Duplicate binding.")
}

///|
test "analyze match arm type mismatch" {
  let source = "match value { Some(inner) => 1.0, None => 1 }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="2")
  inspect(tyck_result.errors[0].message, content="Undefined identifier.")
  inspect(
    tyck_result.errors[1].message,
    content="Mismatched match arm result types. (expected Double, found Int)",
  )
}

///|
test "analyze guard non boolean condition" {
  let source = "guard 1 else { 0 }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="1")
  inspect(tyck_result.errors[0].message, content="Expected boolean expression.")
}

///|
test "analyze guard non boolean pattern guard" {
  let source = "match value { Some(inner) if 1 => inner }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="2")
  inspect(tyck_result.errors[0].message, content="Undefined identifier.")
  inspect(tyck_result.errors[1].message, content="Expected boolean expression.")
}

///|
test "analyze struct literal type mismatch" {
  let source = "Point { x: 1, y: 2.0 }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="1")
  inspect(
    tyck_result.errors[0].message,
    content="Struct field type mismatch. (expected Int, found Double)",
  )
}

///|
test "analyze struct literal ok" {
  let source = "Point { x: 1, y: 2 }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
}

///|
