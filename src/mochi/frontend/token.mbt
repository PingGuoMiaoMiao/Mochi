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
  KeywordLet
  KeywordMut
  KeywordFn
  KeywordReturn
  KeywordWhile
  KeywordStruct
  LiteralBool
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
  Semicolon
  Arrow
  ThinArrow
  DoubleColon
  Pipe
  PipePipe
  AmpAmp
  Assign
  EqualEqual
  Bang
  BangEqual
  Greater
  GreaterEqual
  Less
  LessEqual
  Plus
  Minus
  Star
  Slash
  Percent
  Dot
  LBracket
  RBracket
  Underscore
  EndOfFile
}

///|
pub struct Token {
  kind : TokenKind
  range : SourceRange
  lexeme : String
}
