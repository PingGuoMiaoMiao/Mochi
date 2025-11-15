///|
// 代码生成器 - 组件化设计
// 将 AST 转换为 LLVM IR
// 
// 架构设计：
// 1. 核心数据结构：CodegenContext (LLVMGen) - 管理变量、标签、结构体定义等
// 2. 模块化函数：每个 AST 节点类型对应一个生成函数
// 3. 表达式生成：递归生成，返回 (code, temp_var)
// 4. 语句生成：顺序生成，返回 (code, last_statement_value)
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
  array_element_type : String
  array_element_closure_arity : Int
  tuple_element_count : Int
  struct_name : String
  enum_name : String
}

///|
priv struct ParamLLVMInfo {
  llvm_type : String
  closure_arity : Int
  array_element_type : String
  array_element_closure_arity : Int
  tuple_element_count : Int
  struct_name : String
  enum_name : String
}

///|
fn expr_value(code : String, value : String, llvm_type : String) -> ExprValue {
  {
    code,
    value,
    llvm_type,
    closure_arity: -1,
    array_element_type: "",
    array_element_closure_arity: -1,
    tuple_element_count: -1,
    struct_name: "",
    enum_name: "",
  }
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
  {
    code,
    value,
    llvm_type,
    closure_arity: arity,
    array_element_type: "",
    array_element_closure_arity: -1,
    tuple_element_count: -1,
    struct_name: "",
    enum_name: "",
  }
}

///|
fn expr_value_with_array_metadata(
  base : ExprValue,
  element_type : String,
  element_closure_arity : Int,
) -> ExprValue {
  {
    code: base.code,
    value: base.value,
    llvm_type: base.llvm_type,
    closure_arity: base.closure_arity,
    array_element_type: element_type,
    array_element_closure_arity: element_closure_arity,
    tuple_element_count: base.tuple_element_count,
    struct_name: base.struct_name,
    enum_name: base.enum_name,
  }
}

///|
fn expr_value_with_tuple_metadata(
  base : ExprValue,
  element_count : Int,
) -> ExprValue {
  {
    code: base.code,
    value: base.value,
    llvm_type: base.llvm_type,
    closure_arity: base.closure_arity,
    array_element_type: base.array_element_type,
    array_element_closure_arity: base.array_element_closure_arity,
    tuple_element_count: element_count,
    struct_name: base.struct_name,
    enum_name: base.enum_name,
  }
}

///|
fn expr_value_with_struct_name(
  base : ExprValue,
  struct_name : String,
) -> ExprValue {
  {
    code: base.code,
    value: base.value,
    llvm_type: base.llvm_type,
    closure_arity: base.closure_arity,
    array_element_type: base.array_element_type,
    array_element_closure_arity: base.array_element_closure_arity,
    tuple_element_count: base.tuple_element_count,
    struct_name,
    enum_name: base.enum_name,
  }
}

///|
fn expr_value_with_enum_name(base : ExprValue, enum_name : String) -> ExprValue {
  {
    code: base.code,
    value: base.value,
    llvm_type: base.llvm_type,
    closure_arity: base.closure_arity,
    array_element_type: base.array_element_type,
    array_element_closure_arity: base.array_element_closure_arity,
    tuple_element_count: base.tuple_element_count,
    struct_name: base.struct_name,
    enum_name,
  }
}

///|
priv struct StatementValue {
  value : String
  llvm_type : String
  tuple_element_count : Int
  struct_name : String
  enum_name : String
}

///|
priv struct GlobalVarInfo {
  name : String
  llvm_type : String
  closure_arity : Int
  array_element_type : String
  array_element_closure_arity : Int
  tuple_element_count : Int
  struct_name : String
  enum_name : String
}

///|
priv struct StructFieldInfo {
  name : String
  llvm_type : String
}

///|
priv struct EnumVariantInfo {
  enum_name : String
  variant_name : String
  tag : Int
  param_types : Array[String]
  payload_struct_name : String
}

///|
priv struct EnumInfo {
  name : String
  struct_type : String
  pointer_type : String
  variants : Array[EnumVariantInfo]
}

///|
fn statement_value(value : String, llvm_type : String) -> StatementValue {
  { value, llvm_type, tuple_element_count: -1, struct_name: "", enum_name: "" }
}

///|
fn empty_statement_value() -> StatementValue {
  statement_value("", "i32")
}

///|
fn statement_value_from_expr(value : ExprValue) -> StatementValue {
  {
    value: value.value,
    llvm_type: value.llvm_type,
    tuple_element_count: value.tuple_element_count,
    struct_name: value.struct_name,
    enum_name: value.enum_name,
  }
}

///|
fn statement_value_with_tuple(
  value : String,
  llvm_type : String,
  tuple_element_count : Int,
  struct_name : String,
  enum_name : String,
) -> StatementValue {
  { value, llvm_type, tuple_element_count, struct_name, enum_name }
}

///|
fn global_var_info(
  name : String,
  llvm_type : String,
  closure_arity : Int,
  array_element_type : String,
  array_element_closure_arity : Int,
  tuple_element_count : Int,
  struct_name : String,
  enum_name : String,
) -> GlobalVarInfo {
  {
    name,
    llvm_type,
    closure_arity,
    array_element_type,
    array_element_closure_arity,
    tuple_element_count,
    struct_name,
    enum_name,
  }
}

///|
fn default_value_for_type(llvm_type : String) -> String {
  if llvm_type.contains("*") {
    "null"
  } else if llvm_type == "double" {
    "0.000000e+00"
  } else {
    "0"
  }
}

///|
fn statement_value_has_value(value : StatementValue) -> Bool {
  value.value != ""
}

///|
fn llvm_type_from_token(token : Token) -> String {
  match token.lexeme {
    "Int" => "i32"
    "Bool" => "i32"
    "Double" => "double"
    "Array" => "i32*"
    _ => if token.lexeme.has_suffix("*") { token.lexeme } else { "i32" }
  }
}

///|
fn llvm_type_size(llvm_type : String) -> Int {
  if llvm_type == "double" {
    8
  } else if llvm_type.contains("*") {
    8
  } else {
    4
  }
}

///|
fn normalize_float_literal(literal : String) -> String {
  let sanitized = literal.replace(old="_", new="")
  if sanitized.contains(".") ||
    sanitized.contains("e") ||
    sanitized.contains("E") {
    sanitized
  } else {
    sanitized + ".0"
  }
}

///|
fn struct_def_exists(
  struct_defs : Array[(String, Array[StructFieldInfo])],
  name : String,
) -> Bool {
  for entry in struct_defs {
    if entry.0 == name {
      return true
    }
  }
  false
}

///|
fn resolve_simple_type_name(
  type_name : String,
  struct_defs : Array[(String, Array[StructFieldInfo])],
  enum_infos : Array[EnumInfo],
) -> (String, String, String) {
  if type_name == "Double" {
    return ("double", "", "")
  }
  if type_name == "Bool" || type_name == "Int" {
    return ("i32", "", "")
  }
  if struct_def_exists(struct_defs, type_name) {
    return ("%" + type_name + "*", type_name, "")
  }
  for info in enum_infos {
    if info.name == type_name {
      return (info.pointer_type, "", type_name)
    }
  }
  ("i32", "", "")
}

///|
fn enum_struct_type_name(enum_name : String) -> String {
  "%enum." + enum_name
}

///|
fn enum_struct_pointer_type(enum_name : String) -> String {
  enum_struct_type_name(enum_name) + "*"
}

///|
fn enum_payload_struct_name(
  enum_name : String,
  variant_name : String,
) -> String {
  "%enum." + enum_name + "." + variant_name + ".payload"
}

///|
fn enum_base_struct_size() -> Int {
  // tag i32 (4 bytes) + padding + i8* (8 bytes) -> assume 16 bytes for alignment
  16
}

///|
fn enum_payload_size(param_types : Array[String]) -> Int {
  let mut total = 0
  for ty in param_types {
    total = total + llvm_type_size(ty)
  }
  total
}

///|
fn llvm_gen_enum_variant_value(
  gen : LLVMGen,
  variant_info : EnumVariantInfo,
  args_code : String,
  arg_values : Array[String],
  arg_types : Array[String],
) -> ExprValue {
  let enum_struct_type = enum_struct_type_name(variant_info.enum_name)
  let enum_ptr_type = enum_struct_pointer_type(variant_info.enum_name)
  let mut code = args_code
  let base_raw = gen.next_temp()
  code = code +
    "  " +
    base_raw +
    " = call i8* @minimbt_malloc(i32 " +
    enum_base_struct_size().to_string() +
    ")\n"
  let enum_ptr = gen.next_temp()
  code = code +
    "  " +
    enum_ptr +
    " = bitcast i8* " +
    base_raw +
    " to " +
    enum_ptr_type +
    "\n"
  let tag_ptr = gen.next_temp()
  code = code +
    "  " +
    tag_ptr +
    " = getelementptr " +
    enum_struct_type +
    ", " +
    enum_ptr_type +
    " " +
    enum_ptr +
    ", i32 0, i32 0\n"
  code = code +
    "  store i32 " +
    variant_info.tag.to_string() +
    ", i32* " +
    tag_ptr +
    "\n"
  let payload_field_ptr = gen.next_temp()
  code = code +
    "  " +
    payload_field_ptr +
    " = getelementptr " +
    enum_struct_type +
    ", " +
    enum_ptr_type +
    " " +
    enum_ptr +
    ", i32 0, i32 1\n"
  let mut payload_value = "null"
  if variant_info.param_types.length() > 0 {
    let payload_size = enum_payload_size(variant_info.param_types)
    let payload_raw = gen.next_temp()
    code = code +
      "  " +
      payload_raw +
      " = call i8* @minimbt_malloc(i32 " +
      payload_size.to_string() +
      ")\n"
    let payload_struct_ptr_type = variant_info.payload_struct_name + "*"
    let payload_struct_ptr = gen.next_temp()
    code = code +
      "  " +
      payload_struct_ptr +
      " = bitcast i8* " +
      payload_raw +
      " to " +
      payload_struct_ptr_type +
      "\n"
    let mut field_index = 0
    while field_index < variant_info.param_types.length() {
      let field_type = variant_info.param_types[field_index]
      let field_ptr = gen.next_temp()
      code = code +
        "  " +
        field_ptr +
        " = getelementptr " +
        variant_info.payload_struct_name +
        ", " +
        payload_struct_ptr_type +
        " " +
        payload_struct_ptr +
        ", i32 0, i32 " +
        field_index.to_string() +
        "\n"
      let mut stored_value = default_value_for_type(field_type)
      if field_index < arg_values.length() {
        let mut arg_temp = arg_values[field_index]
        let mut arg_type = if field_index < arg_types.length() {
          arg_types[field_index]
        } else {
          "i32"
        }
        if arg_type == "" {
          arg_type = "i32"
        }
        if arg_type != field_type {
          let (cast_code, cast_temp) = cast_value_to_type(
            gen, arg_temp, arg_type, field_type,
          )
          code = code + cast_code
          arg_temp = cast_temp
        }
        stored_value = arg_temp
      }
      code = code +
        "  store " +
        field_type +
        " " +
        stored_value +
        ", " +
        field_type +
        "* " +
        field_ptr +
        "\n"
      field_index = field_index + 1
    }
    let payload_bitcast = gen.next_temp()
    code = code +
      "  " +
      payload_bitcast +
      " = bitcast " +
      payload_struct_ptr_type +
      " " +
      payload_struct_ptr +
      " to i8*\n"
    payload_value = payload_bitcast
  }
  code = code +
    "  store i8* " +
    payload_value +
    ", i8** " +
    payload_field_ptr +
    "\n"
  let base_value = expr_value(code, enum_ptr, enum_ptr_type)
  expr_value_with_enum_name(base_value, variant_info.enum_name)
}

///|
fn cast_value_to_type(
  gen : LLVMGen,
  value : String,
  from_type : String,
  target_type : String,
) -> (String, String) {
  if target_type == "" || from_type == "" || from_type == target_type {
    return ("", value)
  }
  if target_type == "double" && from_type == "i32" {
    let temp = gen.next_temp()
    return ("  " + temp + " = sitofp i32 " + value + " to double\n", temp)
  }
  if target_type == "i32" && from_type == "double" {
    let temp = gen.next_temp()
    return ("  " + temp + " = fptosi double " + value + " to i32\n", temp)
  }
  if target_type == "i32" && from_type.contains("*") {
    let temp = gen.next_temp()
    return (
      "  " + temp + " = ptrtoint " + from_type + " " + value + " to i32\n",
      temp,
    )
  }
  if target_type.contains("*") && from_type.contains("*") {
    let temp = gen.next_temp()
    return (
      "  " +
      temp +
      " = bitcast " +
      from_type +
      " " +
      value +
      " to " +
      target_type +
      "\n",
      temp,
    )
  }
  if target_type.contains("*") && from_type == "i32" {
    let temp = gen.next_temp()
    return (
      "  " + temp + " = inttoptr i32 " + value + " to " + target_type + "\n",
      temp,
    )
  }
  ("", value)
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
    "sqrt" =>
      Some({
        ir_name: "@sqrt",
        return_type: "double",
        is_void: false,
        param_types: builtin_param_types_one("double"),
      })
    "sin" =>
      Some({
        ir_name: "@sin",
        return_type: "double",
        is_void: false,
        param_types: builtin_param_types_one("double"),
      })
    "cos" =>
      Some({
        ir_name: "@cos",
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
fn llvm_gen_call_self_closure(
  gen : LLVMGen,
  entry : ClosureEntry,
  args_code : String,
  args_temps : Array[String],
) -> ExprValue {
  let mut code = args_code
  let mut param_list = "i8* " + gen.current_env_param
  let mut index = 0
  while index < args_temps.length() {
    param_list = param_list + ", i32 " + args_temps[index]
    index = index + 1
  }
  let mut return_type = "i32"
  let mut tuple_count = -1
  if entry.function_stmt.return_type_is_tuple {
    return_type = "i32*"
    tuple_count = entry.function_stmt.return_tuple_element_types.length()
  }
  let result_temp = gen.next_temp()
  code = code +
    "  " +
    result_temp +
    " = call " +
    return_type +
    " " +
    closure_function_label(entry) +
    "(" +
    param_list +
    ")\n"
  let base_value = expr_value(code, result_temp, return_type)
  if tuple_count >= 0 {
    expr_value_with_tuple_metadata(base_value, tuple_count)
  } else {
    base_value
  }
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
  names.push("sqrt")
  names.push("sin")
  names.push("cos")
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
  struct_defs : Array[(String, Array[StructFieldInfo])] // 结构体定义：(结构体名, 字段信息列表)
  enum_defs : Array[EnumInfo]
  current_function : String // 当前函数名
  current_function_id : Int
  closure_metadata : ClosureMetadata
  mut current_return_type : String
  array_metadata : Array[(String, String, Int)]
  global_vars : Array[GlobalVarInfo]
  is_top_level_context : Bool
  tuple_metadata : Array[(String, Int)]
  struct_metadata : Array[(String, String)]
  enum_value_metadata : Array[(String, String)]
  current_env_param : String
  captured_var_registry : Array[(Int, String, String, Int)]
}

///|
fn LLVMGen::new(
  metadata : ClosureMetadata,
  enum_defs : Array[EnumInfo],
  global_vars : Array[GlobalVarInfo],
  is_top_level : Bool,
  captured_var_registry : Array[(Int, String, String, Int)],
) -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    enum_defs,
    current_function: "",
    current_function_id: -1,
    closure_metadata: metadata,
    current_return_type: "void",
    array_metadata: Array::new(),
    global_vars,
    is_top_level_context: is_top_level,
    tuple_metadata: Array::new(),
    struct_metadata: Array::new(),
    enum_value_metadata: Array::new(),
    current_env_param: "",
    captured_var_registry,
  }
}

///|
fn LLVMGen::new_with_function(
  func_name : String,
  func_id : Int,
  metadata : ClosureMetadata,
  enum_defs : Array[EnumInfo],
  return_type : String,
  global_vars : Array[GlobalVarInfo],
  is_nested_function : Bool,
  captured_var_registry : Array[(Int, String, String, Int)],
) -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    enum_defs,
    current_function: func_name,
    current_function_id: func_id,
    closure_metadata: metadata,
    current_return_type: return_type,
    array_metadata: Array::new(),
    global_vars,
    is_top_level_context: false,
    tuple_metadata: Array::new(),
    struct_metadata: Array::new(),
    enum_value_metadata: Array::new(),
    current_env_param: if is_nested_function {
      "%env"
    } else {
      ""
    },
    captured_var_registry,
  }
}

///|
fn LLVMGen::get_var_entry(
  self : LLVMGen,
  name : String,
) -> (String, String, Int)? {
  let mut index = self.var_map.length() - 1
  while index >= 0 {
    let pair = self.var_map[index]
    if pair.0 == name {
      return Some((pair.1, pair.2, pair.3))
    }
    index = index - 1
  }
  None
}

///|
fn LLVMGen::record_captured_var_type(
  self : LLVMGen,
  func_id : Int,
  name : String,
  llvm_type : String,
  closure_arity : Int,
) -> Unit {
  let mut index = 0
  while index < self.captured_var_registry.length() {
    if self.captured_var_registry[index].0 == func_id &&
      self.captured_var_registry[index].1 == name {
      self.captured_var_registry[index] = (
        func_id, name, llvm_type, closure_arity,
      )
      return
    }
    index = index + 1
  }
  self.captured_var_registry.push((func_id, name, llvm_type, closure_arity))
}

///|
fn LLVMGen::get_captured_var_type(
  self : LLVMGen,
  func_id : Int,
  name : String,
) -> (String, Int)? {
  for entry in self.captured_var_registry {
    if entry.0 == func_id && entry.1 == name {
      return Some((entry.2, entry.3))
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
fn LLVMGen::get_array_metadata(self : LLVMGen, name : String) -> (String, Int) {
  for entry in self.array_metadata {
    if entry.0 == name && entry.1 != "" {
      return (entry.1, entry.2)
    }
  }
  ("", -1)
}

///|
fn LLVMGen::global_var_symbol(name : String) -> String {
  "@minimbt_global_" + name
}

///|
fn LLVMGen::has_global_var(self : LLVMGen, name : String) -> Bool {
  for info in self.global_vars {
    if info.name == name {
      return true
    }
  }
  false
}

///|
fn LLVMGen::get_global_var(self : LLVMGen, name : String) -> GlobalVarInfo? {
  for info in self.global_vars {
    if info.name == name {
      return Some(info)
    }
  }
  None
}

///|
fn LLVMGen::set_array_metadata(
  self : LLVMGen,
  name : String,
  element_type : String,
  closure_arity : Int,
) -> Unit {
  let mut index = 0
  while index < self.array_metadata.length() {
    if self.array_metadata[index].0 == name {
      self.array_metadata[index] = (name, element_type, closure_arity)
      return
    }
    index = index + 1
  }
  self.array_metadata.push((name, element_type, closure_arity))
}

///|
fn LLVMGen::clear_array_metadata(self : LLVMGen, name : String) -> Unit {
  let mut index = 0
  while index < self.array_metadata.length() {
    if self.array_metadata[index].0 == name {
      self.array_metadata[index] = ("", "", -1)
      return
    }
    index = index + 1
  }
}

///|
fn LLVMGen::set_tuple_metadata(
  self : LLVMGen,
  name : String,
  element_count : Int,
) -> Unit {
  let mut index = 0
  while index < self.tuple_metadata.length() {
    if self.tuple_metadata[index].0 == name {
      self.tuple_metadata[index] = (name, element_count)
      return
    }
    index = index + 1
  }
  self.tuple_metadata.push((name, element_count))
}

///|
fn LLVMGen::get_tuple_metadata(self : LLVMGen, name : String) -> Int {
  for entry in self.tuple_metadata {
    if entry.0 == name {
      return entry.1
    }
  }
  -1
}

///|
fn LLVMGen::clear_tuple_metadata(self : LLVMGen, name : String) -> Unit {
  let mut index = 0
  while index < self.tuple_metadata.length() {
    if self.tuple_metadata[index].0 == name {
      self.tuple_metadata[index] = ("", -1)
      return
    }
    index = index + 1
  }
}

///|
fn LLVMGen::set_struct_metadata(
  self : LLVMGen,
  name : String,
  struct_name : String,
) -> Unit {
  let mut index = 0
  while index < self.struct_metadata.length() {
    if self.struct_metadata[index].0 == name {
      self.struct_metadata[index] = (name, struct_name)
      return
    }
    index = index + 1
  }
  self.struct_metadata.push((name, struct_name))
}

///|
fn LLVMGen::get_struct_metadata(self : LLVMGen, name : String) -> String {
  for entry in self.struct_metadata {
    if entry.0 == name {
      return entry.1
    }
  }
  ""
}

///|
fn LLVMGen::clear_struct_metadata(self : LLVMGen, name : String) -> Unit {
  let mut index = 0
  while index < self.struct_metadata.length() {
    if self.struct_metadata[index].0 == name {
      self.struct_metadata[index] = ("", "")
      return
    }
    index = index + 1
  }
}

///|
fn LLVMGen::set_enum_metadata(
  self : LLVMGen,
  name : String,
  enum_name : String,
) -> Unit {
  let mut index = 0
  while index < self.enum_value_metadata.length() {
    if self.enum_value_metadata[index].0 == name {
      self.enum_value_metadata[index] = (name, enum_name)
      return
    }
    index = index + 1
  }
  self.enum_value_metadata.push((name, enum_name))
}

///|
fn LLVMGen::get_enum_metadata(self : LLVMGen, name : String) -> String {
  for entry in self.enum_value_metadata {
    if entry.0 == name && entry.1 != "" {
      return entry.1
    }
  }
  ""
}

///|
fn LLVMGen::clear_enum_metadata(self : LLVMGen, name : String) -> Unit {
  let mut index = 0
  while index < self.enum_value_metadata.length() {
    if self.enum_value_metadata[index].0 == name {
      self.enum_value_metadata[index] = ("", "")
      return
    }
    index = index + 1
  }
}

///|
fn LLVMGen::struct_name_for_type(self : LLVMGen, llvm_type : String) -> String {
  for entry in self.struct_defs {
    let expected_type = "%" + entry.0 + "*"
    if llvm_type == expected_type {
      return entry.0
    }
  }
  ""
}

///|
fn LLVMGen::get_enum_info(self : LLVMGen, enum_name : String) -> EnumInfo? {
  for info in self.enum_defs {
    if info.name == enum_name {
      return Some(info)
    }
  }
  None
}

///|
fn LLVMGen::get_enum_variant_info(
  self : LLVMGen,
  variant_name : String,
) -> EnumVariantInfo? {
  for info in self.enum_defs {
    for variant in info.variants {
      if variant.variant_name == variant_name {
        return Some(variant)
      }
    }
  }
  None
}

///|
fn LLVMGen::find_struct_fields(
  self : LLVMGen,
  struct_name : String,
) -> Array[StructFieldInfo]? {
  for entry in self.struct_defs {
    if entry.0 == struct_name {
      return Some(entry.1)
    }
  }
  None
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
fn LLVMGen::set_var_entry(
  self : LLVMGen,
  name : String,
  temp_name : String,
  llvm_type : String,
  closure_arity : Int,
) -> Unit {
  let mut index = self.var_map.length() - 1
  while index >= 0 {
    if self.var_map[index].0 == name {
      self.var_map[index] = (name, temp_name, llvm_type, closure_arity)
      return
    }
    index = index - 1
  }
  self.add_var_with_type_and_arity(name, temp_name, llvm_type, closure_arity)
}

///|
fn LLVMGen::remove_var_entry(self : LLVMGen, name : String) -> Unit {
  let mut index = self.var_map.length() - 1
  while index >= 0 {
    if self.var_map[index].0 == name {
      ignore(self.var_map.remove(index))
      return
    }
    index = index - 1
  }
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
fn default_param_info() -> ParamLLVMInfo {
  {
    llvm_type: "i32",
    closure_arity: -1,
    array_element_type: "",
    array_element_closure_arity: -1,
    tuple_element_count: -1,
    struct_name: "",
    enum_name: "",
  }
}

///|
fn function_param_llvm_info(
  param : FunctionParam,
  struct_defs : Array[(String, Array[StructFieldInfo])],
  enum_infos : Array[EnumInfo],
) -> ParamLLVMInfo {
  if param.is_function_type {
    let arity = param.function_param_types.length()
    return {
      llvm_type: closure_struct_pointer_type_for_arity(arity),
      closure_arity: arity,
      array_element_type: "",
      array_element_closure_arity: -1,
      tuple_element_count: -1,
      struct_name: "",
      enum_name: "",
    }
  }
  if param.is_tuple_type {
    return {
      llvm_type: "i32*",
      closure_arity: -1,
      array_element_type: "",
      array_element_closure_arity: -1,
      tuple_element_count: param.tuple_element_types.length(),
      struct_name: "",
      enum_name: "",
    }
  }
  match param.type_name {
    Some(type_token) => {
      if type_token.lexeme == "Double" {
        return {
          llvm_type: "double",
          closure_arity: -1,
          array_element_type: "",
          array_element_closure_arity: -1,
          tuple_element_count: -1,
          struct_name: "",
          enum_name: "",
        }
      }
      if type_token.lexeme == "Array" {
        let mut pointer_type = "i32*"
        let mut element_type = "i32"
        let mut element_closure_arity = -1
        match param.element_type_name {
          Some(element_token) =>
            if element_token.lexeme == "Double" {
              pointer_type = "double*"
              element_type = "double"
            } else if element_token.lexeme == "Bool" {
              pointer_type = "i8**"
              element_type = closure_struct_pointer_type_for_arity(1)
              element_closure_arity = 1
            } else if element_token.lexeme == "Int" {
              pointer_type = "i32*"
              element_type = "i32"
            } else {
              pointer_type = "i8**"
              element_type = "i8*"
            }
          None => ()
        }
        return {
          llvm_type: pointer_type,
          closure_arity: -1,
          array_element_type: element_type,
          array_element_closure_arity: element_closure_arity,
          tuple_element_count: -1,
          struct_name: "",
          enum_name: "",
        }
      }
      if type_token.lexeme == "Bool" {
        return default_param_info()
      }
      if type_token.lexeme == "Int" {
        return default_param_info()
      }
      let (resolved_type, struct_name, enum_name) = resolve_simple_type_name(
        type_token.lexeme,
        struct_defs,
        enum_infos,
      )
      if resolved_type != "i32" || struct_name != "" || enum_name != "" {
        return {
          llvm_type: resolved_type,
          closure_arity: -1,
          array_element_type: "",
          array_element_closure_arity: -1,
          tuple_element_count: -1,
          struct_name,
          enum_name,
        }
      }
    }
    None => ()
  }
  default_param_info()
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
fn closure_function_label(entry : ClosureEntry) -> String {
  if entry.parent_id == -1 {
    "@closure_wrapper_" + entry.id.to_string()
  } else {
    "@closure_fn_" + entry.id.to_string()
  }
}

///|
fn generate_top_level_closure_wrapper(
  function_stmt : FunctionStmt,
  entry : ClosureEntry,
  target_name : String,
  return_type : String,
) -> String {
  if entry.parent_id != -1 || return_type != "i32" {
    return ""
  }
  let wrapper_name = closure_function_label(entry)
  let param_count = function_stmt.parameters.length()
  let mut param_list = "i8* %env"
  let mut call_params = ""
  let mut index = 0
  while index < param_count {
    let arg_name = "%" + index.to_string()
    param_list = param_list + ", i32 " + arg_name
    if call_params == "" {
      call_params = "i32 " + arg_name
    } else {
      call_params = call_params + ", i32 " + arg_name
    }
    index = index + 1
  }
  let mut output = "define i32 " + wrapper_name + "(" + param_list + ") {\n"
  output = output + "entry:\n"
  let mut call_line = ""
  if call_params == "" {
    call_line = "  %result = call i32 " + target_name + "()\n"
  } else {
    call_line = "  %result = call i32 " +
      target_name +
      "(" +
      call_params +
      ")\n"
  }
  output = output + call_line
  output = output + "  ret i32 %result\n"
  output + "}\n\n"
}

///|
fn generate_closure_env_type_definitions(metadata : ClosureMetadata) -> String {
  let mut definitions = ""
  for entry in metadata.entries {
    let field_count = entry.free_vars.length()
    if field_count == 0 {
      continue
    }
    let mut line = closure_env_struct_name(entry.id) + " = type { "
    let mut first = true
    let mut index = 0
    while index < field_count {
      if first {
        line = line + "i64"
        first = false
      } else {
        line = line + ", i64"
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
    let arity = entry.function_stmt.parameters.length()
    if !int_array_contains(arities, arity) {
      arities.push(arity)
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
fn enum_payload_param_type(
  token : Token,
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
) -> String {
  if token.lexeme == "Double" {
    "double"
  } else if token.lexeme == "Bool" || token.lexeme == "Int" {
    "i32"
  } else if struct_def_exists(struct_defs_map, token.lexeme) {
    "%" + token.lexeme + "*"
  } else {
    "i32"
  }
}

///|
fn build_enum_info(
  enum_def : EnumDef,
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
) -> EnumInfo {
  let enum_name = enum_def.name.lexeme
  let struct_type = enum_struct_type_name(enum_name)
  let pointer_type = enum_struct_pointer_type(enum_name)
  let variants : Array[EnumVariantInfo] = Array::new()
  let mut tag = 0
  for variant in enum_def.variants {
    let param_types : Array[String] = Array::new()
    for token in variant.param_types {
      param_types.push(enum_payload_param_type(token, struct_defs_map))
    }
    let payload_struct_name = if param_types.length() > 0 {
      enum_payload_struct_name(enum_name, variant.name.lexeme)
    } else {
      ""
    }
    let info : EnumVariantInfo = {
      enum_name,
      variant_name: variant.name.lexeme,
      tag,
      param_types,
      payload_struct_name,
    }
    variants.push(info)
    tag = tag + 1
  }
  { name: enum_name, struct_type, pointer_type, variants }
}

///|
fn build_enum_infos(
  statements : Array[Stmt],
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
) -> Array[EnumInfo] {
  let infos : Array[EnumInfo] = Array::new()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Enum(enum_def) =>
        infos.push(build_enum_info(enum_def, struct_defs_map))
      _ => ()
    }
  }
  infos
}

///|
fn generate_enum_type_definitions(enum_infos : Array[EnumInfo]) -> String {
  if enum_infos.length() == 0 {
    return ""
  }
  let mut output = ""
  for info in enum_infos {
    output = output + info.struct_type + " = type { i32, i8* }\n"
    for variant in info.variants {
      if variant.param_types.length() > 0 {
        let mut line = variant.payload_struct_name + " = type { "
        let mut first = true
        for ty in variant.param_types {
          if first {
            line = line + ty
            first = false
          } else {
            line = line + ", " + ty
          }
        }
        line = line + " }\n"
        output = output + line
      }
    }
  }
  output + "\n"
}

///|
fn generate_global_declarations(global_vars : Array[GlobalVarInfo]) -> String {
  if global_vars.length() == 0 {
    return ""
  }
  let mut declarations = ""
  for info in global_vars {
    let default_value = default_value_for_type(info.llvm_type)
    let symbol = LLVMGen::global_var_symbol(info.name)
    declarations = declarations +
      symbol +
      " = global " +
      info.llvm_type +
      " " +
      default_value +
      "\n"
  }
  declarations + "\n"
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
      for token in let_stmt.destructured_names {
        if token.lexeme != "_" {
          add_name_to_scope(local_scope, token.lexeme)
        }
      }
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
fn collect_global_vars(
  statements : Array[Stmt],
  closure_metadata : ClosureMetadata,
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
  enum_infos : Array[EnumInfo],
) -> Array[GlobalVarInfo] {
  let globals : Array[GlobalVarInfo] = Array::new()
  let registry : Array[(Int, String, String, Int)] = Array::new()
  let gen = LLVMGen::new(
    closure_metadata.clone(),
    enum_infos,
    globals,
    true,
    registry,
  )
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }
  for stmt in statements {
    match stmt.kind {
      StmtKind::Let(let_stmt) => ignore(llvm_gen_let(gen, let_stmt))
      _ => ()
    }
  }
  globals
}

///|
fn generate_llvm(statements : Array[Stmt]) -> String {
  let mut output = "target triple = \"riscv64-unknown-linux-gnu\"\n\n"
  let closure_metadata = analyze_closures(statements)
  let captured_var_registry : Array[(Int, String, String, Int)] = Array::new()

  // 生成外部函数声明
  output = output + generate_external_declarations()
  output = output + generate_closure_env_type_definitions(closure_metadata)
  output = output + generate_closure_struct_definitions(closure_metadata)

  // 第一遍：收集结构体定义并生成类型定义
  let struct_defs_map : Array[(String, Array[StructFieldInfo])] = Array::new()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Struct(struct_def) => {
        let struct_name = struct_def.name.lexeme
        let field_infos : Array[StructFieldInfo] = Array::new()
        output = output + "%" + struct_name + " = type { "
        let mut first = true
        for field in struct_def.fields {
          let field_type = llvm_type_from_token(field.type_name)
          let info : StructFieldInfo = {
            name: field.name.lexeme,
            llvm_type: field_type,
          }
          field_infos.push(info)
          if first {
            output = output + field_type
            first = false
          } else {
            output = output + ", " + field_type
          }
        }
        struct_defs_map.push((struct_name, field_infos))
        output = output + " }\n"
      }
      _ => ()
    }
  }
  output = output + "\n"
  let enum_infos = build_enum_infos(statements, struct_defs_map)
  output = output + generate_enum_type_definitions(enum_infos)
  let global_vars = collect_global_vars(
    statements,
    closure_metadata.clone(),
    struct_defs_map,
    enum_infos,
  )
  output = output + generate_global_declarations(global_vars)

  // 第二遍：生成所有函数定义（包含嵌套函数）
  let main_statements : Array[Stmt] = Array::new()
  let mut has_main_function = false
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
      struct_defs_map, enum_infos, function_stmt, closure_metadata, global_vars,
      captured_var_registry,
    )
    output = output + func_code
  }
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(_) => ()
      _ => ignore(main_statements.push(stmt))
    }
  }

  // 如果没有 main 函数，且 main_statements 不为空，生成一个 main 函数
  // 确保不会重复生成 main 函数
  let mut emitted_minimbt_main = has_main_function
  let mut initializer_emitted = false
  if main_statements.length() > 0 {
    if has_main_function {
      let init_code = llvm_gen_top_level_function(
        "@minimbt_init_globals", struct_defs_map, enum_infos, main_statements, closure_metadata,
        global_vars, captured_var_registry,
      )
      output = output + init_code
      initializer_emitted = true
    } else {
      let main_code = llvm_gen_top_level_function(
        "@minimbt_main", struct_defs_map, enum_infos, main_statements, closure_metadata,
        global_vars, captured_var_registry,
      )
      output = output + main_code
      emitted_minimbt_main = true
    }
  }
  if emitted_minimbt_main {
    output = output + "define i32 @main() {\n" + "entry:\n"
    if initializer_emitted {
      output = output + "  call void @minimbt_init_globals()\n"
    }
    output = output + "  call void @minimbt_main()\n" + "  ret i32 0\n" + "}\n"
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
// 生成顶层语句函数（初始化或脚本 main）
fn llvm_gen_top_level_function(
  function_name : String,
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
  enum_infos : Array[EnumInfo],
  main_statements : Array[Stmt],
  closure_metadata : ClosureMetadata,
  global_vars : Array[GlobalVarInfo],
  captured_var_registry : Array[(Int, String, String, Int)],
) -> String {
  let mut output = "define void " + function_name + "() {\n"
  output = output + "entry:\n"
  let gen = LLVMGen::new(
    closure_metadata.clone(),
    enum_infos,
    global_vars,
    true,
    captured_var_registry,
  )
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }
  gen.current_return_type = "void"
  let (body_code, _) = llvm_gen_statements(gen, main_statements)
  output = output + body_code
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
) -> (String, StatementValue) {
  let mut code = ""
  let mut last_value = empty_statement_value()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Let(let_stmt) => {
        let (stmt_code, stmt_value) = llvm_gen_let(gen, let_stmt)
        code = code + stmt_code
        if statement_value_has_value(stmt_value) {
          last_value = stmt_value
        }
      }
      StmtKind::ExprStmt(expr) => {
        let expr_value = llvm_gen_expr_value(gen, expr)
        code = code + expr_value.code
        last_value = statement_value_from_expr(expr_value)
      }
      StmtKind::Return(return_stmt) => {
        let ret_code = llvm_gen_return(
          gen,
          return_stmt,
          gen.current_return_type,
        )
        code = code + ret_code
        last_value = empty_statement_value()
        break
      }
      StmtKind::Assign(assign_stmt) => {
        let (assign_code, assign_value) = llvm_gen_assign(gen, assign_stmt)
        code = code + assign_code
        if statement_value_has_value(assign_value) {
          last_value = assign_value
        }
      }
      StmtKind::While(while_stmt) => {
        let (while_code, while_value) = llvm_gen_while(gen, while_stmt)
        code = code + while_code
        if statement_value_has_value(while_value) {
          last_value = while_value
        }
      }
      StmtKind::If(if_stmt) => {
        let (if_code, if_value) = llvm_gen_if(gen, if_stmt)
        code = code + if_code
        if statement_value_has_value(if_value) {
          last_value = if_value
        }
      }
      StmtKind::Function(_function_stmt) =>
        // 嵌套函数定义不在语句序列中处理
        ()
      _ => ()
    }
  }
  (code, last_value)
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
    TokenKind::LiteralFloat => {
      let literal = normalize_float_literal(token.lexeme)
      let temp = gen.next_temp()
      let code = "  " + temp + " = fadd double 0.000000e+00, " + literal + "\n"
      expr_value(code, temp, "double")
    }
    TokenKind::LParen =>
      // Unit literal: () - 直接使用常量 0
      expr_value("", "0", "i32")
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
        let mut base_value = expr_value(code, temp, var_type)
        let (element_type, element_closure_arity) = gen.get_array_metadata(
          token.lexeme,
        )
        if element_type != "" {
          base_value = expr_value_with_array_metadata(
            base_value, element_type, element_closure_arity,
          )
        } else {
          let tuple_count = gen.get_tuple_metadata(token.lexeme)
          if tuple_count >= 0 {
            base_value = expr_value_with_tuple_metadata(base_value, tuple_count)
          }
        }
        let struct_name = gen.get_struct_metadata(token.lexeme)
        if struct_name != "" {
          base_value = expr_value_with_struct_name(base_value, struct_name)
        }
        let enum_name = gen.get_enum_metadata(token.lexeme)
        if enum_name != "" {
          expr_value_with_enum_name(base_value, enum_name)
        } else {
          base_value
        }
      }
    }
    None => {
      match gen.get_global_var(token.lexeme) {
        Some(info) => {
          let temp = gen.next_temp()
          let code = "  " +
            temp +
            " = load " +
            info.llvm_type +
            ", " +
            info.llvm_type +
            "* " +
            LLVMGen::global_var_symbol(info.name) +
            "\n"
          return if info.closure_arity >= 0 {
            expr_value_with_closure(
              code,
              temp,
              info.llvm_type,
              info.closure_arity,
            )
          } else {
            let mut base_value = expr_value(code, temp, info.llvm_type)
            if info.array_element_type != "" {
              base_value = expr_value_with_array_metadata(
                base_value,
                info.array_element_type,
                info.array_element_closure_arity,
              )
            } else if info.tuple_element_count >= 0 {
              base_value = expr_value_with_tuple_metadata(
                base_value,
                info.tuple_element_count,
              )
            }
            if info.struct_name != "" {
              base_value = expr_value_with_struct_name(
                base_value,
                info.struct_name,
              )
            }
            if info.enum_name != "" {
              expr_value_with_enum_name(base_value, info.enum_name)
            } else {
              let enum_name = gen.get_enum_metadata(token.lexeme)
              if enum_name != "" {
                expr_value_with_enum_name(base_value, enum_name)
              } else {
                base_value
              }
            }
          }
        }
        None => ()
      }
      match gen.find_local_function_entry(token.lexeme) {
        Some(entry) => llvm_gen_create_closure(gen, entry)
        None =>
          match gen.find_top_level_function_entry(token.lexeme) {
            Some(entry) => llvm_gen_create_closure(gen, entry)
            None => {
              match gen.get_enum_variant_info(token.lexeme) {
                Some(variant_info) =>
                  if variant_info.param_types.length() == 0 {
                    let empty_values : Array[String] = Array::new()
                    let empty_types : Array[String] = Array::new()
                    return llvm_gen_enum_variant_value(
                      gen, variant_info, "", empty_values, empty_types,
                    )
                  }
                None => ()
              }
              let temp = gen.next_temp()
              expr_value("", temp, "i32")
            }
          }
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
    let env_size = entry.free_vars.length() * 8
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
      let mut recorded_type = ""
      let mut recorded_closure_arity = -1
      match gen.get_var_entry(var_name) {
        Some((var_ptr, var_type, var_closure_arity)) => {
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
          recorded_type = var_type
          recorded_closure_arity = var_closure_arity
          let mut stored_value = loaded
          if var_type == "i32" {
            let extend_temp = gen.next_temp()
            code = code +
              "  " +
              extend_temp +
              " = sext i32 " +
              loaded +
              " to i64\n"
            stored_value = extend_temp
          } else {
            let cast_temp = gen.next_temp()
            code = code +
              "  " +
              cast_temp +
              " = ptrtoint " +
              var_type +
              " " +
              loaded +
              " to i64\n"
            stored_value = cast_temp
          }
          code = code +
            "  store i64 " +
            stored_value +
            ", i64* " +
            field_ptr +
            "\n"
        }
        None =>
          match gen.get_global_var(var_name) {
            Some(global_info) => {
              let global_symbol = LLVMGen::global_var_symbol(global_info.name)
              let loaded = gen.next_temp()
              code = code +
                "  " +
                loaded +
                " = load " +
                global_info.llvm_type +
                ", " +
                global_info.llvm_type +
                "* " +
                global_symbol +
                "\n"
              recorded_type = global_info.llvm_type
              recorded_closure_arity = global_info.closure_arity
              let mut stored_value = loaded
              if global_info.llvm_type == "i32" {
                let extend_temp = gen.next_temp()
                code = code +
                  "  " +
                  extend_temp +
                  " = sext i32 " +
                  loaded +
                  " to i64\n"
                stored_value = extend_temp
              } else {
                let cast_temp = gen.next_temp()
                code = code +
                  "  " +
                  cast_temp +
                  " = ptrtoint " +
                  global_info.llvm_type +
                  " " +
                  loaded +
                  " to i64\n"
                stored_value = cast_temp
              }
              code = code +
                "  store i64 " +
                stored_value +
                ", i64* " +
                field_ptr +
                "\n"
            }
            None => ()
          }
      }
      if recorded_type != "" {
        gen.record_captured_var_type(
          entry.id,
          var_name,
          recorded_type,
          recorded_closure_arity,
        )
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
    " " +
    closure_function_label(entry) +
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
  match binary_expr.operator.kind {
    TokenKind::AmpAmp | TokenKind::PipePipe => {
      let mut left_code = left_value.code
      let mut left_temp = left_value.value
      if left_value.llvm_type != "i32" {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen,
          left_temp,
          left_value.llvm_type,
          "i32",
        )
        left_code = left_code + cast_code
        left_temp = cast_temp
      }
      let mut right_code = right_value.code
      let mut right_temp = right_value.value
      if right_value.llvm_type != "i32" {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen,
          right_temp,
          right_value.llvm_type,
          "i32",
        )
        right_code = right_code + cast_code
        right_temp = cast_temp
      }
      let result_temp = gen.next_temp()
      let op_code = llvm_gen_logical_binary_op(
        gen,
        binary_expr.operator,
        left_temp,
        right_temp,
        result_temp,
      )
      let code = left_code + right_code + op_code
      expr_value(code, result_temp, "i32")
    }
    _ => {
      let mut left_code = left_value.code
      let mut left_temp = left_value.value
      let mut left_type = left_value.llvm_type
      if left_type == "" {
        left_type = "i32"
      }
      let mut right_code = right_value.code
      let mut right_temp = right_value.value
      let mut right_type = right_value.llvm_type
      if right_type == "" {
        right_type = "i32"
      }
      let mut operand_type = "i32"
      if left_type == "double" || right_type == "double" {
        operand_type = "double"
      }
      if left_type != operand_type {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen, left_temp, left_type, operand_type,
        )
        left_code = left_code + cast_code
        left_temp = cast_temp
      }
      if right_type != operand_type {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen, right_temp, right_type, operand_type,
        )
        right_code = right_code + cast_code
        right_temp = cast_temp
      }
      let result_temp = gen.next_temp()
      let (op_code, result_type) = llvm_gen_binary_op(
        gen,
        binary_expr.operator,
        left_temp,
        right_temp,
        result_temp,
        operand_type,
      )
      let code = left_code + right_code + op_code
      expr_value(code, result_temp, result_type)
    }
  }
}

///|
// 生成二元运算符的LLVM IR代码
fn llvm_gen_binary_op(
  gen : LLVMGen,
  operator : Token,
  left_temp : String,
  right_temp : String,
  result_temp : String,
  operand_type : String,
) -> (String, String) {
  match operator.kind {
    TokenKind::Plus =>
      if operand_type == "double" {
        (
          "  " +
          result_temp +
          " = fadd double " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "double",
        )
      } else {
        (
          "  " +
          result_temp +
          " = add i32 " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "i32",
        )
      }
    TokenKind::Minus =>
      if operand_type == "double" {
        (
          "  " +
          result_temp +
          " = fsub double " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "double",
        )
      } else {
        (
          "  " +
          result_temp +
          " = sub i32 " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "i32",
        )
      }
    TokenKind::Star =>
      if operand_type == "double" {
        (
          "  " +
          result_temp +
          " = fmul double " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "double",
        )
      } else {
        (
          "  " +
          result_temp +
          " = mul i32 " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "i32",
        )
      }
    TokenKind::Slash =>
      if operand_type == "double" {
        (
          "  " +
          result_temp +
          " = fdiv double " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "double",
        )
      } else {
        (
          "  " +
          result_temp +
          " = sdiv i32 " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "i32",
        )
      }
    TokenKind::Percent =>
      if operand_type == "double" {
        (
          "  " +
          result_temp +
          " = frem double " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "double",
        )
      } else {
        (
          "  " +
          result_temp +
          " = srem i32 " +
          left_temp +
          ", " +
          right_temp +
          "\n",
          "i32",
        )
      }
    TokenKind::Less => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp olt double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    TokenKind::Greater => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp ogt double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    TokenKind::LessEqual => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp ole double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    TokenKind::GreaterEqual => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp oge double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    TokenKind::EqualEqual => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp oeq double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    TokenKind::BangEqual => {
      let cmp_temp = gen.next_temp()
      if operand_type == "double" {
        (
          "  " +
          cmp_temp +
          " = fcmp one double " +
          left_temp +
          ", " +
          right_temp +
          "\n  " +
          result_temp +
          " = zext i1 " +
          cmp_temp +
          " to i32\n",
          "i32",
        )
      } else {
        (
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
          " to i32\n",
          "i32",
        )
      }
    }
    _ =>
      (
        "  " + result_temp + " = add i32 0, 0\n",
        if operand_type == "double" {
          "double"
        } else {
          "i32"
        },
      )
  }
}

///|
fn llvm_gen_logical_binary_op(
  gen : LLVMGen,
  operator : Token,
  left_temp : String,
  right_temp : String,
  result_temp : String,
) -> String {
  match operator.kind {
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
      let mut code = operand_value.code
      let value = operand_value.value
      let mut value_type = operand_value.llvm_type
      if value_type == "" {
        value_type = "i32"
      }
      let temp = gen.next_temp()
      if value_type == "double" {
        code = code +
          "  " +
          temp +
          " = fsub double 0.000000e+00, " +
          value +
          "\n"
        expr_value(code, temp, "double")
      } else {
        code = code + "  " + temp + " = sub i32 0, " + value + "\n"
        expr_value(code, temp, "i32")
      }
    }
    TokenKind::Bang => {
      let operand_value = llvm_gen_expr_value(gen, unary_expr.operand)
      let mut code = operand_value.code
      let mut value = operand_value.value
      let mut operand_type = operand_value.llvm_type
      if operand_type == "" {
        operand_type = "i32"
      }
      if operand_type != "i32" {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen, value, operand_type, "i32",
        )
        code = code + cast_code
        value = cast_temp
      }
      let cmp_temp = gen.next_temp()
      let temp = gen.next_temp()
      let code = code +
        "  " +
        cmp_temp +
        " = icmp eq i32 " +
        value +
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
  let args_types : Array[String] = Array::new()
  let args_closure_arities : Array[Int] = Array::new()
  for arg in call_expr.arguments {
    let arg_value = llvm_gen_expr_value(gen, arg)
    args_code = args_code + arg_value.code
    args_temps.push(arg_value.value)
    args_types.push(arg_value.llvm_type)
    args_closure_arities.push(arg_value.closure_arity)
  }

  // 获取函数名和函数类型
  // 支持普通函数调用（Ident）和限定函数调用（FieldAccess，如 Array::make）
  let mut func_name = ""
  let mut return_type = "i32"
  let mut is_void = false
  let mut builtin_param_types : Array[String]? = None
  let mut return_closure_arity = -1
  let mut array_element_type = ""
  let mut array_element_closure_arity = -1
  let mut return_tuple_count = -1
  let mut return_struct_name = ""
  let mut return_enum_name = ""
  let mut direct_function_entry : ClosureEntry? = None
  let mut is_recursive_call = false
  match call_expr.callee.kind {
    ExprKind::Ident(token) => {
      let name = token.lexeme
      match gen.get_enum_variant_info(name) {
        Some(variant_info) =>
          if variant_info.param_types.length() == call_expr.arguments.length() {
            return llvm_gen_enum_variant_value(
              gen, variant_info, args_code, args_temps, args_types,
            )
          }
        None => ()
      }
      match gen.get_var_entry(name) {
        Some(_) => {
          let callee_value = llvm_gen_ident(gen, token)
          if callee_value.closure_arity >= 0 {
            return llvm_gen_call_closure(
              gen, callee_value, args_code, args_temps,
            )
          } else {
            match gen.find_top_level_function_entry(name) {
              Some(entry) => {
                direct_function_entry = Some(entry)
                if entry.function_stmt.return_type_is_function {
                  return_closure_arity = entry.function_stmt.function_return_param_types.length()
                  return_type = closure_struct_pointer_type_for_arity(
                    return_closure_arity,
                  )
                  return_struct_name = ""
                  return_enum_name = ""
                } else if entry.function_stmt.return_type_is_tuple {
                  return_type = "i32*"
                  return_tuple_count = entry.function_stmt.return_tuple_element_types.length()
                  return_struct_name = ""
                  return_enum_name = ""
                } else {
                  match entry.function_stmt.return_type {
                    Some(ret_token) => {
                      let (resolved_type, resolved_struct, resolved_enum) = resolve_simple_type_name(
                        ret_token.lexeme,
                        gen.struct_defs,
                        gen.enum_defs,
                      )
                      return_type = resolved_type
                      if resolved_struct != "" {
                        return_struct_name = resolved_struct
                        return_enum_name = ""
                      } else if resolved_enum != "" {
                        return_enum_name = resolved_enum
                        return_struct_name = ""
                      } else {
                        return_struct_name = ""
                        return_enum_name = ""
                      }
                    }
                    None => ()
                  }
                }
                func_name = "@" + name
              }
              None => func_name = "@unknown"
            }
          }
        }
        None => {
          match gen.find_local_function_entry(name) {
            Some(entry) => {
              let callee_value = llvm_gen_create_closure(gen, entry)
              return llvm_gen_call_closure(
                gen, callee_value, args_code, args_temps,
              )
            }
            None => ()
          }
          match gen.find_function_entry_by_name(name, -1) {
            Some(entry) => {
              direct_function_entry = Some(entry)
              if entry.function_stmt.return_type_is_function {
                return_closure_arity = entry.function_stmt.function_return_param_types.length()
                return_type = closure_struct_pointer_type_for_arity(
                  return_closure_arity,
                )
                return_struct_name = ""
                return_enum_name = ""
              } else if entry.function_stmt.return_type_is_tuple {
                return_type = "i32*"
                return_tuple_count = entry.function_stmt.return_tuple_element_types.length()
                return_struct_name = ""
                return_enum_name = ""
              } else {
                match entry.function_stmt.return_type {
                  Some(ret_token) => {
                    let (resolved_type, resolved_struct, resolved_enum) = resolve_simple_type_name(
                      ret_token.lexeme,
                      gen.struct_defs,
                      gen.enum_defs,
                    )
                    return_type = resolved_type
                    if resolved_struct != "" {
                      return_struct_name = resolved_struct
                      return_enum_name = ""
                    } else if resolved_enum != "" {
                      return_enum_name = resolved_enum
                      return_struct_name = ""
                    } else {
                      return_struct_name = ""
                      // keep existing enum name if set
                    }
                  }
                  None => ()
                }
              }
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
          if token.lexeme == gen.current_function && gen.current_env_param != "" {
            match gen.closure_metadata.get_entry(gen.current_function_id) {
              Some(entry) => {
                direct_function_entry = Some(entry)
                is_recursive_call = true
              }
              None => ()
            }
          }
        }
      }
    }
    ExprKind::FieldAccess(field_access) => {
      let is_array_make = match field_access.object.kind {
        ExprKind::Ident(token) => token.lexeme == "Array"
        _ => false
      }
      if is_array_make && field_access.field.lexeme == "make" {
        let init_type = if args_types.length() > 1 {
          args_types[1]
        } else {
          "i32"
        }
        let init_closure_arity = if args_closure_arities.length() > 1 {
          args_closure_arities[1]
        } else {
          -1
        }
        if init_closure_arity >= 0 || init_type.contains("*") {
          func_name = "@minimbt_create_ptr_array"
          return_type = "i8**"
          builtin_param_types = Some(builtin_param_types_two("i32", "i8*"))
          array_element_type = init_type
          array_element_closure_arity = init_closure_arity
        } else if init_type == "double" {
          func_name = "@minimbt_create_float_array"
          return_type = "double*"
          builtin_param_types = Some(builtin_param_types_two("i32", "double"))
          array_element_type = "double"
          array_element_closure_arity = -1
        } else {
          func_name = "@minimbt_create_array"
          return_type = "i32*"
          builtin_param_types = Some(builtin_param_types_two("i32", "i32"))
          array_element_type = "i32"
          array_element_closure_arity = -1
        }
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
  let mut param_types_for_call : Array[String] = match builtin_param_types {
    Some(types) => types
    None => Array::new()
  }
  if param_types_for_call.length() == 0 {
    match direct_function_entry {
      Some(entry) => {
        let params : Array[String] = Array::new()
        for param in entry.function_stmt.parameters {
          let param_info = function_param_llvm_info(
            param,
            gen.struct_defs,
            gen.enum_defs,
          )
          params.push(param_info.llvm_type)
        }
        param_types_for_call = params
      }
      None => ()
    }
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
    let mut arg_temp = args_temps[index]
    let param_type = param_types_for_call[index]
    let mut arg_type = args_types[index]
    if param_type == "i32" && arg_type != "i32" {
      let cast_temp = gen.next_temp()
      let cast_code = if arg_type.contains("*") {
        "  " +
        cast_temp +
        " = ptrtoint " +
        arg_type +
        " " +
        arg_temp +
        " to i32\n"
      } else {
        "  " +
        cast_temp +
        " = bitcast " +
        arg_type +
        " " +
        arg_temp +
        " to i32\n"
      }
      args_code = args_code + cast_code
      arg_temp = cast_temp
      arg_type = "i32"
    } else if param_type == "i8*" && arg_type != "i8*" {
      let cast_temp = gen.next_temp()
      let cast_code = if arg_type.contains("*") {
        "  " +
        cast_temp +
        " = bitcast " +
        arg_type +
        " " +
        arg_temp +
        " to i8*\n"
      } else if arg_type == "i32" {
        "  " + cast_temp + " = inttoptr i32 " + arg_temp + " to i8*\n"
      } else {
        "  " +
        cast_temp +
        " = bitcast " +
        arg_type +
        " " +
        arg_temp +
        " to i8*\n"
      }
      args_code = args_code + cast_code
      arg_temp = cast_temp
      arg_type = "i8*"
    } else if param_type == "double" && arg_type != "double" {
      let cast_temp = gen.next_temp()
      let cast_code = if arg_type == "i32" {
        "  " + cast_temp + " = sitofp i32 " + arg_temp + " to double\n"
      } else {
        "  " +
        cast_temp +
        " = bitcast " +
        arg_type +
        " " +
        arg_temp +
        " to double\n"
      }
      args_code = args_code + cast_code
      arg_temp = cast_temp
      arg_type = "double"
    }
    args_temps[index] = arg_temp
    let entry = param_type + " " + arg_temp
    if param_type_list == "" {
      param_type_list = entry
    } else {
      param_type_list = param_type_list + ", " + entry
    }
    index = index + 1
  }
  if is_recursive_call {
    match direct_function_entry {
      Some(entry) =>
        return llvm_gen_call_self_closure(gen, entry, args_code, args_temps)
      None => ()
    }
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
    if return_closure_arity >= 0 {
      expr_value_with_closure(
        code, result_temp, return_type, return_closure_arity,
      )
    } else {
      let mut base_value = expr_value(code, result_temp, return_type)
      if array_element_type != "" {
        base_value = expr_value_with_array_metadata(
          base_value, array_element_type, array_element_closure_arity,
        )
      }
      if return_tuple_count >= 0 {
        base_value = expr_value_with_tuple_metadata(
          base_value, return_tuple_count,
        )
      }
      let mut struct_name = return_struct_name
      if struct_name == "" {
        struct_name = gen.struct_name_for_type(return_type)
      }
      if struct_name != "" {
        base_value = expr_value_with_struct_name(base_value, struct_name)
      }
      if return_enum_name != "" {
        base_value = expr_value_with_enum_name(base_value, return_enum_name)
      }
      base_value
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
  let mut then_temp = if then_value.value != "" {
    then_value.value
  } else {
    "0"
  }
  if then_temp.has_prefix("%") && !then_value.code.contains(then_temp + " =") {
    then_temp = "0"
  }
  let then_store_code = "  store i32 " +
    then_temp +
    ", i32* " +
    result_ptr +
    "\n" +
    "  br label %" +
    merge_label +
    "\n"
  let else_value = llvm_gen_expr_value(gen, if_expr.else_expr)
  let mut else_temp = if else_value.value != "" {
    else_value.value
  } else {
    "0"
  }
  if else_temp.has_prefix("%") && !else_value.code.contains(else_temp + " =") {
    else_temp = "0"
  }
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
fn llvm_gen_let(gen : LLVMGen, let_stmt : LetStmt) -> (String, StatementValue) {
  let value = llvm_gen_expr_value(gen, let_stmt.value)
  if let_stmt.destructured_names.length() > 0 {
    let mut code = value.code
    let tuple_ptr = value.value
    let mut index = 0
    for token in let_stmt.destructured_names {
      if token.lexeme == "_" {
        index = index + 1
        continue
      }
      let elem_ptr = gen.next_temp()
      code = code +
        "  " +
        elem_ptr +
        " = getelementptr i32, i32* " +
        tuple_ptr +
        ", i32 " +
        index.to_string() +
        "\n"
      let load_temp = gen.next_temp()
      code = code + "  " + load_temp + " = load i32, i32* " + elem_ptr + "\n"
      if gen.is_top_level_context {
        let global_name = LLVMGen::global_var_symbol(token.lexeme)
        if !gen.has_global_var(token.lexeme) {
          gen.global_vars.push(
            global_var_info(token.lexeme, "i32", -1, "", -1, -1, "", ""),
          )
        }
        gen.add_var_with_type_and_arity(token.lexeme, global_name, "i32", -1)
        code = code +
          "  store i32 " +
          load_temp +
          ", i32* " +
          global_name +
          "\n"
      } else {
        let var_temp = gen.next_temp()
        gen.add_var_with_type_and_arity(token.lexeme, var_temp, "i32", -1)
        code = code + "  " + var_temp + " = alloca i32\n"
        code = code + "  store i32 " + load_temp + ", i32* " + var_temp + "\n"
      }
      gen.clear_array_metadata(token.lexeme)
      gen.clear_tuple_metadata(token.lexeme)
      gen.clear_struct_metadata(token.lexeme)
      gen.clear_enum_metadata(token.lexeme)
      index = index + 1
    }
    (code, empty_statement_value())
  } else if let_stmt.name.lexeme == "_" {
    // 下划线变量：只生成值的代码，不分配变量
    (value.code, statement_value_from_expr(value))
    // 普通变量：分配内存并存储值
  } else if gen.is_top_level_context {
    let global_name = LLVMGen::global_var_symbol(let_stmt.name.lexeme)
    if !gen.has_global_var(let_stmt.name.lexeme) {
      gen.global_vars.push(
        global_var_info(
          let_stmt.name.lexeme,
          value.llvm_type,
          value.closure_arity,
          value.array_element_type,
          value.array_element_closure_arity,
          value.tuple_element_count,
          value.struct_name,
          value.enum_name,
        ),
      )
    }
    gen.add_var_with_type_and_arity(
      let_stmt.name.lexeme,
      global_name,
      value.llvm_type,
      value.closure_arity,
    )
    let code = value.code +
      "  store " +
      value.llvm_type +
      " " +
      value.value +
      ", " +
      value.llvm_type +
      "* " +
      global_name +
      "\n"
    if value.array_element_type != "" {
      gen.set_array_metadata(
        let_stmt.name.lexeme,
        value.array_element_type,
        value.array_element_closure_arity,
      )
    } else {
      gen.clear_array_metadata(let_stmt.name.lexeme)
    }
    if value.tuple_element_count >= 0 {
      gen.set_tuple_metadata(let_stmt.name.lexeme, value.tuple_element_count)
    } else {
      gen.clear_tuple_metadata(let_stmt.name.lexeme)
    }
    if value.struct_name != "" {
      gen.set_struct_metadata(let_stmt.name.lexeme, value.struct_name)
    } else {
      gen.clear_struct_metadata(let_stmt.name.lexeme)
    }
    if value.enum_name != "" {
      gen.set_enum_metadata(let_stmt.name.lexeme, value.enum_name)
    } else {
      gen.clear_enum_metadata(let_stmt.name.lexeme)
    }
    (code, empty_statement_value())
  } else {
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
    if value.array_element_type != "" {
      gen.set_array_metadata(
        let_stmt.name.lexeme,
        value.array_element_type,
        value.array_element_closure_arity,
      )
    } else {
      gen.clear_array_metadata(let_stmt.name.lexeme)
    }
    if value.tuple_element_count >= 0 {
      gen.set_tuple_metadata(let_stmt.name.lexeme, value.tuple_element_count)
    } else {
      gen.clear_tuple_metadata(let_stmt.name.lexeme)
    }
    if value.struct_name != "" {
      gen.set_struct_metadata(let_stmt.name.lexeme, value.struct_name)
    } else {
      gen.clear_struct_metadata(let_stmt.name.lexeme)
    }
    if value.enum_name != "" {
      gen.set_enum_metadata(let_stmt.name.lexeme, value.enum_name)
    } else {
      gen.clear_enum_metadata(let_stmt.name.lexeme)
    }
    // let 语句本身不返回值
    (code, empty_statement_value())
  }
}

///|
// 占位函数：赋值语句生成

///|
// 模块12: 赋值语句生成
// 支持：变量赋值、数组索引赋值
// 赋值语句：target = value
// 注意：target 可以是 Ident（变量）或 Index（数组索引）
fn llvm_gen_assign(
  gen : LLVMGen,
  assign_stmt : AssignStmt,
) -> (String, StatementValue) {
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
          if value.array_element_type != "" {
            gen.set_array_metadata(
              token.lexeme,
              value.array_element_type,
              value.array_element_closure_arity,
            )
          } else {
            gen.clear_array_metadata(token.lexeme)
          }
          if value.tuple_element_count >= 0 {
            gen.set_tuple_metadata(token.lexeme, value.tuple_element_count)
          } else {
            gen.clear_tuple_metadata(token.lexeme)
          }
          if value.struct_name != "" {
            gen.set_struct_metadata(token.lexeme, value.struct_name)
          } else {
            gen.clear_struct_metadata(token.lexeme)
          }
          if value.enum_name != "" {
            gen.set_enum_metadata(token.lexeme, value.enum_name)
          } else {
            gen.clear_enum_metadata(token.lexeme)
          }
          // 赋值语句返回赋值后的值
          (code, statement_value_from_expr(value))
        }
        // 变量未定义，错误处理（暂时返回空代码）
        None => ("", empty_statement_value())
      }
    // 数组索引赋值：arr[i] = value
    ExprKind::Index(index_expr) => {
      // 生成数组表达式的代码（数组变量名或表达式）
      let array_value = llvm_gen_expr_value(gen, index_expr.array)

      // 生成索引表达式的代码
      let index_value = llvm_gen_expr_value(gen, index_expr.index)
      let mut element_type = array_value.array_element_type
      if element_type == "" {
        if array_value.llvm_type == "double*" {
          element_type = "double"
        } else if array_value.llvm_type == "i8**" {
          element_type = "i8*"
        } else {
          element_type = "i32"
        }
      }
      let mut pointer_kind = "i32"
      if array_value.llvm_type == "double*" || element_type == "double" {
        pointer_kind = "double"
      } else if array_value.llvm_type == "i8**" ||
        element_type.contains("*") ||
        array_value.array_element_closure_arity >= 0 {
        pointer_kind = "ptr"
      }
      let mut value_code = value.code
      let mut stored_value = value.value
      let mut value_type = value.llvm_type
      if value_type == "" {
        value_type = "i32"
      }
      if pointer_kind == "double" {
        if value_type != "double" {
          let (cast_code, cast_temp) = cast_value_to_type(
            gen, stored_value, value_type, "double",
          )
          value_code = value_code + cast_code
          stored_value = cast_temp
          value_type = "double"
        }
      } else if pointer_kind == "ptr" {
        if value_type != "i8*" {
          let cast_temp = gen.next_temp()
          value_code = value_code +
            "  " +
            cast_temp +
            " = bitcast " +
            value_type +
            " " +
            stored_value +
            " to i8*\n"
          stored_value = cast_temp
          value_type = "i8*"
        }
      } else if value_type != "i32" {
        let (cast_code, cast_temp) = cast_value_to_type(
          gen, stored_value, value_type, "i32",
        )
        value_code = value_code + cast_code
        stored_value = cast_temp
        value_type = "i32"
      }
      let elem_ptr_temp = gen.next_temp()
      let gep_code = if pointer_kind == "double" {
        "  " +
        elem_ptr_temp +
        " = getelementptr double, double* " +
        array_value.value +
        ", i32 " +
        index_value.value +
        "\n"
      } else if pointer_kind == "ptr" {
        "  " +
        elem_ptr_temp +
        " = getelementptr i8*, i8** " +
        array_value.value +
        ", i32 " +
        index_value.value +
        "\n"
      } else {
        "  " +
        elem_ptr_temp +
        " = getelementptr i32, i32* " +
        array_value.value +
        ", i32 " +
        index_value.value +
        "\n"
      }
      let store_code = if pointer_kind == "double" {
        "  store double " + stored_value + ", double* " + elem_ptr_temp + "\n"
      } else if pointer_kind == "ptr" {
        "  store i8* " + stored_value + ", i8** " + elem_ptr_temp + "\n"
      } else {
        "  store i32 " + stored_value + ", i32* " + elem_ptr_temp + "\n"
      }
      let code = value_code +
        array_value.code +
        index_value.code +
        gep_code +
        store_code
      (code, statement_value_from_expr(value))
    }
    // 其他类型不支持赋值
    _ => ("", empty_statement_value())
  }
}

///|
// 模块10: if 语句生成
// 支持：if 语句（语句体）、else 分支、控制流
// if 语句：if condition { then_body } else { else_body }
// 注意：if 语句的 body 是语句数组，需要生成最后一个表达式的值
fn llvm_gen_if(gen : LLVMGen, if_stmt : IfStmt) -> (String, StatementValue) {
  // 生成条件表达式
  let (cond_code, cond_temp) = llvm_gen_expr(gen, if_stmt.condition)

  // 生成标签
  let then_label = gen.next_label()
  let else_label = gen.next_label()
  let merge_label = gen.next_label()

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
  let (then_code, then_result) = llvm_gen_statements(gen, if_stmt.then_body)
  // 生成 else 分支（如果有）
  let (else_code, else_result) = match if_stmt.else_body.length() {
    0 => ("", empty_statement_value())
    _ => llvm_gen_statements(gen, if_stmt.else_body)
  }
  let mut result_type = "i32"
  let mut result_tuple_count = -1
  let mut result_struct_name = ""
  let mut result_enum_name = ""
  if statement_value_has_value(then_result) && then_result.llvm_type != "" {
    result_type = then_result.llvm_type
    if then_result.tuple_element_count >= 0 {
      result_tuple_count = then_result.tuple_element_count
    }
    if then_result.struct_name != "" {
      result_struct_name = then_result.struct_name
    }
    if then_result.enum_name != "" {
      result_enum_name = then_result.enum_name
    }
  } else if statement_value_has_value(else_result) &&
    else_result.llvm_type != "" {
    result_type = else_result.llvm_type
    if else_result.tuple_element_count >= 0 {
      result_tuple_count = else_result.tuple_element_count
    }
    if else_result.struct_name != "" {
      result_struct_name = else_result.struct_name
    }
    if else_result.enum_name != "" {
      result_enum_name = else_result.enum_name
    }
  }
  let result_ptr = gen.next_temp()
  let alloc_code = "  " + result_ptr + " = alloca " + result_type + "\n"
  let mut then_value = default_value_for_type(result_type)
  if statement_value_has_value(then_result) && then_result.value != "" {
    then_value = then_result.value
    if then_value.has_prefix("%") && !then_code.contains(then_value + " =") {
      then_value = default_value_for_type(result_type)
    }
  }
  let then_store_code = "  store " +
    result_type +
    " " +
    then_value +
    ", " +
    result_type +
    "* " +
    result_ptr +
    "\n"
  let then_br_code = then_store_code + "  br label %" + merge_label + "\n"
  let mut else_value = default_value_for_type(result_type)
  if statement_value_has_value(else_result) && else_result.value != "" {
    else_value = else_result.value
    if else_value.has_prefix("%") && !else_code.contains(else_value + " =") {
      else_value = default_value_for_type(result_type)
    }
  }
  let else_store_code = "  store " +
    result_type +
    " " +
    else_value +
    ", " +
    result_type +
    "* " +
    result_ptr +
    "\n"
  let else_br_code = else_store_code + "  br label %" + merge_label + "\n"
  let result_temp = gen.next_temp()
  let load_code = "  " +
    result_temp +
    " = load " +
    result_type +
    ", " +
    result_type +
    "* " +
    result_ptr +
    "\n"

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
  (
    code,
    statement_value_with_tuple(
      result_temp, result_type, result_tuple_count, result_struct_name, result_enum_name,
    ),
  )
}

///|
// 模块11: while 循环生成
// 支持：while 循环（语句体）、条件判断、控制流
// while 循环：while condition { body }
// 注意：while 循环的 body 是语句数组，循环后返回最后一个表达式的值（如果有）
// while 循环通常不返回值，返回 Unit (0)
fn llvm_gen_while(
  gen : LLVMGen,
  while_stmt : WhileStmt,
) -> (String, StatementValue) {
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
  (code, empty_statement_value())
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
fn default_return_value(return_type : String) -> String {
  if return_type == "void" {
    "  ret void\n"
  } else if return_type.contains("*") {
    "  ret " + return_type + " null\n"
  } else {
    "  ret " + return_type + " 0\n"
  }
}

///|
// 模块7: 函数定义生成
// 支持：参数处理、函数体生成、返回语句
fn llvm_gen_function(
  struct_defs_map : Array[(String, Array[StructFieldInfo])],
  enum_infos : Array[EnumInfo],
  function_stmt : FunctionStmt,
  closure_metadata : ClosureMetadata,
  global_vars : Array[GlobalVarInfo],
  captured_var_registry : Array[(Int, String, String, Int)],
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
  let mut first = param_list == ""
  let mut param_index = 0
  for param in function_stmt.parameters {
    let param_name = "%" + param_index.to_string()
    let param_info = function_param_llvm_info(
      param, struct_defs_map, enum_infos,
    )
    let entry = param_info.llvm_type + " " + param_name
    if first {
      param_list = entry
      first = false
    } else {
      param_list = param_list + ", " + entry
    }
    param_index = param_index + 1
  }

  // 确定返回类型
  let mut return_type = if is_main { "void" } else { "i32" }
  let mut return_closure_arity = -1
  if function_stmt.return_type_is_function {
    return_closure_arity = function_stmt.function_return_param_types.length()
    return_type = closure_struct_pointer_type_for_arity(return_closure_arity)
  } else if function_stmt.return_type_is_tuple {
    return_type = "i32*"
  } else if !is_main {
    match function_stmt.return_type {
      Some(token) => {
        let (resolved_type, _, _) = resolve_simple_type_name(
          token.lexeme,
          struct_defs_map,
          enum_infos,
        )
        return_type = resolved_type
      }
      None => ()
    }
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
    enum_infos,
    return_type,
    global_vars,
    is_nested_function,
    captured_var_registry,
  )
  // 复制结构体定义到 gen
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }

  // 处理参数：为每个参数分配内存并存储
  let mut param_index = 0
  for param in function_stmt.parameters {
    let param_arg = "%" + param_index.to_string()
    let param_info = function_param_llvm_info(
      param, struct_defs_map, enum_infos,
    )
    // 为参数分配内存
    let param_temp = gen.next_temp()
    gen.add_var_with_type_and_arity(
      param.name.lexeme,
      param_temp,
      param_info.llvm_type,
      param_info.closure_arity,
    )
    output = output +
      "  " +
      param_temp +
      " = alloca " +
      param_info.llvm_type +
      "\n"
    output = output +
      "  store " +
      param_info.llvm_type +
      " " +
      param_arg +
      ", " +
      param_info.llvm_type +
      "* " +
      param_temp +
      "\n"
    if param_info.array_element_type != "" {
      gen.set_array_metadata(
        param.name.lexeme,
        param_info.array_element_type,
        param_info.array_element_closure_arity,
      )
    }
    if param_info.tuple_element_count >= 0 {
      gen.set_tuple_metadata(param.name.lexeme, param_info.tuple_element_count)
    } else {
      gen.clear_tuple_metadata(param.name.lexeme)
    }
    if param_info.struct_name != "" {
      gen.set_struct_metadata(param.name.lexeme, param_info.struct_name)
    } else {
      gen.clear_struct_metadata(param.name.lexeme)
    }
    if param_info.enum_name != "" {
      gen.set_enum_metadata(param.name.lexeme, param_info.enum_name)
    } else {
      gen.clear_enum_metadata(param.name.lexeme)
    }
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
        " = load i64, i64* " +
        field_ptr +
        "\n"
      let (captured_type, captured_closure_arity) = match
        gen.get_captured_var_type(func_id, var_name) {
        Some(info) => info
        None => ("i32", -1)
      }
      let final_type = if captured_type == "" { "i32" } else { captured_type }
      let capture_alloca = gen.next_temp()
      gen.add_var_with_type_and_arity(
        var_name, capture_alloca, final_type, captured_closure_arity,
      )
      output = output + "  " + capture_alloca + " = alloca " + final_type + "\n"
      let mut stored_val = field_val
      if final_type == "i32" {
        let trunc_temp = gen.next_temp()
        output = output +
          "  " +
          trunc_temp +
          " = trunc i64 " +
          field_val +
          " to i32\n"
        stored_val = trunc_temp
      } else {
        let cast_temp = gen.next_temp()
        output = output +
          "  " +
          cast_temp +
          " = inttoptr i64 " +
          field_val +
          " to " +
          final_type +
          "\n"
        stored_val = cast_temp
      }
      output = output +
        "  store " +
        final_type +
        " " +
        stored_val +
        ", " +
        final_type +
        "* " +
        capture_alloca +
        "\n"
      index = index + 1
    }
  }

  // 生成函数体
  if return_closure_arity >= 0 {
    gen.current_return_type = return_type
  }
  let (body_code, last_value) = llvm_gen_statements(gen, function_stmt.body)
  output = output + body_code

  // 检查函数体是否已经包含 return 语句
  let has_return = body_code.contains("ret i32") ||
    body_code.contains("ret void")

  // 如果没有 return 语句，生成返回语句
  if !has_return {
    if is_main {
      // main 函数返回 void（匹配 riscv_rt/start.c）
      output = output + "  ret void\n"
    } else if statement_value_has_value(last_value) {
      output = output +
        "  ret " +
        last_value.llvm_type +
        " " +
        last_value.value +
        "\n"
    } else {
      output = output + default_return_value(gen.current_return_type)
    }
  }
  output = output + "}\n\n"
  if !is_nested_function {
    match function_entry {
      Some(entry) => {
        let wrapper_code = generate_top_level_closure_wrapper(
          function_stmt, entry, func_name, return_type,
        )
        if wrapper_code != "" {
          output = output + wrapper_code
        }
      }
      None => ()
    }
  }
  let _ = closure_metadata.get_free_vars(function_stmt)
  output
}

///|
// 数组字面量生成
fn llvm_gen_array_literal(gen : LLVMGen, array_lit : ArrayLiteral) -> ExprValue {
  let mut code = ""
  let element_values : Array[ExprValue] = Array::new()
  for element in array_lit.elements {
    let value = llvm_gen_expr_value(gen, element)
    code = code + value.code
    element_values.push(value)
  }
  let length = array_lit.elements.length()
  let length_temp = gen.next_temp()
  code = code +
    "  " +
    length_temp +
    " = add i32 0, " +
    length.to_string() +
    "\n"
  let mut element_type = "i32"
  let mut element_closure_arity = -1
  let mut pointer_kind = "i32"
  let mut array_pointer_type = "i32*"
  let mut runtime_func = "@minimbt_create_array"
  let mut default_arg_type = "i32"
  let mut default_arg_value = "0"
  if length > 0 {
    let first = element_values[0]
    element_type = first.llvm_type
    element_closure_arity = first.closure_arity
    if element_type == "double" {
      pointer_kind = "double"
      array_pointer_type = "double*"
      runtime_func = "@minimbt_create_float_array"
      default_arg_type = "double"
      default_arg_value = "0.0"
    } else if element_type.contains("*") || first.closure_arity >= 0 {
      pointer_kind = "ptr"
      array_pointer_type = "i8**"
      runtime_func = "@minimbt_create_ptr_array"
      default_arg_type = "i8*"
      default_arg_value = "null"
    } else {
      element_type = "i32"
    }
  }
  let array_temp = gen.next_temp()
  code = code +
    "  " +
    array_temp +
    " = call " +
    array_pointer_type +
    " " +
    runtime_func +
    "(i32 " +
    length_temp +
    ", " +
    default_arg_type +
    " " +
    default_arg_value +
    ")\n"
  let mut index = 0
  for value in element_values {
    let elem_ptr = gen.next_temp()
    let gep_type = if pointer_kind == "double" {
      "double"
    } else if pointer_kind == "ptr" {
      "i8*"
    } else {
      "i32"
    }
    code = code +
      "  " +
      elem_ptr +
      " = getelementptr " +
      gep_type +
      ", " +
      array_pointer_type +
      " " +
      array_temp +
      ", i32 " +
      index.to_string() +
      "\n"
    let mut stored_value = value.value
    if pointer_kind == "ptr" {
      if value.llvm_type != "i8*" {
        let bitcast_temp = gen.next_temp()
        code = code +
          "  " +
          bitcast_temp +
          " = bitcast " +
          value.llvm_type +
          " " +
          value.value +
          " to i8*\n"
        stored_value = bitcast_temp
      }
      code = code + "  store i8* " + stored_value + ", i8** " + elem_ptr + "\n"
    } else if pointer_kind == "double" {
      let mut final_value = stored_value
      if value.llvm_type != "double" {
        let cast_temp = gen.next_temp()
        code = code +
          "  " +
          cast_temp +
          " = sitofp " +
          value.llvm_type +
          " " +
          stored_value +
          " to double\n"
        final_value = cast_temp
      }
      code = code +
        "  store double " +
        final_value +
        ", double* " +
        elem_ptr +
        "\n"
    } else {
      code = code + "  store i32 " + stored_value + ", i32* " + elem_ptr + "\n"
    }
    index = index + 1
  }
  let base_value = expr_value(code, array_temp, array_pointer_type)
  expr_value_with_array_metadata(
    base_value, element_type, element_closure_arity,
  )
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
  let mut element_type = array_value.array_element_type
  let element_closure_arity = array_value.array_element_closure_arity
  if element_type == "" {
    if array_value.llvm_type == "double*" {
      element_type = "double"
    } else if array_value.llvm_type == "i8**" {
      element_type = "i8*"
    } else {
      element_type = "i32"
    }
  }
  if array_value.llvm_type == "double*" || element_type == "double" {
    let elem_ptr_temp = gen.next_temp()
    let gep_code = "  " +
      elem_ptr_temp +
      " = getelementptr double, double* " +
      array_value.value +
      ", i32 " +
      index_value.value +
      "\n"
    let result_temp = gen.next_temp()
    let load_code = "  " +
      result_temp +
      " = load double, double* " +
      elem_ptr_temp +
      "\n"
    let code = array_value.code + index_value.code + gep_code + load_code
    expr_value(code, result_temp, "double")
  } else if array_value.llvm_type == "i8**" ||
    element_type.contains("*") ||
    element_closure_arity >= 0 {
    let elem_ptr_temp = gen.next_temp()
    let gep_code = "  " +
      elem_ptr_temp +
      " = getelementptr i8*, i8** " +
      array_value.value +
      ", i32 " +
      index_value.value +
      "\n"
    let loaded_temp = gen.next_temp()
    let load_code = "  " +
      loaded_temp +
      " = load i8*, i8** " +
      elem_ptr_temp +
      "\n"
    let mut final_temp = loaded_temp
    let mut additional_code = ""
    if element_type != "" && element_type != "i8*" {
      let cast_temp = gen.next_temp()
      additional_code = "  " +
        cast_temp +
        " = bitcast i8* " +
        loaded_temp +
        " to " +
        element_type +
        "\n"
      final_temp = cast_temp
    }
    let code = array_value.code +
      index_value.code +
      gep_code +
      load_code +
      additional_code
    if element_closure_arity >= 0 {
      expr_value_with_closure(
        code, final_temp, element_type, element_closure_arity,
      )
    } else {
      expr_value(code, final_temp, element_type)
    }
  } else {
    let elem_ptr_temp = gen.next_temp()
    let gep_code = "  " +
      elem_ptr_temp +
      " = getelementptr i32, i32* " +
      array_value.value +
      ", i32 " +
      index_value.value +
      "\n"
    let result_temp = gen.next_temp()
    let load_code = "  " +
      result_temp +
      " = load i32, i32* " +
      elem_ptr_temp +
      "\n"
    let code = array_value.code + index_value.code + gep_code + load_code
    expr_value(code, result_temp, "i32")
  }
}

///|
// 占位函数：元组字面量生成
fn llvm_gen_tuple_literal(gen : LLVMGen, tuple_lit : TupleLiteral) -> ExprValue {
  let element_count = tuple_lit.elements.length()
  let mut code = ""
  let element_values : Array[String] = Array::new()
  for element in tuple_lit.elements {
    let element_value = llvm_gen_expr_value(gen, element)
    code = code + element_value.code
    let mut value_temp = element_value.value
    if element_value.llvm_type != "i32" {
      let cast_temp = gen.next_temp()
      let cast_code = if element_value.llvm_type.contains("*") {
        "  " +
        cast_temp +
        " = ptrtoint " +
        element_value.llvm_type +
        " " +
        element_value.value +
        " to i32\n"
      } else if element_value.llvm_type == "double" {
        "  " +
        cast_temp +
        " = fptosi double " +
        element_value.value +
        " to i32\n"
      } else {
        "  " +
        cast_temp +
        " = bitcast " +
        element_value.llvm_type +
        " " +
        element_value.value +
        " to i32\n"
      }
      code = code + cast_code
      value_temp = cast_temp
    }
    element_values.push(value_temp)
  }
  let size_bytes = (element_count * 4).to_string()
  let raw_ptr = gen.next_temp()
  code = code +
    "  " +
    raw_ptr +
    " = call i8* @minimbt_malloc(i32 " +
    size_bytes +
    ")\n"
  let tuple_ptr = gen.next_temp()
  code = code + "  " + tuple_ptr + " = bitcast i8* " + raw_ptr + " to i32*\n"
  let mut index = 0
  for value_temp in element_values {
    let elem_ptr = gen.next_temp()
    code = code +
      "  " +
      elem_ptr +
      " = getelementptr i32, i32* " +
      tuple_ptr +
      ", i32 " +
      index.to_string() +
      "\n"
    code = code + "  store i32 " + value_temp + ", i32* " + elem_ptr + "\n"
    index = index + 1
  }
  let base_value = expr_value(code, tuple_ptr, "i32*")
  expr_value_with_tuple_metadata(base_value, element_count)
}

///|
fn llvm_gen_struct_literal(
  gen : LLVMGen,
  struct_lit : StructLiteral,
) -> ExprValue {
  let mut code = ""
  let struct_name = struct_lit.name.lexeme
  let field_defs = match gen.find_struct_fields(struct_name) {
    Some(fields) => fields
    None => Array::new()
  }
  let literal_values : Array[ExprValue] = Array::new()
  let literal_names : Array[String] = Array::new()
  for field in struct_lit.fields {
    let value = llvm_gen_expr_value(gen, field.value)
    code = code + value.code
    literal_names.push(field.name.lexeme)
    literal_values.push(value)
  }
  let mut total_size = 0
  let mut size_index = 0
  while size_index < field_defs.length() {
    total_size = total_size + llvm_type_size(field_defs[size_index].llvm_type)
    size_index = size_index + 1
  }
  if total_size == 0 {
    total_size = 4
  }
  let raw_ptr = gen.next_temp()
  code = code +
    "  " +
    raw_ptr +
    " = call i8* @minimbt_malloc(i32 " +
    total_size.to_string() +
    ")\n"
  let struct_ptr = gen.next_temp()
  let llvm_struct_type = "%" + struct_name
  code = code +
    "  " +
    struct_ptr +
    " = bitcast i8* " +
    raw_ptr +
    " to " +
    llvm_struct_type +
    "*\n"
  let mut field_index = 0
  while field_index < field_defs.length() {
    let field_info = field_defs[field_index]
    let mut stored_value = default_value_for_type(field_info.llvm_type)
    let mut value_type = field_info.llvm_type
    let mut literal_index = 0
    while literal_index < literal_names.length() {
      if literal_names[literal_index] == field_info.name {
        let literal_value = literal_values[literal_index]
        let (cast_code, casted_value) = cast_value_to_type(
          gen,
          literal_value.value,
          literal_value.llvm_type,
          field_info.llvm_type,
        )
        code = code + cast_code
        stored_value = casted_value
        value_type = field_info.llvm_type
        break
      }
      literal_index = literal_index + 1
    }
    let field_ptr = gen.next_temp()
    code = code +
      "  " +
      field_ptr +
      " = getelementptr " +
      llvm_struct_type +
      ", " +
      llvm_struct_type +
      "* " +
      struct_ptr +
      ", i32 0, i32 " +
      field_index.to_string() +
      "\n"
    code = code +
      "  store " +
      value_type +
      " " +
      stored_value +
      ", " +
      value_type +
      "* " +
      field_ptr +
      "\n"
    field_index = field_index + 1
  }
  let base_value = expr_value(code, struct_ptr, llvm_struct_type + "*")
  expr_value_with_struct_name(base_value, struct_name)
}

///|
fn llvm_gen_field_access(
  gen : LLVMGen,
  field_access : FieldAccessExpr,
) -> ExprValue {
  let object_value = llvm_gen_expr_value(gen, field_access.object)
  let mut code = object_value.code
  let mut struct_name = object_value.struct_name
  if struct_name == "" {
    struct_name = gen.struct_name_for_type(object_value.llvm_type)
  }
  match gen.find_struct_fields(struct_name) {
    Some(fields) => {
      let mut field_index = -1
      let mut field_type = "i32"
      let mut idx = 0
      while idx < fields.length() {
        if fields[idx].name == field_access.field.lexeme {
          field_index = idx
          field_type = fields[idx].llvm_type
          break
        }
        idx = idx + 1
      }
      if field_index == -1 {
        return expr_value(code, object_value.value, object_value.llvm_type)
      }
      let expected_type = "%" + struct_name + "*"
      let mut object_ptr = object_value.value
      if object_value.llvm_type != expected_type {
        let cast_temp = gen.next_temp()
        code = code +
          "  " +
          cast_temp +
          " = bitcast " +
          object_value.llvm_type +
          " " +
          object_value.value +
          " to " +
          expected_type +
          "\n"
        object_ptr = cast_temp
      }
      let field_ptr = gen.next_temp()
      code = code +
        "  " +
        field_ptr +
        " = getelementptr %" +
        struct_name +
        ", %" +
        struct_name +
        "* " +
        object_ptr +
        ", i32 0, i32 " +
        field_index.to_string() +
        "\n"
      let result_temp = gen.next_temp()
      code = code +
        "  " +
        result_temp +
        " = load " +
        field_type +
        ", " +
        field_type +
        "* " +
        field_ptr +
        "\n"
      expr_value(code, result_temp, field_type)
    }
    None => object_value
  }
}

///|
fn enum_name_from_llvm_type(
  enum_defs : Array[EnumInfo],
  llvm_type : String,
) -> String {
  for info in enum_defs {
    if info.pointer_type == llvm_type ||
      info.struct_type == llvm_type ||
      info.struct_type + "*" == llvm_type {
      return info.name
    }
  }
  ""
}

///|
fn resolve_expr_llvm_type(
  gen : LLVMGen,
  expr : Expr,
  value : ExprValue,
) -> String {
  if value.llvm_type != "" {
    return value.llvm_type
  }
  match expr.kind {
    ExprKind::Ident(token) => {
      match gen.get_var_entry(token.lexeme) {
        Some((_, llvm_type, _)) => return llvm_type
        None => ()
      }
      match gen.get_global_var(token.lexeme) {
        Some(info) => return info.llvm_type
        None => ()
      }
    }
    _ => ()
  }
  ""
}

///|
fn determine_enum_name_for_match(
  gen : LLVMGen,
  expr : Expr,
  value : ExprValue,
) -> String {
  if value.enum_name != "" {
    return value.enum_name
  }
  match expr.kind {
    ExprKind::Ident(token) => {
      let metadata = gen.get_enum_metadata(token.lexeme)
      if metadata != "" {
        return metadata
      }
      match gen.get_global_var(token.lexeme) {
        Some(info) => if info.enum_name != "" { return info.enum_name }
        None => ()
      }
      match gen.get_var_entry(token.lexeme) {
        Some((_, llvm_type, _)) =>
          return enum_name_from_llvm_type(gen.enum_defs, llvm_type)
        None => ()
      }
      match gen.get_global_var(token.lexeme) {
        Some(info) =>
          return enum_name_from_llvm_type(gen.enum_defs, info.llvm_type)
        None => ()
      }
    }
    _ => ()
  }
  enum_name_from_llvm_type(gen.enum_defs, value.llvm_type)
}

///|
fn enum_name_from_match_arms(gen : LLVMGen, arms : Array[MatchArm]) -> String {
  for arm in arms {
    match arm.pattern.kind {
      PatternKind::EnumVariant(enum_pattern) =>
        match gen.get_enum_variant_info(enum_pattern.name.lexeme) {
          Some(variant_info) => return variant_info.enum_name
          None => ()
        }
      _ => ()
    }
  }
  ""
}

///|
fn cleanup_pattern_bindings(gen : LLVMGen, names : Array[String]) -> Unit {
  for name in names {
    if name == "" {
      continue
    }
    gen.remove_var_entry(name)
    gen.clear_array_metadata(name)
    gen.clear_tuple_metadata(name)
    gen.clear_struct_metadata(name)
    gen.clear_enum_metadata(name)
  }
}

///|
fn update_metadata_for_llvm_type(
  gen : LLVMGen,
  name : String,
  llvm_type : String,
) -> Unit {
  gen.clear_array_metadata(name)
  gen.clear_tuple_metadata(name)
  gen.clear_struct_metadata(name)
  gen.clear_enum_metadata(name)
  let struct_name = gen.struct_name_for_type(llvm_type)
  if struct_name != "" {
    gen.set_struct_metadata(name, struct_name)
  }
  let enum_name = enum_name_from_llvm_type(gen.enum_defs, llvm_type)
  if enum_name != "" {
    gen.set_enum_metadata(name, enum_name)
  }
}

///|
fn llvm_gen_bind_enum_variant_arguments(
  gen : LLVMGen,
  enum_pattern : PatternEnumVariant,
  variant_info : EnumVariantInfo,
  payload_value : String,
) -> String {
  if variant_info.param_types.length() == 0 ||
    variant_info.payload_struct_name == "" {
    return ""
  }
  let mut code = ""
  let payload_struct_ptr_type = variant_info.payload_struct_name + "*"
  let payload_struct_ptr = gen.next_temp()
  code = code +
    "  " +
    payload_struct_ptr +
    " = bitcast i8* " +
    payload_value +
    " to " +
    payload_struct_ptr_type +
    "\n"
  let mut index = 0
  while index < enum_pattern.arguments.length() &&
        index < variant_info.param_types.length() {
    match enum_pattern.arguments[index].kind {
      PatternKind::Ident(token) => {
        let field_type = variant_info.param_types[index]
        let field_ptr = gen.next_temp()
        code = code +
          "  " +
          field_ptr +
          " = getelementptr " +
          variant_info.payload_struct_name +
          ", " +
          payload_struct_ptr_type +
          " " +
          payload_struct_ptr +
          ", i32 0, i32 " +
          index.to_string() +
          "\n"
        let field_value = gen.next_temp()
        code = code +
          "  " +
          field_value +
          " = load " +
          field_type +
          ", " +
          field_type +
          "* " +
          field_ptr +
          "\n"
        let binding_alloca = gen.next_temp()
        gen.add_var_with_type_and_arity(
          token.lexeme,
          binding_alloca,
          field_type,
          -1,
        )
        code = code + "  " + binding_alloca + " = alloca " + field_type + "\n"
        code = code +
          "  store " +
          field_type +
          " " +
          field_value +
          ", " +
          field_type +
          "* " +
          binding_alloca +
          "\n"
        update_metadata_for_llvm_type(gen, token.lexeme, field_type)
      }
      PatternKind::Wildcard(_) => ()
      _ => ()
    }
    index = index + 1
  }
  code
}

///|
fn llvm_gen_bind_full_enum_value(
  gen : LLVMGen,
  name : String,
  enum_ptr : String,
  enum_ptr_type : String,
  enum_name : String,
) -> String {
  let binding_alloca = gen.next_temp()
  gen.add_var_with_type_and_arity(name, binding_alloca, enum_ptr_type, -1)
  let mut code = "  " + binding_alloca + " = alloca " + enum_ptr_type + "\n"
  code = code +
    "  store " +
    enum_ptr_type +
    " " +
    enum_ptr +
    ", " +
    enum_ptr_type +
    "* " +
    binding_alloca +
    "\n"
  gen.clear_array_metadata(name)
  gen.clear_tuple_metadata(name)
  gen.clear_struct_metadata(name)
  gen.set_enum_metadata(name, enum_name)
  code
}

///|
fn llvm_gen_match(gen : LLVMGen, match_expr : MatchExpr) -> ExprValue {
  let scrutinee_value = llvm_gen_expr_value(gen, match_expr.value)
  let mut enum_name = determine_enum_name_for_match(
    gen,
    match_expr.value,
    scrutinee_value,
  )
  if enum_name == "" {
    enum_name = enum_name_from_match_arms(gen, match_expr.arms)
  }
  match gen.get_enum_info(enum_name) {
    Some(enum_info) => {
      let mut code = scrutinee_value.code
      let mut scrutinee_type = resolve_expr_llvm_type(
        gen,
        match_expr.value,
        scrutinee_value,
      )
      if scrutinee_type == "" {
        scrutinee_type = enum_info.pointer_type
      }
      let mut enum_ptr = scrutinee_value.value
      if enum_ptr == "" {
        enum_ptr = "null"
      }
      if scrutinee_type != enum_info.pointer_type {
        let cast_temp = gen.next_temp()
        code = code +
          "  " +
          cast_temp +
          " = bitcast " +
          scrutinee_type +
          " " +
          enum_ptr +
          " to " +
          enum_info.pointer_type +
          "\n"
        enum_ptr = cast_temp
      }
      let tag_ptr = gen.next_temp()
      code = code +
        "  " +
        tag_ptr +
        " = getelementptr " +
        enum_info.struct_type +
        ", " +
        enum_info.pointer_type +
        " " +
        enum_ptr +
        ", i32 0, i32 0\n"
      let tag_value = gen.next_temp()
      code = code + "  " + tag_value + " = load i32, i32* " + tag_ptr + "\n"
      let payload_ptr = gen.next_temp()
      code = code +
        "  " +
        payload_ptr +
        " = getelementptr " +
        enum_info.struct_type +
        ", " +
        enum_info.pointer_type +
        " " +
        enum_ptr +
        ", i32 0, i32 1\n"
      let payload_value = gen.next_temp()
      code = code +
        "  " +
        payload_value +
        " = load i8*, i8** " +
        payload_ptr +
        "\n"
      let merge_label = gen.next_label()
      let default_fallback_label = gen.next_label()
      let result_ptr = gen.next_temp()
      let mut result_alloc_code = ""
      let mut result_type = ""
      let mut result_tuple_count = -1
      let mut result_struct_name = ""
      let mut result_enum_name = ""
      let mut result_array_element_type = ""
      let mut result_array_element_closure_arity = -1
      let mut result_closure_arity = -1
      let mut switch_entries = ""
      let mut branch_blocks = ""
      let mut default_label = ""
      let mut default_block_code = ""
      for arm in match_expr.arms {
        match arm.pattern.kind {
          PatternKind::EnumVariant(enum_pattern) =>
            match gen.get_enum_variant_info(enum_pattern.name.lexeme) {
              Some(variant_info) =>
                if variant_info.enum_name == enum_info.name {
                  let arm_label = gen.next_label()
                  switch_entries = switch_entries +
                    "    i32 " +
                    variant_info.tag.to_string() +
                    ", label %" +
                    arm_label +
                    "\n"
                  let bindings : Array[String] = Array::new()
                  collect_pattern_bindings(arm.pattern, bindings)
                  let mut arm_code = llvm_gen_bind_enum_variant_arguments(
                    gen, enum_pattern, variant_info, payload_value,
                  )
                  let arm_value = llvm_gen_expr_value(gen, arm.value)
                  arm_code = arm_code + arm_value.code
                  let mut branch_value = arm_value.value
                  let mut branch_type = arm_value.llvm_type
                  if branch_type == "" {
                    branch_type = "i32"
                  }
                  if result_type == "" {
                    result_type = branch_type
                    result_tuple_count = arm_value.tuple_element_count
                    result_struct_name = arm_value.struct_name
                    result_enum_name = arm_value.enum_name
                    result_array_element_type = arm_value.array_element_type
                    result_array_element_closure_arity = arm_value.array_element_closure_arity
                    result_closure_arity = arm_value.closure_arity
                    result_alloc_code = "  " +
                      result_ptr +
                      " = alloca " +
                      result_type +
                      "\n"
                  } else if branch_type != result_type {
                    let (cast_code, cast_temp) = cast_value_to_type(
                      gen, branch_value, branch_type, result_type,
                    )
                    arm_code = arm_code + cast_code
                    branch_value = cast_temp
                    branch_type = result_type
                  }
                  if branch_value == "" {
                    branch_value = default_value_for_type(result_type)
                  }
                  arm_code = arm_code +
                    "  store " +
                    result_type +
                    " " +
                    branch_value +
                    ", " +
                    result_type +
                    "* " +
                    result_ptr +
                    "\n" +
                    "  br label %" +
                    merge_label +
                    "\n"
                  cleanup_pattern_bindings(gen, bindings)
                  branch_blocks = branch_blocks + arm_label + ":\n" + arm_code
                }
              None => ()
            }
          PatternKind::Wildcard(_) =>
            if default_label == "" {
              default_label = gen.next_label()
              let mut arm_code = ""
              let arm_value = llvm_gen_expr_value(gen, arm.value)
              arm_code = arm_code + arm_value.code
              let mut branch_value = arm_value.value
              let mut branch_type = arm_value.llvm_type
              if branch_type == "" {
                branch_type = "i32"
              }
              if result_type == "" {
                result_type = branch_type
                result_tuple_count = arm_value.tuple_element_count
                result_struct_name = arm_value.struct_name
                result_enum_name = arm_value.enum_name
                result_array_element_type = arm_value.array_element_type
                result_array_element_closure_arity = arm_value.array_element_closure_arity
                result_closure_arity = arm_value.closure_arity
                result_alloc_code = "  " +
                  result_ptr +
                  " = alloca " +
                  result_type +
                  "\n"
              } else if branch_type != result_type {
                let (cast_code, cast_temp) = cast_value_to_type(
                  gen, branch_value, branch_type, result_type,
                )
                arm_code = arm_code + cast_code
                branch_value = cast_temp
              }
              if branch_value == "" {
                branch_value = default_value_for_type(result_type)
              }
              arm_code = arm_code +
                "  store " +
                result_type +
                " " +
                branch_value +
                ", " +
                result_type +
                "* " +
                result_ptr +
                "\n" +
                "  br label %" +
                merge_label +
                "\n"
              branch_blocks = branch_blocks + default_label + ":\n" + arm_code
            }
          PatternKind::Ident(token) => {
            let mut handled_variant_ident = false
            match gen.get_enum_variant_info(token.lexeme) {
              Some(variant_info) =>
                if variant_info.enum_name == enum_info.name &&
                  variant_info.param_types.length() == 0 {
                  let empty_tokens : Array[Token] = Array::new()
                  let empty_args : Array[Pattern] = Array::new()
                  let synthetic_pattern : PatternEnumVariant = {
                    qualifier: empty_tokens,
                    name: token,
                    open: None,
                    arguments: empty_args,
                    close: None,
                    range: arm.pattern.range,
                  }
                  let bindings : Array[String] = Array::new()
                  let mut arm_code = llvm_gen_bind_enum_variant_arguments(
                    gen, synthetic_pattern, variant_info, payload_value,
                  )
                  let arm_value = llvm_gen_expr_value(gen, arm.value)
                  arm_code = arm_code + arm_value.code
                  let mut branch_value = arm_value.value
                  let mut branch_type = arm_value.llvm_type
                  if branch_type == "" {
                    branch_type = "i32"
                  }
                  if result_type == "" {
                    result_type = branch_type
                    result_tuple_count = arm_value.tuple_element_count
                    result_struct_name = arm_value.struct_name
                    result_enum_name = arm_value.enum_name
                    result_array_element_type = arm_value.array_element_type
                    result_array_element_closure_arity = arm_value.array_element_closure_arity
                    result_closure_arity = arm_value.closure_arity
                    result_alloc_code = "  " +
                      result_ptr +
                      " = alloca " +
                      result_type +
                      "\n"
                  } else if branch_type != result_type {
                    let (cast_code, cast_temp) = cast_value_to_type(
                      gen, branch_value, branch_type, result_type,
                    )
                    arm_code = arm_code + cast_code
                    branch_value = cast_temp
                  }
                  if branch_value == "" {
                    branch_value = default_value_for_type(result_type)
                  }
                  arm_code = arm_code +
                    "  store " +
                    result_type +
                    " " +
                    branch_value +
                    ", " +
                    result_type +
                    "* " +
                    result_ptr +
                    "\n" +
                    "  br label %" +
                    merge_label +
                    "\n"
                  cleanup_pattern_bindings(gen, bindings)
                  let arm_label = gen.next_label()
                  switch_entries = switch_entries +
                    "    i32 " +
                    variant_info.tag.to_string() +
                    ", label %" +
                    arm_label +
                    "\n"
                  branch_blocks = branch_blocks + arm_label + ":\n" + arm_code
                  handled_variant_ident = true
                }
              None => ()
            }
            if handled_variant_ident {
              continue
            }
            if default_label == "" {
              default_label = gen.next_label()
              let bindings : Array[String] = Array::new()
              collect_pattern_bindings(arm.pattern, bindings)
              let mut arm_code = llvm_gen_bind_full_enum_value(
                gen,
                token.lexeme,
                enum_ptr,
                enum_info.pointer_type,
                enum_info.name,
              )
              let arm_value = llvm_gen_expr_value(gen, arm.value)
              arm_code = arm_code + arm_value.code
              let mut branch_value = arm_value.value
              let mut branch_type = arm_value.llvm_type
              if branch_type == "" {
                branch_type = "i32"
              }
              if result_type == "" {
                result_type = branch_type
                result_tuple_count = arm_value.tuple_element_count
                result_struct_name = arm_value.struct_name
                result_enum_name = arm_value.enum_name
                result_array_element_type = arm_value.array_element_type
                result_array_element_closure_arity = arm_value.array_element_closure_arity
                result_closure_arity = arm_value.closure_arity
                result_alloc_code = "  " +
                  result_ptr +
                  " = alloca " +
                  result_type +
                  "\n"
              } else if branch_type != result_type {
                let (cast_code, cast_temp) = cast_value_to_type(
                  gen, branch_value, branch_type, result_type,
                )
                arm_code = arm_code + cast_code
                branch_value = cast_temp
              }
              if branch_value == "" {
                branch_value = default_value_for_type(result_type)
              }
              arm_code = arm_code +
                "  store " +
                result_type +
                " " +
                branch_value +
                ", " +
                result_type +
                "* " +
                result_ptr +
                "\n" +
                "  br label %" +
                merge_label +
                "\n"
              cleanup_pattern_bindings(gen, bindings)
              branch_blocks = branch_blocks + default_label + ":\n" + arm_code
            }
          }
          _ => ()
        }
      }
      if result_type == "" {
        result_type = "i32"
        result_alloc_code = "  " + result_ptr + " = alloca i32\n"
      }
      if default_label == "" {
        default_label = default_fallback_label
        let default_value = default_value_for_type(result_type)
        default_block_code = default_label +
          ":\n" +
          "  store " +
          result_type +
          " " +
          default_value +
          ", " +
          result_type +
          "* " +
          result_ptr +
          "\n  br label %" +
          merge_label +
          "\n"
      }
      let switch_code = "  switch i32 " +
        tag_value +
        ", label %" +
        default_label +
        " [\n" +
        switch_entries +
        "  ]\n"
      let result_temp = gen.next_temp()
      let load_code = "  " +
        result_temp +
        " = load " +
        result_type +
        ", " +
        result_type +
        "* " +
        result_ptr +
        "\n"
      let total_code = code +
        result_alloc_code +
        switch_code +
        branch_blocks +
        default_block_code +
        merge_label +
        ":\n" +
        load_code
      if result_closure_arity >= 0 {
        let mut base_value = expr_value_with_closure(
          total_code, result_temp, result_type, result_closure_arity,
        )
        if result_array_element_type != "" {
          base_value = expr_value_with_array_metadata(
            base_value, result_array_element_type, result_array_element_closure_arity,
          )
        }
        if result_tuple_count >= 0 {
          base_value = expr_value_with_tuple_metadata(
            base_value, result_tuple_count,
          )
        }
        if result_struct_name != "" {
          base_value = expr_value_with_struct_name(
            base_value, result_struct_name,
          )
        }
        if result_enum_name != "" {
          base_value = expr_value_with_enum_name(base_value, result_enum_name)
        }
        return base_value
      }
      let mut base_value = expr_value(total_code, result_temp, result_type)
      if result_array_element_type != "" {
        base_value = expr_value_with_array_metadata(
          base_value, result_array_element_type, result_array_element_closure_arity,
        )
      }
      if result_tuple_count >= 0 {
        base_value = expr_value_with_tuple_metadata(
          base_value, result_tuple_count,
        )
      }
      if result_struct_name != "" {
        base_value = expr_value_with_struct_name(base_value, result_struct_name)
      }
      if result_enum_name != "" {
        base_value = expr_value_with_enum_name(base_value, result_enum_name)
      }
      base_value
    }
    None => scrutinee_value
  }
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
