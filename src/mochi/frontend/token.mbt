///|
pub struct SourcePos {
  index : Int
  line : Int
  column : Int
}

///|
pub struct SourceRange {
  start : SourcePos
  end : SourcePos
}

///|
pub enum TokenKind {
  Ident
  KeywordGuard
  KeywordElse
  KeywordIs
  KeywordIf
  KeywordMatch
  KeywordSwitch
  KeywordCase
  KeywordDefault
  LiteralInt
  LiteralString
  LiteralChar
  LiteralFloat
  LBrace
  RBrace
  LParen
  RParen
  Comma
  Colon
  Arrow
  DoubleColon
  Pipe
  Underscore
  EndOfFile
}

///|
pub struct Token {
  kind : TokenKind
  range : SourceRange
  lexeme : String
}
