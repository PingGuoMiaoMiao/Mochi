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
    TokenKind::KeywordLet => self.parse_let_statement()
    TokenKind::KeywordFn => self.parse_function_declaration()
    TokenKind::KeywordReturn => self.parse_return_statement()
    TokenKind::KeywordWhile => self.parse_while_statement()
    TokenKind::KeywordIf => self.parse_if_statement()
    TokenKind::KeywordStruct => self.parse_struct_definition()
    TokenKind::Ident => {
      // Check if this is an assignment statement
      // For simple assignments like "x = ...", offset 1 is Assign
      // For array index assignments like "arr[0] = ...", we need to look further
      let mut offset = 1
      let mut is_assign = false
      // Skip array indices to find the assignment operator
      for {
        if offset >= self.tokens.length() - self.index {
          break
        }
        match self.peek_kind_offset(offset) {
          TokenKind::Dot => {
            // Skip field access: .field
            offset = offset + 1
            match self.peek_kind_offset(offset) {
              TokenKind::Ident => offset = offset + 1
              _ => break
            }
          }
          TokenKind::LBracket => {
            // Skip index expression: [expr]
            offset = offset + 1
            // Skip the index expression (could be complex)
            let mut depth = 1
            for {
              if offset >= self.tokens.length() - self.index {
                break
              }
              match self.peek_kind_offset(offset) {
                TokenKind::LBracket => depth = depth + 1
                TokenKind::RBracket => {
                  depth = depth - 1
                  if depth == 0 {
                    offset = offset + 1
                    break
                  }
                }
                _ => ()
              }
              offset = offset + 1
            }
          }
          TokenKind::Assign => {
            is_assign = true
            break
          }
          TokenKind::Semicolon
          | TokenKind::RParen
          | TokenKind::RBrace
          | TokenKind::Comma =>
            // End of expression, not an assignment
            break
          _ => {
            // Continue looking
            offset = offset + 1
            // Limit search to avoid infinite loops
            if offset > 10 {
              break
            }
          }
        }
      }
      if is_assign {
        self.parse_assign_statement()
      } else {
        self.parse_expression_statement()
      }
    }
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
      // Optional semicolon after expression statement
      let mut semicolon : Token? = None
      match self.peek().kind {
        TokenKind::Semicolon => semicolon = Some(self.advance())
        _ => ()
      }
      let range = match semicolon {
        Some(semi) => combine_ranges(expr.range, semi.range)
        None => expr.range
      }
      let stmt : Stmt = { kind: StmtKind::ExprStmt(expr), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_let_statement(self : Parser) -> Stmt? {
  let let_keyword = self.advance()
  let mut mut_keyword : Token? = None
  match self.peek().kind {
    TokenKind::KeywordMut => mut_keyword = Some(self.advance())
    _ => ()
  }
  // Check for tuple destructuring: let (x, y, z) = ...
  let name = match self.peek().kind {
    TokenKind::LParen => {
      // Tuple destructuring
      let open_paren = self.advance()
      let destructured_names : Array[Token] = Array::new()
      for {
        if self.is_at_end() {
          self.error(self.peek(), "Unterminated tuple destructuring.")
          return None
        }
        match self.peek().kind {
          TokenKind::RParen => {
            let _ = self.advance()
            break
          }
          TokenKind::Ident | TokenKind::Underscore => {
            let ident = self.advance()
            destructured_names.push(ident)
            match self.peek().kind {
              TokenKind::Comma => {
                let _ = self.advance()

              }
              TokenKind::RParen => ()
              _ => {
                self.error(
                  self.peek(),
                  "Expected ',' or ')' in tuple destructuring.",
                )
                return None
              }
            }
          }
          _ => {
            self.error(
              self.peek(),
              "Expected identifier or '_' in tuple destructuring.",
            )
            return None
          }
        }
      }
      // For now, we'll use the first name as the main name
      // In a full implementation, we'd need to handle multiple bindings
      if destructured_names.length() > 0 {
        destructured_names[0]
      } else {
        // Empty tuple destructuring, use underscore
        let underscore_token : Token = {
          kind: TokenKind::Underscore,
          range: open_paren.range,
          lexeme: "_",
        }
        underscore_token
      }
    }
    TokenKind::Ident => self.advance()
    TokenKind::Underscore => self.advance()
    _ => {
      self.error(self.peek(), "Expected identifier after 'let'.")
      return None
    }
  }
  let mut colon : Token? = None
  let mut type_name : Token? = None
  match self.peek().kind {
    TokenKind::Colon => {
      colon = Some(self.advance())
      // Try to parse function type: (Type) -> Type
      match self.peek().kind {
        TokenKind::LParen => {
          // Function type: (Type) -> Type
          let _ = self.advance() // consume LParen
          let param_types : Array[Token] = Array::new()
          match self.peek().kind {
            TokenKind::RParen => {
              let _ = self.advance()
              // consume RParen
            }
            _ =>
              for {
                if self.is_at_end() {
                  break
                }
                match self.peek().kind {
                  TokenKind::Ident => {
                    let param_type = self.advance()
                    param_types.push(param_type)
                    match self.peek().kind {
                      TokenKind::Comma => {
                        let _ = self.advance()

                      }
                      TokenKind::RParen => {
                        let _ = self.advance()
                        break
                      }
                      _ => {
                        self.error(
                          self.peek(),
                          "Expected ',' or ')' in function type.",
                        )
                        return None
                      }
                    }
                  }
                  TokenKind::RParen => {
                    let _ = self.advance()
                    break
                  }
                  _ => {
                    self.error(
                      self.peek(),
                      "Expected type name in function type.",
                    )
                    return None
                  }
                }
              }
          }
          match self.peek().kind {
            TokenKind::Arrow | TokenKind::ThinArrow => {
              let _ = self.advance() // consume ->
              match self.peek().kind {
                TokenKind::Ident => type_name = Some(self.advance())
                _ => {
                  self.error(self.peek(), "Expected return type after '->'.")
                  return None
                }
              }
            }
            _ => {
              self.error(
                self.peek(),
                "Expected '->' after function parameter types.",
              )
              return None
            }
          }
        }
        TokenKind::Ident => {
          // Check for Array[Type] syntax
          let type_token = self.advance()
          match self.peek().kind {
            TokenKind::LBracket => {
              // Array[Type] syntax
              let _ = self.advance() // consume [
              // Parse element type (could be Int, Bool, or function type)
              match self.peek().kind {
                TokenKind::LParen => {
                  // Array[(Type) -> Type] - function type as element
                  let _ = self.advance() // consume LParen
                  match self.peek().kind {
                    TokenKind::RParen => {
                      let _ = self.advance() // consume RParen
                      match self.peek().kind {
                        TokenKind::Arrow | TokenKind::ThinArrow => {
                          let _ = self.advance() // consume ->
                          match self.peek().kind {
                            TokenKind::Ident => {
                              let _ = self.advance() // consume return type
                              match self.peek().kind {
                                TokenKind::RBracket => {
                                  let _ = self.advance()
                                  // consume ]
                                }
                                _ =>
                                  self.error(
                                    self.peek(),
                                    "Expected ']' after array element type.",
                                  )
                              }
                            }
                            _ =>
                              self.error(
                                self.peek(),
                                "Expected return type after '->'.",
                              )
                          }
                        }
                        _ =>
                          self.error(
                            self.peek(),
                            "Expected '->' after function parameter types.",
                          )
                      }
                    }
                    TokenKind::Ident => {
                      let _ = self.advance() // consume param type
                      match self.peek().kind {
                        TokenKind::RParen => {
                          let _ = self.advance() // consume RParen
                          match self.peek().kind {
                            TokenKind::Arrow | TokenKind::ThinArrow => {
                              let _ = self.advance() // consume ->
                              match self.peek().kind {
                                TokenKind::Ident => {
                                  let _ = self.advance() // consume return type
                                  match self.peek().kind {
                                    TokenKind::RBracket => {
                                      let _ = self.advance()
                                      // consume ]
                                    }
                                    _ =>
                                      self.error(
                                        self.peek(),
                                        "Expected ']' after array element type.",
                                      )
                                  }
                                }
                                _ =>
                                  self.error(
                                    self.peek(),
                                    "Expected return type after '->'.",
                                  )
                              }
                            }
                            _ =>
                              self.error(
                                self.peek(),
                                "Expected '->' after function parameter types.",
                              )
                          }
                        }
                        _ =>
                          self.error(
                            self.peek(),
                            "Expected ')' after function parameter type.",
                          )
                      }
                    }
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected type name in function type.",
                      )
                  }
                }
                TokenKind::Ident => {
                  let _ = self.advance() // consume element type
                  match self.peek().kind {
                    TokenKind::RBracket => {
                      let _ = self.advance()
                      // consume ]
                    }
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected ']' after array element type.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected element type in Array[Type].",
                  )
              }
              type_name = Some(type_token) // Use the Array token as type name
            }
            _ => type_name = Some(type_token) // Regular type name
          }
        }
        _ => self.error(self.peek(), "Expected type name after ':'.")
      }
    }
    _ => ()
  }
  let assign = match self.peek().kind {
    TokenKind::Assign => self.advance()
    _ => {
      self.error(self.peek(), "Expected '=' in let statement.")
      return None
    }
  }
  match self.parse_simple_expr() {
    None => None
    Some(value) => {
      let semicolon = match self.peek().kind {
        TokenKind::Semicolon => self.advance()
        _ => {
          self.error(self.peek(), "Expected ';' after let statement.")
          return None
        }
      }
      let range = combine_ranges(let_keyword.range, semicolon.range)
      let stmt_info : LetStmt = {
        let_keyword,
        mut_keyword,
        name,
        colon,
        type_name,
        assign,
        value,
        semicolon,
        range,
      }
      let stmt : Stmt = { kind: StmtKind::Let(stmt_info), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_assign_statement(self : Parser) -> Stmt? {
  // Parse target expression (can be identifier, field access, or array index expression)
  // Start with identifier
  let first_token = match self.peek().kind {
    TokenKind::Ident => self.advance()
    _ => {
      self.error(self.peek(), "Expected identifier for assignment.")
      return None
    }
  }
  let mut target : Expr = {
    kind: ExprKind::Ident(first_token),
    range: first_token.range,
  }
  // Parse field access and array indices (but stop before '=' token)
  for {
    match self.peek().kind {
      TokenKind::Dot => {
        // Field access: .field
        let dot = self.advance()
        let field = match self.peek().kind {
          TokenKind::Ident => self.advance()
          _ => {
            self.error(self.peek(), "Expected field name after '.'.")
            return None
          }
        }
        let field_range = combine_ranges(target.range, field.range)
        let field_access : FieldAccessExpr = {
          object: target,
          dot,
          field,
          range: field_range,
        }
        target = {
          kind: ExprKind::FieldAccess(field_access),
          range: field_range,
        }
      }
      TokenKind::LBracket => {
        let open_bracket = self.advance()
        match self.parse_simple_expr() {
          None => {
            self.error(self.peek(), "Expected expression in array index.")
            return None
          }
          Some(index_expr) => {
            let close_bracket = match self.peek().kind {
              TokenKind::RBracket => self.advance()
              _ => {
                self.error(self.peek(), "Expected ']' after array index.")
                return None
              }
            }
            let index_range = combine_ranges(target.range, close_bracket.range)
            let index_expr_struct : IndexExpr = {
              array: target,
              open_bracket,
              index: index_expr,
              close_bracket,
              range: index_range,
            }
            target = {
              kind: ExprKind::Index(index_expr_struct),
              range: index_range,
            }
          }
        }
      }
      _ => break
    }
  }
  let assign = match self.peek().kind {
    TokenKind::Assign => self.advance()
    _ => {
      self.error(self.peek(), "Expected '=' in assignment.")
      return None
    }
  }
  match self.parse_simple_expr() {
    None => None
    Some(value) => {
      let semicolon = match self.peek().kind {
        TokenKind::Semicolon => self.advance()
        _ => {
          self.error(self.peek(), "Expected ';' after assignment.")
          return None
        }
      }
      let range = combine_ranges(target.range, semicolon.range)
      let info : AssignStmt = { target, assign, value, semicolon, range }
      let stmt : Stmt = { kind: StmtKind::Assign(info), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::peek_kind_offset(self : Parser, offset : Int) -> TokenKind {
  let index = self.index + offset
  if index >= self.tokens.length() {
    return TokenKind::EndOfFile
  }
  self.tokens[index].kind
}

///|
fn Parser::parse_return_statement(self : Parser) -> Stmt? {
  let keyword = self.advance()
  let mut value : Expr? = None
  match self.peek().kind {
    TokenKind::Semicolon => ()
    TokenKind::RBrace => ()
    _ =>
      match self.parse_simple_expr() {
        Some(expr) => value = Some(expr)
        None => return None
      }
  }
  let mut semicolon : Token? = None
  match self.peek().kind {
    TokenKind::Semicolon => semicolon = Some(self.advance())
    _ => ()
  }
  let mut range = keyword.range
  match value {
    Some(expr) => range = combine_ranges(range, expr.range)
    None => ()
  }
  match semicolon {
    Some(token) => range = combine_ranges(range, token.range)
    None => ()
  }
  let return_stmt : ReturnStmt = { keyword, value, semicolon, range }
  let stmt : Stmt = { kind: StmtKind::Return(return_stmt), range }
  Some(stmt)
}

///|
fn Parser::parse_if_statement(self : Parser) -> Stmt? {
  let keyword = self.advance()
  match self.parse_simple_expr() {
    None => None
    Some(condition) => {
      let open_brace = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after if condition.")
          return None
        }
      }
      let then_body : Array[Stmt] = Array::new()
      while !self.is_at_end() {
        match self.peek().kind {
          TokenKind::RBrace => break
          TokenKind::Semicolon => {
            // Skip standalone semicolons (empty statements)
            let _ = self.advance()

          }
          _ =>
            match self.parse_statement() {
              Some(stmt) => then_body.push(stmt)
              None => self.synchronize()
            }
        }
      }
      let close_brace = match self.peek().kind {
        TokenKind::RBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '}' to close if body.")
          return None
        }
      }
      // Check for else clause (supports else if)
      let mut else_keyword : Token? = None
      let mut else_open_brace : Token? = None
      let else_body : Array[Stmt] = Array::new()
      let mut else_close_brace : Token? = None
      match self.peek().kind {
        TokenKind::KeywordElse => {
          else_keyword = Some(self.advance())
          // Check for else if
          match self.peek().kind {
            TokenKind::KeywordIf =>
              // Parse else if as a nested if statement
              match self.parse_if_statement() {
                Some(else_if_stmt) => else_body.push(else_if_stmt)
                // else_close_brace remains None for else if
                None => return None
              }
            TokenKind::LBrace => {
              else_open_brace = Some(self.advance())
              while !self.is_at_end() {
                match self.peek().kind {
                  TokenKind::RBrace => break
                  TokenKind::Semicolon => {
                    // Skip standalone semicolons (empty statements)
                    let _ = self.advance()

                  }
                  _ =>
                    match self.parse_statement() {
                      Some(stmt) => else_body.push(stmt)
                      None => self.synchronize()
                    }
                }
              }
              else_close_brace = match self.peek().kind {
                TokenKind::RBrace => Some(self.advance())
                _ => {
                  self.error(self.peek(), "Expected '}' to close else body.")
                  return None
                }
              }
            }
            _ => {
              self.error(self.peek(), "Expected '{' or 'if' after 'else'.")
              return None
            }
          }
        }
        _ => ()
      }
      let range = combine_ranges(
        keyword.range,
        match else_close_brace {
          Some(close) => close.range
          None => close_brace.range
        },
      )
      let info : IfStmt = {
        keyword,
        condition,
        open_brace,
        then_body,
        close_brace,
        else_keyword,
        else_open_brace,
        else_body,
        else_close_brace,
        range,
      }
      let stmt : Stmt = { kind: StmtKind::If(info), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_if_expression(self : Parser) -> Expr? {
  let keyword = self.advance()
  match self.parse_simple_expr() {
    None => None
    Some(condition) => {
      let open_brace = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after if condition.")
          return None
        }
      }
      // Parse then expression (single expression, not statements)
      let then_expr = match self.parse_simple_expr() {
        None => {
          self.error(self.peek(), "Expected expression in if then branch.")
          return None
        }
        Some(expr) => expr
      }
      let close_brace = match self.peek().kind {
        TokenKind::RBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '}' after if then expression.")
          return None
        }
      }
      // Parse else clause (required for if expression)
      let else_keyword = match self.peek().kind {
        TokenKind::KeywordElse => self.advance()
        _ => {
          self.error(self.peek(), "Expected 'else' clause in if expression.")
          return None
        }
      }
      let else_open_brace = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after else.")
          return None
        }
      }
      // Parse else expression (single expression, not statements)
      let else_expr = match self.parse_simple_expr() {
        None => {
          self.error(self.peek(), "Expected expression in if else branch.")
          return None
        }
        Some(expr) => expr
      }
      let else_close_brace = match self.peek().kind {
        TokenKind::RBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '}' after if else expression.")
          return None
        }
      }
      let range = combine_ranges(keyword.range, else_close_brace.range)
      let if_expr : IfExpr = {
        keyword,
        condition,
        open_brace,
        then_expr,
        close_brace,
        else_keyword,
        else_open_brace,
        else_expr,
        else_close_brace,
        range,
      }
      let expr : Expr = { kind: ExprKind::If(if_expr), range }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_while_statement(self : Parser) -> Stmt? {
  let keyword = self.advance()
  match self.parse_simple_expr() {
    None => None
    Some(condition) => {
      let open_brace = match self.peek().kind {
        TokenKind::LBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '{' after while condition.")
          return None
        }
      }
      let body : Array[Stmt] = Array::new()
      while !self.is_at_end() {
        match self.peek().kind {
          TokenKind::RBrace => break
          TokenKind::Semicolon => {
            // Skip standalone semicolons (empty statements)
            let _ = self.advance()

          }
          _ =>
            match self.parse_statement() {
              Some(stmt) => body.push(stmt)
              None => self.synchronize()
            }
        }
      }
      let close_brace = match self.peek().kind {
        TokenKind::RBrace => self.advance()
        _ => {
          self.error(self.peek(), "Expected '}' to close while body.")
          return None
        }
      }
      let range = combine_ranges(keyword.range, close_brace.range)
      let info : WhileStmt = {
        keyword,
        condition,
        open_brace,
        body,
        close_brace,
        range,
      }
      let stmt : Stmt = { kind: StmtKind::While(info), range }
      Some(stmt)
    }
  }
}

///|
fn Parser::parse_function_declaration(self : Parser) -> Stmt? {
  let fn_keyword = self.advance()
  let name = match self.peek().kind {
    TokenKind::Ident => self.advance()
    _ => {
      self.error(self.peek(), "Expected function name after 'fn'.")
      return None
    }
  }
  let mut open_paren : Token? = None
  let mut close_paren : Token? = None
  let parameters : Array[FunctionParam] = Array::new()
  match self.peek().kind {
    TokenKind::LParen => {
      open_paren = Some(self.advance())
      match self.peek().kind {
        TokenKind::RParen => close_paren = Some(self.advance())
        _ =>
          for {
            if self.is_at_end() {
              break
            }
            match self.peek().kind {
              TokenKind::RParen => {
                close_paren = Some(self.advance())
                break
              }
              TokenKind::Ident => {
                let param_name = self.advance()
                let mut colon : Token? = None
                let mut type_name : Token? = None
                let mut element_type_name : Token? = None
                match self.peek().kind {
                  TokenKind::Colon => {
                    colon = Some(self.advance())
                    // Try to parse function type: (Type) -> Type
                    match self.peek().kind {
                      TokenKind::LParen => {
                        // Could be function type: (Type) -> Type or tuple type: (Type, Type, ...)
                        let _ = self.advance() // consume LParen
                        match self.peek().kind {
                          TokenKind::RParen => {
                            // Empty parens - could be function type () -> Type
                            let _ = self.advance() // consume RParen
                            match self.peek().kind {
                              TokenKind::Arrow | TokenKind::ThinArrow => {
                                let _ = self.advance() // consume ->
                                match self.peek().kind {
                                  TokenKind::Ident => {
                                    let _ = self.advance()
                                    // consume return type
                                  }
                                  _ =>
                                    self.error(
                                      self.peek(),
                                      "Expected return type after '->'.",
                                    )
                                }
                              }
                              _ =>
                                self.error(
                                  self.peek(),
                                  "Expected '->' after function parameter types.",
                                )
                            }
                          }
                          TokenKind::Ident => {
                            let _ = self.advance() // consume first type
                            match self.peek().kind {
                              TokenKind::Comma => {
                                // Tuple type: (Type, Type, ...)
                                let _ = self.advance() // consume comma
                                // Parse remaining tuple elements
                                for {
                                  if self.is_at_end() {
                                    break
                                  }
                                  match self.peek().kind {
                                    TokenKind::RParen => {
                                      let _ = self.advance() // consume RParen
                                      break
                                    }
                                    TokenKind::Ident => {
                                      let _ = self.advance() // consume type
                                      match self.peek().kind {
                                        TokenKind::Comma => {
                                          let _ = self.advance()
                                          // consume comma
                                        }
                                        TokenKind::RParen => {
                                          let _ = self.advance() // consume RParen
                                          break
                                        }
                                        _ => {
                                          self.error(
                                            self.peek(),
                                            "Expected ',' or ')' in tuple type.",
                                          )
                                          break
                                        }
                                      }
                                    }
                                    _ => {
                                      self.error(
                                        self.peek(),
                                        "Expected type name in tuple type.",
                                      )
                                      break
                                    }
                                  }
                                }
                              }
                              TokenKind::RParen => {
                                // Single type in parens - could be function type (Type) -> Type
                                let _ = self.advance() // consume RParen
                                match self.peek().kind {
                                  TokenKind::Arrow | TokenKind::ThinArrow => {
                                    let _ = self.advance() // consume ->
                                    match self.peek().kind {
                                      TokenKind::Ident => {
                                        let _ = self.advance()
                                        // consume return type
                                      }
                                      _ =>
                                        self.error(
                                          self.peek(),
                                          "Expected return type after '->'.",
                                        )
                                    }
                                  }
                                  _ =>
                                    self.error(
                                      self.peek(),
                                      "Expected '->' after function parameter types.",
                                    )
                                }
                              }
                              _ =>
                                self.error(
                                  self.peek(),
                                  "Expected ',' or ')' after type in parameter type.",
                                )
                            }
                          }
                          _ =>
                            self.error(
                              self.peek(),
                              "Expected type name in function or tuple type.",
                            )
                        }
                      }
                      TokenKind::Ident => {
                        // Check for Array[Type] syntax
                        let type_token = self.advance() // consume type token
                        match self.peek().kind {
                          TokenKind::LBracket => {
                            // Array[Type] syntax
                            let _ = self.advance() // consume [
                            // Parse element type (could be Int, Bool, or function type)
                            match self.peek().kind {
                              TokenKind::LParen => {
                                // Array[(Type) -> Type] - function type as element
                                let _ = self.advance() // consume LParen
                                match self.peek().kind {
                                  TokenKind::RParen => {
                                    let _ = self.advance() // consume RParen
                                    match self.peek().kind {
                                      TokenKind::Arrow | TokenKind::ThinArrow => {
                                        let _ = self.advance() // consume ->
                                        match self.peek().kind {
                                          TokenKind::Ident => {
                                            let _ = self.advance() // consume return type
                                            match self.peek().kind {
                                              TokenKind::RBracket => {
                                                let _ = self.advance()
                                                // consume ]
                                              }
                                              _ =>
                                                self.error(
                                                  self.peek(),
                                                  "Expected ']' after array element type.",
                                                )
                                            }
                                          }
                                          _ =>
                                            self.error(
                                              self.peek(),
                                              "Expected return type after '->'.",
                                            )
                                        }
                                      }
                                      _ =>
                                        self.error(
                                          self.peek(),
                                          "Expected '->' after function parameter types.",
                                        )
                                    }
                                  }
                                  TokenKind::Ident => {
                                    let _ = self.advance() // consume param type
                                    match self.peek().kind {
                                      TokenKind::RParen => {
                                        let _ = self.advance() // consume RParen
                                        match self.peek().kind {
                                          TokenKind::Arrow
                                          | TokenKind::ThinArrow => {
                                            let _ = self.advance() // consume ->
                                            match self.peek().kind {
                                              TokenKind::Ident => {
                                                let _ = self.advance() // consume return type
                                                match self.peek().kind {
                                                  TokenKind::RBracket => {
                                                    let _ = self.advance()
                                                    // consume ]
                                                  }
                                                  _ =>
                                                    self.error(
                                                      self.peek(),
                                                      "Expected ']' after array element type.",
                                                    )
                                                }
                                              }
                                              _ =>
                                                self.error(
                                                  self.peek(),
                                                  "Expected return type after '->'.",
                                                )
                                            }
                                          }
                                          _ =>
                                            self.error(
                                              self.peek(),
                                              "Expected '->' after function parameter types.",
                                            )
                                        }
                                      }
                                      _ =>
                                        self.error(
                                          self.peek(),
                                          "Expected ')' after function parameter type.",
                                        )
                                    }
                                  }
                                  _ =>
                                    self.error(
                                      self.peek(),
                                      "Expected type name in function type.",
                                    )
                                }
                              }
                              TokenKind::Ident => {
                                let element_type_token = self.advance() // consume element type
                                element_type_name = Some(element_type_token) // Set element type in outer scope
                                // Check for nested Array[Type] or closing bracket
                                for {
                                  match self.peek().kind {
                                    TokenKind::LBracket => {
                                      // Nested Array[Type] - parse recursively
                                      let _ = self.advance() // consume [
                                      match self.peek().kind {
                                        TokenKind::Ident => {
                                          let nested_element = self.advance() // consume nested element type
                                          element_type_name = Some(
                                            nested_element,
                                          ) // Update element type for nested array
                                          match self.peek().kind {
                                            TokenKind::RBracket => {
                                              let _ = self.advance() // consume ]
                                              // Check for closing bracket of outer array
                                              match self.peek().kind {
                                                TokenKind::RBracket => {
                                                  let _ = self.advance() // consume ]
                                                  break
                                                }
                                                _ =>
                                                  self.error(
                                                    self.peek(),
                                                    "Expected ']' after nested array element type.",
                                                  )
                                              }
                                            }
                                            _ =>
                                              self.error(
                                                self.peek(),
                                                "Expected ']' after nested array element type.",
                                              )
                                          }
                                        }
                                        _ =>
                                          self.error(
                                            self.peek(),
                                            "Expected element type in nested Array[Type].",
                                          )
                                      }
                                    }
                                    TokenKind::RBracket => {
                                      let _ = self.advance() // consume ]
                                      break
                                    }
                                    _ => {
                                      self.error(
                                        self.peek(),
                                        "Expected ']' after array element type.",
                                      )
                                      break
                                    }
                                  }
                                }
                                type_name = Some(type_token) // Store Array token as type name
                                // element_type_name is already set above
                              }
                              _ =>
                                self.error(
                                  self.peek(),
                                  "Expected element type in Array[Type].",
                                )
                            }
                            type_name = Some(type_token) // Store Array token as type name
                            // element_type_name should be set in the TokenKind::Ident branch above
                          }
                          _ => type_name = Some(type_token) // Regular type name
                          // No element type for non-Array types
                        }
                      }
                      _ =>
                        self.error(self.peek(), "Expected type name after ':'.")
                    }
                    let param : FunctionParam = {
                      name: param_name,
                      colon,
                      type_name,
                      element_type_name,
                    }
                    parameters.push(param)
                  }
                  _ => {
                    // No type annotation
                    let param : FunctionParam = {
                      name: param_name,
                      colon: None,
                      type_name: None,
                      element_type_name: None,
                    }
                    parameters.push(param)
                  }
                }
                match self.peek().kind {
                  TokenKind::Comma => {
                    let _ = self.advance()

                  }
                  TokenKind::RParen => ()
                  _ =>
                    self.error(
                      self.peek(),
                      "Expected ',' or ')' after parameter.",
                    )
                }
              }
              _ => {
                self.error(self.peek(), "Expected parameter name.")
                let _ = self.advance()

              }
            }
          }
      }
      match close_paren {
        Some(_) => ()
        None => {
          self.error(self.peek(), "Expected ')' after function parameters.")
          return None
        }
      }
    }
    TokenKind::LBrace => ()
    TokenKind::Arrow => ()
    TokenKind::ThinArrow => ()
    _ => {
      self.error(self.peek(), "Expected '(' or '{' after function name.")
      return None
    }
  }
  let mut arrow : Token? = None
  let mut return_type : Token? = None
  match self.peek().kind {
    TokenKind::Arrow => {
      arrow = Some(self.advance())
      // Try to parse function type: (Type) -> Type
      match self.peek().kind {
        TokenKind::LParen => {
          // Function type: (Type) -> Type
          let _ = self.advance() // consume LParen
          match self.peek().kind {
            TokenKind::RParen => {
              let _ = self.advance() // consume RParen
              match self.peek().kind {
                TokenKind::Arrow | TokenKind::ThinArrow => {
                  let _ = self.advance() // consume ->
                  match self.peek().kind {
                    TokenKind::Ident => return_type = Some(self.advance()) // consume return type
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected return type after '->'.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected '->' after function parameter types.",
                  )
              }
            }
            TokenKind::Ident => {
              let _ = self.advance() // consume param type
              match self.peek().kind {
                TokenKind::RParen => {
                  let _ = self.advance() // consume RParen
                  match self.peek().kind {
                    TokenKind::Arrow | TokenKind::ThinArrow => {
                      let _ = self.advance() // consume ->
                      match self.peek().kind {
                        TokenKind::Ident => return_type = Some(self.advance()) // consume return type
                        _ =>
                          self.error(
                            self.peek(),
                            "Expected return type after '->'.",
                          )
                      }
                    }
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected '->' after function parameter types.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected ')' after function parameter type.",
                  )
              }
            }
            _ => self.error(self.peek(), "Expected type name in function type.")
          }
        }
        TokenKind::Ident => return_type = Some(self.advance())
        _ => self.error(self.peek(), "Expected return type after '->'.")
      }
    }
    TokenKind::ThinArrow => {
      arrow = Some(self.advance())
      // Try to parse function type: (Type) -> Type
      match self.peek().kind {
        TokenKind::LParen => {
          // Function type: (Type) -> Type
          let _ = self.advance() // consume LParen
          match self.peek().kind {
            TokenKind::RParen => {
              let _ = self.advance() // consume RParen
              match self.peek().kind {
                TokenKind::Arrow | TokenKind::ThinArrow => {
                  let _ = self.advance() // consume ->
                  match self.peek().kind {
                    TokenKind::Ident => return_type = Some(self.advance()) // consume return type
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected return type after '->'.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected '->' after function parameter types.",
                  )
              }
            }
            TokenKind::Ident => {
              let _ = self.advance() // consume param type
              match self.peek().kind {
                TokenKind::RParen => {
                  let _ = self.advance() // consume RParen
                  match self.peek().kind {
                    TokenKind::Arrow | TokenKind::ThinArrow => {
                      let _ = self.advance() // consume ->
                      match self.peek().kind {
                        TokenKind::Ident => return_type = Some(self.advance()) // consume return type
                        _ =>
                          self.error(
                            self.peek(),
                            "Expected return type after '->'.",
                          )
                      }
                    }
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected '->' after function parameter types.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected ')' after function parameter type.",
                  )
              }
            }
            _ => self.error(self.peek(), "Expected type name in function type.")
          }
        }
        TokenKind::Ident => {
          // Check for Array[Type] syntax
          let type_token = self.advance()
          match self.peek().kind {
            TokenKind::LBracket => {
              // Array[Type] syntax
              let _ = self.advance() // consume [
              // Parse element type (could be Int, Bool, or nested Array[Type])
              match self.peek().kind {
                TokenKind::Ident => {
                  let _ = self.advance() // consume element type
                  match self.peek().kind {
                    TokenKind::RBracket => {
                      let _ = self.advance()
                      // consume ]
                    }
                    TokenKind::LBracket => {
                      // Nested Array[Array[Type]]
                      let _ = self.advance() // consume [
                      match self.peek().kind {
                        TokenKind::Ident => {
                          let _ = self.advance() // consume nested element type
                          match self.peek().kind {
                            TokenKind::RBracket => {
                              let _ = self.advance() // consume ]
                              match self.peek().kind {
                                TokenKind::RBracket => {
                                  let _ = self.advance()
                                  // consume outer ]
                                }
                                _ =>
                                  self.error(
                                    self.peek(),
                                    "Expected ']' after nested array type.",
                                  )
                              }
                            }
                            _ =>
                              self.error(
                                self.peek(),
                                "Expected ']' after nested array element type.",
                              )
                          }
                        }
                        _ =>
                          self.error(
                            self.peek(),
                            "Expected element type in nested Array[Type].",
                          )
                      }
                    }
                    _ =>
                      self.error(
                        self.peek(),
                        "Expected ']' after array element type.",
                      )
                  }
                }
                _ =>
                  self.error(
                    self.peek(),
                    "Expected element type in Array[Type].",
                  )
              }
              return_type = Some(type_token) // Use the Array token as return type
            }
            _ => return_type = Some(type_token) // Regular type name
          }
        }
        _ => self.error(self.peek(), "Expected return type after '->'.")
      }
    }
    _ => ()
  }
  // Function body can be either { ... } or a single expression
  let mut open_brace : Token? = None
  let mut close_brace : Token? = None
  let body : Array[Stmt] = Array::new()
  match self.peek().kind {
    TokenKind::LBrace => {
      open_brace = Some(self.advance())
      while !self.is_at_end() {
        match self.peek().kind {
          TokenKind::RBrace => break
          TokenKind::Semicolon => {
            // Skip standalone semicolons (empty statements)
            let _ = self.advance()

          }
          _ =>
            match self.parse_statement() {
              Some(stmt) => body.push(stmt)
              None => self.synchronize()
            }
        }
      }
      close_brace = match self.peek().kind {
        TokenKind::RBrace => Some(self.advance())
        _ => {
          self.error(self.peek(), "Expected '}' to close function body.")
          return None
        }
      }
    }
    _ => {
      // Single expression function body (no braces)
      // Create dummy braces for AST structure
      let dummy_brace : Token = {
        kind: TokenKind::LBrace,
        range: fn_keyword.range,
        lexeme: "{",
      }
      open_brace = Some(dummy_brace)
      match self.parse_simple_expr() {
        Some(expr) => {
          let expr_stmt : Stmt = {
            kind: StmtKind::ExprStmt(expr),
            range: expr.range,
          }
          body.push(expr_stmt)
          let dummy_close_brace : Token = {
            kind: TokenKind::RBrace,
            range: expr.range,
            lexeme: "}",
          }
          close_brace = Some(dummy_close_brace)
        }
        None => {
          self.error(self.peek(), "Expected function body.")
          return None
        }
      }
    }
  }
  let range = combine_ranges(
    fn_keyword.range,
    match close_brace {
      Some(close) => close.range
      None => fn_keyword.range
    },
  )
  let info : FunctionStmt = {
    fn_keyword,
    name,
    open_paren,
    parameters,
    close_paren,
    arrow,
    return_type,
    open_brace: match open_brace {
      Some(brace) => brace
      None => {
        let dummy : Token = {
          kind: TokenKind::LBrace,
          range: fn_keyword.range,
          lexeme: "{",
        }
        dummy
      }
    },
    body,
    close_brace: match close_brace {
      Some(brace) => brace
      None => {
        let dummy : Token = {
          kind: TokenKind::RBrace,
          range: fn_keyword.range,
          lexeme: "}",
        }
        dummy
      }
    },
    range,
  }
  let stmt : Stmt = { kind: StmtKind::Function(info), range }
  Some(stmt)
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
  self.parse_or_expr(allow_struct_literal)
}

///|
fn Parser::parse_or_expr(self : Parser, allow_struct_literal : Bool) -> Expr? {
  match self.parse_and_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::PipePipe => {
            let operator = self.advance()
            match self.parse_and_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_and_expr(self : Parser, allow_struct_literal : Bool) -> Expr? {
  match self.parse_equality_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::AmpAmp => {
            let operator = self.advance()
            match self.parse_equality_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_equality_expr(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  match self.parse_comparison_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::EqualEqual | TokenKind::BangEqual => {
            let operator = self.advance()
            match self.parse_comparison_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_comparison_expr(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  match self.parse_additive_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::Greater
          | TokenKind::GreaterEqual
          | TokenKind::Less
          | TokenKind::LessEqual => {
            let operator = self.advance()
            match self.parse_additive_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_additive_expr(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  match self.parse_multiplicative_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::Plus | TokenKind::Minus => {
            let operator = self.advance()
            match self.parse_multiplicative_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_multiplicative_expr(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  match self.parse_unary_expr(allow_struct_literal) {
    None => None
    Some(initial) => {
      let mut expr = initial
      for {
        match self.peek().kind {
          TokenKind::Star | TokenKind::Slash | TokenKind::Percent => {
            let operator = self.advance()
            match self.parse_unary_expr(false) {
              Some(right) => expr = make_binary_expr(expr, operator, right)
              None => return None
            }
          }
          _ => break
        }
      }
      Some(expr)
    }
  }
}

///|
fn Parser::parse_unary_expr(
  self : Parser,
  allow_struct_literal : Bool,
) -> Expr? {
  match self.peek().kind {
    TokenKind::Bang | TokenKind::Minus => {
      let operator = self.advance()
      match self.parse_unary_expr(allow_struct_literal) {
        Some(operand) => Some(make_unary_expr(operator, operand))
        None => None
      }
    }
    _ => self.parse_primary_expr(allow_struct_literal)
  }
}

///|
fn Parser::parse_primary_expr(
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
    | TokenKind::LiteralFloat
    | TokenKind::LiteralBool => {
      let literal = self.advance()
      let expr : Expr = {
        kind: ExprKind::Literal(literal),
        range: literal.range,
      }
      Some(expr)
    }
    TokenKind::LParen => self.parse_grouping_expr()
    TokenKind::LBracket => self.parse_array_literal()
    TokenKind::KeywordIf => self.parse_if_expression()
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
fn make_binary_expr(left : Expr, operator : Token, right : Expr) -> Expr {
  let range = combine_ranges(left.range, right.range)
  let binary : BinaryExpr = { left, operator, right, range }
  { kind: ExprKind::Binary(binary), range }
}

///|
fn make_unary_expr(operator : Token, operand : Expr) -> Expr {
  let range = combine_ranges(operator.range, operand.range)
  let unary : UnaryExpr = { operator, operand, range }
  { kind: ExprKind::Unary(unary), range }
}

///|
fn Parser::parse_postfix_expr(self : Parser, base : Expr) -> Expr? {
  let mut expr = base
  for {
    match self.peek().kind {
      TokenKind::Dot => {
        // Field access: expr.field
        let dot = self.advance()
        let field = match self.peek().kind {
          TokenKind::Ident => self.advance()
          _ => {
            self.error(self.peek(), "Expected field name after '.'.")
            return None
          }
        }
        let field_range = combine_ranges(expr.range, field.range)
        let field_access : FieldAccessExpr = {
          object: expr,
          dot,
          field,
          range: field_range,
        }
        expr = { kind: ExprKind::FieldAccess(field_access), range: field_range }
      }
      TokenKind::LBracket => {
        let open_bracket = self.advance()
        match self.parse_simple_expr() {
          None => {
            self.error(self.peek(), "Expected expression in array index.")
            return None
          }
          Some(index_expr) => {
            let close_bracket = match self.peek().kind {
              TokenKind::RBracket => self.advance()
              _ => {
                self.error(self.peek(), "Expected ']' after array index.")
                return None
              }
            }
            let index_range = combine_ranges(expr.range, close_bracket.range)
            let index_expr_struct : IndexExpr = {
              array: expr,
              open_bracket,
              index: index_expr,
              close_bracket,
              range: index_range,
            }
            expr = {
              kind: ExprKind::Index(index_expr_struct),
              range: index_range,
            }
          }
        }
      }
      TokenKind::LParen => {
        let open_paren = self.advance()
        let arguments : Array[Expr] = Array::new()
        match self.peek().kind {
          TokenKind::RParen => {
            let close_paren = self.advance()
            let call_range = combine_ranges(expr.range, close_paren.range)
            let call_expr : CallExpr = {
              callee: expr,
              open_paren,
              arguments,
              close_paren,
              range: call_range,
            }
            expr = { kind: ExprKind::Call(call_expr), range: call_range }
          }
          _ =>
            for {
              if self.is_at_end() {
                self.error(self.peek(), "Unterminated function call.")
                return None
              }
              match self.parse_simple_expr() {
                None => {
                  self.error(
                    self.peek(),
                    "Expected expression in function call.",
                  )
                  return None
                }
                Some(arg) => {
                  arguments.push(arg)
                  match self.peek().kind {
                    TokenKind::Comma => {
                      let _ = self.advance()

                    }
                    TokenKind::RParen => {
                      let close_paren = self.advance()
                      let call_range = combine_ranges(
                        expr.range,
                        close_paren.range,
                      )
                      let call_expr : CallExpr = {
                        callee: expr,
                        open_paren,
                        arguments,
                        close_paren,
                        range: call_range,
                      }
                      expr = {
                        kind: ExprKind::Call(call_expr),
                        range: call_range,
                      }
                      break
                    }
                    _ => {
                      self.error(
                        self.peek(),
                        "Expected ',' or ')' after argument.",
                      )
                      return None
                    }
                  }
                }
              }
            }
        }
      }
      _ => break
    }
  }
  Some(expr)
}

///|
fn Parser::parse_call_expr(self : Parser, callee : Expr) -> Expr? {
  self.parse_postfix_expr(callee)
}

///|
fn Parser::parse_array_literal(self : Parser) -> Expr? {
  let open_bracket = self.advance()
  let elements : Array[Expr] = Array::new()
  match self.peek().kind {
    TokenKind::RBracket => {
      let close_bracket = self.advance()
      let range = combine_ranges(open_bracket.range, close_bracket.range)
      let array_lit : ArrayLiteral = {
        open_bracket,
        elements,
        close_bracket,
        range,
      }
      let expr : Expr = { kind: ExprKind::ArrayLiteral(array_lit), range }
      Some(expr)
    }
    _ =>
      for {
        if self.is_at_end() {
          self.error(self.peek(), "Unterminated array literal.")
          return None
        }
        match self.parse_simple_expr() {
          None => {
            self.error(self.peek(), "Expected expression in array literal.")
            return None
          }
          Some(element) => {
            elements.push(element)
            match self.peek().kind {
              TokenKind::Comma => {
                let _ = self.advance()

              }
              TokenKind::RBracket => {
                let close_bracket = self.advance()
                let range = combine_ranges(
                  open_bracket.range,
                  close_bracket.range,
                )
                let array_lit : ArrayLiteral = {
                  open_bracket,
                  elements,
                  close_bracket,
                  range,
                }
                let expr : Expr = {
                  kind: ExprKind::ArrayLiteral(array_lit),
                  range,
                }
                return Some(expr)
              }
              _ => {
                self.error(
                  self.peek(),
                  "Expected ',' or ']' after array element.",
                )
                return None
              }
            }
          }
        }
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
  // If there's a qualifier, create a FieldAccess expression (Array::make)
  let base_expr : Expr = if qualifier.length() > 0 {
    // Build nested field access: qualifier[0]::qualifier[1]::...::name
    let mut current_expr : Expr = {
      kind: ExprKind::Ident(qualifier[0]),
      range: qualifier[0].range,
    }
    let mut i = 1
    while i < qualifier.length() {
      // Create a dummy dot token for ::
      let dummy_dot : Token = {
        kind: TokenKind::Dot,
        range: qualifier[i - 1].range,
        lexeme: "::",
      }
      let field_range = combine_ranges(current_expr.range, qualifier[i].range)
      let field_access : FieldAccessExpr = {
        object: current_expr,
        dot: dummy_dot,
        field: qualifier[i],
        range: field_range,
      }
      current_expr = {
        kind: ExprKind::FieldAccess(field_access),
        range: field_range,
      }
      i = i + 1
    }
    // Add the final name as a field access
    let dummy_dot : Token = {
      kind: TokenKind::Dot,
      range: if qualifier.length() > 0 {
        qualifier[qualifier.length() - 1].range
      } else {
        first.range
      },
      lexeme: "::",
    }
    let final_range = combine_ranges(current_expr.range, name.range)
    let final_field_access : FieldAccessExpr = {
      object: current_expr,
      dot: dummy_dot,
      field: name,
      range: final_range,
    }
    { kind: ExprKind::FieldAccess(final_field_access), range: final_range }
  } else {
    { kind: ExprKind::Ident(name), range }
  }
  // Parse field access (a.x), function calls, and array indexing
  self.parse_postfix_expr(base_expr)
}

///|
fn Parser::parse_grouping_expr(self : Parser) -> Expr? {
  let open = self.advance()
  match self.peek().kind {
    TokenKind::RParen => {
      let close = self.advance()
      let range = combine_ranges(open.range, close.range)
      let unit_token : Token = {
        kind: TokenKind::LiteralBool,
        range,
        lexeme: "()",
      }
      let expr : Expr = { kind: ExprKind::Literal(unit_token), range }
      Some(expr)
    }
    _ => {
      // Try to parse as tuple literal (multiple expressions separated by commas)
      let elements : Array[Expr] = Array::new()
      match self.parse_simple_expr() {
        None => None
        Some(first_expr) => {
          elements.push(first_expr)
          // Check if there are more elements (comma-separated)
          let mut is_tuple = false
          while !self.is_at_end() {
            match self.peek().kind {
              TokenKind::Comma => {
                is_tuple = true
                let _ = self.advance()
                match self.parse_simple_expr() {
                  None => {
                    self.error(
                      self.peek(),
                      "Expected expression after ',' in tuple.",
                    )
                    return None
                  }
                  Some(expr) => elements.push(expr)
                }
              }
              TokenKind::RParen => break
              _ => {
                self.error(self.peek(), "Expected ',' or ')' in tuple.")
                return None
              }
            }
          }
          let close = match self.peek().kind {
            TokenKind::RParen => self.advance()
            _ => {
              self.error(self.peek(), "Expected ')' after tuple elements.")
              return None
            }
          }
          let range = combine_ranges(open.range, close.range)
          if is_tuple || elements.length() > 1 {
            // It's a tuple literal
            let tuple_lit : TupleLiteral = {
              open_paren: open,
              elements,
              close_paren: close,
              range,
            }
            let expr : Expr = { kind: ExprKind::TupleLiteral(tuple_lit), range }
            // Allow chained calls after tuple
            self.parse_call_expr(expr)
          } else {
            // It's a grouping expression (single expression in parentheses)
            let grouped_expr = elements[0]
            let kind = grouped_expr.kind
            let grouped : Expr = { kind, range }
            // Allow chained calls after grouping (e.g., (f())(args))
            self.parse_call_expr(grouped)
          }
        }
      }
    }
  }
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
        TokenKind::ThinArrow => self.advance()
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
        TokenKind::ThinArrow => self.advance()
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
    TokenKind::ThinArrow => self.advance()
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
          TokenKind::LBrace =>
            // Point::{ ... } - stop collecting path here
            // The ::{ will be handled by parse_struct_literal
            break
          _ => {
            self.error(self.peek(), "Expected identifier or '{' after '::'.")
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

///|
fn Parser::parse_struct_definition(self : Parser) -> Stmt? {
  let keyword = self.advance()
  let name = match self.peek().kind {
    TokenKind::Ident => self.advance()
    _ => {
      self.error(self.peek(), "Expected struct name after 'struct'.")
      return None
    }
  }
  let open_brace = match self.peek().kind {
    TokenKind::LBrace => self.advance()
    _ => {
      self.error(self.peek(), "Expected '{' after struct name.")
      return None
    }
  }
  let fields : Array[StructFieldDef] = Array::new()
  while !self.is_at_end() {
    match self.peek().kind {
      TokenKind::RBrace => break
      TokenKind::Semicolon => {
        // Skip standalone semicolons
        let _ = self.advance()

      }
      _ => {
        // Parse field definition: name: Type;
        let field_name = match self.peek().kind {
          TokenKind::Ident => self.advance()
          _ => {
            self.error(self.peek(), "Expected field name in struct definition.")
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
        // Parse type name (could be simple type or Array[Type])
        let type_name = match self.peek().kind {
          TokenKind::Ident => {
            let type_token = self.advance()
            // Check for Array[Type] syntax
            match self.peek().kind {
              TokenKind::LBracket => {
                // Array[Type] syntax
                let _ = self.advance() // consume [
                match self.peek().kind {
                  TokenKind::Ident => {
                    let _ = self.advance() // consume element type
                    match self.peek().kind {
                      TokenKind::RBracket => {
                        let _ = self.advance()
                        // consume ]
                      }
                      _ => {
                        self.error(
                          self.peek(),
                          "Expected ']' after array element type.",
                        )
                        return None
                      }
                    }
                  }
                  _ => {
                    self.error(
                      self.peek(),
                      "Expected element type in Array[Type].",
                    )
                    return None
                  }
                }
                type_token // Use the Array token as type name
              }
              _ => type_token // Regular type name
            }
          }
          _ => {
            self.error(self.peek(), "Expected type name after ':'.")
            return None
          }
        }
        let semicolon = match self.peek().kind {
          TokenKind::Semicolon => self.advance()
          _ => {
            self.error(self.peek(), "Expected ';' after struct field.")
            return None
          }
        }
        let field_range = combine_ranges(field_name.range, semicolon.range)
        let field : StructFieldDef = {
          name: field_name,
          colon,
          type_name,
          semicolon,
          range: field_range,
        }
        fields.push(field)
      }
    }
  }
  let close_brace = match self.peek().kind {
    TokenKind::RBrace => self.advance()
    _ => {
      self.error(self.peek(), "Expected '}' to close struct definition.")
      return None
    }
  }
  let range = combine_ranges(keyword.range, close_brace.range)
  let struct_def : StructDef = {
    keyword,
    name,
    open_brace,
    fields,
    close_brace,
    range,
  }
  let stmt : Stmt = { kind: StmtKind::Struct(struct_def), range }
  Some(stmt)
}
