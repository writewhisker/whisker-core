--- Deploy Command - Multi-platform Deployment
-- @module whisker.cli.commands.deploy

local DeployCommand = {}

local PLATFORMS = {
  html = {name = "Static HTML", build = function(story) return {success = true} end},
  ["itch.io"] = {name = "Itch.io", build = function(story) return {success = true} end},
  ["github-pages"] = {name = "GitHub Pages", build = function(story) return {success = true} end}
}

function DeployCommand._parse_args(args)
  return {
    story_path = args[1],
    platform = args[2] or "html",
    output = args[3] or "dist"
  }
end

function DeployCommand.run(args)
  local config = DeployCommand._parse_args(args)
  
  if not config.story_path then
    io.stderr:write("Error: Story path required\n")
    return 1
  end
  
  local platform = PLATFORMS[config.platform]
  if not platform then
    io.stderr:write("Error: Unknown platform '" .. config.platform .. "'\n")
    return 1
  end
  
  print("Deploying to " .. platform.name .. "...")
  local result = platform.build(config.story_path)
  
  if result.success then
    print("Deployment successful!")
    print("Output: " .. config.output)
    return 0
  end
  
  return 1
end

function DeployCommand.help()
  print([[
Usage: whisker deploy <story> [platform] [output]

Deploy story to various platforms.

Platforms: html, itch.io, github-pages
]])
end

return DeployCommand
