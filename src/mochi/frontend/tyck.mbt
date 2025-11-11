///|
pub enum TypeKind {
  Unknown
  Unit
  Bool
  Int
  Double
}

///|
pub struct Type {
  kind : TypeKind
}

///|
fn Type::unknown() -> Type {
  { kind: TypeKind::Unknown }
}

///|
fn Type::unit() -> Type {
  { kind: TypeKind::Unit }
}

///|
fn Type::bool() -> Type {
  { kind: TypeKind::Bool }
}

///|
fn Type::int() -> Type {
  { kind: TypeKind::Int }
}

///|
fn Type::double() -> Type {
  { kind: TypeKind::Double }
}

///|
fn Type::equals(self : Type, other : Type) -> Bool {
  match self.kind {
    TypeKind::Unknown =>
      match other.kind {
        TypeKind::Unknown => true
        _ => false
      }
    TypeKind::Unit =>
      match other.kind {
        TypeKind::Unit => true
        _ => false
      }
    TypeKind::Bool =>
      match other.kind {
        TypeKind::Bool => true
        _ => false
      }
    TypeKind::Int =>
      match other.kind {
        TypeKind::Int => true
        _ => false
      }
    TypeKind::Double =>
      match other.kind {
        TypeKind::Double => true
        _ => false
      }
  }
}

///|
fn Type::name(self : Type) -> String {
  match self.kind {
    TypeKind::Unknown => "<unknown>"
    TypeKind::Unit => "Unit"
    TypeKind::Bool => "Bool"
    TypeKind::Int => "Int"
    TypeKind::Double => "Double"
  }
}

///|
pub struct SymbolBinding {
  token : Token
  ty : Type
}

///|
pub struct SymbolTable {
  bindings : Array[SymbolBinding]
}

///|
fn SymbolTable::empty() -> SymbolTable {
  { bindings: Array::new() }
}

///|
fn SymbolTable::add_binding(
  self : SymbolTable,
  token : Token,
  ty : Type,
) -> Unit {
  let binding : SymbolBinding = { token, ty }
  self.bindings.push(binding)
}

///|
fn SymbolTable::lookup_token(self : SymbolTable, token : Token) -> Type? {
  for binding in self.bindings {
    if binding.token.lexeme == token.lexeme {
      return Some(binding.ty)
    }
  }
  None
}

///|
pub struct TypeEnv {
  tables : Array[SymbolTable]
}

///|
fn TypeEnv::empty() -> TypeEnv {
  { tables: Array::new() }
}

///|
fn TypeEnv::from_table(table : SymbolTable) -> TypeEnv {
  let tables = Array::new()
  tables.push(table)
  { tables, }
}

///|
fn TypeEnv::lookup_token(self : TypeEnv, token : Token) -> Type? {
  let mut index = self.tables.length()
  for {
    if index == 0 {
      break
    }
    index = index - 1
    let table = self.tables[index]
    match table.lookup_token(token) {
      Some(ty) => return Some(ty)
      None => ()
    }
  }
  None
}

///|
fn TypeEnv::push_empty(self : TypeEnv) -> Unit {
  self.tables.push(SymbolTable::empty())
}

///|
fn TypeEnv::pop(self : TypeEnv) -> Unit {
  if self.tables.length() == 0 {
    return
  }
  let _ = self.tables.pop()

}

///|
fn TypeEnv::insert_token(self : TypeEnv, token : Token, ty : Type) -> Unit {
  if self.tables.length() == 0 {
    self.push_empty()
  }
  let index = self.tables.length() - 1
  self.tables[index].add_binding(token, ty)
}

///|
fn TypeEnv::current_table_contains(self : TypeEnv, token : Token) -> Bool {
  if self.tables.length() == 0 {
    return false
  }
  let index = self.tables.length() - 1
  match self.tables[index].lookup_token(token) {
    Some(_) => true
    None => false
  }
}

///|
pub struct TyckError {
  message : String
  range : SourceRange
}

///|
fn TyckError::new(message : String, range : SourceRange) -> TyckError {
  { message, range }
}

///|
pub struct TyckResult {
  errors : Array[TyckError]
}

///|
fn TyckResult::with_errors(errors : Array[TyckError]) -> TyckResult {
  { errors, }
}

///|
priv struct Tycker {
  env : TypeEnv
  errors : Array[TyckError]
}

///|
fn Tycker::new() -> Tycker {
  let env = TypeEnv::empty()
  env.push_empty()
  let errors : Array[TyckError] = Array::new()
  { env, errors }
}

///|
fn Tycker::into_result(self : Tycker) -> TyckResult {
  TyckResult::with_errors(self.errors)
}

///|
fn Tycker::analyze_statements(self : Tycker, statements : Array[Stmt]) -> Unit {
  for statement in statements {
    self.visit_stmt(statement)
  }
}

///|
fn Tycker::visit_stmt(self : Tycker, stmt : Stmt) -> Unit {
  match stmt.kind {
    StmtKind::ExprStmt(expr) => {
      let _ = self.visit_expr(expr)

    }
    StmtKind::Guard(guard_stmt) => self.visit_guard_stmt(guard_stmt)
    StmtKind::Switch(switch_stmt) => self.visit_switch_stmt(switch_stmt)
  }
}

///|
fn Tycker::visit_guard_stmt(self : Tycker, guard_stmt : GuardStmt) -> Unit {
  let condition_type = self.visit_expr(guard_stmt.condition)
  self.ensure_bool(condition_type, guard_stmt.condition.range)
  match guard_stmt.pattern {
    Some(pattern) => {
      self.env.push_empty()
      self.visit_pattern(pattern)
      self.env.pop()
    }
    None => ()
  }
  match guard_stmt.else_clause {
    Some(clause) =>
      match clause.body {
        Some(body) => {
          let _ = self.visit_expr(body)

        }
        None => ()
      }
    None => ()
  }
}

///|
fn Tycker::visit_switch_stmt(self : Tycker, switch_stmt : SwitchStmt) -> Unit {
  let _ = self.visit_expr(switch_stmt.value)
  let mut result_type : Type = Type::unknown()
  let mut has_result = false
  for case in switch_stmt.cases {
    let case_type = self.visit_switch_case(case)
    if !has_result {
      result_type = case_type
      has_result = true
    } else if !case_type.equals(result_type) &&
      !case_type.equals(Type::unknown()) &&
      !result_type.equals(Type::unknown()) {
      self.report_error(
        case.value.range,
        "Mismatched switch case result types.",
      )
    }
  }
  match switch_stmt.default_case {
    Some(default_case) => {
      let default_type = self.visit_expr(default_case.value)
      let mut mismatch = has_result && !default_type.equals(result_type)
      if mismatch {
        mismatch = mismatch && !default_type.equals(Type::unknown())
        mismatch = mismatch && !result_type.equals(Type::unknown())
      }
      if mismatch {
        self.report_error(
          default_case.value.range,
          "Mismatched switch case result types.",
        )
      }
    }
    None => ()
  }
}

///|
fn Tycker::visit_switch_case(self : Tycker, case : SwitchCase) -> Type {
  self.env.push_empty()
  self.visit_pattern(case.pattern)
  let value_type = self.visit_expr(case.value)
  self.env.pop()
  value_type
}

///|
fn Tycker::visit_expr(self : Tycker, expr : Expr) -> Type {
  match expr.kind {
    ExprKind::Ident(token) => self.resolve_ident(token)
    ExprKind::Literal(token) => self.type_of_literal(token)
    ExprKind::StructLiteral(struct_lit) => self.visit_struct_literal(struct_lit)
    ExprKind::Match(match_expr) => self.visit_match_expr(match_expr)
  }
}

///|
fn Tycker::resolve_ident(self : Tycker, token : Token) -> Type {
  match self.env.lookup_token(token) {
    Some(ty) => ty
    None => {
      self.report_error(token.range, "Undefined identifier.")
      Type::unknown()
    }
  }
}

///|
fn Tycker::type_of_literal(_self : Tycker, token : Token) -> Type {
  match token.kind {
    TokenKind::LiteralInt => Type::int()
    TokenKind::LiteralFloat => Type::double()
    TokenKind::LiteralString => Type::unknown()
    TokenKind::LiteralChar => Type::unknown()
    _ => Type::unknown()
  }
}

///|
fn Tycker::visit_struct_literal(
  self : Tycker,
  struct_lit : StructLiteral,
) -> Type {
  for field in struct_lit.fields {
    let field_type = self.visit_expr(field.value)
    let expected = self.lookup_struct_field_type(
      struct_lit.name.lexeme,
      field.name.lexeme,
    )
    match expected {
      Some(expected_type) =>
        if !field_type.equals(expected_type) &&
          !field_type.equals(Type::unknown()) {
          self.report_type_mismatch(
            field.value.range,
            field_type,
            expected_type,
            "Struct field type mismatch.",
          )
        }
      None => ()
    }
  }
  Type::unknown()
}

///|
fn Tycker::lookup_struct_field_type(
  self : Tycker,
  struct_name : String,
  field_name : String,
) -> Type? {
  let _ = self
  match struct_name {
    "Point" =>
      match field_name {
        "x" => Some(Type::int())
        "y" => Some(Type::int())
        _ => None
      }
    _ => None
  }
}

///|
fn Tycker::visit_match_expr(self : Tycker, match_expr : MatchExpr) -> Type {
  let _ = self.visit_expr(match_expr.value)
  let mut result_type : Type = Type::unknown()
  let mut has_result = false
  for arm in match_expr.arms {
    let arm_type = self.visit_match_arm(arm)
    if !has_result {
      result_type = arm_type
      has_result = true
    } else if !arm_type.equals(result_type) &&
      !arm_type.equals(Type::unknown()) &&
      !result_type.equals(Type::unknown()) {
      self.report_type_mismatch(
        arm.value.range,
        arm_type,
        result_type,
        "Mismatched match arm result types.",
      )
    }
  }
  result_type
}

///|
fn Tycker::visit_match_arm(self : Tycker, arm : MatchArm) -> Type {
  self.env.push_empty()
  self.visit_pattern(arm.pattern)
  match arm.guard_expr {
    Some(expr) => {
      let guard_type = self.visit_expr(expr)
      self.ensure_bool(guard_type, expr.range)
    }
    None => ()
  }
  let value_type = self.visit_expr(arm.value)
  self.env.pop()
  value_type
}

///|
fn Tycker::visit_pattern(self : Tycker, pattern : Pattern) -> Unit {
  match pattern.kind {
    PatternKind::Struct(struct_pattern) =>
      self.visit_struct_pattern(struct_pattern)
    PatternKind::Tuple(tuple_pattern) => self.visit_tuple_pattern(tuple_pattern)
    PatternKind::Or(or_pattern) => self.visit_or_pattern(or_pattern)
    PatternKind::EnumVariant(enum_pattern) =>
      self.visit_enum_pattern(enum_pattern)
    PatternKind::Wildcard(_) => ()
    PatternKind::Ident(token) => self.bind_token(token)
    PatternKind::Literal(_) => ()
  }
}

///|
fn Tycker::visit_struct_pattern(
  self : Tycker,
  struct_pattern : PatternStruct,
) -> Unit {
  for field in struct_pattern.fields {
    match field.pattern {
      Some(inner) => self.visit_pattern(inner)
      None => self.bind_token(field.name)
    }
  }
}

///|
fn Tycker::visit_tuple_pattern(
  self : Tycker,
  tuple_pattern : PatternTuple,
) -> Unit {
  for element in tuple_pattern.elements {
    self.visit_pattern(element)
  }
}

///|
fn Tycker::visit_or_pattern(self : Tycker, or_pattern : PatternOr) -> Unit {
  for pattern in or_pattern.patterns {
    self.visit_pattern(pattern)
  }
}

///|
fn Tycker::visit_enum_pattern(
  self : Tycker,
  enum_pattern : PatternEnumVariant,
) -> Unit {
  for arg in enum_pattern.arguments {
    self.visit_pattern(arg)
  }
}

///|
fn Tycker::report_error(
  self : Tycker,
  range : SourceRange,
  message : String,
) -> Unit {
  let error = TyckError::new(message, range)
  self.errors.push(error)
}

///|
fn Tycker::bind_token(self : Tycker, token : Token) -> Unit {
  if self.env.current_table_contains(token) {
    self.report_error(token.range, "Duplicate binding.")
  } else {
    self.env.insert_token(token, Type::unknown())
  }
}

///|
fn Tycker::ensure_bool(self : Tycker, ty : Type, range : SourceRange) -> Unit {
  match ty.kind {
    TypeKind::Bool => ()
    TypeKind::Unknown => ()
    _ => self.report_error(range, "Expected boolean expression.")
  }
}

///|
fn Tycker::report_type_mismatch(
  self : Tycker,
  range : SourceRange,
  actual : Type,
  expected : Type,
  message : String,
) -> Unit {
  let detail = message +
    " (expected " +
    expected.name() +
    ", found " +
    actual.name() +
    ")"
  self.report_error(range, detail)
}

///|
fn empty_range() -> SourceRange {
  let pos : SourcePos = { index: 0, line: 0, column: 0 }
  { start: pos, end: pos }
}

///|
pub fn analyze(statements : Array[Stmt]) -> TyckResult {
  let _ = Type::unknown()
  let _ = Type::unit()
  let _ = Type::bool()
  let _ = Type::int()
  let _ = Type::double()
  let _ = TypeEnv::empty()
  let _ = TypeEnv::from_table(SymbolTable::empty())
  let _ = statements
  let _ = TyckError::new("", empty_range())
  let tycker = Tycker::new()
  tycker.analyze_statements(statements)
  tycker.into_result()
}
