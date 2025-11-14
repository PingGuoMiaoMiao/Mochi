///|
// 代码生成器 - 组件化设计
// 将 AST 转换为 LLVM IR
// 
// 架构设计：
// 1. 核心数据结构：CodegenContext (LLVMGen) - 管理变量、标签、结构体定义等
// 2. 模块化函数：每个 AST 节点类型对应一个生成函数
// 3. 表达式生成：递归生成，返回 (code, temp_var)
// 4. 语句生成：顺序生成，返回 (code, last_expr_temp)
// 5. 控制流：使用基本块和 phi 节点实现 SSA 形式

///|
pub enum EmitFormat {
  LLVM
  ASM
}

///|
pub fn emit_format_llvm() -> EmitFormat {
  EmitFormat::LLVM
}

///|
pub fn emit_format_asm() -> EmitFormat {
  EmitFormat::ASM
}

///|
pub struct CodegenResult {
  code : String
  errors : Array[String]
}

///|
priv struct BuiltinFuncInfo {
  ir_name : String
  return_type : String
  is_void : Bool
  param_types : Array[String]
}

///|
priv struct ExprValue {
  code : String
  value : String
  llvm_type : String
  closure_arity : Int
}

///|
fn expr_value(code : String, value : String, llvm_type : String) -> ExprValue {
  { code, value, llvm_type, closure_arity: -1 }
}

///|
fn empty_expr_value() -> ExprValue {
  expr_value("", "", "i32")
}

///|
fn expr_value_with_closure(
  code : String,
  value : String,
  llvm_type : String,
  arity : Int,
) -> ExprValue {
  { code, value, llvm_type, closure_arity: arity }
}

///|
fn builtin_param_types_none() -> Array[String] {
  Array::new()
}

///|
fn builtin_param_types_one(type0 : String) -> Array[String] {
  let params : Array[String] = Array::new()
  params.push(type0)
  params
}

///|
fn builtin_param_types_two(type0 : String, type1 : String) -> Array[String] {
  let params : Array[String] = Array::new()
  params.push(type0)
  params.push(type1)
  params
}

///|
fn get_builtin_function(name : String) -> BuiltinFuncInfo? {
  match name {
    "print_int" =>
      Some({
        ir_name: "@minimbt_print_int",
        return_type: "void",
        is_void: true,
        param_types: builtin_param_types_one("i32"),
      })
    "print_double" =>
      Some({
        ir_name: "@minimbt_print_double",
        return_type: "void",
        is_void: true,
        param_types: builtin_param_types_one("double"),
      })
    "print_endline" =>
      Some({
        ir_name: "@minimbt_print_endline",
        return_type: "void",
        is_void: true,
        param_types: builtin_param_types_none(),
      })
    "int_of_float" =>
      Some({
        ir_name: "@minimbt_int_of_float",
        return_type: "i32",
        is_void: false,
        param_types: builtin_param_types_one("double"),
      })
    "float_of_int" =>
      Some({
        ir_name: "@minimbt_float_of_int",
        return_type: "double",
        is_void: false,
        param_types: builtin_param_types_one("i32"),
      })
    "truncate" =>
      Some({
        ir_name: "@minimbt_truncate",
        return_type: "i32",
        is_void: false,
        param_types: builtin_param_types_one("double"),
      })
    "abs_float" =>
      Some({
        ir_name: "@minimbt_abs_float",
        return_type: "double",
        is_void: false,
        param_types: builtin_param_types_one("double"),
      })
    _ => None
  }
}

///|
fn llvm_gen_call_closure(
  gen : LLVMGen,
  callee : ExprValue,
  args_code : String,
  args_temps : Array[String],
) -> ExprValue {
  let arity = callee.closure_arity
  if arity < 0 {
    return expr_value("", "0", "i32")
  }
  let closure_struct_type = closure_struct_type_name_for_arity(arity)
  let closure_ptr_type = closure_struct_pointer_type_for_arity(arity)
  let fn_pointer_type = closure_function_pointer_type_for_arity(arity)
  let fn_field_ptr = gen.next_temp()
  let env_field_ptr = gen.next_temp()
  let fn_ptr = gen.next_temp()
  let env_ptr = gen.next_temp()
  let mut code = callee.code +
    "  " +
    fn_field_ptr +
    " = getelementptr " +
    closure_struct_type +
    ", " +
    closure_ptr_type +
    " " +
    callee.value +
    ", i32 0, i32 0\n" +
    "  " +
    fn_ptr +
    " = load " +
    fn_pointer_type +
    ", " +
    fn_pointer_type +
    "* " +
    fn_field_ptr +
    "\n" +
    "  " +
    env_field_ptr +
    " = getelementptr " +
    closure_struct_type +
    ", " +
    closure_ptr_type +
    " " +
    callee.value +
    ", i32 0, i32 1\n" +
    "  " +
    env_ptr +
    " = load i8*, i8** " +
    env_field_ptr +
    "\n"
  code = code + args_code
  let mut param_list = "i8* " + env_ptr
  let mut index = 0
  while index < args_temps.length() {
    param_list = param_list + ", i32 " + args_temps[index]
    index = index + 1
  }
  let result_temp = gen.next_temp()
  code = code +
    "  " +
    result_temp +
    " = call i32 " +
    fn_ptr +
    "(" +
    param_list +
    ")\n"
  expr_value(code, result_temp, "i32")
}

///|
fn builtin_function_names() -> Array[String] {
  let names : Array[String] = Array::new()
  names.push("print_int")
  names.push("print_double")
  names.push("print_endline")
  names.push("int_of_float")
  names.push("float_of_int")
  names.push("truncate")
  names.push("abs_float")
  names
}

///|
fn format_builtin_declaration(info : BuiltinFuncInfo) -> String {
  let mut decl = "declare " + info.return_type + " " + info.ir_name + "("
  let mut first = true
  for param_type in info.param_types {
    if first {
      decl = decl + param_type
      first = false
    } else {
      decl = decl + ", " + param_type
    }
  }
  decl + ")\n"
}

///|
pub fn codegen(statements : Array[Stmt], format : EmitFormat) -> CodegenResult {
  let errors : Array[String] = Array::new()
  match format {
    EmitFormat::LLVM => {
      let code = generate_llvm(statements)
      { code, errors }
    }
    EmitFormat::ASM => {
      let code = generate_asm(statements)
      { code, errors }
    }
  }
}

///|
// LLVMGen: 代码生成上下文，管理变量、标签、结构体定义等
priv struct LLVMGen {
  mut var_counter : Int // 临时变量计数器
  mut label_counter : Int // 标签计数器
  var_map : Array[(String, String, String, Int)] // 变量 -> (alloca, llvm_type, closure_arity)
  struct_defs : Array[(String, Array[String])] // 结构体定义：(结构体名, 字段名列表)
  current_function : String // 当前函数名
  current_function_id : Int
  closure_metadata : ClosureMetadata
  mut current_return_type : String
}

///|
fn LLVMGen::new(metadata : ClosureMetadata) -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    current_function: "",
    current_function_id: -1,
    closure_metadata: metadata,
    current_return_type: "void",
  }
}

///|
fn LLVMGen::new_with_function(
  func_name : String,
  func_id : Int,
  metadata : ClosureMetadata,
  return_type : String,
) -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    current_function: func_name,
    current_function_id: func_id,
    closure_metadata: metadata,
    current_return_type: return_type,
  }
}

///|
fn LLVMGen::get_var_entry(
  self : LLVMGen,
  name : String,
) -> (String, String, Int)? {
  for pair in self.var_map {
    if pair.0 == name {
      return Some((pair.1, pair.2, pair.3))
    }
  }
  None
}

///|
fn LLVMGen::get_var_name(self : LLVMGen, name : String) -> String {
  match self.get_var_entry(name) {
    Some(entry) => entry.0
    None => ""
  }
}

///|
fn LLVMGen::get_var_type(self : LLVMGen, name : String) -> String {
  match self.get_var_entry(name) {
    Some(entry) => entry.1
    None => ""
  }
}

///|
fn LLVMGen::get_var_closure_arity(self : LLVMGen, name : String) -> Int {
  match self.get_var_entry(name) {
    Some(entry) => entry.2
    None => -1
  }
}

///|
fn LLVMGen::find_function_entry_by_name(
  self : LLVMGen,
  name : String,
  parent_id : Int,
) -> ClosureEntry? {
  for entry in self.closure_metadata.entries {
    if entry.name == name && entry.parent_id == parent_id {
      return Some(entry)
    }
  }
  None
}

///|
fn LLVMGen::find_local_function_entry(
  self : LLVMGen,
  name : String,
) -> ClosureEntry? {
  self.find_function_entry_by_name(name, self.current_function_id)
}

///|
fn LLVMGen::find_top_level_function_entry(
  self : LLVMGen,
  name : String,
) -> ClosureEntry? {
  self.find_function_entry_by_name(name, -1)
}

///|
fn LLVMGen::add_var_with_type_and_arity(
  self : LLVMGen,
  name : String,
  temp_name : String,
  llvm_type : String,
  closure_arity : Int,
) -> Unit {
  self.var_map.push((name, temp_name, llvm_type, closure_arity))
}

///|
fn LLVMGen::add_var_with_type(
  self : LLVMGen,
  name : String,
  temp_name : String,
  llvm_type : String,
) -> Unit {
  self.add_var_with_type_and_arity(name, temp_name, llvm_type, -1)
}

///|
fn LLVMGen::add_var(self : LLVMGen, name : String, temp_name : String) -> Unit {
  self.add_var_with_type(name, temp_name, "i32")
}

///|
fn LLVMGen::update_var(
  self : LLVMGen,
  name : String,
  temp_name : String,
  llvm_type : String,
  closure_arity : Int,
) -> Unit {
  let mut index = 0
  for {
    if index >= self.var_map.length() {
      break
    }
    if self.var_map[index].0 == name {
      self.var_map[index] = (name, temp_name, llvm_type, closure_arity)
      break
    }
    index = index + 1
  }
}

///|
fn LLVMGen::next_temp(self : LLVMGen) -> String {
  let num = self.var_counter
  self.var_counter = self.var_counter + 1
  "%t" + num.to_string()
}

///|
fn LLVMGen::next_label(self : LLVMGen) -> String {
  let num = self.label_counter
  self.label_counter = self.label_counter + 1
  "label" + num.to_string()
}

///|
// 生成LLVM IR代码的主函数
fn function_id(function_stmt : FunctionStmt) -> Int {
  function_stmt.range.start.index
}

///|
fn clone_string_array(source : Array[String]) -> Array[String] {
  let result : Array[String] = Array::new()
  for item in source {
    result.push(item)
  }
  result
}

///|
fn scope_contains(scope : Array[String], name : String) -> Bool {
  for entry in scope {
    if entry == name {
      return true
    }
  }
  false
}

///|
fn add_name_to_scope(scope : Array[String], name : String) -> Unit {
  if name == "" {
    return
  }
  if !scope_contains(scope, name) {
    scope.push(name)
  }
}

///|
fn merge_scopes(
  scope_a : Array[String],
  scope_b : Array[String],
) -> Array[String] {
  let merged = clone_string_array(scope_a)
  for entry in scope_b {
    add_name_to_scope(merged, entry)
  }
  merged
}

///|
fn record_free_var(free_vars : Array[String], name : String) -> Unit {
  if name == "" {
    return
  }
  if !scope_contains(free_vars, name) {
    free_vars.push(name)
  }
}

///|
priv struct ClosureEntry {
  id : Int
  parent_id : Int
  name : String
  free_vars : Array[String]
  function_stmt : FunctionStmt
}

///|
priv struct ClosureMetadata {
  entries : Array[ClosureEntry]
}

///|
fn ClosureMetadata::new() -> ClosureMetadata {
  { entries: Array::new() }
}

///|
fn clone_closure_entry(entry : ClosureEntry) -> ClosureEntry {
  {
    id: entry.id,
    parent_id: entry.parent_id,
    name: entry.name,
    free_vars: clone_string_array(entry.free_vars),
    function_stmt: entry.function_stmt,
  }
}

///|
fn ClosureMetadata::clone(self : ClosureMetadata) -> ClosureMetadata {
  let entries : Array[ClosureEntry] = Array::new()
  for entry in self.entries {
    entries.push(clone_closure_entry(entry))
  }
  { entries, }
}

///|
fn ClosureMetadata::record(
  self : ClosureMetadata,
  id : Int,
  parent_id : Int,
  name : String,
  free_vars : Array[String],
  function_stmt : FunctionStmt,
) -> Unit {
  self.entries.push({ id, parent_id, name, free_vars, function_stmt })
}

///|
fn ClosureMetadata::get_entry(
  self : ClosureMetadata,
  id : Int,
) -> ClosureEntry? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry)
    }
  }
  None
}

///|
fn ClosureMetadata::get_free_vars(
  self : ClosureMetadata,
  function_stmt : FunctionStmt,
) -> Array[String] {
  let id = function_id(function_stmt)
  for entry in self.entries {
    if entry.id == id {
      return clone_string_array(entry.free_vars)
    }
  }
  Array::new()
}

///|
fn gather_global_scope(statements : Array[Stmt]) -> Array[String] {
  let scope = builtin_function_names()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) =>
        add_name_to_scope(scope, function_stmt.name.lexeme)
      StmtKind::Let(let_stmt) => add_name_to_scope(scope, let_stmt.name.lexeme)
      _ => ()
    }
  }
  scope
}

///|
fn closure_env_struct_name(id : Int) -> String {
  "%closure_env." + id.to_string()
}

///|
fn closure_struct_type_name_for_arity(param_count : Int) -> String {
  "%closure_fn_" + param_count.to_string()
}

///|
fn closure_struct_pointer_type_for_arity(param_count : Int) -> String {
  closure_struct_type_name_for_arity(param_count) + "*"
}

///|
fn closure_function_pointer_type_for_arity(arity : Int) -> String {
  let mut type_str = "i32 (i8*"
  let mut index = 0
  while index < arity {
    type_str = type_str + ", i32"
    index = index + 1
  }
  type_str + ")*"
}

///|
fn closure_function_pointer_type(function_stmt : FunctionStmt) -> String {
  closure_function_pointer_type_for_arity(function_stmt.parameters.length())
}

///|
fn generate_closure_env_type_definitions(metadata : ClosureMetadata) -> String {
  let mut definitions = ""
  for entry in metadata.entries {
    if entry.parent_id == -1 {
      continue
    }
    let field_count = entry.free_vars.length()
    if field_count == 0 {
      continue
    }
    let mut line = closure_env_struct_name(entry.id) + " = type { "
    let mut first = true
    let mut index = 0
    while index < field_count {
      if first {
        line = line + "i32"
        first = false
      } else {
        line = line + ", i32"
      }
      index = index + 1
    }
    line = line + " }\n"
    definitions = definitions + line
  }
  if definitions.length() > 0 {
    definitions = definitions + "\n"
  }
  definitions
}

///|
fn int_array_contains(array : Array[Int], value : Int) -> Bool {
  for item in array {
    if item == value {
      return true
    }
  }
  false
}

///|
fn generate_closure_struct_definitions(metadata : ClosureMetadata) -> String {
  let arities : Array[Int] = Array::new()
  for entry in metadata.entries {
    if entry.parent_id != -1 {
      let arity = entry.function_stmt.parameters.length()
      if !int_array_contains(arities, arity) {
        arities.push(arity)
      }
    }
  }
  let mut definitions = ""
  for arity in arities {
    let type_name = closure_struct_type_name_for_arity(arity)
    let fn_type = closure_function_pointer_type_for_arity(arity)
    definitions = definitions + type_name + " = type { " + fn_type + ", i8* }\n"
  }
  if definitions.length() > 0 {
    definitions = definitions + "\n"
  }
  definitions
}

///|
fn collect_all_functions(statements : Array[Stmt]) -> Array[FunctionStmt] {
  let functions : Array[FunctionStmt] = Array::new()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) => {
        functions.push(function_stmt)
        collect_nested_functions(function_stmt.body, functions)
      }
      _ => ()
    }
  }
  functions
}

///|
fn collect_nested_functions(
  statements : Array[Stmt],
  accumulator : Array[FunctionStmt],
) -> Unit {
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) => {
        accumulator.push(function_stmt)
        collect_nested_functions(function_stmt.body, accumulator)
      }
      StmtKind::If(if_stmt) => {
        collect_nested_functions(if_stmt.then_body, accumulator)
        if if_stmt.else_body.length() > 0 {
          collect_nested_functions(if_stmt.else_body, accumulator)
        }
      }
      StmtKind::While(while_stmt) =>
        collect_nested_functions(while_stmt.body, accumulator)
      StmtKind::Guard(guard_stmt) =>
        match guard_stmt.else_clause {
          Some(clause) =>
            match clause.body {
              Some(body_expr) =>
                collect_functions_from_expr(body_expr, accumulator)
              None => ()
            }
          None => ()
        }
      StmtKind::Switch(switch_stmt) => {
        for case in switch_stmt.cases {
          collect_functions_from_expr(case.value, accumulator)
        }
        match switch_stmt.default_case {
          Some(default_case) =>
            collect_functions_from_expr(default_case.value, accumulator)
          None => ()
        }
      }
      StmtKind::ExprStmt(expr) => collect_functions_from_expr(expr, accumulator)
      StmtKind::Let(let_stmt) =>
        collect_functions_from_expr(let_stmt.value, accumulator)
      StmtKind::Assign(assign_stmt) => {
        collect_functions_from_expr(assign_stmt.target, accumulator)
        collect_functions_from_expr(assign_stmt.value, accumulator)
      }
      StmtKind::Return(return_stmt) =>
        match return_stmt.value {
          Some(value) => collect_functions_from_expr(value, accumulator)
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn collect_functions_from_expr(
  expr : Expr,
  accumulator : Array[FunctionStmt],
) -> Unit {
  match expr.kind {
    ExprKind::If(if_expr) => {
      collect_functions_from_expr(if_expr.condition, accumulator)
      collect_functions_from_expr(if_expr.then_expr, accumulator)
      collect_functions_from_expr(if_expr.else_expr, accumulator)
    }
    ExprKind::Binary(binary_expr) => {
      collect_functions_from_expr(binary_expr.left, accumulator)
      collect_functions_from_expr(binary_expr.right, accumulator)
    }
    ExprKind::Unary(unary_expr) =>
      collect_functions_from_expr(unary_expr.operand, accumulator)
    ExprKind::Call(call_expr) => {
      collect_functions_from_expr(call_expr.callee, accumulator)
      for argument in call_expr.arguments {
        collect_functions_from_expr(argument, accumulator)
      }
    }
    ExprKind::ArrayLiteral(array_lit) =>
      for element in array_lit.elements {
        collect_functions_from_expr(element, accumulator)
      }
    ExprKind::Index(index_expr) => {
      collect_functions_from_expr(index_expr.array, accumulator)
      collect_functions_from_expr(index_expr.index, accumulator)
    }
    ExprKind::TupleLiteral(tuple_lit) =>
      for element in tuple_lit.elements {
        collect_functions_from_expr(element, accumulator)
      }
    ExprKind::StructLiteral(struct_lit) =>
      for field in struct_lit.fields {
        collect_functions_from_expr(field.value, accumulator)
      }
    ExprKind::Match(match_expr) => {
      collect_functions_from_expr(match_expr.value, accumulator)
      for arm in match_expr.arms {
        collect_functions_from_expr(arm.value, accumulator)
      }
    }
    ExprKind::FieldAccess(field_access) =>
      collect_functions_from_expr(field_access.object, accumulator)
    _ => ()
  }
}

///|
fn analyze_closures(statements : Array[Stmt]) -> ClosureMetadata {
  let metadata = ClosureMetadata::new()
  let global_scope = gather_global_scope(statements)
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) =>
        analyze_function_closure(function_stmt, global_scope, metadata, -1)
      _ => ()
    }
  }
  metadata
}

///|
fn analyze_function_closure(
  function_stmt : FunctionStmt,
  parent_scope : Array[String],
  metadata : ClosureMetadata,
  parent_function_id : Int,
) -> Unit {
  let free_vars = compute_function_free_vars(
    function_stmt, parent_scope, metadata,
  )
  metadata.record(
    function_id(function_stmt),
    parent_function_id,
    function_stmt.name.lexeme,
    free_vars,
    function_stmt,
  )
}

///|
fn init_function_scope(function_stmt : FunctionStmt) -> Array[String] {
  let local_scope : Array[String] = Array::new()
  add_name_to_scope(local_scope, function_stmt.name.lexeme)
  for param in function_stmt.parameters {
    add_name_to_scope(local_scope, param.name.lexeme)
  }
  local_scope
}

///|
fn compute_function_free_vars(
  function_stmt : FunctionStmt,
  parent_scope : Array[String],
  metadata : ClosureMetadata,
) -> Array[String] {
  let free_vars : Array[String] = Array::new()
  let local_scope = init_function_scope(function_stmt)
  collect_free_vars_in_statements(
    function_stmt.body,
    parent_scope,
    local_scope,
    free_vars,
    metadata,
    function_id(function_stmt),
  )
  free_vars
}

///|
fn collect_free_vars_in_statements(
  statements : Array[Stmt],
  parent_scope : Array[String],
  local_scope : Array[String],
  free_vars : Array[String],
  metadata : ClosureMetadata,
  current_function_id : Int,
) -> Unit {
  for stmt in statements {
    collect_free_vars_in_stmt(
      stmt, parent_scope, local_scope, free_vars, metadata, current_function_id,
    )
  }
}

///|
fn collect_free_vars_in_stmt(
  stmt : Stmt,
  parent_scope : Array[String],
  local_scope : Array[String],
  free_vars : Array[String],
  metadata : ClosureMetadata,
  current_function_id : Int,
) -> Unit {
  match stmt.kind {
    StmtKind::ExprStmt(expr) =>
      collect_free_vars_in_expr(expr, parent_scope, local_scope, free_vars)
    StmtKind::Let(let_stmt) => {
      collect_free_vars_in_expr(
        let_stmt.value,
        parent_scope,
        local_scope,
        free_vars,
      )
      add_name_to_scope(local_scope, let_stmt.name.lexeme)
    }
    StmtKind::Assign(assign_stmt) => {
      collect_free_vars_in_expr(
        assign_stmt.target,
        parent_scope,
        local_scope,
        free_vars,
      )
      collect_free_vars_in_expr(
        assign_stmt.value,
        parent_scope,
        local_scope,
        free_vars,
      )
    }
    StmtKind::Return(return_stmt) =>
      match return_stmt.value {
        Some(value) =>
          collect_free_vars_in_expr(value, parent_scope, local_scope, free_vars)
        None => ()
      }
    StmtKind::While(while_stmt) => {
      collect_free_vars_in_expr(
        while_stmt.condition,
        parent_scope,
        local_scope,
        free_vars,
      )
      let body_scope = clone_string_array(local_scope)
      collect_free_vars_in_statements(
        while_stmt.body,
        parent_scope,
        body_scope,
        free_vars,
        metadata,
        current_function_id,
      )
    }
    StmtKind::If(if_stmt) => {
      collect_free_vars_in_expr(
        if_stmt.condition,
        parent_scope,
        local_scope,
        free_vars,
      )
      let then_scope = clone_string_array(local_scope)
      collect_free_vars_in_statements(
        if_stmt.then_body,
        parent_scope,
        then_scope,
        free_vars,
        metadata,
        current_function_id,
      )
      if if_stmt.else_body.length() > 0 {
        let else_scope = clone_string_array(local_scope)
        collect_free_vars_in_statements(
          if_stmt.else_body,
          parent_scope,
          else_scope,
          free_vars,
          metadata,
          current_function_id,
        )
      }
    }
    StmtKind::Function(function_stmt) => {
      let nested_parent_scope = merge_scopes(parent_scope, local_scope)
      analyze_function_closure(
        function_stmt, nested_parent_scope, metadata, current_function_id,
      )
      add_name_to_scope(local_scope, function_stmt.name.lexeme)
    }
    StmtKind::Guard(guard_stmt) => {
      collect_free_vars_in_expr(
        guard_stmt.condition,
        parent_scope,
        local_scope,
        free_vars,
      )
      match guard_stmt.pattern {
        Some(pattern) => {
          let pattern_scope = clone_string_array(local_scope)
          collect_pattern_bindings(pattern, pattern_scope)
          match guard_stmt.else_clause {
            Some(clause) =>
              match clause.body {
                Some(body_expr) =>
                  collect_free_vars_in_expr(
                    body_expr, parent_scope, pattern_scope, free_vars,
                  )
                None => ()
              }
            None => ()
          }
        }
        None => ()
      }
    }
    StmtKind::Switch(switch_stmt) => {
      collect_free_vars_in_expr(
        switch_stmt.value,
        parent_scope,
        local_scope,
        free_vars,
      )
      for case in switch_stmt.cases {
        let case_scope = clone_string_array(local_scope)
        collect_pattern_bindings(case.pattern, case_scope)
        collect_free_vars_in_expr(
          case.value,
          parent_scope,
          case_scope,
          free_vars,
        )
      }
      match switch_stmt.default_case {
        Some(default_case) =>
          collect_free_vars_in_expr(
            default_case.value,
            parent_scope,
            local_scope,
            free_vars,
          )
        None => ()
      }
    }
    StmtKind::Struct(_) | StmtKind::Enum(_) => ()
  }
}

///|
fn collect_pattern_bindings(pattern : Pattern, scope : Array[String]) -> Unit {
  match pattern.kind {
    PatternKind::Ident(token) => add_name_to_scope(scope, token.lexeme)
    PatternKind::Tuple(tuple_pattern) =>
      for element in tuple_pattern.elements {
        collect_pattern_bindings(element, scope)
      }
    PatternKind::Struct(struct_pattern) =>
      for field in struct_pattern.fields {
        match field.pattern {
          Some(sub_pattern) => collect_pattern_bindings(sub_pattern, scope)
          None => add_name_to_scope(scope, field.name.lexeme)
        }
      }
    PatternKind::EnumVariant(enum_pattern) =>
      for argument in enum_pattern.arguments {
        collect_pattern_bindings(argument, scope)
      }
    PatternKind::Or(or_pattern) =>
      for sub_pattern in or_pattern.patterns {
        collect_pattern_bindings(sub_pattern, scope)
      }
    PatternKind::Wildcard(_) | PatternKind::Literal(_) => ()
  }
}

///|
fn collect_free_vars_in_expr(
  expr : Expr,
  parent_scope : Array[String],
  local_scope : Array[String],
  free_vars : Array[String],
) -> Unit {
  match expr.kind {
    ExprKind::Ident(token) => {
      let name = token.lexeme
      if !scope_contains(local_scope, name) &&
        scope_contains(parent_scope, name) {
        record_free_var(free_vars, name)
      }
    }
    ExprKind::Binary(binary_expr) => {
      collect_free_vars_in_expr(
        binary_expr.left,
        parent_scope,
        local_scope,
        free_vars,
      )
      collect_free_vars_in_expr(
        binary_expr.right,
        parent_scope,
        local_scope,
        free_vars,
      )
    }
    ExprKind::Unary(unary_expr) =>
      collect_free_vars_in_expr(
        unary_expr.operand,
        parent_scope,
        local_scope,
        free_vars,
      )
    ExprKind::Call(call_expr) => {
      collect_free_vars_in_expr(
        call_expr.callee,
        parent_scope,
        local_scope,
        free_vars,
      )
      for argument in call_expr.arguments {
        collect_free_vars_in_expr(
          argument, parent_scope, local_scope, free_vars,
        )
      }
    }
    ExprKind::ArrayLiteral(array_lit) =>
      for element in array_lit.elements {
        collect_free_vars_in_expr(element, parent_scope, local_scope, free_vars)
      }
    ExprKind::Index(index_expr) => {
      collect_free_vars_in_expr(
        index_expr.array,
        parent_scope,
        local_scope,
        free_vars,
      )
      collect_free_vars_in_expr(
        index_expr.index,
        parent_scope,
        local_scope,
        free_vars,
      )
    }
    ExprKind::TupleLiteral(tuple_lit) =>
      for element in tuple_lit.elements {
        collect_free_vars_in_expr(element, parent_scope, local_scope, free_vars)
      }
    ExprKind::If(if_expr) => {
      collect_free_vars_in_expr(
        if_expr.condition,
        parent_scope,
        local_scope,
        free_vars,
      )
      collect_free_vars_in_expr(
        if_expr.then_expr,
        parent_scope,
        local_scope,
        free_vars,
      )
      collect_free_vars_in_expr(
        if_expr.else_expr,
        parent_scope,
        local_scope,
        free_vars,
      )
    }
    ExprKind::FieldAccess(field_access) =>
      collect_free_vars_in_expr(
        field_access.object,
        parent_scope,
        local_scope,
        free_vars,
      )
    ExprKind::StructLiteral(struct_lit) =>
      for field in struct_lit.fields {
        collect_free_vars_in_expr(
          field.value,
          parent_scope,
          local_scope,
          free_vars,
        )
      }
    ExprKind::Match(match_expr) => {
      collect_free_vars_in_expr(
        match_expr.value,
        parent_scope,
        local_scope,
        free_vars,
      )
      for arm in match_expr.arms {
        let arm_scope = clone_string_array(local_scope)
        collect_pattern_bindings(arm.pattern, arm_scope)
        match arm.guard_expr {
          Some(guard_expr) =>
            collect_free_vars_in_expr(
              guard_expr, parent_scope, arm_scope, free_vars,
            )
          None => ()
        }
        collect_free_vars_in_expr(arm.value, parent_scope, arm_scope, free_vars)
      }
    }
    ExprKind::Literal(_) => ()
  }
}

///|
fn generate_llvm(statements : Array[Stmt]) -> String {
  let mut output = "target triple = \"riscv64-unknown-linux-gnu\"\n\n"
  let closure_metadata = analyze_closures(statements)

  // 生成外部函数声明
  output = output + generate_external_declarations()
  output = output + generate_closure_env_type_definitions(closure_metadata)
  output = output + generate_closure_struct_definitions(closure_metadata)

  // 第一遍：收集结构体定义并生成类型定义
  let struct_defs_map : Array[(String, Array[String])] = Array::new()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Struct(struct_def) => {
        let struct_name = struct_def.name.lexeme
        let field_names : Array[String] = Array::new()
        for field in struct_def.fields {
          field_names.push(field.name.lexeme)
        }
        struct_defs_map.push((struct_name, field_names))
        // 生成结构体类型定义
        output = output + "%" + struct_name + " = type { "
        let mut first = true
        for _field in struct_def.fields {
          if first {
            output = output + "i32"
            first = false
          } else {
            output = output + ", i32"
          }
        }
        output = output + " }\n"
      }
      _ => ()
    }
  }
  output = output + "\n"

  // 第二遍：生成所有函数定义（包含嵌套函数）
  let main_statements : Array[Stmt] = Array::new()
  let mut has_main_function = false
  let mut has_main_statements = false
  let all_functions = collect_all_functions(statements)
  for function_stmt in all_functions {
    let entry = closure_metadata.get_entry(function_id(function_stmt))
    let is_top_level = match entry {
      Some(info) => info.parent_id == -1
      None => true
    }
    if is_top_level && function_stmt.name.lexeme == "main" {
      has_main_function = true
    }
    let func_code = llvm_gen_function(
      struct_defs_map, function_stmt, closure_metadata,
    )
    output = output + func_code
  }
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(_) => ()
      _ => {
        ignore(main_statements.push(stmt))
        has_main_statements = true
      }
    }
  }

  // 如果没有 main 函数，且 main_statements 不为空，生成一个 main 函数
  // 确保不会重复生成 main 函数
  let mut emitted_minimbt_main = false
  if !has_main_function && has_main_statements && main_statements.length() > 0 {
    let main_code = llvm_gen_main_function(
      struct_defs_map, main_statements, closure_metadata,
    )
    output = output + main_code
    emitted_minimbt_main = true
  } else if has_main_function {
    emitted_minimbt_main = true
  }
  if emitted_minimbt_main {
    output = output +
      "define i32 @main() {\n" +
      "entry:\n" +
      "  call void @minimbt_main()\n" +
      "  ret i32 0\n" +
      "}\n"
  }
  output
}

///|
// 生成外部函数声明
// 支持 riscv_rt 运行时库中的所有函数
fn generate_external_declarations() -> String {
  let mut declarations = ""
  for name in builtin_function_names() {
    match get_builtin_function(name) {
      Some(info) =>
        declarations = declarations + format_builtin_declaration(info)
      None => ()
    }
  }
  declarations = declarations +
    "declare i32* @minimbt_create_array(i32, i32)\n" +
    "declare i8** @minimbt_create_ptr_array(i32, i8*)\n" +
    "declare double* @minimbt_create_float_array(i32, double)\n" +
    "declare i8* @minimbt_malloc(i32)\n"
  declarations + "\n"
}

///|
// 生成主函数
fn llvm_gen_main_function(
  struct_defs_map : Array[(String, Array[String])],
  main_statements : Array[Stmt],
  closure_metadata : ClosureMetadata,
) -> String {
  // 生成 minimbt_main 函数以匹配 riscv_rt/start.c
  let mut output = "define void @minimbt_main() {\n"
  output = output + "entry:\n"
  let gen = LLVMGen::new(closure_metadata.clone())
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }
  gen.current_return_type = "void"
  let (body_code, _last_expr_temp) = llvm_gen_statements(gen, main_statements)
  output = output + body_code
  // main 函数返回 void（匹配 riscv_rt/start.c）
  // 检查函数体是否已经包含 return 语句
  let has_return = body_code.contains("ret void") ||
    body_code.contains("ret i32")
  if !has_return {
    output = output + "  ret void\n"
  }
  output = output + "}\n"
  output
}

///|
// 生成语句序列
// 返回 (生成的代码, 最后一个表达式的临时变量名)
fn llvm_gen_statements(
  gen : LLVMGen,
  statements : Array[Stmt],
) -> (String, String) {
  let mut code = ""
  let mut last_expr_temp = ""
  for stmt in statements {
    match stmt.kind {
      StmtKind::Let(let_stmt) => {
        let (stmt_code, value_temp) = llvm_gen_let(gen, let_stmt)
        code = code + stmt_code
        if let_stmt.name.lexeme == "_" {
          last_expr_temp = value_temp
        }
      }
      StmtKind::ExprStmt(expr) => {
        let (expr_code, expr_temp) = llvm_gen_expr(gen, expr)
        code = code + expr_code
        if expr_code == "" && expr_temp != "" {
          code = code + "  " + expr_temp + " = add i32 0, 0\n"
        }
        last_expr_temp = expr_temp
      }
      StmtKind::Return(return_stmt) => {
        let ret_code = llvm_gen_return(
          gen,
          return_stmt,
          gen.current_return_type,
        )
        code = code + ret_code
        last_expr_temp = ""
        break
      }
      StmtKind::Assign(assign_stmt) => {
        let (assign_code, value_temp) = llvm_gen_assign(gen, assign_stmt)
        code = code + assign_code
        last_expr_temp = value_temp
      }
      StmtKind::While(while_stmt) => {
        let (while_code, while_last_temp) = llvm_gen_while(gen, while_stmt)
        code = code + while_code
        if while_last_temp != "" {
          last_expr_temp = while_last_temp
        }
      }
      StmtKind::If(if_stmt) => {
        let (if_code, if_last_temp) = llvm_gen_if(gen, if_stmt)
        code = code + if_code
        if if_last_temp != "" {
          last_expr_temp = if_last_temp
        }
      }
      StmtKind::Function(_function_stmt) =>
        // 嵌套函数定义不在语句序列中处理
        ()
      _ => ()
    }
  }
  (code, last_expr_temp)
}

///|
// 生成表达式的LLVM IR代码
// 返回 ExprValue，包含代码、值和 LLVM 类型
fn llvm_gen_expr_value(gen : LLVMGen, expr : Expr) -> ExprValue {
  match expr.kind {
    ExprKind::Literal(token) => llvm_gen_literal(gen, token)
    ExprKind::Ident(token) => llvm_gen_ident(gen, token)
    ExprKind::Binary(binary_expr) => llvm_gen_binary(gen, binary_expr)
    ExprKind::Unary(unary_expr) => llvm_gen_unary(gen, unary_expr)
    ExprKind::Call(call_expr) => llvm_gen_call(gen, call_expr)
    ExprKind::If(if_expr) => llvm_gen_if_expr(gen, if_expr)
    ExprKind::ArrayLiteral(array_lit) => llvm_gen_array_literal(gen, array_lit)
    ExprKind::Index(index_expr) => llvm_gen_index(gen, index_expr)
    ExprKind::TupleLiteral(tuple_lit) => llvm_gen_tuple_literal(gen, tuple_lit)
    ExprKind::StructLiteral(struct_lit) =>
      llvm_gen_struct_literal(gen, struct_lit)
    ExprKind::FieldAccess(field_access) =>
      llvm_gen_field_access(gen, field_access)
    ExprKind::Match(match_expr) => llvm_gen_match(gen, match_expr)
  }
}

///|
fn llvm_gen_expr(gen : LLVMGen, expr : Expr) -> (String, String) {
  let value = llvm_gen_expr_value(gen, expr)
  (value.code, value.value)
}

///|
// TODO: 以下函数需要逐个实现
// 1. llvm_gen_literal - 字面量生成
// 2. llvm_gen_ident - 标识符生成
// 3. llvm_gen_binary - 二元表达式生成
// 4. llvm_gen_unary - 一元表达式生成
// 5. llvm_gen_call - 函数调用生成
// 6. llvm_gen_if_expr - if 表达式生成（需要正确处理 phi 节点）
// 7. llvm_gen_let - let 语句生成
// 8. llvm_gen_assign - 赋值语句生成
// 9. llvm_gen_if - if 语句生成
// 10. llvm_gen_while - while 循环生成
// 11. llvm_gen_return - return 语句生成
// 12. llvm_gen_function - 函数定义生成
// 13. llvm_gen_array_literal - 数组字面量生成
// 14. llvm_gen_index - 数组索引生成
// 15. llvm_gen_tuple_literal - 元组字面量生成
// 16. llvm_gen_struct_literal - 结构体字面量生成
// 17. llvm_gen_field_access - 字段访问生成
// 18. llvm_gen_match - match 表达式生成

///|
// 模块1: 字面量生成
// 支持：整数、布尔值、Unit 类型
fn llvm_gen_literal(gen : LLVMGen, token : Token) -> ExprValue {
  match token.kind {
    TokenKind::LiteralInt => {
      let temp = gen.next_temp()
      let code = "  " + temp + " = add i32 0, " + token.lexeme + "\n"
      expr_value(code, temp, "i32")
    }
    TokenKind::LiteralBool =>
      match token.lexeme {
        "true" => {
          let temp = gen.next_temp()
          let code = "  " + temp + " = add i32 0, 1\n"
          expr_value(code, temp, "i32")
        }
        "false" => {
          let temp = gen.next_temp()
          let code = "  " + temp + " = add i32 0, 0\n"
          expr_value(code, temp, "i32")
        }
        _ => {
          let temp = gen.next_temp()
          expr_value("", temp, "i32")
        }
      }
    TokenKind::LParen => {
      // Unit literal: () - 表示为 i32 0
      let temp = gen.next_temp()
      let code = "  " + temp + " = add i32 0, 0\n"
      expr_value(code, temp, "i32")
    }
    _ => {
      let temp = gen.next_temp()
      expr_value("", temp, "i32")
    }
  }
}

///|
// 模块2: 标识符生成
// 支持：变量访问、函数名识别（嵌套函数）
fn llvm_gen_ident(gen : LLVMGen, token : Token) -> ExprValue {
  match gen.get_var_entry(token.lexeme) {
    Some((var_ptr, var_type, closure_arity)) => {
      let temp = gen.next_temp()
      let code = "  " +
        temp +
        " = load " +
        var_type +
        ", " +
        var_type +
        "* " +
        var_ptr +
        "\n"
      if closure_arity >= 0 {
        expr_value_with_closure(code, temp, var_type, closure_arity)
      } else {
        expr_value(code, temp, var_type)
      }
    }
    None =>
      match gen.find_local_function_entry(token.lexeme) {
        Some(entry) => llvm_gen_create_closure(gen, entry)
        None => {
          let temp = gen.next_temp()
          expr_value("", temp, "i32")
        }
      }
  }
}

///|
fn llvm_gen_create_closure(gen : LLVMGen, entry : ClosureEntry) -> ExprValue {
  let param_count = entry.function_stmt.parameters.length()
  let closure_struct_type = closure_struct_type_name_for_arity(param_count)
  let closure_ptr_type = closure_struct_pointer_type_for_arity(param_count)
  let fn_pointer_type = closure_function_pointer_type(entry.function_stmt)
  let mut code = ""

  // 构建环境
  let mut env_ptr_value = "null"
  if entry.free_vars.length() > 0 {
    let env_size = entry.free_vars.length() * 4
    let env_raw = gen.next_temp()
    code = code +
      "  " +
      env_raw +
      " = call i8* @minimbt_malloc(i32 " +
      env_size.to_string() +
      ")\n"
    let env_struct_name = closure_env_struct_name(entry.id)
    let env_struct_ptr_type = env_struct_name + "*"
    let env_struct_ptr = gen.next_temp()
    code = code +
      "  " +
      env_struct_ptr +
      " = bitcast i8* " +
      env_raw +
      " to " +
      env_struct_ptr_type +
      "\n"
    let mut index = 0
    for var_name in entry.free_vars {
      let field_ptr = gen.next_temp()
      code = code +
        "  " +
        field_ptr +
        " = getelementptr " +
        env_struct_name +
        ", " +
        env_struct_ptr_type +
        " " +
        env_struct_ptr +
        ", i32 0, i32 " +
        index.to_string() +
        "\n"
      match gen.get_var_entry(var_name) {
        Some((var_ptr, var_type, _)) => {
          let loaded = gen.next_temp()
          code = code +
            "  " +
            loaded +
            " = load " +
            var_type +
            ", " +
            var_type +
            "* " +
            var_ptr +
            "\n"
          let mut stored_value = loaded
          if var_type != "i32" {
            let cast_temp = gen.next_temp()
            code = code +
              "  " +
              cast_temp +
              " = ptrtoint " +
              var_type +
              " " +
              loaded +
              " to i32\n"
            stored_value = cast_temp
          }
          code = code +
            "  store i32 " +
            stored_value +
            ", i32* " +
            field_ptr +
            "\n"
        }
        None => ()
      }
      index = index + 1
    }
    env_ptr_value = env_raw
  }

  // 分配闭包结构
  let closure_size_temp = gen.next_temp()
  code = code + "  " + closure_size_temp + " = add i32 0, 16\n"
  let closure_raw = gen.next_temp()
  code = code +
    "  " +
    closure_raw +
    " = call i8* @minimbt_malloc(i32 " +
    closure_size_temp +
    ")\n"
  let closure_ptr = gen.next_temp()
  code = code +
    "  " +
    closure_ptr +
    " = bitcast i8* " +
    closure_raw +
    " to " +
    closure_ptr_type +
    "\n"

  // 存储函数指针
  let fn_field_ptr = gen.next_temp()
  code = code +
    "  " +
    fn_field_ptr +
    " = getelementptr " +
    closure_struct_type +
    ", " +
    closure_ptr_type +
    " " +
    closure_ptr +
    ", i32 0, i32 0\n"
  code = code +
    "  store " +
    fn_pointer_type +
    " @closure_fn_" +
    entry.id.to_string() +
    ", " +
    fn_pointer_type +
    "* " +
    fn_field_ptr +
    "\n"

  // 存储环境指针
  let env_field_ptr = gen.next_temp()
  code = code +
    "  " +
    env_field_ptr +
    " = getelementptr " +
    closure_struct_type +
    ", " +
    closure_ptr_type +
    " " +
    closure_ptr +
    ", i32 0, i32 1\n"
  code = code +
    "  store i8* " +
    env_ptr_value +
    ", i8** " +
    env_field_ptr +
    "\n"
  expr_value_with_closure(code, closure_ptr, closure_ptr_type, param_count)
}

///|
// 模块3: 二元表达式生成
// 支持：算术运算（+、-、*、/、%）、比较运算（<、>、<=、>=、==、!=）、逻辑运算（&&、||）
fn llvm_gen_binary(gen : LLVMGen, binary_expr : BinaryExpr) -> ExprValue {
  let left_value = llvm_gen_expr_value(gen, binary_expr.left)
  let right_value = llvm_gen_expr_value(gen, binary_expr.right)
  let temp = gen.next_temp()
  let op_code = llvm_gen_binary_op(
    gen,
    binary_expr.operator,
    left_value.value,
    right_value.value,
    temp,
  )
  let code = left_value.code + right_value.code + op_code
  expr_value(code, temp, "i32")
}

///|
// 生成二元运算符的LLVM IR代码
fn llvm_gen_binary_op(
  gen : LLVMGen,
  operator : Token,
  left_temp : String,
  right_temp : String,
  result_temp : String,
) -> String {
  match operator.kind {
    TokenKind::Plus =>
      "  " + result_temp + " = add i32 " + left_temp + ", " + right_temp + "\n"
    TokenKind::Minus =>
      "  " + result_temp + " = sub i32 " + left_temp + ", " + right_temp + "\n"
    TokenKind::Star =>
      "  " + result_temp + " = mul i32 " + left_temp + ", " + right_temp + "\n"
    TokenKind::Slash =>
      "  " + result_temp + " = sdiv i32 " + left_temp + ", " + right_temp + "\n"
    TokenKind::Percent =>
      "  " + result_temp + " = srem i32 " + left_temp + ", " + right_temp + "\n"
    TokenKind::Less => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp slt i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::Greater => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp sgt i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::LessEqual => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp sle i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::GreaterEqual => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp sge i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::EqualEqual => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp eq i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::BangEqual => {
      let cmp_temp = gen.next_temp()
      "  " +
      cmp_temp +
      " = icmp ne i32 " +
      left_temp +
      ", " +
      right_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      cmp_temp +
      " to i32\n"
    }
    TokenKind::AmpAmp => {
      let cmp1_temp = gen.next_temp()
      let cmp2_temp = gen.next_temp()
      let bool_temp = gen.next_temp()
      "  " +
      cmp1_temp +
      " = icmp ne i32 " +
      left_temp +
      ", 0\n  " +
      cmp2_temp +
      " = icmp ne i32 " +
      right_temp +
      ", 0\n  " +
      bool_temp +
      " = and i1 " +
      cmp1_temp +
      ", " +
      cmp2_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      bool_temp +
      " to i32\n"
    }
    TokenKind::PipePipe => {
      let cmp1_temp = gen.next_temp()
      let cmp2_temp = gen.next_temp()
      let bool_temp = gen.next_temp()
      "  " +
      cmp1_temp +
      " = icmp ne i32 " +
      left_temp +
      ", 0\n  " +
      cmp2_temp +
      " = icmp ne i32 " +
      right_temp +
      ", 0\n  " +
      bool_temp +
      " = or i1 " +
      cmp1_temp +
      ", " +
      cmp2_temp +
      "\n  " +
      result_temp +
      " = zext i1 " +
      bool_temp +
      " to i32\n"
    }
    _ => "  " + result_temp + " = add i32 0, 0\n"
  }
}

///|
// 模块4: 一元表达式生成
// 支持：取负（-）、逻辑非（!）
fn llvm_gen_unary(gen : LLVMGen, unary_expr : UnaryExpr) -> ExprValue {
  match unary_expr.operator.kind {
    TokenKind::Minus => {
      let operand_value = llvm_gen_expr_value(gen, unary_expr.operand)
      let temp = gen.next_temp()
      let code = operand_value.code +
        "  " +
        temp +
        " = sub i32 0, " +
        operand_value.value +
        "\n"
      expr_value(code, temp, "i32")
    }
    TokenKind::Bang => {
      let operand_value = llvm_gen_expr_value(gen, unary_expr.operand)
      let cmp_temp = gen.next_temp()
      let temp = gen.next_temp()
      let code = operand_value.code +
        "  " +
        cmp_temp +
        " = icmp eq i32 " +
        operand_value.value +
        ", 0\n  " +
        temp +
        " = zext i1 " +
        cmp_temp +
        " to i32\n"
      expr_value(code, temp, "i32")
    }
    _ => {
      let temp = gen.next_temp()
      expr_value("", temp, "i32")
    }
  }
}

///|
// 模块5: 函数调用生成
// 支持：普通函数调用、嵌套函数调用（后续支持闭包）
fn llvm_gen_call(gen : LLVMGen, call_expr : CallExpr) -> ExprValue {
  // 生成参数代码
  let mut args_code = ""
  let args_temps : Array[String] = Array::new()
  for arg in call_expr.arguments {
    let arg_value = llvm_gen_expr_value(gen, arg)
    args_code = args_code + arg_value.code
    args_temps.push(arg_value.value)
  }

  // 获取函数名和函数类型
  // 支持普通函数调用（Ident）和限定函数调用（FieldAccess，如 Array::make）
  let mut func_name = ""
  let mut return_type = "i32"
  let mut is_void = false
  let mut builtin_param_types : Array[String]? = None
  let mut return_closure_arity = -1
  match call_expr.callee.kind {
    ExprKind::Ident(token) =>
      match gen.get_var_entry(token.lexeme) {
        Some(_) => {
          let callee_value = llvm_gen_ident(gen, token)
          if callee_value.closure_arity >= 0 {
            return llvm_gen_call_closure(
              gen, callee_value, args_code, args_temps,
            )
          } else {
            func_name = "@unknown"
          }
        }
        None => {
          let name = token.lexeme
          match gen.find_function_entry_by_name(name, -1) {
            Some(entry) =>
              if entry.function_stmt.return_type_is_function {
                return_closure_arity = entry.function_stmt.function_return_param_types.length()
              }
            None => ()
          }
          match get_builtin_function(name) {
            Some(info) => {
              func_name = info.ir_name
              return_type = info.return_type
              is_void = info.is_void
              builtin_param_types = Some(info.param_types)
            }
            None => func_name = "@" + name
          }
        }
      }
    ExprKind::FieldAccess(field_access) => {
      let is_array_make = match field_access.object.kind {
        ExprKind::Ident(token) => token.lexeme == "Array"
        _ => false
      }
      if is_array_make && field_access.field.lexeme == "make" {
        func_name = "@minimbt_create_array"
        return_type = "i32*"
        builtin_param_types = Some(builtin_param_types_two("i32", "i32"))
      } else {
        let module_name = match field_access.object.kind {
          ExprKind::Ident(token) => token.lexeme
          _ => ""
        }
        func_name = "@" + module_name + "_" + field_access.field.lexeme
      }
    }
    _ => {
      let callee_value = llvm_gen_expr_value(gen, call_expr.callee)
      if callee_value.closure_arity >= 0 {
        return llvm_gen_call_closure(gen, callee_value, args_code, args_temps)
      } else {
        func_name = "@unknown"
      }
    }
  }

  // 检查是否是 @unknown 函数（不应该调用）
  if func_name == "@unknown" {
    // 对于未知函数，生成错误处理代码
    // 暂时返回 0，实际应该报告错误
    let temp = gen.next_temp()
    let code = "  " + temp + " = add i32 0, 0\n"
    return expr_value(code, temp, "i32")
  }

  // 生成函数调用代码
  let args_count = args_temps.length()
  let param_types_for_call : Array[String] = match builtin_param_types {
    Some(types) => types
    None => Array::new()
  }
  if param_types_for_call.length() == 0 {
    let mut idx = 0
    while idx < args_count {
      param_types_for_call.push("i32")
      idx = idx + 1
    }
  } else if param_types_for_call.length() < args_count {
    let fallback_index = param_types_for_call.length() - 1
    let fallback_type = param_types_for_call[fallback_index]
    while param_types_for_call.length() < args_count {
      param_types_for_call.push(fallback_type)
    }
  }
  let mut param_type_list = ""
  let mut index = 0
  while index < args_count {
    let arg_temp = args_temps[index]
    let param_type = param_types_for_call[index]
    let entry = param_type + " " + arg_temp
    if param_type_list == "" {
      param_type_list = entry
    } else {
      param_type_list = param_type_list + ", " + entry
    }
    index = index + 1
  }
  if is_void {
    // void 函数，不返回值
    let call_code = "  call void " + func_name + "(" + param_type_list + ")\n"
    // 对于 void 函数，返回一个 dummy 值（0）
    let result_temp = gen.next_temp()
    let code = args_code + call_code + "  " + result_temp + " = add i32 0, 0\n"
    expr_value(code, result_temp, "i32")
  } else {
    // 有返回值的函数
    let result_temp = gen.next_temp()
    let call_code = "  " +
      result_temp +
      " = call " +
      return_type +
      " " +
      func_name +
      "(" +
      param_type_list +
      ")\n"
    let code = args_code + call_code

    // 如果返回类型是指针类型（如 i32*），需要转换为 i32（通过 ptrtoint）
    // 但为了简化，我们暂时假设所有函数调用都返回 i32
    // 对于 Array::make，它返回 i32*，但我们暂时将其转换为 i32
    if return_type == "i32*" {
      // 指针类型，需要转换为 i32（通过 ptrtoint）
      let ptr_temp = result_temp
      let int_temp = gen.next_temp()
      let ptrtoint_code = "  " +
        int_temp +
        " = ptrtoint i32* " +
        ptr_temp +
        " to i32\n"
      expr_value(code + ptrtoint_code, int_temp, "i32")
    } else if return_closure_arity >= 0 {
      expr_value_with_closure(
        code, result_temp, return_type, return_closure_arity,
      )
    } else if return_closure_arity >= 0 {
      expr_value_with_closure(
        code, result_temp, return_type, return_closure_arity,
      )
    } else {
      expr_value(code, result_temp, return_type)
    }
  }
}

///|
// 模块9: if 表达式生成
// 使用 alloca + store 模式避免复杂 phi
fn llvm_gen_if_expr(gen : LLVMGen, if_expr : IfExpr) -> ExprValue {
  let cond_value = llvm_gen_expr_value(gen, if_expr.condition)
  let then_label = gen.next_label()
  let else_label = gen.next_label()
  let merge_label = gen.next_label()
  let result_ptr = gen.next_temp()
  let alloc_code = "  " + result_ptr + " = alloca i32\n"
  let cmp_temp = gen.next_temp()
  let cmp_code = "  " +
    cmp_temp +
    " = icmp ne i32 " +
    cond_value.value +
    ", 0\n"
  let br_code = "  br i1 " +
    cmp_temp +
    ", label %" +
    then_label +
    ", label %" +
    else_label +
    "\n"
  let then_value = llvm_gen_expr_value(gen, if_expr.then_expr)
  let then_temp = if then_value.value != "" { then_value.value } else { "0" }
  let then_store_code = "  store i32 " +
    then_temp +
    ", i32* " +
    result_ptr +
    "\n" +
    "  br label %" +
    merge_label +
    "\n"
  let else_value = llvm_gen_expr_value(gen, if_expr.else_expr)
  let else_temp = if else_value.value != "" { else_value.value } else { "0" }
  let else_store_code = "  store i32 " +
    else_temp +
    ", i32* " +
    result_ptr +
    "\n" +
    "  br label %" +
    merge_label +
    "\n"
  let result_temp = gen.next_temp()
  let load_code = "  " + result_temp + " = load i32, i32* " + result_ptr + "\n"
  let code = alloc_code +
    cond_value.code +
    cmp_code +
    br_code +
    then_label +
    ":\n" +
    then_value.code +
    then_store_code +
    else_label +
    ":\n" +
    else_value.code +
    else_store_code +
    merge_label +
    ":\n" +
    load_code
  expr_value(code, result_temp, "i32")
}

///|
// 模块6: let 语句生成
// 支持：变量分配、内存管理、下划线变量（忽略值）
fn llvm_gen_let(gen : LLVMGen, let_stmt : LetStmt) -> (String, String) {
  let value = llvm_gen_expr_value(gen, let_stmt.value)

  // 检查是否是下划线变量（忽略值）
  if let_stmt.name.lexeme == "_" {
    // 下划线变量：只生成值的代码，不分配变量
    (value.code, value.value)
  } else {
    // 普通变量：分配内存并存储值
    let var_temp = gen.next_temp()
    gen.add_var_with_type_and_arity(
      let_stmt.name.lexeme,
      var_temp,
      value.llvm_type,
      value.closure_arity,
    )
    let code = value.code +
      "  " +
      var_temp +
      " = alloca " +
      value.llvm_type +
      "\n" +
      "  store " +
      value.llvm_type +
      " " +
      value.value +
      ", " +
      value.llvm_type +
      "* " +
      var_temp +
      "\n"
    // 返回变量指针（用于后续使用）
    (code, value.value)
  }
}

///|
// 占位函数：赋值语句生成

///|
// 模块12: 赋值语句生成
// 支持：变量赋值、数组索引赋值
// 赋值语句：target = value
// 注意：target 可以是 Ident（变量）或 Index（数组索引）
fn llvm_gen_assign(gen : LLVMGen, assign_stmt : AssignStmt) -> (String, String) {
  // 生成 value 表达式的代码
  let value = llvm_gen_expr_value(gen, assign_stmt.value)

  // 根据 target 的类型生成不同的赋值代码
  match assign_stmt.target.kind {
    // 变量赋值：x = value
    ExprKind::Ident(token) =>
      // 获取变量的 alloca 地址
      match gen.get_var_entry(token.lexeme) {
        Some((var_name, var_type, _)) => {
          let store_code = "  store " +
            var_type +
            " " +
            value.value +
            ", " +
            var_type +
            "* " +
            var_name +
            "\n"
          let code = value.code + store_code
          // 赋值语句返回赋值后的值
          (code, value.value)
        }
        // 变量未定义，错误处理（暂时返回空代码）
        None => ("", "")
      }
    // 数组索引赋值：arr[i] = value
    ExprKind::Index(index_expr) => {
      // 生成数组表达式的代码（数组变量名或表达式）
      let array_value = llvm_gen_expr_value(gen, index_expr.array)

      // 生成索引表达式的代码
      let index_value = llvm_gen_expr_value(gen, index_expr.index)

      // 使用 getelementptr 计算元素地址
      // getelementptr i32, i32* %array, i32 %index
      let elem_ptr_temp = gen.next_temp()
      let gep_code = "  " +
        elem_ptr_temp +
        " = getelementptr i32, i32* " +
        array_value.value +
        ", i32 " +
        index_value.value +
        "\n"

      // 使用 store 指令存储值
      let store_code = "  store i32 " +
        value.value +
        ", i32* " +
        elem_ptr_temp +
        "\n"

      // 组合所有代码
      let code = value.code +
        array_value.code +
        index_value.code +
        gep_code +
        store_code
      // 赋值语句返回赋值后的值
      (code, value.value)
    }
    // 其他类型不支持赋值
    _ => ("", "")
  }
}

///|
// 模块10: if 语句生成
// 支持：if 语句（语句体）、else 分支、控制流
// if 语句：if condition { then_body } else { else_body }
// 注意：if 语句的 body 是语句数组，需要生成最后一个表达式的值
fn llvm_gen_if(gen : LLVMGen, if_stmt : IfStmt) -> (String, String) {
  // 生成条件表达式
  let (cond_code, cond_temp) = llvm_gen_expr(gen, if_stmt.condition)

  // 生成标签
  let then_label = gen.next_label()
  let else_label = gen.next_label()
  let merge_label = gen.next_label()
  let result_ptr = gen.next_temp()
  let alloc_code = "  " + result_ptr + " = alloca i32\n"

  // 生成条件比较
  let cmp_temp = gen.next_temp()
  let cmp_code = "  " + cmp_temp + " = icmp ne i32 " + cond_temp + ", 0\n"

  // 生成分支指令
  let br_code = "  br i1 " +
    cmp_temp +
    ", label %" +
    then_label +
    ", label %" +
    else_label +
    "\n"

  // 生成 then 分支（语句数组）
  let (then_code, then_last_temp) = llvm_gen_statements(gen, if_stmt.then_body)
  let then_value = if then_last_temp != "" { then_last_temp } else { "0" }
  let then_store_code = "  store i32 " +
    then_value +
    ", i32* " +
    result_ptr +
    "\n"
  let then_br_code = then_store_code + "  br label %" + merge_label + "\n"

  // 生成 else 分支（如果有）
  let (else_code, else_last_temp) = match if_stmt.else_body.length() {
    0 => ("", "")
    _ => llvm_gen_statements(gen, if_stmt.else_body)
  }
  let else_value = if else_last_temp != "" { else_last_temp } else { "0" }
  let else_store_code = "  store i32 " +
    else_value +
    ", i32* " +
    result_ptr +
    "\n"
  let else_br_code = else_store_code + "  br label %" + merge_label + "\n"
  let result_temp = gen.next_temp()
  let load_code = "  " + result_temp + " = load i32, i32* " + result_ptr + "\n"

  // 组合所有代码
  let code = alloc_code +
    cond_code +
    cmp_code +
    br_code +
    then_label +
    ":\n" +
    then_code +
    then_br_code +
    else_label +
    ":\n" +
    else_code +
    else_br_code +
    merge_label +
    ":\n" +
    load_code
  (code, result_temp)
}

///|
// 模块11: while 循环生成
// 支持：while 循环（语句体）、条件判断、控制流
// while 循环：while condition { body }
// 注意：while 循环的 body 是语句数组，循环后返回最后一个表达式的值（如果有）
// while 循环通常不返回值，返回 Unit (0)
fn llvm_gen_while(gen : LLVMGen, while_stmt : WhileStmt) -> (String, String) {
  // 生成标签
  let loop_label = gen.next_label()
  let body_label = gen.next_label()
  let exit_label = gen.next_label()

  // 跳转到循环入口
  let init_br_code = "  br label %" + loop_label + "\n"

  // 循环入口：检查条件
  let (cond_code, cond_temp) = llvm_gen_expr(gen, while_stmt.condition)
  let cmp_temp = gen.next_temp()
  let cmp_code = "  " + cmp_temp + " = icmp ne i32 " + cond_temp + ", 0\n"
  let cond_br_code = "  br i1 " +
    cmp_temp +
    ", label %" +
    body_label +
    ", label %" +
    exit_label +
    "\n"

  // 循环体：生成语句数组
  let (body_code, _body_last_temp) = llvm_gen_statements(gen, while_stmt.body)
  let body_br_code = "  br label %" + loop_label + "\n"

  // 退出标签：while 循环返回 Unit (0)
  // 注意：while 循环通常不返回值，如果需要返回值，可以在循环体中处理
  let exit_code = exit_label + ":\n"

  // 组合所有代码
  let code = init_br_code +
    loop_label +
    ":\n" +
    cond_code +
    cmp_code +
    cond_br_code +
    body_label +
    ":\n" +
    body_code +
    body_br_code +
    exit_code

  // while 循环返回空字符串（表示没有返回值，或返回 Unit）
  (code, "")
}

///|
// 模块8: return 语句生成
// 支持：返回值处理
fn llvm_gen_return(
  gen : LLVMGen,
  return_stmt : ReturnStmt,
  return_type : String,
) -> String {
  match return_stmt.value {
    Some(expr) => {
      let value = llvm_gen_expr_value(gen, expr)
      value.code + "  ret " + value.llvm_type + " " + value.value + "\n"
    }
    None =>
      if return_type == "void" {
        "  ret void\n"
      } else if return_type.contains("*") {
        "  ret " + return_type + " null\n"
      } else {
        "  ret " + return_type + " 0\n"
      }
  }
}

///|
// 模块7: 函数定义生成
// 支持：参数处理、函数体生成、返回语句
fn llvm_gen_function(
  struct_defs_map : Array[(String, Array[String])],
  function_stmt : FunctionStmt,
  closure_metadata : ClosureMetadata,
) -> String {
  let func_id = function_id(function_stmt)
  let function_entry = closure_metadata.get_entry(func_id)
  let mut is_nested_function = false
  let mut free_vars : Array[String] = Array::new()
  let func_name = match function_entry {
    Some(entry) => {
      is_nested_function = entry.parent_id != -1
      free_vars = clone_string_array(entry.free_vars)
      if function_stmt.name.lexeme == "main" && !is_nested_function {
        "@minimbt_main"
      } else if is_nested_function {
        "@closure_fn_" + entry.id.to_string()
      } else {
        "@" + function_stmt.name.lexeme
      }
    }
    None =>
      if function_stmt.name.lexeme == "main" {
        "@minimbt_main"
      } else {
        "@" + function_stmt.name.lexeme
      }
  }
  let is_main = function_stmt.name.lexeme == "main" && !is_nested_function

  // 生成参数列表
  let mut param_list = ""
  if is_nested_function {
    param_list = "i8* %env"
  }
  let mut first = true
  if param_list != "" {
    first = false
  }
  let mut param_index = 0
  for _param in function_stmt.parameters {
    let param_name = "%" + param_index.to_string()
    if first {
      param_list = "i32 " + param_name
      first = false
    } else {
      param_list = param_list + ", i32 " + param_name
    }
    param_index = param_index + 1
  }

  // 确定返回类型
  let mut return_type = if is_main { "void" } else { "i32" }
  let mut return_closure_arity = -1
  if function_stmt.return_type_is_function {
    return_closure_arity = function_stmt.function_return_param_types.length()
    return_type = closure_struct_pointer_type_for_arity(return_closure_arity)
  }
  let mut output = "define " +
    return_type +
    " " +
    func_name +
    "(" +
    param_list +
    ") {\n"
  output = output + "entry:\n"

  // 创建新的 LLVMGen 实例
  let gen = LLVMGen::new_with_function(
    function_stmt.name.lexeme,
    func_id,
    closure_metadata.clone(),
    return_type,
  )
  // 复制结构体定义到 gen
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }

  // 处理参数：为每个参数分配内存并存储
  let mut param_index = 0
  for param in function_stmt.parameters {
    let param_arg = "%" + param_index.to_string()
    // 为参数分配内存
    let param_temp = gen.next_temp()
    gen.add_var(param.name.lexeme, param_temp)
    output = output + "  " + param_temp + " = alloca i32\n"
    output = output + "  store i32 " + param_arg + ", i32* " + param_temp + "\n"
    param_index = param_index + 1
  }
  if is_nested_function && free_vars.length() > 0 {
    let env_struct_name = closure_env_struct_name(func_id)
    let env_struct_ptr_type = env_struct_name + "*"
    let env_ptr_temp = gen.next_temp()
    output = output +
      "  " +
      env_ptr_temp +
      " = bitcast i8* %env to " +
      env_struct_ptr_type +
      "\n"
    let mut index = 0
    for var_name in free_vars {
      let field_ptr = gen.next_temp()
      output = output +
        "  " +
        field_ptr +
        " = getelementptr " +
        env_struct_name +
        ", " +
        env_struct_ptr_type +
        " " +
        env_ptr_temp +
        ", i32 0, i32 " +
        index.to_string() +
        "\n"
      let field_val = gen.next_temp()
      output = output +
        "  " +
        field_val +
        " = load i32, i32* " +
        field_ptr +
        "\n"
      let capture_alloca = gen.next_temp()
      gen.add_var(var_name, capture_alloca)
      output = output + "  " + capture_alloca + " = alloca i32\n"
      output = output +
        "  store i32 " +
        field_val +
        ", i32* " +
        capture_alloca +
        "\n"
      index = index + 1
    }
  }

  // 生成函数体
  if return_closure_arity >= 0 {
    gen.current_return_type = return_type
  }
  let (body_code, last_expr_temp) = llvm_gen_statements(gen, function_stmt.body)
  output = output + body_code

  // 检查函数体是否已经包含 return 语句
  let has_return = body_code.contains("ret i32") ||
    body_code.contains("ret void")

  // 如果没有 return 语句，生成返回语句
  if !has_return {
    if is_main {
      // main 函数返回 void（匹配 riscv_rt/start.c）
      output = output + "  ret void\n"
    } else if last_expr_temp != "" {
      output = output + "  ret i32 " + last_expr_temp + "\n"
    } else {
      output = output + "  ret i32 0\n"
    }
  }
  output = output + "}\n\n"
  let _ = closure_metadata.get_free_vars(function_stmt)
  output
}

///|
// 占位函数：数组字面量生成
fn llvm_gen_array_literal(gen : LLVMGen, array_lit : ArrayLiteral) -> ExprValue {
  let temp = gen.next_temp()
  expr_value("", temp, "i32")
}

///|
// 模块13: 数组索引访问生成
// 支持：数组索引访问 arr[index]
// 使用 getelementptr 和 load 指令
// 注意：数组变量应该是指针类型（i32*），但如果它存储在 var_map 中，需要特殊处理
fn llvm_gen_index(gen : LLVMGen, index_expr : IndexExpr) -> ExprValue {
  // 生成数组表达式的代码（数组变量名或表达式）
  let array_value = llvm_gen_expr_value(gen, index_expr.array)

  // 生成索引表达式的代码
  let index_value = llvm_gen_expr_value(gen, index_expr.index)

  // 获取数组指针
  // 如果 array_temp 是通过 load 得到的 i32 值，但它实际上应该是 i32* 指针
  // 我们需要检查 array_expr 是否是标识符，如果是，直接从 var_map 获取指针
  let array_ptr_temp = match index_expr.array.kind {
    ExprKind::Ident(token) => {
      // 如果是标识符，直接获取变量的地址（指针）
      let var_name = gen.get_var_name(token.lexeme)
      if var_name != "" {
        // 变量已定义，直接使用变量地址（它是指针）
        var_name
      } else {
        // 变量未定义，使用 array_temp（可能是参数或其他）
        // 如果 array_temp 是 i32 值，需要将它转换为指针
        // 暂时假设 array_temp 已经是指针类型
        array_value.value
      }
    }
    _ => array_value.value
  }

  // 使用 getelementptr 计算元素地址
  // getelementptr i32, i32* %array_ptr, i32 %index
  let elem_ptr_temp = gen.next_temp()
  let gep_code = "  " +
    elem_ptr_temp +
    " = getelementptr i32, i32* " +
    array_ptr_temp +
    ", i32 " +
    index_value.value +
    "\n"

  // 使用 load 指令加载元素值
  let result_temp = gen.next_temp()
  let load_code = "  " +
    result_temp +
    " = load i32, i32* " +
    elem_ptr_temp +
    "\n"

  // 组合所有代码
  // 如果 array_ptr_temp == array_temp，不需要额外的代码
  let code = if array_ptr_temp == array_value.value {
    array_value.code + index_value.code + gep_code + load_code
  } else {
    // 如果 array_ptr_temp != array_temp，说明我们使用了 var_name，不需要 array_code
    index_value.code + gep_code + load_code
  }
  expr_value(code, result_temp, "i32")
}

///|
// 占位函数：元组字面量生成
fn llvm_gen_tuple_literal(gen : LLVMGen, tuple_lit : TupleLiteral) -> ExprValue {
  let temp = gen.next_temp()
  expr_value("", temp, "i32")
}

///|
// 占位函数：结构体字面量生成
fn llvm_gen_struct_literal(
  gen : LLVMGen,
  struct_lit : StructLiteral,
) -> ExprValue {
  let temp = gen.next_temp()
  expr_value("", temp, "i32")
}

///|
// 占位函数：字段访问生成
fn llvm_gen_field_access(
  gen : LLVMGen,
  field_access : FieldAccessExpr,
) -> ExprValue {
  let temp = gen.next_temp()
  expr_value("", temp, "i32")
}

///|
// 占位函数：match 表达式生成
fn llvm_gen_match(gen : LLVMGen, match_expr : MatchExpr) -> ExprValue {
  let temp = gen.next_temp()
  expr_value("", temp, "i32")
}

///|
// 生成汇编代码（暂不实现）
fn generate_asm(statements : Array[Stmt]) -> String {
  let mut output = ".text\n"
  output = output + ".globl main\n"
  output = output + "main:\n"
  output = output + "  li a0, 0\n"
  output = output + "  ret\n"
  output
}
