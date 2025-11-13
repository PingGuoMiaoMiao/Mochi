///|
pub enum ExprKind {
  Ident(Token)
  Literal(Token)
  StructLiteral(StructLiteral)
  Match(MatchExpr)
  Binary(BinaryExpr)
  Unary(UnaryExpr)
  Call(CallExpr)
  ArrayLiteral(ArrayLiteral)
  Index(IndexExpr)
  TupleLiteral(TupleLiteral)
  If(IfExpr)
  FieldAccess(FieldAccessExpr)
}

///|
pub struct Expr {
  kind : ExprKind
  range : SourceRange
}

///|
pub struct BinaryExpr {
  left : Expr
  operator : Token
  right : Expr
  range : SourceRange
}

///|
pub struct UnaryExpr {
  operator : Token
  operand : Expr
  range : SourceRange
}

///|
pub struct CallExpr {
  callee : Expr
  open_paren : Token
  arguments : Array[Expr]
  close_paren : Token
  range : SourceRange
}

///|
pub struct ArrayLiteral {
  open_bracket : Token
  elements : Array[Expr]
  close_bracket : Token
  range : SourceRange
}

///|
pub struct IndexExpr {
  array : Expr
  open_bracket : Token
  index : Expr
  close_bracket : Token
  range : SourceRange
}

///|
pub struct TupleLiteral {
  open_paren : Token
  elements : Array[Expr]
  close_paren : Token
  range : SourceRange
}

///|
pub struct IfExpr {
  keyword : Token
  condition : Expr
  open_brace : Token
  then_expr : Expr
  close_brace : Token
  else_keyword : Token
  else_open_brace : Token
  else_expr : Expr
  else_close_brace : Token
  range : SourceRange
}

///|
pub struct FieldAccessExpr {
  object : Expr
  dot : Token
  field : Token
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
pub struct LetStmt {
  let_keyword : Token
  mut_keyword : Token?
  name : Token
  colon : Token?
  type_name : Token?
  assign : Token
  value : Expr
  semicolon : Token
  range : SourceRange
}

///|
pub struct AssignStmt {
  target : Expr // Can be Ident or Index expression
  assign : Token
  value : Expr
  semicolon : Token
  range : SourceRange
}

///|
pub struct FunctionParam {
  name : Token
  colon : Token?
  type_name : Token?
  element_type_name : Token? // For Array[Type], stores the element type token
}

///|
pub struct FunctionStmt {
  fn_keyword : Token
  generic_params : Array[Token] // Generic type parameters like [T]
  name : Token
  open_paren : Token?
  parameters : Array[FunctionParam]
  close_paren : Token?
  arrow : Token?
  return_type : Token?
  open_brace : Token
  body : Array[Stmt]
  close_brace : Token
  range : SourceRange
}

///|
pub struct ReturnStmt {
  keyword : Token
  value : Expr?
  semicolon : Token?
  range : SourceRange
}

///|
pub struct WhileStmt {
  keyword : Token
  condition : Expr
  open_brace : Token
  body : Array[Stmt]
  close_brace : Token
  range : SourceRange
}

///|
pub struct IfStmt {
  keyword : Token
  condition : Expr
  open_brace : Token
  then_body : Array[Stmt]
  close_brace : Token
  else_keyword : Token?
  else_open_brace : Token?
  else_body : Array[Stmt]
  else_close_brace : Token?
  range : SourceRange
}

///|
pub struct StructFieldDef {
  name : Token
  colon : Token
  type_name : Token
  semicolon : Token
  range : SourceRange
}

///|
pub struct StructDef {
  keyword : Token
  name : Token
  open_brace : Token
  fields : Array[StructFieldDef]
  close_brace : Token
  range : SourceRange
}

///|
pub struct EnumVariant {
  name : Token
  open_paren : Token?
  param_types : Array[Token]
  close_paren : Token?
  semicolon : Token
  range : SourceRange
}

///|
pub struct EnumDef {
  keyword : Token
  name : Token
  open_brace : Token
  variants : Array[EnumVariant]
  close_brace : Token
  range : SourceRange
}

///|
pub enum StmtKind {
  ExprStmt(Expr)
  Guard(GuardStmt)
  Switch(SwitchStmt)
  Let(LetStmt)
  Assign(AssignStmt)
  Function(FunctionStmt)
  Return(ReturnStmt)
  While(WhileStmt)
  If(IfStmt)
  Struct(StructDef)
  Enum(EnumDef)
}

///|
pub struct Stmt {
  kind : StmtKind
  range : SourceRange
}
