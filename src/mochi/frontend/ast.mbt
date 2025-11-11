///|
pub enum ExprKind {
  Ident(Token)
  Literal(Token)
  StructLiteral(StructLiteral)
  Match(MatchExpr)
}

///|
pub struct Expr {
  kind : ExprKind
  range : SourceRange
}

///|
pub struct StructField {
  name : Token
  colon : Token
  value : Expr
  range : SourceRange
}

///|
pub struct StructLiteral {
  qualifier : Array[Token]
  name : Token
  open : Token
  fields : Array[StructField]
  close : Token
  range : SourceRange
}

///|
pub struct GuardElseClause {
  keyword : Token
  open_brace : Token
  body : Expr?
  close_brace : Token
  range : SourceRange
}

///|
pub struct GuardStmt {
  keyword : Token
  condition : Expr
  is_token : Token?
  pattern : Pattern?
  else_clause : GuardElseClause?
  range : SourceRange
}

///|
pub enum PatternKind {
  Wildcard(Token)
  Ident(Token)
  Struct(PatternStruct)
  Literal(Token)
  Tuple(PatternTuple)
  Or(PatternOr)
  EnumVariant(PatternEnumVariant)
}

///|
pub struct Pattern {
  kind : PatternKind
  range : SourceRange
}

///|
pub struct PatternStructField {
  name : Token
  colon : Token?
  pattern : Pattern?
  range : SourceRange
}

///|
pub struct PatternStruct {
  qualifier : Array[Token]
  name : Token
  open : Token
  fields : Array[PatternStructField]
  close : Token
  range : SourceRange
}

///|
pub struct PatternTuple {
  qualifier : Array[Token]
  name : Token?
  open : Token
  elements : Array[Pattern]
  close : Token
  range : SourceRange
}

///|
pub struct PatternOr {
  patterns : Array[Pattern]
  bars : Array[Token]
  range : SourceRange
}

///|
pub struct PatternEnumVariant {
  qualifier : Array[Token]
  name : Token
  open : Token?
  arguments : Array[Pattern]
  close : Token?
  range : SourceRange
}

///|
pub struct MatchArm {
  pattern : Pattern
  if_keyword : Token?
  guard_expr : Expr?
  arrow : Token
  value : Expr
  range : SourceRange
}

///|
pub struct MatchExpr {
  keyword : Token
  value : Expr
  open : Token
  arms : Array[MatchArm]
  close : Token
  range : SourceRange
}

///|
pub struct SwitchCase {
  keyword : Token
  pattern : Pattern
  arrow : Token
  value : Expr
  range : SourceRange
}

///|
pub struct SwitchDefault {
  keyword : Token
  arrow : Token
  value : Expr
  range : SourceRange
}

///|
pub struct SwitchStmt {
  keyword : Token
  value : Expr
  open : Token
  cases : Array[SwitchCase]
  default_case : SwitchDefault?
  close : Token
  range : SourceRange
}

///|
pub enum StmtKind {
  ExprStmt(Expr)
  Guard(GuardStmt)
  Switch(SwitchStmt)
}

///|
pub struct Stmt {
  kind : StmtKind
  range : SourceRange
}
