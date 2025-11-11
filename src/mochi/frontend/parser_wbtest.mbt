///|
fn pattern_lexeme(pattern : Pattern) -> String {
  match pattern.kind {
    PatternKind::Struct(pattern_struct) => pattern_struct.name.lexeme
    PatternKind::Ident(token) => token.lexeme
    PatternKind::Wildcard(token) => token.lexeme
    PatternKind::Literal(token) => token.lexeme
    PatternKind::Tuple(tuple_pattern) =>
      match tuple_pattern.name {
        Some(token) => token.lexeme
        None => "(tuple)"
      }
    PatternKind::Or(_) => "<or>"
    PatternKind::EnumVariant(variant) => variant.name.lexeme
  }
}

///|
test "parse empty source" {
  let lex = tokenize("")
  let result = parse(lex.tokens)
  inspect(result.declarations.length().to_string(), content="0")
  inspect(result.errors.length().to_string(), content="0")
}

///|
test "guard with else clause" {
  let lex = tokenize("guard value else { fallback }")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) => {
      match guard_stmt.condition.kind {
        ExprKind::Ident(token) => inspect(token.lexeme, content="value")
        _ => inspect("unexpected", content="value")
      }
      match guard_stmt.pattern {
        Some(_) => inspect("pattern", content="None")
        None => inspect("None", content="None")
      }
      match guard_stmt.else_clause {
        Some(clause) =>
          match clause.body {
            Some(expr) =>
              match expr.kind {
                ExprKind::Ident(token) =>
                  inspect(token.lexeme, content="fallback")
                ExprKind::Literal(token) =>
                  inspect(token.lexeme, content="fallback")
                _ => inspect("unexpected", content="fallback")
              }
            None => inspect("missing", content="fallback")
          }
        None => inspect("missing", content="present")
      }
    }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard without else" {
  let lex = tokenize("guard ready")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.else_clause {
        Some(_) => inspect("unexpected", content="None")
        None => inspect("None", content="None")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard with is pattern" {
  let lex = tokenize("guard option is SomeValue else { fallback }")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::Ident(token) =>
              inspect(token.lexeme, content="SomeValue")
            _ => inspect("unexpected", content="SomeValue")
          }
        None => inspect("missing", content="SomeValue")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard struct pattern" {
  let source = "guard point is Point { x: value }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::Struct(struct_pattern) => {
              inspect(
                struct_pattern.qualifier.length().to_string(),
                content="0",
              )
              inspect(struct_pattern.name.lexeme, content="Point")
              inspect(struct_pattern.fields.length().to_string(), content="1")
              let field = struct_pattern.fields[0]
              inspect(field.name.lexeme, content="x")
            }
            _ => inspect("unexpected", content="struct")
          }
        None => inspect("missing", content="Point")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard constructor pattern" {
  let source = "guard option is Some(inner)"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::EnumVariant(enum_pattern) => {
              inspect(enum_pattern.qualifier.length().to_string(), content="0")
              inspect(enum_pattern.name.lexeme, content="Some")
              inspect(enum_pattern.arguments.length().to_string(), content="1")
            }
            _ => inspect("unexpected", content="variant")
          }
        None => inspect("missing", content="Some")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard wildcard pattern" {
  let lex = tokenize("guard value is _")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::Wildcard(token) => inspect(token.lexeme, content="_")
            _ => inspect("unexpected", content="_")
          }
        None => inspect("missing", content="_")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard literal pattern" {
  let lex = tokenize("guard number is 42 else { fallback }")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::Literal(token) => inspect(token.lexeme, content="42")
            _ => inspect("unexpected", content="42")
          }
        None => inspect("missing", content="42")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "match struct pattern" {
  let source = "match value { Point { x: inner } => inner }"
  let lex = tokenize(source)
  inspect(lex.errors.length().to_string(), content="0")
  inspect(lex.tokens.length().to_string(), content="13")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) => {
          inspect(match_expr.arms.length().to_string(), content="1")
          inspect(pattern_lexeme(match_expr.arms[0].pattern), content="Point")
          let arm = match_expr.arms[0]
          match arm.pattern.kind {
            PatternKind::Struct(pattern) => {
              inspect(pattern.qualifier.length().to_string(), content="0")
              inspect(pattern.fields.length().to_string(), content="1")
              let field = pattern.fields[0]
              inspect(field.name.lexeme, content="x")
            }
            _ => inspect("unexpected", content="struct")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match tuple pattern" {
  let source = "match pair { (left, right) => left }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::Tuple(tuple_pattern) => {
              match tuple_pattern.name {
                Some(_) => inspect("unexpected", content="None")
                None => inspect("None", content="None")
              }
              inspect(tuple_pattern.elements.length().to_string(), content="2")
            }
            _ => inspect("unexpected", content="tuple")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match single element tuple pattern" {
  let source = "match value { (inner,) => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::Tuple(tuple_pattern) =>
              inspect(tuple_pattern.elements.length().to_string(), content="1")
            _ => inspect("unexpected", content="tuple")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match tuple pattern missing paren" {
  let source = "match value { (left, right => left }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="2")
  inspect(
    result.errors[0].message,
    content="Expected ',' or ')' in tuple pattern.",
  )
  inspect(result.errors[1].message, content="Expected expression")
}

///|
test "match or pattern" {
  let source = "match value { Some(inner) | None => inner }"
  let lex = tokenize(source)
  inspect(lex.errors.length().to_string(), content="0")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) => {
          inspect(match_expr.arms.length().to_string(), content="1")
          match match_expr.arms[0].pattern.kind {
            PatternKind::Or(or_pattern) => {
              inspect(or_pattern.patterns.length().to_string(), content="2")
              inspect(or_pattern.bars.length().to_string(), content="1")
              let first = or_pattern.patterns[0]
              match first.kind {
                PatternKind::EnumVariant(enum_pattern) => {
                  inspect(
                    enum_pattern.qualifier.length().to_string(),
                    content="0",
                  )
                  inspect(enum_pattern.name.lexeme, content="Some")
                }
                _ => inspect("unexpected", content="variant")
              }
              let second = or_pattern.patterns[1]
              match second.kind {
                PatternKind::Ident(token) =>
                  inspect(token.lexeme, content="None")
                _ => inspect("unexpected", content="ident")
              }
            }
            _ => inspect("unexpected", content="or")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match or pattern missing right" {
  let source = "match value { Some(inner) | => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="2")
  inspect(result.errors[0].message, content="Unexpected token in pattern.")
  inspect(result.errors[1].message, content="Expected expression")
}

///|
test "match chained or pattern" {
  let source = "match value { A | B | C => value }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::Or(or_pattern) => {
              inspect(or_pattern.patterns.length().to_string(), content="3")
              inspect(or_pattern.bars.length().to_string(), content="2")
            }
            _ => inspect("unexpected", content="or")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match nested match" {
  let source = "match value { Some(inner) => match inner { Point { x } => x } }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(outer) => {
          inspect(outer.arms.length().to_string(), content="1")
          match outer.arms[0].value.kind {
            ExprKind::Match(inner_match) => {
              inspect(inner_match.arms.length().to_string(), content="1")
              match inner_match.arms[0].pattern.kind {
                PatternKind::Struct(pattern) =>
                  inspect(pattern.name.lexeme, content="Point")
                _ => inspect("unexpected", content="struct")
              }
            }
            _ => inspect("unexpected", content="match")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "switch struct pattern" {
  let source = "switch value { case Point { x: inner } => inner default => fallback }"
  let lex = tokenize(source)
  inspect(lex.errors.length().to_string(), content="0")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Switch(switch_stmt) => {
      inspect(switch_stmt.cases.length().to_string(), content="1")
      let case = switch_stmt.cases[0]
      match case.pattern.kind {
        PatternKind::Struct(pattern) =>
          inspect(pattern.name.lexeme, content="Point")
        _ => inspect("unexpected", content="struct")
      }
      match switch_stmt.default_case {
        Some(default_clause) =>
          match default_clause.value.kind {
            ExprKind::Ident(token) => inspect(token.lexeme, content="fallback")
            _ => inspect("unexpected", content="ident")
          }
        None => inspect("missing", content="default")
      }
    }
    _ => inspect("unexpected", content="switch")
  }
}

///|
test "nested match with guard error" {
  let source = "match value { Some(inner) => guard inner is Point { => inner } }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="4")
  let messages : Array[String] = Array::new()
  for err in result.errors {
    messages.push(err.message)
  }
  inspect(
    messages.join("|"),
    content="Expected expression|Expected expression|Expected expression|Expected expression",
  )
}

///|
test "match wildcard pattern" {
  let lex = tokenize("match value { _ => 0 }")
  inspect(lex.tokens.length().to_string(), content="8")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) => {
          inspect(match_expr.arms.length().to_string(), content="1")
          match match_expr.arms[0].pattern.kind {
            PatternKind::Wildcard(token) => inspect(token.lexeme, content="_")
            _ => inspect("unexpected", content="wildcard")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "guard or pattern" {
  let source = "guard value is Some(inner) | None else { fallback }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::Guard(guard_stmt) =>
      match guard_stmt.pattern {
        Some(pattern) =>
          match pattern.kind {
            PatternKind::Or(or_pattern) => {
              inspect(or_pattern.patterns.length().to_string(), content="2")
              inspect(or_pattern.bars.length().to_string(), content="1")
            }
            _ => inspect("unexpected", content="or")
          }
        None => inspect("missing", content="pattern")
      }
    _ => inspect("unexpected", content="guard")
  }
}

///|
test "guard tuple pattern missing close" {
  let source = "guard value is Some(inner"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="1")
  inspect(
    result.errors[0].message,
    content="Expected ',' or ')' after pattern in variant.",
  )
}

///|
test "switch missing arrow" {
  let source = "switch value { case Point { x: inner } inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="2")
  inspect(result.errors[0].message, content="Expected '=>' in switch case.")
  inspect(result.errors[0].token.lexeme, content="inner")
  inspect(result.errors[1].message, content="Expected expression")
  inspect(result.errors[1].token.lexeme, content="}")
}

///|
test "switch multiple errors" {
  let source = "switch value { case Point { x: => y default => }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="4")
  let messages : Array[String] = Array::new()
  for err in result.errors {
    messages.push(err.message)
  }
  inspect(
    messages.join("|"),
    content="Unexpected token in pattern.|Expected ',' or '}' after struct pattern field.|Expected expression|Expected expression",
  )
}

///|
test "switch multiple cases" {
  let source = "switch value { case Some(inner) => inner case None => fallback default => other }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::Switch(switch_stmt) => {
      inspect(switch_stmt.cases.length().to_string(), content="2")
      match switch_stmt.default_case {
        Some(default_clause) =>
          match default_clause.value.kind {
            ExprKind::Ident(token) => inspect(token.lexeme, content="other")
            _ => inspect("unexpected", content="ident")
          }
        None => inspect("missing", content="default")
      }
      match switch_stmt.cases[0].pattern.kind {
        PatternKind::EnumVariant(enum_pattern) => {
          inspect(enum_pattern.qualifier.length().to_string(), content="0")
          inspect(enum_pattern.name.lexeme, content="Some")
        }
        _ => inspect("unexpected", content="variant")
      }
      match switch_stmt.cases[1].pattern.kind {
        PatternKind::Ident(token) => inspect(token.lexeme, content="None")
        _ => inspect("unexpected", content="ident")
      }
    }
    _ => inspect("unexpected", content="switch")
  }
}

///|
test "struct literal basic" {
  let lex = tokenize("Point { x: 1, y: 2 }")
  inspect(lex.tokens.length().to_string(), content="11")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  inspect(result.declarations.length().to_string(), content="1")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::StructLiteral(struct_lit) => {
          inspect(struct_lit.qualifier.length().to_string(), content="0")
          inspect(struct_lit.fields.length().to_string(), content="2")
          let first = struct_lit.fields[0]
          inspect(first.name.lexeme, content="x")
          match first.value.kind {
            ExprKind::Literal(token) => inspect(token.lexeme, content="1")
            _ => inspect("unexpected", content="literal")
          }
          let second = struct_lit.fields[1]
          inspect(second.name.lexeme, content="y")
        }
        _ => inspect("unexpected", content="struct")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "parse struct pattern direct" {
  let lex = tokenize("Point { x: inner }")
  let parser = Parser::make(lex.tokens)
  match parser.parse_pattern() {
    Some(pattern) =>
      match pattern.kind {
        PatternKind::Struct(struct_pat) => {
          inspect(struct_pat.qualifier.length().to_string(), content="0")
          inspect(struct_pat.fields.length().to_string(), content="1")
        }
        _ => inspect("unexpected", content="struct")
      }
    None => inspect("unexpected", content="pattern")
  }
}

///|
test "guard constructor missing paren" {
  let source = "guard value is Some("
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="1")
  inspect(result.errors[0].message, content="Unexpected token in pattern.")
}

///|
test "struct literal trailing comma" {
  let lex = tokenize("Point { x: 1, y: 2, }")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="1")
  inspect(
    result.errors[0].message,
    content="Expected field name in struct literal.",
  )
}

///|
test "match qualified enum pattern" {
  let source = "match value { Module::Variant(inner) => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::EnumVariant(enum_pattern) => {
              inspect(enum_pattern.qualifier.length().to_string(), content="1")
              inspect(enum_pattern.qualifier[0].lexeme, content="Module")
              inspect(enum_pattern.name.lexeme, content="Variant")
              inspect(enum_pattern.arguments.length().to_string(), content="1")
            }
            _ => inspect("unexpected", content="variant")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match qualified enum pattern multiple args" {
  let source = "match value { Module::Variant(x, y) => x }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::EnumVariant(enum_pattern) => {
              inspect(enum_pattern.qualifier.length().to_string(), content="1")
              inspect(enum_pattern.qualifier[0].lexeme, content="Module")
              inspect(enum_pattern.name.lexeme, content="Variant")
              inspect(enum_pattern.arguments.length().to_string(), content="2")
            }
            _ => inspect("unexpected", content="variant")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match enum pattern struct payload" {
  let source = "match value { Module::Variant(Point { x: inner }) => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::EnumVariant(enum_pattern) => {
              inspect(enum_pattern.arguments.length().to_string(), content="1")
              match enum_pattern.arguments[0].kind {
                PatternKind::Struct(struct_pattern) =>
                  inspect(struct_pattern.name.lexeme, content="Point")
                _ => inspect("unexpected", content="struct")
              }
            }
            _ => inspect("unexpected", content="variant")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match arm with guard" {
  let source = "match value { Some(inner) if ready => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) => {
          inspect(match_expr.arms.length().to_string(), content="1")
          let arm = match_expr.arms[0]
          match arm.pattern.kind {
            PatternKind::EnumVariant(enum_pattern) =>
              inspect(enum_pattern.name.lexeme, content="Some")
            _ => inspect("unexpected", content="variant")
          }
          match arm.if_keyword {
            Some(token) => inspect(token.lexeme, content="if")
            None => inspect("missing", content="if")
          }
          match arm.guard_expr {
            Some(expr_guard) =>
              match expr_guard.kind {
                ExprKind::Ident(token) => inspect(token.lexeme, content="ready")
                _ => inspect("unexpected", content="ident")
              }
            None => inspect("missing", content="guard")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match arm with guard success" {
  let source = "match value { Some(inner) if check => result }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) => {
          inspect(match_expr.arms.length().to_string(), content="1")
          let arm = match_expr.arms[0]
          match arm.pattern.kind {
            PatternKind::EnumVariant(enum_pattern) =>
              inspect(enum_pattern.name.lexeme, content="Some")
            _ => inspect("unexpected", content="variant")
          }
          match arm.guard_expr {
            Some(expr_guard) =>
              match expr_guard.kind {
                ExprKind::Ident(token) => inspect(token.lexeme, content="check")
                _ => inspect("unexpected", content="ident")
              }
            None => inspect("missing", content="guard")
          }
          match arm.value.kind {
            ExprKind::Ident(token) => inspect(token.lexeme, content="result")
            _ => inspect("unexpected", content="ident")
          }
        }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match enum pattern struct payload missing brace" {
  let source = "match value { Module::Variant(Point { x: inner ) => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="3")
  let messages : Array[String] = Array::new()
  for err in result.errors {
    messages.push(err.message)
  }
  inspect(
    messages.join("|"),
    content="Expected ',' or '}' after struct pattern field.|Expected expression|Expected expression",
  )
}

///|
test "struct literal qualified" {
  let lex = tokenize("Module::Point { x: 1 }")
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::StructLiteral(struct_lit) => {
          inspect(struct_lit.qualifier.length().to_string(), content="1")
          inspect(struct_lit.qualifier[0].lexeme, content="Module")
          inspect(struct_lit.name.lexeme, content="Point")
        }
        _ => inspect("unexpected", content="struct")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match qualified struct pattern" {
  let source = "match value { Module::Point { x: inner } => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="0")
  match result.declarations[0].kind {
    StmtKind::ExprStmt(expr) =>
      match expr.kind {
        ExprKind::Match(match_expr) =>
          match match_expr.arms[0].pattern.kind {
            PatternKind::Struct(pattern) => {
              inspect(pattern.qualifier.length().to_string(), content="1")
              inspect(pattern.qualifier[0].lexeme, content="Module")
              inspect(pattern.name.lexeme, content="Point")
            }
            _ => inspect("unexpected", content="struct")
          }
        _ => inspect("unexpected", content="match")
      }
    _ => inspect("unexpected", content="expr")
  }
}

///|
test "match enum pattern missing variant" {
  let source = "match value { Module:: => value }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="1")
  let messages : Array[String] = Array::new()
  for err in result.errors {
    messages.push(err.message)
  }
  inspect(messages.join("|"), content="Expected identifier after '::'.")
}

///|
test "match guard missing expression" {
  let source = "match value { Some(inner) if => inner }"
  let lex = tokenize(source)
  let result = parse(lex.tokens)
  inspect(result.errors.length().to_string(), content="3")
  let messages : Array[String] = Array::new()
  for err in result.errors {
    messages.push(err.message)
  }
  inspect(
    messages.join("|"),
    content="Expected expression|Expected '=>' in match arm.|Expected expression",
  )
}
