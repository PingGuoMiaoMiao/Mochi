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
  var_map : Array[(String, String)] // 变量名到临时变量名的映射
  struct_defs : Array[(String, Array[String])] // 结构体定义：(结构体名, 字段名列表)
  nested_functions : Array[(String, String)] // 嵌套函数映射：(嵌套函数名, 父函数名)
  current_function : String // 当前函数名
}

///|
fn LLVMGen::new() -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    nested_functions: Array::new(),
    current_function: "",
  }
}

///|
fn LLVMGen::new_with_function(func_name : String) -> LLVMGen {
  {
    var_counter: 0,
    label_counter: 0,
    var_map: Array::new(),
    struct_defs: Array::new(),
    nested_functions: Array::new(),
    current_function: func_name,
  }
}

///|
fn LLVMGen::add_nested_function(
  self : LLVMGen,
  nested_func_name : String,
  parent_func_name : String,
) -> Unit {
  self.nested_functions.push((nested_func_name, parent_func_name))
}

///|
fn LLVMGen::get_parent_function(
  self : LLVMGen,
  nested_func_name : String,
) -> String {
  for pair in self.nested_functions {
    if pair.0 == nested_func_name {
      return pair.1
    }
  }
  ""
}

///|
fn LLVMGen::is_nested_function(self : LLVMGen, func_name : String) -> Bool {
  for pair in self.nested_functions {
    if pair.0 == func_name {
      return true
    }
  }
  false
}

///|
fn LLVMGen::get_var_name(self : LLVMGen, name : String) -> String {
  for pair in self.var_map {
    if pair.0 == name {
      return pair.1
    }
  }
  ""
}

///|
fn LLVMGen::add_var(self : LLVMGen, name : String, temp_name : String) -> Unit {
  self.var_map.push((name, temp_name))
}

///|
fn LLVMGen::update_var(
  self : LLVMGen,
  name : String,
  temp_name : String,
) -> Unit {
  let mut index = 0
  for {
    if index >= self.var_map.length() {
      break
    }
    if self.var_map[index].0 == name {
      self.var_map[index] = (name, temp_name)
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
fn generate_llvm(statements : Array[Stmt]) -> String {
  let mut output = "target triple = \"riscv64-unknown-linux-gnu\"\n\n"

  // 生成外部函数声明
  output = output + generate_external_declarations()

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

  // 第二遍：生成所有函数定义
  let main_statements : Array[Stmt] = Array::new()
  let mut has_main_function = false
  let mut has_main_statements = false
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) => {
        if function_stmt.name.lexeme == "main" {
          has_main_function = true
        }
        let func_code = llvm_gen_function(struct_defs_map, function_stmt)
        output = output + func_code
      }
      _ => {
        ignore(main_statements.push(stmt))
        has_main_statements = true
      }
    }
  }

  // 如果没有 main 函数，且 main_statements 不为空，生成一个 main 函数
  // 确保不会重复生成 main 函数
  if !has_main_function && has_main_statements && main_statements.length() > 0 {
    let main_code = llvm_gen_main_function(struct_defs_map, main_statements)
    output = output + main_code
  }
  output
}

///|
// 生成外部函数声明
// 支持 riscv_rt 运行时库中的所有函数
fn generate_external_declarations() -> String {
  // 基本 I/O 函数（兼容旧版本）
  "declare void @print_int(i32)\n" +
  "declare void @print_double(double)\n" +
  "declare void @print_endline()\n" +
  "declare i32 @int_of_float(double)\n" +
  "declare double @float_of_int(i32)\n" +
  "declare i32 @truncate(double)\n" +
  "declare double @abs_float(double)\n" +
  "declare i8* @malloc(i32)\n" +
  // minimbt 运行时库函数
  "declare i32 @minimbt_read_int()\n" +
  "declare i32 @minimbt_read_char()\n" +
  "declare void @minimbt_print_int(i32)\n" +
  "declare void @minimbt_print_endline()\n" +
  "declare void @minimbt_print_char(i32)\n" +
  "declare i32 @minimbt_int_of_float(double)\n" +
  "declare double @minimbt_float_of_int(i32)\n" +
  "declare i32 @minimbt_truncate(double)\n" +
  "declare i32 @minimbt_floor(double)\n" +
  "declare double @minimbt_abs_float(double)\n" +
  "declare double @minimbt_sqrt(double)\n" +
  "declare double @minimbt_sin(double)\n" +
  "declare double @minimbt_cos(double)\n" +
  "declare double @minimbt_atan(double)\n" +
  "declare i8* @minimbt_malloc(i32)\n" +
  // 数组创建函数
  "declare i32* @minimbt_create_array(i32, i32)\n" +
  "declare i8** @minimbt_create_ptr_array(i32, i8*)\n" +
  "declare double* @minimbt_create_float_array(i32, double)\n" +
  // 检查算术函数
  "declare i32 @minimbt_checked_add(i32, i32)\n" +
  "declare i32 @minimbt_checked_sub(i32, i32)\n" +
  "declare i32 @minimbt_checked_mul(i32, i32)\n" +
  "declare i32 @minimbt_checked_div(i32, i32)\n" +
  // mincaml 兼容函数
  "declare void @mincaml_print_int(i32)\n" +
  "declare void @mincaml_print_endline()\n" +
  "declare i32 @mincaml_int_of_float(double)\n" +
  "declare double @mincaml_float_of_int(i32)\n" +
  "declare i32 @mincaml_truncate(double)\n" +
  "declare i32 @mincaml_floor(double)\n" +
  "declare double @mincaml_abs_float(double)\n" +
  "declare double @mincaml_sqrt(double)\n" +
  "declare double @mincaml_sin(double)\n" +
  "declare double @mincaml_cos(double)\n" +
  "declare double @mincaml_atan(double)\n" +
  "declare i8* @mincaml_malloc(i32)\n" +
  "declare i32* @mincaml_create_array(i32, i32)\n" +
  "declare i8** @mincaml_create_ptr_array(i32, i8*)\n" +
  "declare double* @mincaml_create_float_array(i32, double)\n\n"
}

///|
// 生成主函数
fn llvm_gen_main_function(
  struct_defs_map : Array[(String, Array[String])],
  main_statements : Array[Stmt],
) -> String {
  // 生成 minimbt_main 函数以匹配 riscv_rt/start.c
  let mut output = "define void @minimbt_main() {\n"
  output = output + "entry:\n"
  let gen = LLVMGen::new()
  for struct_def in struct_defs_map {
    gen.struct_defs.push(struct_def)
  }
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
        let ret_code = llvm_gen_return(gen, return_stmt)
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
// 返回 (生成的代码, 临时变量名)
fn llvm_gen_expr(gen : LLVMGen, expr : Expr) -> (String, String) {
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
fn llvm_gen_literal(gen : LLVMGen, token : Token) -> (String, String) {
  match token.kind {
    TokenKind::LiteralInt => {
      let temp = gen.next_temp()
      let code = "  " + temp + " = add i32 0, " + token.lexeme + "\n"
      (code, temp)
    }
    TokenKind::LiteralBool =>
      match token.lexeme {
        "true" => {
          let temp = gen.next_temp()
          let code = "  " + temp + " = add i32 0, 1\n"
          (code, temp)
        }
        "false" => {
          let temp = gen.next_temp()
          let code = "  " + temp + " = add i32 0, 0\n"
          (code, temp)
        }
        _ => {
          let temp = gen.next_temp()
          ("", temp)
        }
      }
    TokenKind::LParen => {
      // Unit literal: () - 表示为 i32 0
      let temp = gen.next_temp()
      let code = "  " + temp + " = add i32 0, 0\n"
      (code, temp)
    }
    _ => {
      let temp = gen.next_temp()
      ("", temp)
    }
  }
}

///|
// 模块2: 标识符生成
// 支持：变量访问、函数名识别（嵌套函数）
fn llvm_gen_ident(gen : LLVMGen, token : Token) -> (String, String) {
  let var_name = gen.get_var_name(token.lexeme)
  if var_name == "" {
    // 变量未定义，可能是函数名（如 adder）
    // 检查是否是嵌套函数名
    if gen.is_nested_function(token.lexeme) {
      // 如果是嵌套函数标识符，返回空字符串
      // 这样在生成返回语句时可以检测到并返回第一个参数的值
      ("", "")
    } else {
      // 不是嵌套函数，可能是其他函数名或未定义的变量
      // 为了简化，我们假设如果是函数名，返回一个占位符值
      let temp = gen.next_temp()
      ("", temp)
    }
  } else {
    // 加载变量的值
    let temp = gen.next_temp()
    let code = "  " + temp + " = load i32, i32* " + var_name + "\n"
    (code, temp)
  }
}

///|
// 模块3: 二元表达式生成
// 支持：算术运算（+、-、*、/、%）、比较运算（<、>、<=、>=、==、!=）、逻辑运算（&&、||）
fn llvm_gen_binary(gen : LLVMGen, binary_expr : BinaryExpr) -> (String, String) {
  let (left_code, left_temp) = llvm_gen_expr(gen, binary_expr.left)
  let (right_code, right_temp) = llvm_gen_expr(gen, binary_expr.right)
  let temp = gen.next_temp()
  let op_code = llvm_gen_binary_op(
    gen,
    binary_expr.operator,
    left_temp,
    right_temp,
    temp,
  )
  let code = left_code + right_code + op_code
  (code, temp)
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
      "  " +
      cmp1_temp +
      " = icmp ne i32 " +
      left_temp +
      ", 0\n  " +
      cmp2_temp +
      " = icmp ne i32 " +
      right_temp +
      ", 0\n  " +
      result_temp +
      " = and i32 " +
      cmp1_temp +
      ", " +
      cmp2_temp +
      "\n"
    }
    TokenKind::PipePipe => {
      let cmp1_temp = gen.next_temp()
      let cmp2_temp = gen.next_temp()
      "  " +
      cmp1_temp +
      " = icmp ne i32 " +
      left_temp +
      ", 0\n  " +
      cmp2_temp +
      " = icmp ne i32 " +
      right_temp +
      ", 0\n  " +
      result_temp +
      " = or i32 " +
      cmp1_temp +
      ", " +
      cmp2_temp +
      "\n"
    }
    _ => "  " + result_temp + " = add i32 0, 0\n"
  }
}

///|
// 模块4: 一元表达式生成
// 支持：取负（-）、逻辑非（!）
fn llvm_gen_unary(gen : LLVMGen, unary_expr : UnaryExpr) -> (String, String) {
  match unary_expr.operator.kind {
    TokenKind::Minus => {
      let (operand_code, operand_temp) = llvm_gen_expr(gen, unary_expr.operand)
      let temp = gen.next_temp()
      let code = operand_code +
        "  " +
        temp +
        " = sub i32 0, " +
        operand_temp +
        "\n"
      (code, temp)
    }
    TokenKind::Bang => {
      let (operand_code, operand_temp) = llvm_gen_expr(gen, unary_expr.operand)
      let temp = gen.next_temp()
      let code = operand_code +
        "  " +
        temp +
        " = xor i32 " +
        operand_temp +
        ", 1\n"
      (code, temp)
    }
    _ => {
      let temp = gen.next_temp()
      ("", temp)
    }
  }
}

///|
// 模块5: 函数调用生成
// 支持：普通函数调用、嵌套函数调用（后续支持闭包）
fn llvm_gen_call(gen : LLVMGen, call_expr : CallExpr) -> (String, String) {
  // 生成参数代码
  let mut args_code = ""
  let args_temps : Array[String] = Array::new()
  for arg in call_expr.arguments {
    let (arg_code, arg_temp) = llvm_gen_expr(gen, arg)
    args_code = args_code + arg_code
    args_temps.push(arg_temp)
  }

  // 构建参数列表
  let mut args_list = ""
  let mut first = true
  for arg_temp in args_temps {
    if first {
      args_list = arg_temp
      first = false
    } else {
      args_list = args_list + ", " + arg_temp
    }
  }

  // 获取函数名和函数类型
  // 支持普通函数调用（Ident）和限定函数调用（FieldAccess，如 Array::make）
  let (func_name, return_type, is_void, param_types) = match
    call_expr.callee.kind {
    ExprKind::Ident(token) => {
      // 普通函数调用：function_name(args)
      let name = token.lexeme
      // 检查是否是特殊的运行时函数
      match name {
        "print_int" => ("@minimbt_print_int", "void", true, "i32")
        "print_double" => ("@print_double", "void", true, "double")
        "print_endline" => ("@minimbt_print_endline", "void", true, "")
        "truncate" => ("@minimbt_truncate", "i32", false, "double")
        "int_of_float" => ("@minimbt_int_of_float", "i32", false, "double")
        "float_of_int" => ("@minimbt_float_of_int", "double", false, "i32")
        "abs_float" => ("@minimbt_abs_float", "double", false, "double")
        _ =>
          // 普通函数调用，默认所有参数都是 i32，返回值是 i32
          // 参数类型需要根据实际参数数量生成
          ("@" + name, "i32", false, "i32")
      }
    }
    ExprKind::FieldAccess(field_access) => {
      // 限定函数调用：Array::make(args)
      // 检查是否是 Array::make
      let is_array_make = match field_access.object.kind {
        ExprKind::Ident(token) => token.lexeme == "Array"
        _ => false
      }
      if is_array_make && field_access.field.lexeme == "make" {
        // Array::make(size, value)
        // 根据参数类型决定使用哪个函数
        // 如果第二个参数是 double，使用 minimbt_create_float_array
        // 否则使用 minimbt_create_array
        // 暂时假设所有 Array::make 都使用 minimbt_create_array（i32 数组）
        // TODO: 根据类型检查结果确定使用哪个函数
        if args_temps.length() == 2 {
          // 检查第二个参数的类型（暂时假设是 i32，实际应该从类型检查器获取）
          // 为了简化，我们暂时使用 minimbt_create_array
          // 如果需要支持 double 数组，需要类型信息
          ("@minimbt_create_array", "i32*", false, "i32, i32")
        } else {
          ("@minimbt_create_array", "i32*", false, "i32, i32")
        }
      } else {
        // 其他限定函数调用：尝试作为普通函数调用处理
        // 例如：Module::function -> @Module_function
        let module_name = match field_access.object.kind {
          ExprKind::Ident(token) => token.lexeme
          _ => ""
        }
        let func_name = module_name + "_" + field_access.field.lexeme
        ("@" + func_name, "i32", false, "i32")
      }
    }
    _ =>
      // 不支持的调用表达式类型
      // 暂时返回错误值，应该在实际使用时报告错误
      ("@unknown", "i32", false, "i32")
  }

  // 检查是否是 @unknown 函数（不应该调用）
  if func_name == "@unknown" {
    // 对于未知函数，生成错误处理代码
    // 暂时返回 0，实际应该报告错误
    let temp = gen.next_temp()
    let code = "  " + temp + " = add i32 0, 0\n"
    return (code, temp)
  }

  // 生成函数调用代码
  // 构建带类型的参数列表：为每个参数添加类型
  // 对于普通函数调用，所有参数都是 i32
  // 对于特殊函数调用（如 Array::make），param_types 可能是 "i32, i32"
  // 简化处理：如果 param_types 是 "i32"，所有参数都是 i32
  // 如果 param_types 包含逗号，需要按逗号分割（暂时简化处理）
  let mut param_type_list = ""
  let mut first = true

  // 确定每个参数的类型
  // 对于普通函数（param_types 是 "i32"），所有参数都是 i32
  // 对于特殊函数（param_types 是 "i32, i32"），需要按顺序使用类型
  // 简化处理：如果 param_types 包含逗号，只使用第一个类型（TODO: 正确解析多个类型）
  let default_param_type = if param_types.contains(",") {
    // 多个参数类型，暂时只使用第一个类型（简化处理）
    // 找到第一个逗号，取前面的部分作为类型
    let mut base_type = ""
    for ch in param_types.to_array() {
      if ch == ',' {
        break
      } else {
        base_type = base_type + ch.to_string()
      }
    }
    base_type
  } else {
    // 单个参数类型，所有参数都使用这个类型
    param_types
  }

  // 为每个参数添加类型
  for arg_temp in args_temps {
    let param_type = if default_param_type != "" {
      default_param_type
    } else {
      "i32"
    }
    if first {
      param_type_list = param_type + " " + arg_temp
      first = false
    } else {
      param_type_list = param_type_list + ", " + param_type + " " + arg_temp
    }
  }
  if is_void {
    // void 函数，不返回值
    let call_code = "  call void " + func_name + "(" + param_type_list + ")\n"
    // 对于 void 函数，返回一个 dummy 值（0）
    let result_temp = gen.next_temp()
    let code = args_code + call_code + "  " + result_temp + " = add i32 0, 0\n"
    (code, result_temp)
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
      (code + ptrtoint_code, int_temp)
    } else {
      (code, result_temp)
    }
  }
}

///|
// 模块9: if 表达式生成
// 支持：嵌套 if、phi 节点、前驱标签正确性
// if 表达式：if condition { then_expr } else { else_expr }
// 返回：(生成的代码, 结果临时变量名, merge_label)
// merge_label 用于嵌套 if 表达式的情况，让外层 if 表达式知道嵌套 if 表达式的合并点
fn llvm_gen_if_expr_internal(
  gen : LLVMGen,
  if_expr : IfExpr,
  outer_merge_label : String,
) -> (String, String, String) {
  // 生成条件表达式
  let (cond_code, cond_temp) = llvm_gen_expr(gen, if_expr.condition)

  // 生成标签
  let then_label = gen.next_label()
  let else_label = gen.next_label()
  // 如果提供了 outer_merge_label，使用它作为 merge_label（嵌套 if 表达式的情况）
  // 否则，生成新的 merge_label
  let merge_label = if outer_merge_label != "" {
    outer_merge_label
  } else {
    gen.next_label()
  }
  let result_temp = gen.next_temp()

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

  // 生成 then 分支
  let (then_code, then_temp) = llvm_gen_expr(gen, if_expr.then_expr)
  let then_br_code = "  br label %" + merge_label + "\n"

  // 生成 else 分支
  // 检查 else_expr 是否是嵌套的 if 表达式
  let (else_code, else_temp, else_phi_label) = match if_expr.else_expr.kind {
    ExprKind::If(nested_if_expr) => {
      // else_expr 是嵌套的 if 表达式
      // 让嵌套 if 表达式使用自己的 merge_label（不传入 outer_merge_label）
      // 这样嵌套 if 表达式会生成自己的 merge_label，然后跳转到外层的 merge_label
      let (nested_code, nested_temp, nested_merge_label) = llvm_gen_if_expr_internal(
        gen, nested_if_expr, "",
      )
      // 嵌套 if 表达式使用自己的 merge_label
      // 我们需要在嵌套 if 表达式的 merge_label 之后添加跳转到外层的 merge_label 的指令
      // 但是，由于嵌套 if 表达式的代码已经包含了 merge_label 和 phi 节点，我们需要在其后添加跳转指令
      // 实际上，嵌套 if 表达式的代码结构是：条件代码 + then代码 + else代码 + merge_label + phi节点
      // 我们需要在 phi 节点之后添加跳转到外层的 merge_label 的指令
      // 但是，由于嵌套 if 表达式的代码已经包含了 phi 节点，我们需要在其后添加跳转指令
      // 所以，我们需要在嵌套 if 表达式的代码之后添加跳转指令
      // 但是，由于嵌套 if 表达式的代码已经包含了 merge_label 和 phi 节点，我们需要在其后添加跳转指令
      // 所以，我们需要在嵌套 if 表达式的代码之后添加跳转指令
      let nested_br_code = "  br label %" + merge_label + "\n"
      // 嵌套 if 表达式的 merge_label 跳转到外层的 merge_label
      // 外层的 PHI 节点应该使用嵌套 if 表达式的 merge_label 作为前驱
      (nested_code + nested_br_code, nested_temp, nested_merge_label)
    }
    _ => {
      // else_expr 不是嵌套的 if 表达式，正常生成代码
      let (code, temp) = llvm_gen_expr(gen, if_expr.else_expr)
      let else_br_code = "  br label %" + merge_label + "\n"
      (code + else_br_code, temp, else_label)
    }
  }
  let phi_code = "  " +
    result_temp +
    " = phi i32 [ " +
    then_temp +
    ", %" +
    then_label +
    " ], [ " +
    else_temp +
    ", %" +
    else_phi_label +
    " ]\n"

  // 组合所有代码
  let code = cond_code +
    cmp_code +
    br_code +
    then_label +
    ":\n" +
    then_code +
    then_br_code +
    else_label +
    ":\n" +
    else_code +
    merge_label +
    ":\n" +
    phi_code
  (code, result_temp, merge_label)
}

///|
// 模块9: if 表达式生成（公共接口）
// 支持：嵌套 if、phi 节点、前驱标签正确性
// if 表达式：if condition { then_expr } else { else_expr }
fn llvm_gen_if_expr(gen : LLVMGen, if_expr : IfExpr) -> (String, String) {
  let (code, temp, _merge_label) = llvm_gen_if_expr_internal(gen, if_expr, "")
  (code, temp)
}

///|
// 模块6: let 语句生成
// 支持：变量分配、内存管理、下划线变量（忽略值）
fn llvm_gen_let(gen : LLVMGen, let_stmt : LetStmt) -> (String, String) {
  let (value_code, value_temp) = llvm_gen_expr(gen, let_stmt.value)

  // 检查是否是下划线变量（忽略值）
  if let_stmt.name.lexeme == "_" {
    // 下划线变量：只生成值的代码，不分配变量
    (value_code, value_temp)
  } else {
    // 普通变量：分配内存并存储值
    let var_temp = gen.next_temp()
    gen.add_var(let_stmt.name.lexeme, var_temp)
    let code = value_code +
      "  " +
      var_temp +
      " = alloca i32\n" +
      "  store i32 " +
      value_temp +
      ", i32* " +
      var_temp +
      "\n"
    // 返回变量指针（用于后续使用）
    (code, var_temp)
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
  let (value_code, value_temp) = llvm_gen_expr(gen, assign_stmt.value)

  // 根据 target 的类型生成不同的赋值代码
  match assign_stmt.target.kind {
    // 变量赋值：x = value
    ExprKind::Ident(token) => {
      // 获取变量的 alloca 地址
      let var_name = gen.get_var_name(token.lexeme)
      if var_name == "" {
        // 变量未定义，错误处理（暂时返回空代码）
        ("", "")
      } else {
        // 使用 store 指令将值存储到变量地址
        let store_code = "  store i32 " +
          value_temp +
          ", i32* " +
          var_name +
          "\n"
        let code = value_code + store_code
        // 赋值语句返回赋值后的值
        (code, value_temp)
      }
    }
    // 数组索引赋值：arr[i] = value
    ExprKind::Index(index_expr) => {
      // 生成数组表达式的代码（数组变量名或表达式）
      let (array_code, array_temp) = llvm_gen_expr(gen, index_expr.array)

      // 生成索引表达式的代码
      let (index_code, index_temp) = llvm_gen_expr(gen, index_expr.index)

      // 使用 getelementptr 计算元素地址
      // getelementptr i32, i32* %array, i32 %index
      let elem_ptr_temp = gen.next_temp()
      let gep_code = "  " +
        elem_ptr_temp +
        " = getelementptr i32, i32* " +
        array_temp +
        ", i32 " +
        index_temp +
        "\n"

      // 使用 store 指令存储值
      let store_code = "  store i32 " +
        value_temp +
        ", i32* " +
        elem_ptr_temp +
        "\n"

      // 组合所有代码
      let code = value_code + array_code + index_code + gep_code + store_code
      // 赋值语句返回赋值后的值
      (code, value_temp)
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
  let result_temp = gen.next_temp()

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
  let then_br_code = "  br label %" + merge_label + "\n"

  // 生成 else 分支（如果有）
  let (else_code, else_last_temp) = match if_stmt.else_body.length() {
    0 => ("", "")
    _ => llvm_gen_statements(gen, if_stmt.else_body)
  }
  let else_br_code = "  br label %" + merge_label + "\n"

  // 生成 phi 节点（合并两个分支的值）
  // 如果 then 分支有值，使用它；否则使用 else 分支的值；如果都没有，使用 0
  let then_value = if then_last_temp != "" { then_last_temp } else { "0" }
  let else_value = if else_last_temp != "" { else_last_temp } else { "0" }
  let phi_code = "  " +
    result_temp +
    " = phi i32 [ " +
    then_value +
    ", %" +
    then_label +
    " ], [ " +
    else_value +
    ", %" +
    else_label +
    " ]\n"

  // 组合所有代码
  let code = cond_code +
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
    phi_code
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
fn llvm_gen_return(gen : LLVMGen, return_stmt : ReturnStmt) -> String {
  match return_stmt.value {
    Some(expr) => {
      let (expr_code, temp) = llvm_gen_expr(gen, expr)
      expr_code + "  ret i32 " + temp + "\n"
    }
    None => "  ret i32 0\n"
  }
}

///|
// 模块7: 函数定义生成
// 支持：参数处理、函数体生成、返回语句
fn llvm_gen_function(
  struct_defs_map : Array[(String, Array[String])],
  function_stmt : FunctionStmt,
) -> String {
  // 如果是 main 函数，生成 minimbt_main 以匹配 riscv_rt/start.c
  let func_name = if function_stmt.name.lexeme == "main" {
    "@minimbt_main"
  } else {
    "@" + function_stmt.name.lexeme
  }
  let is_main = function_stmt.name.lexeme == "main"

  // 生成参数列表
  let mut param_list = ""
  let mut first = true
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

  // 确定返回类型：main 函数返回 void（匹配 riscv_rt/start.c），其他函数返回 i32
  let return_type = if is_main { "void" } else { "i32" }
  let mut output = "define " +
    return_type +
    " " +
    func_name +
    "(" +
    param_list +
    ") {\n"
  output = output + "entry:\n"

  // 创建新的 LLVMGen 实例
  let gen = LLVMGen::new_with_function(function_stmt.name.lexeme)
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

  // 生成函数体
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
  output
}

///|
// 占位函数：数组字面量生成
fn llvm_gen_array_literal(
  gen : LLVMGen,
  array_lit : ArrayLiteral,
) -> (String, String) {
  let temp = gen.next_temp()
  ("", temp)
}

///|
// 模块13: 数组索引访问生成
// 支持：数组索引访问 arr[index]
// 使用 getelementptr 和 load 指令
// 注意：数组变量应该是指针类型（i32*），但如果它存储在 var_map 中，需要特殊处理
fn llvm_gen_index(gen : LLVMGen, index_expr : IndexExpr) -> (String, String) {
  // 生成数组表达式的代码（数组变量名或表达式）
  let (array_code, array_temp) = llvm_gen_expr(gen, index_expr.array)

  // 生成索引表达式的代码
  let (index_code, index_temp) = llvm_gen_expr(gen, index_expr.index)

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
        array_temp
      }
    }
    _ => array_temp
  }

  // 使用 getelementptr 计算元素地址
  // getelementptr i32, i32* %array_ptr, i32 %index
  let elem_ptr_temp = gen.next_temp()
  let gep_code = "  " +
    elem_ptr_temp +
    " = getelementptr i32, i32* " +
    array_ptr_temp +
    ", i32 " +
    index_temp +
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
  let code = if array_ptr_temp == array_temp {
    array_code + index_code + gep_code + load_code
  } else {
    // 如果 array_ptr_temp != array_temp，说明我们使用了 var_name，不需要 array_code
    index_code + gep_code + load_code
  }
  (code, result_temp)
}

///|
// 占位函数：元组字面量生成
fn llvm_gen_tuple_literal(
  gen : LLVMGen,
  tuple_lit : TupleLiteral,
) -> (String, String) {
  let temp = gen.next_temp()
  ("", temp)
}

///|
// 占位函数：结构体字面量生成
fn llvm_gen_struct_literal(
  gen : LLVMGen,
  struct_lit : StructLiteral,
) -> (String, String) {
  let temp = gen.next_temp()
  ("", temp)
}

///|
// 占位函数：字段访问生成
fn llvm_gen_field_access(
  gen : LLVMGen,
  field_access : FieldAccessExpr,
) -> (String, String) {
  let temp = gen.next_temp()
  ("", temp)
}

///|
// 占位函数：match 表达式生成
fn llvm_gen_match(gen : LLVMGen, match_expr : MatchExpr) -> (String, String) {
  let temp = gen.next_temp()
  ("", temp)
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
