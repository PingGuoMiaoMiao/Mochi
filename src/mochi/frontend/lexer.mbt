///|
pub struct LexError {
  message : String
  range : SourceRange
}

///|
pub struct LexResult {
  tokens : Array[Token]
  errors : Array[LexError]
}

///|
priv struct Scanner {
  view : StringView
  length : Int
  mut index : Int
  mut line : Int
  mut column : Int
  mut token_start_index : Int
  mut token_start_line : Int
  mut token_start_column : Int
  tokens : Array[Token]
  errors : Array[LexError]
}

///|
fn Scanner::make(source : String) -> Scanner {
  let view = source[:]
  let tokens : Array[Token] = Array::new()
  let errors : Array[LexError] = Array::new()
  {
    view,
    length: view.length(),
    index: 0,
    line: 0,
    column: 0,
    token_start_index: 0,
    token_start_line: 0,
    token_start_column: 0,
    tokens,
    errors,
  }
}

///|
fn Scanner::scan_all(self : Scanner) -> LexResult {
  for {
    self.skip_trivia()
    if self.is_at_end() {
      break
    }
    self.begin_token()
    self.scan_token()
  }
  self.emit_eof_token()
  { tokens: self.tokens, errors: self.errors }
}

///|
fn Scanner::skip_trivia(self : Scanner) -> Unit {
  for {
    if self.is_at_end() {
      return
    }
    let ch = self.peek()
    match ch {
      ' ' | '\t' | '\r' | '\n' => {
        let _ = self.advance()

      }
      '/' =>
        if self.peek_next() == '/' {
          self.consume_line_comment()
        } else {
          return
        }
      _ => return
    }
  }
}

///|
fn Scanner::consume_line_comment(self : Scanner) -> Unit {
  for {
    if self.is_at_end() {
      return
    }
    let ch = self.peek()
    if ch == '\n' {
      return
    }
    let _ = self.advance()

  }
}

///|
fn Scanner::begin_token(self : Scanner) -> Unit {
  self.token_start_index = self.index
  self.token_start_line = self.line
  self.token_start_column = self.column
}

///|
fn Scanner::scan_token(self : Scanner) -> Unit {
  let ch = self.advance()
  if is_alpha(ch) {
    self.scan_identifier_or_keyword()
    return
  }
  if ch == '_' {
    if is_identifier_char(self.peek()) {
      self.scan_identifier_or_keyword()
    } else {
      self.emit_token(TokenKind::Underscore)
    }
    return
  }
  if is_digit(ch) {
    self.scan_number(ch)
    return
  }
  match ch {
    '"' => self.scan_string()
    '\'' => self.scan_char_literal()
    '{' => self.emit_token(TokenKind::LBrace)
    '}' => self.emit_token(TokenKind::RBrace)
    '(' => self.emit_token(TokenKind::LParen)
    ')' => self.emit_token(TokenKind::RParen)
    ',' => self.emit_token(TokenKind::Comma)
    ';' => self.emit_token(TokenKind::Semicolon)
    ':' =>
      if self.match_char(':') {
        self.emit_token(TokenKind::DoubleColon)
      } else {
        self.emit_token(TokenKind::Colon)
      }
    '.' => self.emit_token(TokenKind::Dot)
    '[' => self.emit_token(TokenKind::LBracket)
    ']' => self.emit_token(TokenKind::RBracket)
    '|' =>
      if self.match_char('|') {
        self.emit_token(TokenKind::PipePipe)
      } else {
        self.emit_token(TokenKind::Pipe)
      }
    '&' =>
      if self.match_char('&') {
        self.emit_token(TokenKind::AmpAmp)
      } else {
        self.report_error("Unexpected '&'.")
      }
    '+' => self.emit_token(TokenKind::Plus)
    '-' =>
      if self.match_char('>') {
        self.emit_token(TokenKind::ThinArrow)
      } else {
        self.emit_token(TokenKind::Minus)
      }
    '*' => self.emit_token(TokenKind::Star)
    '/' => self.emit_token(TokenKind::Slash)
    '%' => self.emit_token(TokenKind::Percent)
    '!' =>
      if self.match_char('=') {
        self.emit_token(TokenKind::BangEqual)
      } else {
        self.emit_token(TokenKind::Bang)
      }
    '>' =>
      if self.match_char('=') {
        self.emit_token(TokenKind::GreaterEqual)
      } else {
        self.emit_token(TokenKind::Greater)
      }
    '<' =>
      if self.match_char('=') {
        self.emit_token(TokenKind::LessEqual)
      } else {
        self.emit_token(TokenKind::Less)
      }
    '=' =>
      if self.match_char('>') {
        self.emit_token(TokenKind::Arrow)
      } else if self.match_char('=') {
        self.emit_token(TokenKind::EqualEqual)
      } else {
        self.emit_token(TokenKind::Assign)
      }
    _ => self.report_error("Unexpected character.")
  }
}

///|
fn Scanner::scan_identifier_or_keyword(self : Scanner) -> Unit {
  for {
    let next = self.peek()
    if !self.is_at_end() && is_identifier_char(next) {
      let _ = self.advance()

    } else {
      break
    }
  }
  let lexeme = slice_to_string(self.view, self.token_start_index, self.index)
  let kind = keyword_kind(lexeme)
  self.emit_token(kind)
}

///|
fn keyword_kind(lexeme : String) -> TokenKind {
  match lexeme {
    "guard" => TokenKind::KeywordGuard
    "else" => TokenKind::KeywordElse
    "is" => TokenKind::KeywordIs
    "if" => TokenKind::KeywordIf
    "match" => TokenKind::KeywordMatch
    "switch" => TokenKind::KeywordSwitch
    "case" => TokenKind::KeywordCase
    "default" => TokenKind::KeywordDefault
    "let" => TokenKind::KeywordLet
    "mut" => TokenKind::KeywordMut
    "fn" => TokenKind::KeywordFn
    "return" => TokenKind::KeywordReturn
    "while" => TokenKind::KeywordWhile
    "struct" => TokenKind::KeywordStruct
    "enum" => TokenKind::KeywordEnum
    "true" => TokenKind::LiteralBool
    "false" => TokenKind::LiteralBool
    _ => TokenKind::Ident
  }
}

///|
fn Scanner::scan_number(self : Scanner, first : Char) -> Unit {
  if first == '0' {
    let next = self.peek()
    match next {
      'x' | 'X' => {
        let _ = self.advance()
        if !self.consume_digits(16, false) {
          self.report_error("Invalid numeric literal.")
        }
        self.emit_token(TokenKind::LiteralInt)
        return
      }
      'b' | 'B' => {
        let _ = self.advance()
        if !self.consume_digits(2, false) {
          self.report_error("Invalid numeric literal.")
        }
        self.emit_token(TokenKind::LiteralInt)
        return
      }
      'o' | 'O' => {
        let _ = self.advance()
        if !self.consume_digits(8, false) {
          self.report_error("Invalid numeric literal.")
        }
        self.emit_token(TokenKind::LiteralInt)
        return
      }
      _ => ()
    }
  }
  let _ = self.consume_digits(10, true)
  let mut is_float = false
  if self.peek() == '.' {
    let _ = self.advance()
    let fraction_digits = self.consume_digits(10, false)
    if !fraction_digits {
      self.report_error("Invalid float literal.")
    }
    is_float = true
  }
  if self.peek() == 'e' || self.peek() == 'E' {
    let _ = self.advance()
    if self.peek() == '+' || self.peek() == '-' {
      let _ = self.advance()

    }
    if !self.consume_digits(10, false) {
      self.report_error("Invalid exponent in float literal.")
    }
    is_float = true
  }
  if is_float {
    self.emit_token(TokenKind::LiteralFloat)
  } else {
    self.emit_token(TokenKind::LiteralInt)
  }
}

///|
fn Scanner::consume_digits(
  self : Scanner,
  base : Int,
  allow_empty : Bool,
) -> Bool {
  let mut saw_digit = false
  let mut last_was_underscore = false
  for {
    if self.is_at_end() {
      break
    }
    let next = self.peek()
    if is_digit_in_base(next, base) {
      let _ = self.advance()
      saw_digit = true
      last_was_underscore = false
      continue
    }
    if next == '_' {
      if !saw_digit || last_was_underscore {
        self.report_error("Invalid underscore placement in number.")
      }
      let _ = self.advance()
      last_was_underscore = true
      continue
    }
    break
  }
  if !saw_digit && !allow_empty {
    return false
  }
  if last_was_underscore {
    self.report_error("Numeric literal cannot end with underscore.")
    return true
  }
  true
}

///|
fn Scanner::scan_string(self : Scanner) -> Unit {
  for {
    if self.is_at_end() {
      self.report_error("Unterminated string literal.")
      return
    }
    let ch = self.peek()
    if ch == '"' {
      let _ = self.advance()
      self.emit_token(TokenKind::LiteralString)
      return
    }
    if ch == '\n' || ch == '\r' {
      self.report_error("String literal cannot contain newline.")
      let _ = self.advance()
      if ch == '\r' && self.peek() == '\n' {
        let _ = self.advance()

      }
      self.skip_until_char('"')
      return
    }
    if ch == '\\' {
      let _ = self.advance()
      if !self.consume_escape_sequence() {
        // continue scanning until closing quote
      }
    } else {
      let _ = self.advance()

    }
  }
}

///|
fn Scanner::scan_char_literal(self : Scanner) -> Unit {
  if self.is_at_end() {
    self.report_error("Unterminated char literal.")
    return
  }
  let ch = self.peek()
  if ch == '\'' {
    self.report_error("Char literal cannot be empty.")
    let _ = self.advance()
    self.skip_until_char('\'')
    return
  }
  if ch == '\n' || ch == '\r' {
    self.report_error("Invalid char literal.")
    let _ = self.advance()
    self.skip_until_char('\'')
    return
  }
  if ch == '\\' {
    let _ = self.advance()
    match self.consume_escape_sequence_for_char() {
      Some(_) => ()
      None => {
        self.skip_until_char('\'')
        return
      }
    }
  } else {
    let _ = self.advance()

  }
  if !self.match_char('\'') {
    self.report_error("Unterminated char literal.")
    self.skip_until_char('\'')
    return
  }
  self.emit_token(TokenKind::LiteralChar)
}

///|
fn Scanner::emit_token(self : Scanner, kind : TokenKind) -> Unit {
  let start : SourcePos = {
    index: self.token_start_index,
    line: self.token_start_line,
    column: self.token_start_column,
  }
  let end : SourcePos = {
    index: self.index,
    line: self.line,
    column: self.column,
  }
  let range : SourceRange = { start, end }
  let lexeme = slice_to_string(self.view, self.token_start_index, self.index)
  let token : Token = { kind, range, lexeme }
  self.tokens.push(token)
}

///|
fn Scanner::emit_eof_token(self : Scanner) -> Unit {
  let pos : SourcePos = {
    index: self.index,
    line: self.line,
    column: self.column,
  }
  let range : SourceRange = { start: pos, end: pos }
  let eof : Token = { kind: TokenKind::EndOfFile, range, lexeme: "" }
  self.tokens.push(eof)
}

///|
fn Scanner::report_error(self : Scanner, message : String) -> Unit {
  let start : SourcePos = {
    index: self.token_start_index,
    line: self.token_start_line,
    column: self.token_start_column,
  }
  let end : SourcePos = {
    index: self.index,
    line: self.line,
    column: self.column,
  }
  let range : SourceRange = { start, end }
  let error : LexError = { message, range }
  self.errors.push(error)
}

///|
fn slice_to_string(view : StringView, start : Int, end : Int) -> String {
  let chars : Array[Char] = Array::new()
  let mut idx = start
  for {
    if idx >= end {
      break
    }
    let value = view[idx]
    let ch = Int::unsafe_to_char(value)
    chars.push(ch)
    idx = idx + 1
  }
  String::from_array(chars)
}

///|
fn Scanner::match_char(self : Scanner, expected : Char) -> Bool {
  if self.is_at_end() {
    return false
  }
  let current = self.peek()
  if current != expected {
    return false
  }
  let _ = self.advance()
  true
}

///|
fn Scanner::peek(self : Scanner) -> Char {
  if self.is_at_end() {
    '\u{0}'
  } else {
    to_char(self.view[self.index])
  }
}

///|
fn Scanner::peek_next(self : Scanner) -> Char {
  let next_index = self.index + 1
  if next_index >= self.length {
    '\u{0}'
  } else {
    to_char(self.view[next_index])
  }
}

///|
fn Scanner::advance(self : Scanner) -> Char {
  if self.is_at_end() {
    return '\u{0}'
  }
  let value = self.view[self.index]
  self.index = self.index + 1
  let ch = to_char(value)
  match ch {
    '\n' => {
      self.line = self.line + 1
      self.column = 0
    }
    _ => self.column = self.column + 1
  }
  ch
}

///|
fn Scanner::is_at_end(self : Scanner) -> Bool {
  self.index >= self.length
}

///|
fn to_char(value : Int) -> Char {
  Int::unsafe_to_char(value)
}

///|
fn is_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_identifier_char(ch : Char) -> Bool {
  is_alpha(ch) || is_digit(ch) || ch == '_'
}

///|
fn is_digit_in_base(ch : Char, base : Int) -> Bool {
  if base == 2 {
    return ch == '0' || ch == '1'
  }
  if base == 8 {
    return ch >= '0' && ch <= '7'
  }
  if base == 10 {
    return is_digit(ch)
  }
  if base == 16 {
    if ch >= '0' && ch <= '9' {
      return true
    }
    if ch >= 'a' && ch <= 'f' {
      return true
    }
    if ch >= 'A' && ch <= 'F' {
      return true
    }
    return false
  }
  false
}

///|
fn Scanner::consume_escape_sequence(self : Scanner) -> Bool {
  if self.is_at_end() {
    self.report_error("Invalid escape sequence.")
    return false
  }
  let ch = self.peek()
  match ch {
    '"' | '\\' | '\'' | 'n' | 't' | 'r' => {
      let _ = self.advance()
      true
    }
    'u' => self.consume_unicode_escape()
    _ => {
      self.report_error("Invalid escape sequence.")
      let _ = self.advance()
      false
    }
  }
}

///|
fn Scanner::consume_escape_sequence_for_char(self : Scanner) -> Char? {
  if self.is_at_end() {
    self.report_error("Invalid escape sequence.")
    return None
  }
  let ch = self.peek()
  match ch {
    '\'' | '"' | '\\' | 'n' | 't' | 'r' => {
      let _ = self.advance()
      Some(
        match ch {
          'n' => '\n'
          't' => '\t'
          'r' => '\r'
          '\'' => '\''
          '"' => '"'
          '\\' => '\\'
          _ => ch
        },
      )
    }
    'u' =>
      match self.consume_unicode_escape_char() {
        Some(unicode_char) => Some(unicode_char)
        None => None
      }
    _ => {
      self.report_error("Invalid escape sequence.")
      let _ = self.advance()
      None
    }
  }
}

///|
fn Scanner::consume_unicode_escape_char(self : Scanner) -> Char? {
  let _ = self.advance()
  if !self.match_char('{') {
    self.report_error("Invalid unicode escape.")
    return None
  }
  let mut digits = 0
  let mut value : Int = 0
  for {
    if self.is_at_end() {
      self.report_error("Invalid unicode escape.")
      return None
    }
    let ch = self.peek()
    if ch == '}' {
      let _ = self.advance()
      break
    }
    if !is_digit_in_base(ch, 16) {
      self.report_error("Invalid unicode escape.")
      let _ = self.advance()
      return None
    }
    value = value * 16 + hex_value(ch)
    digits = digits + 1
    if digits > 6 {
      self.report_error("Unicode escape too long.")
      return None
    }
    let _ = self.advance()

  }
  if digits == 0 {
    self.report_error("Invalid unicode escape.")
    return None
  }
  if value > 0x10FFFF {
    self.report_error("Unicode escape out of range.")
    return None
  }
  if is_unicode_surrogate(value) {
    self.report_error("Unicode escape must not specify surrogate code point.")
    return None
  }
  Some(Int::unsafe_to_char(value))
}

///|
fn hex_value(ch : Char) -> Int {
  match ch {
    '0' => 0
    '1' => 1
    '2' => 2
    '3' => 3
    '4' => 4
    '5' => 5
    '6' => 6
    '7' => 7
    '8' => 8
    '9' => 9
    'a' | 'A' => 10
    'b' | 'B' => 11
    'c' | 'C' => 12
    'd' | 'D' => 13
    'e' | 'E' => 14
    _ => 15
  }
}

///|
fn Scanner::skip_until_char(self : Scanner, target : Char) -> Unit {
  for {
    if self.is_at_end() {
      return
    }
    if self.peek() == target {
      let _ = self.advance()
      return
    }
    let _ = self.advance()

  }
}

///|
fn Scanner::consume_unicode_escape(self : Scanner) -> Bool {
  match self.consume_unicode_escape_char() {
    Some(_) => true
    None => false
  }
}

///|
fn is_unicode_surrogate(value : Int) -> Bool {
  value >= 0xD800 && value <= 0xDFFF
}

///|
pub fn tokenize(source : String) -> LexResult {
  let scanner = Scanner::make(source)
  scanner.scan_all()
}
