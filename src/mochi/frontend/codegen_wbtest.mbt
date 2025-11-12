///|
test "codegen llvm literal expr" {
  let source = "42"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
  let result = codegen(parse_result.declarations, emit_format_llvm())
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.code.contains("ret i32 42").to_string(), content="true")
}

///|
test "codegen asm literal expr" {
  let source = "42"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
  let result = codegen(parse_result.declarations, emit_format_asm())
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.code.contains("li a0, 42").to_string(), content="true")
}

///|
test "codegen llvm non literal fallback" {
  let source = "foo"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="1")
  let result = codegen(parse_result.declarations, emit_format_llvm())
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.code.contains("ret i32 0").to_string(), content="true")
}

///|
test "codegen llvm function return" {
  let source = "fn main { return 1; }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
  let result = codegen(parse_result.declarations, emit_format_llvm())
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.code.contains("ret i32 1").to_string(), content="true")
}

///|
test "codegen asm function return default" {
  let source = "fn main { return; }"
  let lex = tokenize(source)
  let parse_result = parse(lex.tokens)
  inspect(parse_result.errors.length().to_string(), content="0")
  let tyck_result = analyze(parse_result.declarations)
  inspect(tyck_result.errors.length().to_string(), content="0")
  let result = codegen(parse_result.declarations, emit_format_asm())
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.code.contains("li a0, 0").to_string(), content="true")
}
