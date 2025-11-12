///|
fn read_emit_format() -> @frontend.EmitFormat {
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
    IOError(message) => {
      println("Failed to read file: " + message)
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
  println("  moon run src/bin/main.mbt -- --typecheck <input.mbt>")
  println("  moon run src/bin/main.mbt -- <input.mbt> -o <output_file>")
  @sys.exit(1)
}

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage(None)
  }
  if args[1] == "--typecheck" {
    if args.length() < 3 {
      print_usage(Some("Missing input file for --typecheck."))
    }
    let input_file = args[2]
    let source = read_source_or_exit(input_file)
    match run_frontend_pipeline(source) {
      Some(_) => ()
      None => @sys.exit(1)
    }
    return
  }
  let mut index = 1
  if args[1] == "--compile" {
    index = 2
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
