-- Whisker Script Compiler CLI
-- Command-line tool for compiling .ws files to Lua
--
-- lib/whisker/tools/whiskerc/init.lua

--------------------------------------------------------------------------------
-- CLI Module
--------------------------------------------------------------------------------

local CLI = {}

--- Version information
CLI.VERSION = "1.0.0"
CLI.NAME = "whiskerc"

--------------------------------------------------------------------------------
-- Dependencies (lazily loaded)
--------------------------------------------------------------------------------

local _lexer_module = nil
local _parser_module = nil
local _compiler_module = nil
local _errors_module = nil

--- Get lexer module (lazy load)
local function get_lexer_module()
  if not _lexer_module then
    local ok, mod = pcall(require, "whisker.script.lexer")
    if ok then _lexer_module = mod end
  end
  return _lexer_module
end

--- Get parser module (lazy load)
local function get_parser_module()
  if not _parser_module then
    local ok, mod = pcall(require, "whisker.script.parser")
    if ok then _parser_module = mod end
  end
  return _parser_module
end

--- Get compiler module (lazy load)
local function get_compiler_module()
  if not _compiler_module then
    local ok, mod = pcall(require, "whisker.script.compiler")
    if ok then _compiler_module = mod end
  end
  return _compiler_module
end

--- Get errors module (lazy load)
local function get_errors_module()
  if not _errors_module then
    local ok, mod = pcall(require, "whisker.script.errors")
    if ok then _errors_module = mod end
  end
  return _errors_module
end

--- Create a new CLI instance with optional container
-- @param container table|nil DI container for resolving dependencies
-- @return table CLI instance
function CLI.new(container)
  local instance = {
    _container = container,
    _lexer_module = nil,
    _parser_module = nil,
    _compiler_module = nil,
    _errors_module = nil,
  }
  setmetatable(instance, { __index = CLI })

  -- If container provided, try to resolve dependencies
  if container then
    if container:has("lexer") then
      instance._lexer_module = container:resolve("lexer")
    end
    if container:has("parser") then
      instance._parser_module = container:resolve("parser")
    end
    if container:has("compiler") then
      instance._compiler_module = container:resolve("compiler")
    end
    if container:has("script_errors") then
      instance._errors_module = container:resolve("script_errors")
    end
  end

  return instance
end

--- Get or lazy load lexer module
function CLI:get_lexer_module()
  return self._lexer_module or get_lexer_module()
end

--- Get or lazy load parser module
function CLI:get_parser_module()
  return self._parser_module or get_parser_module()
end

--- Get or lazy load compiler module
function CLI:get_compiler_module()
  return self._compiler_module or get_compiler_module()
end

--- Get or lazy load errors module
function CLI:get_errors_module()
  return self._errors_module or get_errors_module()
end

--------------------------------------------------------------------------------
-- File I/O
--------------------------------------------------------------------------------

--- Read a file
---@param path string File path
---@return string|nil contents, string|nil error
local function read_file(path)
  local file, err = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. path .. (err and (" (" .. err .. ")") or "")
  end

  local contents = file:read("*all")
  file:close()
  return contents
end

--- Write a file
---@param path string File path
---@param contents string File contents
---@return boolean success, string|nil error
local function write_file(path, contents)
  local file, err = io.open(path, "w")
  if not file then
    return false, "Cannot write file: " .. path .. (err and (" (" .. err .. ")") or "")
  end

  file:write(contents)
  file:close()
  return true
end

--- Check if file exists
---@param path string File path
---@return boolean
local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Compilation
--------------------------------------------------------------------------------

--- Compile a single file (static method for backward compatibility)
---@param input_path string Input file path
---@param output_path string|nil Output file path (nil = stdout)
---@param options table Options {verbose, quiet, force, optimize}
---@return boolean success
function CLI.compile_file(input_path, output_path, options)
  -- Use static lazy loading for backward compatibility
  local LexerModule = get_lexer_module()
  local Parser = get_parser_module()
  local Compiler = get_compiler_module()
  local Errors = get_errors_module()

  if not LexerModule or not Parser or not Compiler or not Errors then
    print("Error: Script modules not available")
    return false
  end

  local Lexer = LexerModule.Lexer
  options = options or {}

  -- Read source
  local source, err = read_file(input_path)
  if not source then
    if not options.quiet then
      print("Error: " .. err)
    end
    return false
  end

  -- Lex
  if options.verbose then
    print("Lexing " .. input_path .. "...")
  end

  local lexer = Lexer.new(source, input_path)
  local tokens = lexer:tokenize()

  -- Check for lexer errors
  local has_errors = false
  for _, token in ipairs(tokens) do
    if token.type == "ERROR" then
      local formatted = Errors.format_error({
        message = token.value,
        line = token.line,
        column = token.column
      }, source, input_path)
      print(formatted)
      has_errors = true
    end
  end

  if has_errors and not options.force then
    if not options.quiet then
      print("\nCompilation failed due to lexer errors.")
    end
    return false
  end

  -- Parse
  if options.verbose then
    print("Parsing...")
  end

  local parser = Parser.new(tokens, input_path)
  local ast = parser:parse_with_recovery()

  -- Add suggestions to errors
  ast.errors = Errors.add_suggestions(ast.errors or {})

  -- Report parse errors
  for _, error_info in ipairs(ast.errors or {}) do
    local formatted = Errors.format_error(error_info, source, input_path)
    print(formatted)
    has_errors = true
  end

  -- Semantic validation
  local validation_errors = Errors.validate(ast)
  for _, error_info in ipairs(validation_errors) do
    local formatted = Errors.format_error(error_info, source, input_path)
    print(formatted)
    has_errors = true
  end

  if has_errors and not options.force then
    if not options.quiet then
      print("\n" .. Errors.format_summary(ast.errors or {}))
      print("Compilation failed.")
    end
    return false
  end

  -- Optimize
  local compiler = Compiler.new()

  if options.optimize then
    if options.verbose then
      print("Optimizing...")
    end
    ast = compiler:optimize(ast)
  end

  -- Compile
  if options.verbose then
    print("Generating Lua code...")
  end

  local lua_code = compiler:compile(ast)

  -- Write output
  if output_path then
    local ok, write_err = write_file(output_path, lua_code)
    if not ok then
      if not options.quiet then
        print("Error: " .. write_err)
      end
      return false
    end

    if not options.quiet then
      print("Compiled: " .. input_path .. " -> " .. output_path)
    end
  else
    -- Print to stdout
    print(lua_code)
  end

  return true
end

--- Compile multiple files
---@param input_paths table Array of input paths
---@param output_dir string|nil Output directory
---@param options table Options
---@return number success_count, number error_count
function CLI.compile_files(input_paths, output_dir, options)
  local success_count = 0
  local error_count = 0

  for _, input_path in ipairs(input_paths) do
    local output_path = nil

    if output_dir then
      -- Generate output path from input
      local basename = input_path:match("([^/\\]+)%.ws$") or input_path:match("([^/\\]+)$")
      output_path = output_dir .. "/" .. basename .. ".lua"
    end

    if CLI.compile_file(input_path, output_path, options) then
      success_count = success_count + 1
    else
      error_count = error_count + 1
    end
  end

  return success_count, error_count
end

--------------------------------------------------------------------------------
-- Watch Mode
--------------------------------------------------------------------------------

--- Watch a file for changes and recompile
---@param input_path string Input file path
---@param output_path string Output file path
---@param options table Options
function CLI.watch(input_path, output_path, options)
  print("Watching " .. input_path .. " for changes...")
  print("Press Ctrl+C to stop\n")

  -- Initial compile
  CLI.compile_file(input_path, output_path, options)

  -- Get initial modification time
  local function get_mtime(path)
    local file = io.popen("stat -f %m " .. path .. " 2>/dev/null || stat -c %Y " .. path .. " 2>/dev/null")
    if file then
      local mtime = file:read("*a")
      file:close()
      return tonumber(mtime) or 0
    end
    return 0
  end

  local last_mtime = get_mtime(input_path)

  -- Poll for changes
  while true do
    -- Sleep for 1 second
    os.execute("sleep 1")

    local current_mtime = get_mtime(input_path)

    if current_mtime > last_mtime then
      print("\nChange detected, recompiling...")
      CLI.compile_file(input_path, output_path, options)
      last_mtime = current_mtime
    end
  end
end

--------------------------------------------------------------------------------
-- Check Mode
--------------------------------------------------------------------------------

--- Check syntax without generating output (static method for backward compatibility)
---@param input_path string Input file path
---@param options table Options
---@return boolean valid
function CLI.check(input_path, options)
  -- Use static lazy loading for backward compatibility
  local LexerModule = get_lexer_module()
  local Parser = get_parser_module()
  local Errors = get_errors_module()

  if not LexerModule or not Parser or not Errors then
    print("Error: Script modules not available")
    return false
  end

  local Lexer = LexerModule.Lexer
  options = options or {}

  local source, err = read_file(input_path)
  if not source then
    print("Error: " .. err)
    return false
  end

  if options.verbose then
    print("Checking " .. input_path .. "...")
  end

  -- Lex
  local lexer = Lexer.new(source, input_path)
  local tokens = lexer:tokenize()

  local error_count = 0

  for _, token in ipairs(tokens) do
    if token.type == "ERROR" then
      local formatted = Errors.format_error({
        message = token.value,
        line = token.line,
        column = token.column
      }, source, input_path)
      print(formatted)
      error_count = error_count + 1
    end
  end

  -- Parse
  local parser = Parser.new(tokens, input_path)
  local ast = parser:parse_with_recovery()

  ast.errors = Errors.add_suggestions(ast.errors or {})

  for _, error_info in ipairs(ast.errors or {}) do
    local formatted = Errors.format_error(error_info, source, input_path)
    print(formatted)
    error_count = error_count + 1
  end

  -- Semantic validation
  local validation_errors = Errors.validate(ast)
  for _, error_info in ipairs(validation_errors) do
    local formatted = Errors.format_error(error_info, source, input_path)
    print(formatted)
    error_count = error_count + 1
  end

  if error_count == 0 then
    if not options.quiet then
      print(input_path .. ": OK")
    end
    return true
  else
    if not options.quiet then
      print("\n" .. Errors.format_summary(ast.errors or {}))
    end
    return false
  end
end

--------------------------------------------------------------------------------
-- Command Line Interface
--------------------------------------------------------------------------------

--- Print usage information
function CLI.print_help()
  print([[
Whisker Script Compiler (whiskerc) v]] .. CLI.VERSION .. [[


Usage:
  whiskerc compile <input.ws> [-o output.lua] [options]
  whiskerc check <input.ws> [options]
  whiskerc watch <input.ws> -o <output.lua> [options]
  whiskerc version
  whiskerc help

Commands:
  compile     Compile a .ws file to Lua
  check       Check syntax without generating output
  watch       Watch file for changes and recompile
  version     Show version information
  help        Show this help message

Options:
  -o FILE          Write output to FILE
  -v, --verbose    Verbose output
  -q, --quiet      Quiet mode (errors only)
  --force          Compile even with errors
  --optimize       Enable optimizations

Examples:
  whiskerc compile story.ws -o story.lua
  whiskerc compile story.ws                     # Print to stdout
  whiskerc check story.ws                       # Syntax check only
  whiskerc watch story.ws -o story.lua          # Recompile on changes
  whiskerc compile story.ws -o story.lua --optimize
]])
end

--- Print version information
function CLI.print_version()
  print(CLI.NAME .. " " .. CLI.VERSION)
  print("Whisker Script Compiler")
  print("Part of whisker-core")
end

--- Parse command line arguments
---@param args table Command line arguments
---@return string|nil command, table parsed
local function parse_args(args)
  local command = args[1]
  local parsed = {
    inputs = {},
    output = nil,
    verbose = false,
    quiet = false,
    force = false,
    optimize = false,
  }

  local i = 2
  while i <= #args do
    local arg = args[i]

    if arg == "-o" or arg == "--output" then
      parsed.output = args[i + 1]
      i = i + 2
    elseif arg == "-v" or arg == "--verbose" then
      parsed.verbose = true
      i = i + 1
    elseif arg == "-q" or arg == "--quiet" then
      parsed.quiet = true
      i = i + 1
    elseif arg == "--force" then
      parsed.force = true
      i = i + 1
    elseif arg == "--optimize" then
      parsed.optimize = true
      i = i + 1
    elseif arg:sub(1, 1) ~= "-" then
      table.insert(parsed.inputs, arg)
      i = i + 1
    else
      print("Unknown option: " .. arg)
      i = i + 1
    end
  end

  return command, parsed
end

--- Main entry point
---@param args table Command line arguments
---@return boolean success
function CLI.main(args)
  local command, parsed = parse_args(args)

  if command == "compile" then
    if #parsed.inputs == 0 then
      print("Error: No input file specified")
      print("Usage: whiskerc compile <input.ws> [-o output.lua]")
      return false
    end

    local input = parsed.inputs[1]
    return CLI.compile_file(input, parsed.output, {
      verbose = parsed.verbose,
      quiet = parsed.quiet,
      force = parsed.force,
      optimize = parsed.optimize,
    })

  elseif command == "check" then
    if #parsed.inputs == 0 then
      print("Error: No input file specified")
      print("Usage: whiskerc check <input.ws>")
      return false
    end

    local all_ok = true
    for _, input in ipairs(parsed.inputs) do
      if not CLI.check(input, {
        verbose = parsed.verbose,
        quiet = parsed.quiet,
      }) then
        all_ok = false
      end
    end
    return all_ok

  elseif command == "watch" then
    if #parsed.inputs == 0 then
      print("Error: No input file specified")
      print("Usage: whiskerc watch <input.ws> -o <output.lua>")
      return false
    end

    if not parsed.output then
      print("Error: Output file required for watch mode")
      print("Usage: whiskerc watch <input.ws> -o <output.lua>")
      return false
    end

    CLI.watch(parsed.inputs[1], parsed.output, {
      verbose = parsed.verbose,
      quiet = parsed.quiet,
      force = parsed.force,
      optimize = parsed.optimize,
    })
    return true  -- watch runs forever

  elseif command == "version" then
    CLI.print_version()
    return true

  elseif command == "help" or command == nil then
    CLI.print_help()
    return true

  else
    print("Unknown command: " .. command)
    print("Run 'whiskerc help' for usage")
    return false
  end
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return CLI
