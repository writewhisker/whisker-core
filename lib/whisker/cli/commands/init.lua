--- Init Command - Project Scaffolding
-- @module whisker.cli.commands.init
-- @author Whisker Development Team
-- @license MIT

local lfs = require("lfs")
local json = require("whisker.utils.json")

local InitCommand = {}

--- Project templates
local TEMPLATES = {
  basic = {
    name = "Basic Story",
    description = "Simple interactive story template",
    files = {
      ["story.json"] = function(name)
        return json.encode({
          name = name,
          startPassage = "Start",
          passages = {
            {
              name = "Start",
              text = "Welcome to your story!\n\n[[Continue->Next]]"
            },
            {
              name = "Next",
              text = "This is your second passage.\n\nThe End."
            }
          }
        }, true)
      end,
      ["README.md"] = function(name)
        return string.format([[# %s

An interactive fiction story created with Whisker.

## Getting Started

```bash
whisker serve story.json
```

## Development

Edit `story.json` to modify your story.

The dev server provides hot reload for instant updates.
]], name)
      end,
      [".gitignore"] = function()
        return [[.whisker-cache/
*.swp
*.tmp
.DS_Store
]]
      end
    }
  },
  tutorial = {
    name = "Tutorial Story",
    description = "Interactive tutorial with examples",
    files = {
      ["story.json"] = function(name)
        return json.encode({
          name = name,
          startPassage = "Tutorial",
          passages = {
            {
              name = "Tutorial",
              text = "# Whisker Tutorial\n\nLearn the basics:\n\n[[Variables->VarExample]]\n[[Choices->ChoiceExample]]"
            }
          }
        }, true)
      end
    }
  }
}

--- Parse arguments
function InitCommand._parse_args(args)
  local config = {
    name = nil,
    template = "basic",
    directory = nil,
    force = false
  }
  
  local i = 1
  while i <= #args do
    local arg = args[i]
    
    if arg == "--template" or arg == "-t" then
      i = i + 1
      config.template = args[i]
    elseif arg == "--force" or arg == "-f" then
      config.force = true
    elseif not arg:match("^%-") then
      if not config.name then
        config.name = arg
      else
        config.directory = arg
      end
    end
    
    i = i + 1
  end
  
  return config
end

--- Create project
function InitCommand.run(args)
  local config = InitCommand._parse_args(args)
  
  if not config.name then
    io.stderr:write("Error: Project name required\n")
    io.stderr:write("Usage: whisker init <name> [options]\n")
    return 1
  end
  
  local dir = config.directory or config.name
  local template = TEMPLATES[config.template]
  
  if not template then
    io.stderr:write("Error: Unknown template '" .. config.template .. "'\n")
    return 1
  end
  
  -- Check if directory exists
  local attr = lfs.attributes(dir)
  if attr and not config.force then
    io.stderr:write("Error: Directory '" .. dir .. "' already exists\n")
    io.stderr:write("Use --force to overwrite\n")
    return 1
  end
  
  -- Create directory
  local success, err = lfs.mkdir(dir)
  if not success and not attr then
    io.stderr:write("Error creating directory: " .. tostring(err) .. "\n")
    return 1
  end
  
  -- Create files from template
  print("Creating project '" .. config.name .. "' in '" .. dir .. "'...")
  
  for filename, generator in pairs(template.files) do
    local filepath = dir .. "/" .. filename
    local content = generator(config.name)
    
    local file, file_err = io.open(filepath, "w")
    if not file then
      io.stderr:write("Error creating " .. filename .. ": " .. tostring(file_err) .. "\n")
      return 1
    end
    
    file:write(content)
    file:close()
    
    print("  Created " .. filename)
  end
  
  print("\nProject created successfully!")
  print("\nNext steps:")
  print("  cd " .. dir)
  print("  whisker serve story.json")
  
  return 0
end

function InitCommand.help()
  print([[
Usage: whisker init <name> [directory] [options]

Initialize a new Whisker project with scaffolding.

Arguments:
  <name>              Project name
  [directory]         Target directory (defaults to project name)

Options:
  --template, -t <name>  Template to use (default: basic)
  --force, -f            Overwrite existing directory

Available templates:
  basic       Simple interactive story
  tutorial    Tutorial with examples

Examples:
  whisker init my-story
  whisker init my-story --template tutorial
  whisker init my-story ./projects/story --force
]])
end

return InitCommand
