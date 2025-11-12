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
priv struct LLVMGen {
  mut var_counter : Int
  mut label_counter : Int
  var_map : Array[(String, String)]
}

///|
fn LLVMGen::new() -> LLVMGen {
  { var_counter: 0, label_counter: 0, var_map: Array::new() }
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
fn generate_llvm(statements : Array[Stmt]) -> String {
  let mut output = "target triple = \"riscv64-unknown-linux-gnu\"\n\n"
  output = output + "@_print_int = external global i32 (i32)\n\n"
  // Generate all function definitions first
  let main_statements : Array[Stmt] = Array::new()
  for stmt in statements {
    match stmt.kind {
      StmtKind::Function(function_stmt) => {
        let func_name = "@" + function_stmt.name.lexeme
        let mut param_list = ""
        let mut first = true
        for _ in function_stmt.parameters {
          if first {
            param_list = "i32"
            first = false
          } else {
            param_list = param_list + ", i32"
          }
        }
        output = output + "define i32 " + func_name + "(" + param_list + ") {\n"
        output = output + "entry:\n"
        let gen = LLVMGen::new()
        // Add parameters to var_map
        let mut param_index = 0
        for param in function_stmt.parameters {
          let param_temp = "%arg" + param_index.to_string()
          gen.add_var(param.name.lexeme, param_temp)
          output = output + "  " + param_temp + " = alloca i32\n"
          output = output +
            "  store i32 %" +
            param_index.to_string() +
            ", i32* " +
            param_temp +
            "\n"
          param_index = param_index + 1
        }
        let (code, returned, last_temp) = llvm_gen_statements(
          gen,
          function_stmt.body,
          true,
        )
        output = output + code
        if !returned {
          if last_temp != "" {
            output = output + "  ret i32 " + last_temp + "\n"
          } else {
            output = output + "  ret i32 0\n"
          }
        }
        output = output + "}\n\n"
      }
      _ => main_statements.push(stmt)
    }
  }
  // Generate main function
  output = output + "define i32 @main() {\n"
  output = output + "entry:\n"
  let gen = LLVMGen::new()
  let (code, returned, last_temp) = llvm_gen_statements(
    gen, main_statements, false,
  )
  output = output + code
  if !returned {
    if last_temp != "" {
      output = output + "  ret i32 " + last_temp + "\n"
    } else {
      output = output + "  ret i32 0\n"
    }
  }
  output = output + "}\n"
  output
}

///|
fn llvm_gen_statements(
  gen : LLVMGen,
  statements : Array[Stmt],
  stop_at_return : Bool,
) -> (String, Bool, String) {
  let mut code = ""
  let mut returned = false
  let mut last_temp = ""
  for stmt in statements {
    if returned && stop_at_return {
      break
    }
    match stmt.kind {
      StmtKind::Let(let_stmt) => {
        let (stmt_code, temp_name) = llvm_gen_let(gen, let_stmt)
        code = code + stmt_code
        last_temp = temp_name
      }
      StmtKind::ExprStmt(expr) => {
        let (expr_code, expr_temp) = llvm_gen_expr(gen, expr)
        code = code + expr_code
        last_temp = expr_temp
        if !stop_at_return {
          code = code + "  ret i32 " + expr_temp + "\n"
          returned = true
        }
      }
      StmtKind::Return(return_stmt) => {
        let (ret_code, _) = llvm_gen_return(gen, return_stmt)
        code = code + ret_code
        returned = true
      }
      StmtKind::Assign(assign_stmt) => {
        let (assign_code, new_temp) = llvm_gen_assign(gen, assign_stmt)
        code = code + assign_code
        last_temp = new_temp
      }
      StmtKind::While(while_stmt) => {
        let (while_code, while_last_temp) = llvm_gen_while(gen, while_stmt)
        code = code + while_code
        last_temp = while_last_temp
      }
      StmtKind::If(if_stmt) => {
        let (if_code, if_last_temp) = llvm_gen_if(gen, if_stmt)
        code = code + if_code
        last_temp = if_last_temp
      }
      StmtKind::Function(function_stmt) => {
        let (func_code, func_returned, func_last_temp) = llvm_gen_statements(
          gen,
          function_stmt.body,
          true,
        )
        code = code + func_code
        if func_returned {
          returned = true
        } else if func_last_temp != "" {
          code = code + "  ret i32 " + func_last_temp + "\n"
          returned = true
        } else {
          code = code + "  ret i32 0\n"
          returned = true
        }
      }
      _ => ()
    }
  }
  (code, returned, last_temp)
}

///|
fn llvm_gen_let(gen : LLVMGen, let_stmt : LetStmt) -> (String, String) {
  let (value_code, value_temp) = llvm_gen_expr(gen, let_stmt.value)
  gen.add_var(let_stmt.name.lexeme, value_temp)
  (value_code, value_temp)
}

///|
fn llvm_gen_assign(gen : LLVMGen, assign_stmt : AssignStmt) -> (String, String) {
  let (value_code, value_temp) = llvm_gen_expr(gen, assign_stmt.value)
  // Handle assignment target (can be identifier or array index)
  match assign_stmt.target.kind {
    ExprKind::Ident(token) => {
      let var_name = token.lexeme
      let old_var_temp = gen.get_var_name(var_name)
      if old_var_temp == "" {
        gen.add_var(var_name, value_temp)
        (value_code, value_temp)
      } else {
        gen.update_var(var_name, value_temp)
        (value_code, value_temp)
      }
    }
    ExprKind::Index(_index_expr) => {
      // Array index assignment - for now, just return the value code
      // In a full implementation, we'd need to generate store instructions
      (value_code, value_temp)
    }
    _ => {
      // Invalid assignment target - return value code anyway
      (value_code, value_temp)
    }
  }
}

///|
fn llvm_gen_if(gen : LLVMGen, if_stmt : IfStmt) -> (String, String) {
  let (condition_code, condition_temp) = llvm_gen_expr(gen, if_stmt.condition)
  let then_label = gen.next_label()
  let else_label = gen.next_label()
  let merge_label = gen.next_label()
  let cmp_temp = gen.next_temp()
  let mut code = condition_code
  code = code + "  " + cmp_temp + " = icmp ne i32 " + condition_temp + ", 0\n"
  code = code +
    "  br i1 " +
    cmp_temp +
    ", " +
    then_label +
    ", " +
    else_label +
    "\n"
  code = code + then_label + ":\n"
  let (then_code, _, then_last_temp) = llvm_gen_statements(
    gen,
    if_stmt.then_body,
    false,
  )
  code = code + then_code
  let then_result_temp = if then_last_temp != "" {
    then_last_temp
  } else {
    let temp = gen.next_temp()
    code = code + "  " + temp + " = add i32 0, 0\n"
    temp
  }
  code = code + "  br " + merge_label + "\n"
  code = code + else_label + ":\n"
  let else_result_temp = match if_stmt.else_keyword {
    Some(_) => {
      let (else_code, _, else_last_temp) = llvm_gen_statements(
        gen,
        if_stmt.else_body,
        false,
      )
      code = code + else_code
      if else_last_temp != "" {
        else_last_temp
      } else {
        let temp = gen.next_temp()
        code = code + "  " + temp + " = add i32 0, 0\n"
        temp
      }
    }
    None => {
      let temp = gen.next_temp()
      code = code + "  " + temp + " = add i32 0, 0\n"
      temp
    }
  }
  code = code + "  br " + merge_label + "\n"
  code = code + merge_label + ":\n"
  let result_temp = gen.next_temp()
  code = code +
    "  " +
    result_temp +
    " = phi i32 [ " +
    then_result_temp +
    ", " +
    then_label +
    " ], [ " +
    else_result_temp +
    ", " +
    else_label +
    " ]\n"
  (code, result_temp)
}

///|
fn llvm_gen_while(gen : LLVMGen, while_stmt : WhileStmt) -> (String, String) {
  let loop_entry_label = gen.next_label()
  let loop_body_label = gen.next_label()
  let loop_exit_label = gen.next_label()
  let mut code = ""
  code = code + loop_entry_label + ":\n"
  let (condition_code, condition_temp) = llvm_gen_expr(
    gen,
    while_stmt.condition,
  )
  code = code + condition_code
  let cmp_temp = gen.next_temp()
  code = code + "  " + cmp_temp + " = icmp ne i32 " + condition_temp + ", 0\n"
  code = code +
    "  br i1 " +
    cmp_temp +
    ", " +
    loop_body_label +
    ", " +
    loop_exit_label +
    "\n"
  code = code + loop_body_label + ":\n"
  let (body_code, _, _) = llvm_gen_statements(gen, while_stmt.body, false)
  code = code + body_code
  code = code + "  br " + loop_entry_label + "\n"
  code = code + loop_exit_label + ":\n"
  let last_temp = gen.next_temp()
  code = code + "  " + last_temp + " = add i32 0, 0\n"
  (code, last_temp)
}

///|
fn llvm_gen_return(gen : LLVMGen, return_stmt : ReturnStmt) -> (String, Bool) {
  match return_stmt.value {
    Some(expr) => {
      let (expr_code, temp) = llvm_gen_expr(gen, expr)
      let code = expr_code + "  ret i32 " + temp + "\n"
      (code, true)
    }
    None => ("  ret i32 0\n", true)
  }
}

///|
fn llvm_gen_expr(gen : LLVMGen, expr : Expr) -> (String, String) {
  match expr.kind {
    ExprKind::Literal(token) =>
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
        _ => {
          let temp = gen.next_temp()
          ("", temp)
        }
      }
    ExprKind::Ident(token) => {
      let var_name = gen.get_var_name(token.lexeme)
      if var_name == "" {
        let temp = gen.next_temp()
        ("", temp)
      } else {
        let temp = gen.next_temp()
        let code = "  " + temp + " = add i32 0, " + var_name + "\n"
        (code, temp)
      }
    }
    ExprKind::Unary(unary_expr) =>
      match unary_expr.operator.kind {
        TokenKind::Minus => {
          let (operand_code, operand_temp) = llvm_gen_expr(
            gen,
            unary_expr.operand,
          )
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
          let (operand_code, operand_temp) = llvm_gen_expr(
            gen,
            unary_expr.operand,
          )
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
    ExprKind::Binary(binary_expr) => {
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
    ExprKind::Call(call_expr) => {
      // Generate code for callee (should be an identifier)
      let (callee_code, _) = llvm_gen_expr(gen, call_expr.callee)
      // Generate code for arguments
      let mut args_code = ""
      let args_temps : Array[String] = Array::new()
      for arg in call_expr.arguments {
        let (arg_code, arg_temp) = llvm_gen_expr(gen, arg)
        args_code = args_code + arg_code
        args_temps.push(arg_temp)
      }
      // Build argument list
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
      // Generate function name from callee (assuming it's an identifier)
      let func_name = match call_expr.callee.kind {
        ExprKind::Ident(token) => "@" + token.lexeme
        _ => "@unknown"
      }
      // Generate call instruction
      let result_temp = gen.next_temp()
      let call_code = "  " +
        result_temp +
        " = call i32 " +
        func_name +
        "(" +
        (if args_temps.length() > 0 { "i32 " + args_list } else { "" }) +
        ")\n"
      let code = callee_code + args_code + call_code
      (code, result_temp)
    }
    ExprKind::ArrayLiteral(_array_lit) => {
      // For now, we'll generate a simple placeholder
      // In a full implementation, we'd allocate memory and store elements
      let temp = gen.next_temp()
      let code = "  " + temp + " = add i32 0, 0\n" // Placeholder
      (code, temp)
    }
    ExprKind::Index(index_expr) => {
      // Generate code for array and index
      let (array_code, _array_temp) = llvm_gen_expr(gen, index_expr.array)
      let (index_code, _index_temp) = llvm_gen_expr(gen, index_expr.index)
      // For now, we'll generate a simple placeholder
      // In a full implementation, we'd use getelementptr to access array elements
      let temp = gen.next_temp()
      let code = array_code + index_code + "  " + temp + " = add i32 0, 0\n" // Placeholder
      (code, temp)
    }
    ExprKind::TupleLiteral(tuple_lit) => {
      // Generate code for all tuple elements
      let mut code = ""
      let element_temps : Array[String] = Array::new()
      for element in tuple_lit.elements {
        let (element_code, element_temp) = llvm_gen_expr(gen, element)
        code = code + element_code
        element_temps.push(element_temp)
      }
      // For now, we'll return the first element's temp as a placeholder
      // In a full implementation, we'd create a struct or use multiple return values
      let temp = if element_temps.length() > 0 {
        element_temps[0]
      } else {
        let placeholder = gen.next_temp()
        code = code + "  " + placeholder + " = add i32 0, 0\n"
        placeholder
      }
      (code, temp)
    }
    _ => {
      let temp = gen.next_temp()
      ("", temp)
    }
  }
}

///|
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
fn generate_asm(statements : Array[Stmt]) -> String {
  let mut output = ".text\n"
  output = output + ".globl main\n"
  output = output + "main:\n"
  let mut emitted = false
  for stmt in statements {
    if emitted {
      continue
    }
    match stmt.kind {
      StmtKind::ExprStmt(expr) => {
        output = output + asm_return_from_expr(expr)
        emitted = true
      }
      StmtKind::Return(return_stmt) => {
        output = output + asm_return_from_optional(return_stmt.value)
        emitted = true
      }
      StmtKind::Function(function_stmt) =>
        for body_stmt in function_stmt.body {
          if emitted {
            break
          }
          match body_stmt.kind {
            StmtKind::Return(return_stmt) => {
              output = output + asm_return_from_optional(return_stmt.value)
              emitted = true
            }
            StmtKind::ExprStmt(expr) => {
              output = output + asm_return_from_expr(expr)
              emitted = true
            }
            _ => ()
          }
        }
      _ => ()
    }
  }
  if !emitted {
    output = output + "  li a0, 0\n"
    output = output + "  ret\n"
  }
  output
}

///|
fn literal_int_value(expr : Expr) -> String? {
  match expr.kind {
    ExprKind::Literal(token) =>
      match token.kind {
        TokenKind::LiteralInt => Some(token.lexeme)
        _ => None
      }
    ExprKind::Unary(unary_expr) =>
      match unary_expr.operator.kind {
        TokenKind::Minus =>
          match unary_expr.operand.kind {
            ExprKind::Literal(token) =>
              match token.kind {
                TokenKind::LiteralInt => Some("-" + token.lexeme)
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn asm_return_from_expr(expr : Expr) -> String {
  match literal_int_value(expr) {
    Some(value) => "  li a0, " + value + "\n  ret\n"
    None => "  li a0, 0\n  ret\n"
  }
}

///|
fn asm_return_from_optional(value : Expr?) -> String {
  match value {
    Some(expr) => asm_return_from_expr(expr)
    None => "  li a0, 0\n  ret\n"
  }
}
