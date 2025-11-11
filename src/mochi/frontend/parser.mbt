///|
pub struct ParseResult {
  declarations : Array[Stmt]
  errors : Array[ParseError]
}

///|
pub struct ParseError {
  message : String
  token : Token
}

///|
pub fn parse(tokens : Array[Token]) -> ParseResult {
  let parser = Parser::make(tokens)
  parser.parse_module()
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int
  errors : Array[ParseError]
}

///|
priv struct ParsedPath {
  qualifier : Array[Token]
  name : Token
}

///|
fn Parser::make(tokens : Array[Token]) -> Parser {
  let errors : Array[ParseError] = Array::new()
  { tokens, index: 0, errors }
}

///|
fn Parser::parse_module(self : Parser) -> ParseResult {
  let declarations : Array[Stmt] = Array::new()
  while !self.is_at_end() {
    match self.parse_statement() {
      Some(stmt) => declarations.push(stmt)
      None => self.synchronize()
    }
  }
  { declarations, errors: self.errors }
}

///|
fn Parser::parse_statement(self : Parser) -> Stmt? {
  let token = self.peek()
  match token.kind {
    TokenKind::KeywordGuard => self.parse_guard_statement()
    TokenKind::KeywordSwitch => self.parse_switch_statement()
    _ => self.parse_expression_statement()
  }
}

///|
fn Parser::parse_guard_statement(self : Parser) -> Stmt? {
  let keyword = self.advance()
  match self.parse_simple_expr() {
    None => None
    Some(condition) => {
      let mut is_token : Token? = None
      let mut pattern_value : Pattern? = None
      match self.peek().kind {
        TokenKind::KeywordIs => {
          is_token = Some(self.advance())
          match self.parse_pattern() {
            Some(pattern) => pattern_value = Some(pattern)
            None => return None
          }
        }
        _ => ()
      }
      let else_clause = self.parse_guard_else_clause()
      let mut range = combine_ranges(keyword.range, condition.range)
      match pattern_value {
        Some(pattern) => range = combine_ranges(range, pattern.range)
        None => ()
      }
      match else_clause {
        Some(clause) => range = combine_ranges(range, clause.range)
        None => ()
      }
      let guard_stmt : GuardStmt = {
        keyword,
        condition,
        is_token,
        pattern: pattern_value,
        else_clause,
        range,
      }
      let stmt : Stmt = { kind: StmtKind::Guard(guard_stmt), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_guard_else_clause(self : Parser) -> GuardElseClause? {
  match self.peek().kind {
    TokenKind::KeywordElse => ()
    _ => return None
  }
  let else_keyword = self.advance()
  let open_brace = match self.peek().kind {
    TokenKind::LBrace => self.advance()
    _ => {
      self.error(self.peek(), "Expected '{' after 'else'.")
      return None
    }
  }
  let mut body_expr : Expr? = None
  match self.peek().kind {
    TokenKind::RBrace => ()
    _ => body_expr = self.parse_simple_expr()
  }
  let close_brace = match self.peek().kind {
    TokenKind::RBrace => self.advance()
    _ => {
      self.error(self.peek(), "Expected '}' after guard else block.")
      return None
    }
  }
  let range = combine_ranges(else_keyword.range, close_brace.range)
  let clause : GuardElseClause = {
    keyword: else_keyword,
    open_brace,
    body: body_expr,
    close_brace,
    range,
  }
  Some(clause)
}

///|
fn Parser::parse_expression_statement(self : Parser) -> Stmt? {
  match self.parse_simple_expr() {
    None => None
    Some(expr) => {
      let range = expr.range
      let stmt : Stmt = { kind: StmtKind::ExprStmt(expr), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_simple_expr(self : Parser) -> Expr? {
  self.parse_simple_expr_with_options(true)
}

///|
fn Parser::parse_simple_expr_with_options(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  let token = self.peek()
  match token.kind {
    TokenKind::KeywordMatch => self.parse_match_expression()
    TokenKind::Ident => self.parse_identifier_expression(allow_struct_literal)
    TokenKind::LiteralInt
    | TokenKind::LiteralString
    | TokenKind::LiteralChar
    | TokenKind::LiteralFloat => {
      let literal = self.advance()
      let expr : Expr = {
        kind: ExprKind::Literal(literal),
        range: literal.range,
      }
      Some(expr)
    }
    _ => {
      self.error(token, "Expected expression")
      if !self.is_at_end() {
        let _ = self.advance()

      }
      None
    }
  }
}

///|
fn Parser::parse_identifier_expression(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  let first = self.advance()
  let parsed = self.collect_path(first)
  let qualifier = parsed.qualifier
  let name = parsed.name
  let start_token = if qualifier.length() > 0 { qualifier[0] } else { first }
  if allow_struct_literal {
    match self.peek().kind {
      TokenKind::LBrace => {
        let open = self.advance()
        return self.parse_struct_literal(qualifier, name, open, start_token)
      }
      _ => ()
    }
  }
  let range = combine_ranges(start_token.range, name.range)
  let expr : Expr = { kind: ExprKind::Ident(name), range }
  Some(expr)
}

///|
fn Parser::parse_match_expression(self : Parser) -> Expr? {
  let keyword = self.advance()
  match self.parse_simple_expr_with_options(false) {
    None => None
    Some(value) => {
      let open = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after match value.")
          return None
        }
      }
      let arms : Array[MatchArm] = Array::new()
      for {
        if self.is_at_end() {
          self.error(open, "Unterminated match expression.")
          return None
        }
        let next = self.peek()
        match next.kind {
          TokenKind::RBrace => {
            let close = self.advance()
            let range = combine_ranges(keyword.range, close.range)
            let match_expr : MatchExpr = {
              keyword,
              value,
              open,
              arms,
              close,
              range,
            }
            let expr : Expr = { kind: ExprKind::Match(match_expr), range }
            return Some(expr)
          }
          _ => ()
        }
        match self.parse_match_arm() {
          None => return None
          Some(arm) => arms.push(arm)
        }
        let separator = self.peek()
        match separator.kind {
          TokenKind::Comma => {
            let _ = self.advance()

          }
          TokenKind::RBrace => ()
          _ => {
            self.error(separator, "Expected ',' or '}' after match arm.")
            return None
          }
        }
      }
    }
  }
}

///|
fn Parser::parse_match_arm(self : Parser) -> MatchArm? {
  match self.parse_pattern() {
    None => None
    Some(pattern) => {
      let mut if_token : Token? = None
      let mut guard_expr : Expr? = None
      match self.peek().kind {
        TokenKind::KeywordIf => {
          let keyword_if = self.advance()
          if_token = Some(keyword_if)
          match self.parse_simple_expr() {
            Some(expr) => guard_expr = Some(expr)
            None => ()
          }
        }
        _ => ()
      }
      let arrow = match self.peek().kind {
        TokenKind::Arrow => self.advance()
        _ => {
          self.error(self.peek(), "Expected '=>' in match arm.")
          return None
        }
      }
      match self.parse_simple_expr() {
        None => None
        Some(value) => {
          let mut range = pattern.range
          match guard_expr {
            Some(expr) => range = combine_ranges(range, expr.range)
            None =>
              match if_token {
                Some(token) => range = combine_ranges(range, token.range)
                None => ()
              }
          }
          range = combine_ranges(range, value.range)
          let arm : MatchArm = {
            pattern,
            if_keyword: if_token,
            guard_expr,
            arrow,
            value,
            range,
          }
          Some(arm)
        }
      }
    }
  }
}

///|
fn Parser::parse_struct_literal(
  self : Parser,
  qualifier : Array[Token],
  name : Token,
  open : Token,
  start_token : Token,
) -> Expr? {
  let fields : Array[StructField] = Array::new()
  for {
    if self.is_at_end() {
      self.error(open, "Unterminated struct literal.")
      return None
    }
    let next = self.peek()
    match next.kind {
      TokenKind::RBrace => {
        let close = self.advance()
        let range = combine_ranges(start_token.range, close.range)
        let struct_lit : StructLiteral = {
          qualifier,
          name,
          open,
          fields,
          close,
          range,
        }
        let expr : Expr = { kind: ExprKind::StructLiteral(struct_lit), range }
        return Some(expr)
      }
      _ => ()
    }
    let field_name = match self.peek().kind {
      TokenKind::Ident => self.advance()
      _ => {
        self.error(self.peek(), "Expected field name in struct literal.")
        return None
      }
    }
    let colon = match self.peek().kind {
      TokenKind::Colon => self.advance()
      _ => {
        self.error(self.peek(), "Expected ':' after field name.")
        return None
      }
    }
    match self.parse_simple_expr() {
      None => return None
      Some(value) => {
        let field_range = combine_ranges(field_name.range, value.range)
        let field : StructField = {
          name: field_name,
          colon,
          value,
          range: field_range,
        }
        fields.push(field)
      }
    }
    let separator = self.peek()
    match separator.kind {
      TokenKind::Comma => {
        let _ = self.advance()
        match self.peek().kind {
          TokenKind::RBrace => {
            self.error(self.peek(), "Expected field name in struct literal.")
            return None
          }
          _ => ()
        }
      }
      TokenKind::RBrace => ()
      _ => {
        self.error(separator, "Expected ',' or '}' after struct field.")
        return None
      }
    }
  }
}

///|
fn Parser::synchronize(self : Parser) -> Unit {
  if self.is_at_end() {
    return
  }
  let _ = self.advance()

}

///|
fn Parser::is_at_end(self : Parser) -> Bool {
  match self.peek().kind {
    TokenKind::EndOfFile => true
    _ => false
  }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::advance(self : Parser) -> Token {
  if !self.is_at_end() {
    self.index = self.index + 1
  }
  self.tokens[self.index - 1]
}

///|
fn Parser::error(self : Parser, token : Token, message : String) -> Unit {
  let error : ParseError = { message, token }
  self.errors.push(error)
}

///|
fn combine_ranges(left : SourceRange, right : SourceRange) -> SourceRange {
  let start = if left.start.index <= right.start.index {
    left.start
  } else {
    right.start
  }
  { start, end: right.end }
}

///|
fn Parser::parse_switch_statement(self : Parser) -> Stmt? {
  let keyword = self.advance()
  match self.parse_simple_expr_with_options(false) {
    None => None
    Some(value) => {
      let open = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after switch value.")
          return None
        }
      }
      let cases : Array[SwitchCase] = Array::new()
      let mut default_case : SwitchDefault? = None
      for {
        if self.is_at_end() {
          self.error(open, "Unterminated switch statement.")
          return None
        }
        let next = self.peek()
        match next.kind {
          TokenKind::RBrace => {
            let close = self.advance()
            let range = combine_ranges(keyword.range, close.range)
            let stmt_info : SwitchStmt = {
              keyword,
              value,
              open,
              cases,
              default_case,
              close,
              range,
            }
            let stmt : Stmt = { kind: StmtKind::Switch(stmt_info), range }
            return Some(stmt)
          }
          TokenKind::KeywordCase =>
            match self.parse_switch_case() {
              None => return None
              Some(case_info) => cases.push(case_info)
            }
          TokenKind::KeywordDefault => {
            match default_case {
              Some(_) => {
                self.error(next, "Duplicate default clause in switch.")
                return None
              }
              None => ()
            }
            match self.parse_switch_default() {
              None => return None
              Some(default_info) => default_case = Some(default_info)
            }
          }
          _ => {
            self.error(next, "Expected 'case', 'default', or '}' in switch.")
            if !self.is_at_end() {
              let _ = self.advance()

            }
            return None
          }
        }
      }
    }
  }
}

///|
fn Parser::parse_switch_case(self : Parser) -> SwitchCase? {
  let keyword = self.advance()
  match self.parse_pattern() {
    None => None
    Some(pattern) => {
      let arrow = match self.peek().kind {
        TokenKind::Arrow => self.advance()
        _ => {
          self.error(self.peek(), "Expected '=>' in switch case.")
          return None
        }
      }
      match self.parse_simple_expr() {
        None => None
        Some(value) => {
          let range = combine_ranges(keyword.range, value.range)
          let case_info : SwitchCase = { keyword, pattern, arrow, value, range }
          let separator = self.peek()
          match separator.kind {
            TokenKind::Comma => {
              let _ = self.advance()

            }
            TokenKind::RBrace
            | TokenKind::KeywordCase
            | TokenKind::KeywordDefault => ()
            _ => {
              self.error(
                separator, "Expected ',', 'case', 'default', or '}' after switch case.",
              )
              return None
            }
          }
          Some(case_info)
        }
      }
    }
  }
}

///|
fn Parser::parse_switch_default(self : Parser) -> SwitchDefault? {
  let keyword = self.advance()
  let arrow = match self.peek().kind {
    TokenKind::Arrow => self.advance()
    _ => {
      self.error(self.peek(), "Expected '=>' in default clause.")
      return None
    }
  }
  match self.parse_simple_expr() {
    None => None
    Some(value) => {
      let range = combine_ranges(keyword.range, value.range)
      let default_info : SwitchDefault = { keyword, arrow, value, range }
      let separator = self.peek()
      match separator.kind {
        TokenKind::Comma => {
          let _ = self.advance()

        }
        TokenKind::RBrace => ()
        _ => {
          self.error(separator, "Expected ',' or '}' after default clause.")
          return None
        }
      }
      Some(default_info)
    }
  }
}

///|
fn Parser::parse_pattern(self : Parser) -> Pattern? {
  self.parse_or_pattern()
}

///|
fn Parser::parse_or_pattern(self : Parser) -> Pattern? {
  match self.parse_primary_pattern() {
    None => None
    Some(first_pattern) => {
      let patterns : Array[Pattern] = Array::new()
      let bars : Array[Token] = Array::new()
      append_pattern_to_or(patterns, bars, first_pattern, None)
      let mut range = first_pattern.range
      for {
        match self.peek().kind {
          TokenKind::Pipe => {
            let bar = self.advance()
            match self.parse_primary_pattern() {
              Some(next_pattern) => {
                range = combine_ranges(range, next_pattern.range)
                append_pattern_to_or(patterns, bars, next_pattern, Some(bar))
              }
              None => return None
            }
          }
          _ => break
        }
      }
      if bars.length() == 0 {
        Some(patterns[0])
      } else {
        let info : PatternOr = { patterns, bars, range }
        let pattern : Pattern = { kind: PatternKind::Or(info), range }
        Some(pattern)
      }
    }
  }
}

///|
fn Parser::parse_primary_pattern(self : Parser) -> Pattern? {
  let token = self.peek()
  match token.kind {
    TokenKind::Underscore => {
      let wildcard = self.advance()
      let pattern : Pattern = {
        kind: PatternKind::Wildcard(wildcard),
        range: wildcard.range,
      }
      Some(pattern)
    }
    TokenKind::LiteralInt
    | TokenKind::LiteralString
    | TokenKind::LiteralChar
    | TokenKind::LiteralFloat => {
      let literal = self.advance()
      let pattern : Pattern = {
        kind: PatternKind::Literal(literal),
        range: literal.range,
      }
      Some(pattern)
    }
    TokenKind::Ident => {
      let first = self.advance()
      let parsed = self.collect_path(first)
      let qualifier = parsed.qualifier
      let name = parsed.name
      let start_token = if qualifier.length() > 0 {
        qualifier[0]
      } else {
        first
      }
      match self.peek().kind {
        TokenKind::LBrace => {
          let open = self.advance()
          self.parse_struct_pattern(qualifier, name, open, start_token)
        }
        TokenKind::LParen => {
          let open = self.advance()
          self.parse_enum_variant_with_parens(
            qualifier, name, open, start_token,
          )
        }
        _ =>
          if qualifier.length() > 0 {
            let empty_args : Array[Pattern] = Array::new()
            let pattern = self.make_enum_variant_pattern(
              qualifier,
              name,
              None,
              empty_args,
              None,
              start_token,
            )
            Some(pattern)
          } else {
            let pattern : Pattern = {
              kind: PatternKind::Ident(name),
              range: name.range,
            }
            Some(pattern)
          }
      }
    }
    TokenKind::LParen => self.parse_parenthesized_pattern()
    _ => {
      self.error(token, "Unexpected token in pattern.")
      if !self.is_at_end() {
        let _ = self.advance()

      }
      None
    }
  }
}

///|
fn Parser::collect_path(self : Parser, first : Token) -> ParsedPath {
  let qualifier : Array[Token] = Array::new()
  let mut current = first
  for {
    match self.peek().kind {
      TokenKind::DoubleColon => {
        let _ = self.advance()
        match self.peek().kind {
          TokenKind::Ident => {
            qualifier.push(current)
            current = self.advance()
          }
          _ => {
            self.error(self.peek(), "Expected identifier after '::'.")
            return { qualifier, name: current }
          }
        }
      }
      _ => break
    }
  }
  { qualifier, name: current }
}

///|
fn Parser::parse_parenthesized_pattern(self : Parser) -> Pattern? {
  let open = self.advance()
  match self.peek().kind {
    TokenKind::RParen => {
      self.error(self.peek(), "Tuple pattern cannot be empty.")
      let close = self.advance()
      let elements : Array[Pattern] = Array::new()
      let range = combine_ranges(open.range, close.range)
      let info : PatternTuple = {
        qualifier: Array::new(),
        name: None,
        open,
        elements,
        close,
        range,
      }
      let pattern : Pattern = { kind: PatternKind::Tuple(info), range }
      return Some(pattern)
    }
    _ => ()
  }
  match self.parse_pattern() {
    None => None
    Some(first_pattern) =>
      match self.peek().kind {
        TokenKind::Comma => {
          let elements : Array[Pattern] = Array::new()
          elements.push(first_pattern)
          for {
            let _ = self.advance()
            match self.peek().kind {
              TokenKind::RParen => {
                let close = self.advance()
                let range = combine_ranges(open.range, close.range)
                let info : PatternTuple = {
                  qualifier: Array::new(),
                  name: None,
                  open,
                  elements,
                  close,
                  range,
                }
                let pattern : Pattern = {
                  kind: PatternKind::Tuple(info),
                  range,
                }
                return Some(pattern)
              }
              _ => ()
            }
            match self.parse_pattern() {
              Some(next_pattern) => elements.push(next_pattern)
              None => return None
            }
            match self.peek().kind {
              TokenKind::Comma => continue
              TokenKind::RParen => {
                let close = self.advance()
                let range = combine_ranges(open.range, close.range)
                let info : PatternTuple = {
                  qualifier: Array::new(),
                  name: None,
                  open,
                  elements,
                  close,
                  range,
                }
                let pattern : Pattern = {
                  kind: PatternKind::Tuple(info),
                  range,
                }
                return Some(pattern)
              }
              _ => {
                self.error(self.peek(), "Expected ',' or ')' in tuple pattern.")
                return None
              }
            }
          }
        }
        TokenKind::RParen => {
          let close = self.advance()
          let range = combine_ranges(open.range, close.range)
          let updated = pattern_with_range(first_pattern, range)
          Some(updated)
        }
        _ => {
          self.error(self.peek(), "Expected ',' or ')' in tuple pattern.")
          None
        }
      }
  }
}

///|
fn Parser::parse_struct_pattern(
  self : Parser,
  qualifier : Array[Token],
  name : Token,
  open : Token,
  start_token : Token,
) -> Pattern? {
  let fields : Array[PatternStructField] = Array::new()
  for {
    if self.is_at_end() {
      self.error(open, "Unterminated struct pattern.")
      return None
    }
    let next = self.peek()
    match next.kind {
      TokenKind::RBrace => {
        let close = self.advance()
        let range = combine_ranges(start_token.range, close.range)
        let info : PatternStruct = {
          qualifier,
          name,
          open,
          fields,
          close,
          range,
        }
        let pattern : Pattern = { kind: PatternKind::Struct(info), range }
        return Some(pattern)
      }
      _ => ()
    }
    let field_name = match self.peek().kind {
      TokenKind::Ident => self.advance()
      _ => {
        self.error(self.peek(), "Expected field name in struct pattern.")
        return None
      }
    }
    let mut colon_token : Token? = None
    let mut field_pattern : Pattern? = None
    match self.peek().kind {
      TokenKind::Colon => {
        colon_token = Some(self.advance())
        field_pattern = self.parse_pattern()
      }
      _ => ()
    }
    let field_range = match field_pattern {
      Some(pattern) => combine_ranges(field_name.range, pattern.range)
      None => field_name.range
    }
    let field_info : PatternStructField = {
      name: field_name,
      colon: colon_token,
      pattern: field_pattern,
      range: field_range,
    }
    fields.push(field_info)
    let separator = self.peek()
    match separator.kind {
      TokenKind::Comma => {
        let _ = self.advance()
        match self.peek().kind {
          TokenKind::RBrace => {
            self.error(self.peek(), "Expected field name in struct pattern.")
            return None
          }
          _ => ()
        }
      }
      TokenKind::RBrace => ()
      _ => {
        self.error(separator, "Expected ',' or '}' after struct pattern field.")
        return None
      }
    }
  }
}

///|
fn Parser::parse_enum_variant_with_parens(
  self : Parser,
  qualifier : Array[Token],
  name : Token,
  open : Token,
  start_token : Token,
) -> Pattern? {
  let arguments : Array[Pattern] = Array::new()
  match self.peek().kind {
    TokenKind::RParen => {
      let close = self.advance()
      let pattern = self.make_enum_variant_pattern(
        qualifier,
        name,
        Some(open),
        arguments,
        Some(close),
        start_token,
      )
      return Some(pattern)
    }
    _ => ()
  }
  for {
    match self.parse_pattern() {
      Some(argument) => arguments.push(argument)
      None => return None
    }
    match self.peek().kind {
      TokenKind::Comma => {
        let _ = self.advance()

      }
      TokenKind::RParen => {
        let close = self.advance()
        let pattern = self.make_enum_variant_pattern(
          qualifier,
          name,
          Some(open),
          arguments,
          Some(close),
          start_token,
        )
        return Some(pattern)
      }
      _ => {
        self.error(self.peek(), "Expected ',' or ')' after pattern in variant.")
        return None
      }
    }
  }
}

///|
fn Parser::make_enum_variant_pattern(
  _self : Parser,
  qualifier : Array[Token],
  name : Token,
  open : Token?,
  arguments : Array[Pattern],
  close : Token?,
  start_token : Token,
) -> Pattern {
  let end_range = match close {
    Some(token) => token.range
    None => name.range
  }
  let range = combine_ranges(start_token.range, end_range)
  let info : PatternEnumVariant = {
    qualifier,
    name,
    open,
    arguments,
    close,
    range,
  }
  { kind: PatternKind::EnumVariant(info), range }
}

///|
fn pattern_with_range(pattern : Pattern, range : SourceRange) -> Pattern {
  match pattern.kind {
    PatternKind::Wildcard(token) => {
      let new_pattern : Pattern = { kind: PatternKind::Wildcard(token), range }
      new_pattern
    }
    PatternKind::Ident(token) => {
      let new_pattern : Pattern = { kind: PatternKind::Ident(token), range }
      new_pattern
    }
    PatternKind::Literal(token) => {
      let new_pattern : Pattern = { kind: PatternKind::Literal(token), range }
      new_pattern
    }
    PatternKind::Struct(info) => {
      let new_info : PatternStruct = {
        qualifier: info.qualifier,
        name: info.name,
        open: info.open,
        fields: info.fields,
        close: info.close,
        range,
      }
      let new_pattern : Pattern = { kind: PatternKind::Struct(new_info), range }
      new_pattern
    }
    PatternKind::Tuple(info) => {
      let new_info : PatternTuple = {
        qualifier: info.qualifier,
        name: info.name,
        open: info.open,
        elements: info.elements,
        close: info.close,
        range,
      }
      let new_pattern : Pattern = { kind: PatternKind::Tuple(new_info), range }
      new_pattern
    }
    PatternKind::Or(info) => {
      let new_info : PatternOr = {
        patterns: info.patterns,
        bars: info.bars,
        range,
      }
      let new_pattern : Pattern = { kind: PatternKind::Or(new_info), range }
      new_pattern
    }
    PatternKind::EnumVariant(info) => {
      let new_info : PatternEnumVariant = {
        qualifier: info.qualifier,
        name: info.name,
        open: info.open,
        arguments: info.arguments,
        close: info.close,
        range,
      }
      let new_pattern : Pattern = {
        kind: PatternKind::EnumVariant(new_info),
        range,
      }
      new_pattern
    }
  }
}

///|
fn append_pattern_to_or(
  patterns : Array[Pattern],
  bars : Array[Token],
  pattern : Pattern,
  leading_bar : Token?,
) -> Unit {
  match leading_bar {
    Some(bar) => bars.push(bar)
    None => ()
  }
  match pattern.kind {
    PatternKind::Or(info) => {
      let count = info.patterns.length()
      let mut index = 0
      for {
        if index >= count {
          break
        }
        patterns.push(info.patterns[index])
        if index < info.bars.length() {
          bars.push(info.bars[index])
        }
        index = index + 1
      }
    }
    _ => patterns.push(pattern)
  }
}
