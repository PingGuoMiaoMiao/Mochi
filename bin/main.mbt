///|
fn read_emit_format() -> @frontend.EmitFormat {
  // Try to read minimoonbit.json, but it's optional
  let content_opt : String? = Some(@fs.read_file_to_string("minimoonbit.json")) catch {
    IOError(_) => None
  }
  return match content_opt {
    Some(content) =>
      if content.contains("\"emit\": \"asm\"") ||
        content.contains("\"emit\":\"asm\"") {
        @frontend.emit_format_asm()
      } else {
        @frontend.emit_format_llvm()
      }
    None => @frontend.emit_format_llvm()
  }
}

///|
fn read_source_or_exit(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    IOError(_) => {
      println("Error: no such file")
      @sys.exit(1)
      ""
    }
  }
}

///|
fn write_output_or_exit(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    IOError(message) => {
      println("Failed to write output file: " + message)
      @sys.exit(1)
    }
  }
}

///|
fn run_frontend_pipeline(source : String) -> Array[@frontend.Stmt]? {
  let lex_result = @frontend.tokenize(source)
  if lex_result.errors.length() > 0 {
    println(
      "Lexing failed with " +
      lex_result.errors.length().to_string() +
      " error(s).",
    )
    for err in lex_result.errors {
      println(err.message)
    }
    return None
  }
  println(
    "Lexing succeeded with " +
    lex_result.tokens.length().to_string() +
    " token(s).",
  )
  let parse_result = @frontend.parse(lex_result.tokens)
  if parse_result.errors.length() > 0 {
    println(
      "Parsing failed with " +
      parse_result.errors.length().to_string() +
      " error(s).",
    )
    for err in parse_result.errors {
      println(
        "Parse error: " + err.message + " (near " + err.token.lexeme + ")",
      )
    }
    return None
  }
  println(
    "Parsing succeeded with " +
    parse_result.declarations.length().to_string() +
    " top-level node(s).",
  )
  let tyck_result = @frontend.analyze(parse_result.declarations)
  if tyck_result.errors.length() > 0 {
    println(
      "Type checking failed with " +
      tyck_result.errors.length().to_string() +
      " error(s).",
    )
    for err in tyck_result.errors {
      println("Type error: " + err.message)
    }
    return None
  }
  println("Type checking succeeded.")
  Some(parse_result.declarations)
}

///|
fn print_usage(message : String?) -> Unit {
  match message {
    Some(text) => println("Error: " + text)
    None => ()
  }
  println("Usage:")
  println("  moon run bin/main.mbt -- --typecheck <input.mbt>")
  println("  moon run bin/main.mbt -- <input.mbt> -o <output_file>")
  @sys.exit(1)
}

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() == 0 {
    print_usage(None)
  }
  // Skip the first argument if it's the program name (ends with .wasm or is an executable path)
  let mut start_index = 0
  if args.length() > 0 {
    let first_arg = args[0]
    // Check if first argument looks like a program name (ends with .wasm, .exe, or contains /bin/ or bin.wasm)
    if first_arg.has_suffix(".wasm") ||
      first_arg.has_suffix(".exe") ||
      first_arg.contains("/bin/") ||
      first_arg.contains("\\bin\\") ||
      first_arg.contains("bin.wasm") {
      start_index = 1
    }
  }
  // Adjust start_index if we have no real arguments left
  if start_index >= args.length() {
    print_usage(None)
  }
  // Handle --typecheck mode
  if args[start_index] == "--typecheck" {
    if start_index + 1 >= args.length() {
      print_usage(Some("Missing input file for --typecheck."))
    }
    let input_file = args[start_index + 1]
    let source = read_source_or_exit(input_file)
    match run_frontend_pipeline(source) {
      Some(_) => ()
      None => @sys.exit(1)
    }
    return
  }
  // Handle compilation mode
  let mut index = start_index
  if args[start_index] == "--compile" {
    if start_index + 1 >= args.length() {
      print_usage(Some("Missing input file for compilation."))
    }
    index = start_index + 1
  }
  if index >= args.length() {
    print_usage(Some("Missing input file for compilation."))
  }
  let mut input_path : String? = None
  let mut output_path : String? = None
  while index < args.length() {
    let arg = args[index]
    if arg == "-o" {
      index = index + 1
      if index >= args.length() {
        print_usage(Some("Missing output file after -o."))
      }
      output_path = Some(args[index])
    } else {
      match input_path {
        Some(_) => print_usage(Some("Unexpected argument: " + arg))
        None => input_path = Some(arg)
      }
    }
    index = index + 1
  }
  match input_path {
    Some(_) => ()
    None => print_usage(Some("Missing input file for compilation."))
  }
  match output_path {
    Some(_) => ()
    None =>
      print_usage(Some("Missing -o <output_file> argument for compilation."))
  }
  let input_file = match input_path {
    Some(path) => path
    None => ""
  }
  let output_file = match output_path {
    Some(path) => path
    None => ""
  }
  let source = read_source_or_exit(input_file)
  match run_frontend_pipeline(source) {
    Some(declarations) => {
      let emit_format = read_emit_format()
      let codegen_result = @frontend.codegen(declarations, emit_format)
      if codegen_result.errors.length() > 0 {
        println(
          "Code generation failed with " +
          codegen_result.errors.length().to_string() +
          " error(s).",
        )
        for err in codegen_result.errors {
          println("Codegen error: " + err)
        }
        @sys.exit(1)
      }
      write_output_or_exit(output_file, codegen_result.code)
      println(
        "Code generation succeeded. Output written to " + output_file + ".",
      )
    }
    None => @sys.exit(1)
  }
}
