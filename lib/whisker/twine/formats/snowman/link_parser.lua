--- Snowman link parser
-- Parses <a data-passage="..."> links
--
-- lib/whisker/twine/formats/snowman/link_parser.lua

local LinkParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Link Extraction
--------------------------------------------------------------------------------

--- Extract links from HTML content
---@param html_content string HTML content
---@return table Array of link info tables
function LinkParser.parse_links(html_content)
  local links = {}

  -- Pattern: <a href="..." data-passage="PassageName">Text</a>
  for link_html in html_content:gmatch("<a[^>]*data%-passage=[^>]*>.-</a>") do
    local passage_name = link_html:match('data%-passage%s*=%s*["\']([^"\']+)["\']')
    local link_text = link_html:match(">([^<]+)</a>")

    if passage_name and link_text then
      table.insert(links, {
        text = link_text,
        destination = passage_name
      })
    end
  end

  return links
end

--------------------------------------------------------------------------------
-- Link Replacement
--------------------------------------------------------------------------------

--- Replace Snowman links with WhiskerScript choices in content
---@param html_content string HTML content
---@return table Array of AST nodes
function LinkParser.replace_links_with_choices(html_content)
  local ast_nodes = {}

  -- Split content by links
  local pos = 1

  while pos <= #html_content do
    local link_start = html_content:find("<a[^>]*data%-passage=", pos)

    if not link_start then
      -- No more links, add remaining text
      local text = html_content:sub(pos)
      if text ~= "" and not text:match("^%s*$") then
        table.insert(ast_nodes, ASTBuilder.create_text(text))
      end
      break
    end

    -- Add text before link
    if link_start > pos then
      local text = html_content:sub(pos, link_start - 1)
      if text ~= "" and not text:match("^%s*$") then
        table.insert(ast_nodes, ASTBuilder.create_text(text))
      end
    end

    -- Find end of link tag
    local link_end = html_content:find("</a>", link_start)

    if not link_end then
      -- Malformed link
      local remaining = html_content:sub(pos)
      if remaining ~= "" then
        table.insert(ast_nodes, ASTBuilder.create_text(remaining))
      end
      break
    end

    local link_html = html_content:sub(link_start, link_end + 3)

    -- Parse link
    local passage_name = link_html:match('data%-passage%s*=%s*["\']([^"\']+)["\']')
    local link_text = link_html:match(">([^<]+)</a>")

    if passage_name and link_text then
      -- Create choice node
      table.insert(ast_nodes, ASTBuilder.create_choice(link_text, {}, passage_name))
    end

    pos = link_end + 4
  end

  return ast_nodes
end

--- Check if content contains Snowman data-passage links
---@param html_content string HTML content
---@return boolean True if contains data-passage links
function LinkParser.has_data_passage_links(html_content)
  return html_content:find("data%-passage=") ~= nil
end

return LinkParser
