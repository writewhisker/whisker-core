--- Static Site Exporter
-- Export stories as multi-page static HTML sites
-- @module whisker.export.static.static_exporter
-- @author Whisker Core Team
-- @license MIT
--
-- Exports stories as complete static websites with:
-- - Individual HTML pages for each passage
-- - Navigation and back button support
-- - Save/load game functionality
-- - Theme switching (light/dark)
-- - CSS custom properties for styling

local ExportUtils = require("whisker.export.utils")

local StaticExporter = {}
StaticExporter.__index = StaticExporter
StaticExporter._dependencies = {}

--- Create a new Static Site exporter instance
-- @param deps table Optional dependencies
-- @return StaticExporter A new exporter
function StaticExporter.new(deps)
  deps = deps or {}
  local self = setmetatable({}, StaticExporter)
  return self
end

--- Get exporter metadata
-- @return table Metadata
function StaticExporter:metadata()
  return {
    format = "static",
    version = "1.0.0",
    description = "Multi-page static HTML site export",
    file_extension = ".html",
    mime_type = "text/html",
  }
end

--- Check if story can be exported
-- @param story table Story data
-- @param options table Export options
-- @return boolean, string Whether export is possible and any error
function StaticExporter:can_export(story, options)
  if not story then
    return false, "No story provided"
  end
  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end
  return true
end

--- Export story to static site
-- @param story table Story data
-- @param options table Export options:
--   - multi_page: boolean (multi-page vs single page, default false)
--   - include_save: boolean (include save/load, default true)
--   - include_theme: boolean (include theme toggle, default true)
--   - include_back: boolean (include back button, default true)
--   - theme: string ("light", "dark", "auto", default "auto")
--   - site_url: string (base URL for sitemap/SEO, default "/")
--   - include_sitemap: boolean (generate sitemap.xml, default true with multi_page)
--   - include_robots: boolean (generate robots.txt, default true with multi_page)
--   - include_404: boolean (generate 404.html, default true with multi_page)
--   - include_seo: boolean (include OG tags, JSON-LD, default true)
-- @return table Export bundle with files, manifest
function StaticExporter:export(story, options)
  options = options or {}
  local warnings = {}

  local multi_page = options.multi_page == true
  local include_save = options.include_save ~= false
  local include_theme = options.include_theme ~= false
  local include_back = options.include_back ~= false
  local theme = options.theme or "auto"
  local site_url = options.site_url or "/"
  local include_sitemap = options.include_sitemap ~= false and multi_page
  local include_robots = options.include_robots ~= false and multi_page
  local include_404 = options.include_404 ~= false and multi_page
  local include_seo = options.include_seo ~= false

  -- Generate HTML
  local title = story.name or story.title or "Interactive Story"
  local description = story.description or "An interactive story"
  local author = story.author or ""

  local files = {}

  if multi_page then
    -- Multi-page mode: generate one HTML file per passage
    files = self:generate_multi_page_site(story, {
      include_save = include_save,
      include_theme = include_theme,
      include_back = include_back,
      theme = theme,
      include_seo = include_seo,
      site_url = site_url,
      author = author,
    })

    -- Add sitemap.xml
    if include_sitemap then
      files["sitemap.xml"] = self:generate_sitemap(story, site_url)
    end

    -- Add robots.txt
    if include_robots then
      files["robots.txt"] = self:generate_robots(site_url)
    end

    -- Add 404.html
    if include_404 then
      files["404.html"] = self:generate_404_page(title, description)
    end
  else
    -- Single-page mode (default)
    local story_json = self:serialize_story(story)
    local html = self:generate_html(story_json, title, description, {
      include_save = include_save,
      include_theme = include_theme,
      include_back = include_back,
      theme = theme,
      include_seo = include_seo,
      author = author,
      site_url = site_url,
    })
    files["index.html"] = html
  end

  -- Generate filename
  local safe_title = title:lower():gsub("[^%w]", "_")
  local filename = multi_page and (safe_title .. "_site.zip") or (safe_title .. ".html")

  return {
    content = files["index.html"],
    files = files,
    assets = {},
    manifest = {
      format = "static",
      story_name = story.name or story.title or "Untitled",
      passage_count = #story.passages,
      file_count = 0, -- Will be counted externally
      exported_at = os.time(),
      filename = filename,
      multi_page = multi_page,
      include_save = include_save,
      include_theme = include_theme,
    },
    warnings = #warnings > 0 and warnings or nil,
  }
end

--- Serialize story to JSON string
-- @param story table Story data
-- @return string JSON string
function StaticExporter:serialize_story(story)
  local serialized = {
    title = story.title or story.name or "Untitled",
    author = story.author or "Anonymous",
    startPassage = story.start_passage or story.start or "Start",
    ifid = story.ifid,
    metadata = {
      title = story.title or story.name,
      description = story.description,
      author = story.author,
    },
    variables = self:serialize_variables(story.variables or {}),
    passages = self:serialize_passages(story.passages or {}),
  }

  return self:to_json(serialized)
end

--- Serialize variables
-- @param variables table Variables table
-- @return table Serialized variables
function StaticExporter:serialize_variables(variables)
  local result = {}
  if type(variables) == "table" then
    for name, var in pairs(variables) do
      if type(var) == "table" then
        table.insert(result, {
          name = name,
          default = var.default or var.initial or var.value,
        })
      else
        table.insert(result, {
          name = name,
          default = var,
        })
      end
    end
  end
  return result
end

--- Serialize passages array
-- @param passages table Array of passages
-- @return table Serialized passages
function StaticExporter:serialize_passages(passages)
  local result = {}
  for _, passage in ipairs(passages) do
    table.insert(result, {
      id = passage.id or passage.name,
      title = passage.title or passage.name or "Untitled",
      name = passage.name or passage.id,
      content = passage.text or passage.content or "",
      tags = passage.tags,
      choices = self:serialize_choices(passage.choices or passage.links or {}),
    })
  end
  return result
end

--- Serialize choices array
-- @param choices table Array of choices
-- @return table Serialized choices
function StaticExporter:serialize_choices(choices)
  local result = {}
  for _, choice in ipairs(choices) do
    table.insert(result, {
      text = choice.text or choice.label or "",
      target = choice.target or choice.passage or choice.link or "",
      condition = choice.condition,
      effects = choice.effects,
    })
  end
  return result
end

--- Convert Lua table to JSON string
-- @param data any Data to convert
-- @return string JSON string
function StaticExporter:to_json(data)
  if data == nil then
    return "null"
  end

  local t = type(data)

  if t == "boolean" then
    return data and "true" or "false"
  end

  if t == "number" then
    return tostring(data)
  end

  if t == "string" then
    return '"' .. ExportUtils.escape_json(data) .. '"'
  end

  if t == "table" then
    -- Check if array
    if #data > 0 or next(data) == nil then
      local parts = {}
      for i, v in ipairs(data) do
        parts[i] = self:to_json(v)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      local keys = {}
      for k in pairs(data) do
        table.insert(keys, k)
      end
      table.sort(keys)

      for _, k in ipairs(keys) do
        local v = data[k]
        table.insert(parts, '"' .. ExportUtils.escape_json(tostring(k)) .. '":' .. self:to_json(v))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

--- Generate the HTML document
-- @param story_json string Story JSON data
-- @param title string Page title
-- @param description string Page description
-- @param options table Options (include_save, include_theme, include_seo, author, site_url)
-- @return string HTML content
function StaticExporter:generate_html(story_json, title, description, options)
  local escaped_title = ExportUtils.escape_html(title)
  local escaped_description = ExportUtils.escape_html(description)
  local author = options.author or ""
  local site_url = options.site_url or "/"

  -- Build SEO meta tags
  local seo_tags = ""
  if options.include_seo then
    seo_tags = self:generate_seo_tags({
      title = escaped_title,
      description = escaped_description,
      author = author,
      url = site_url,
      type = "website",
    })
  end

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="]] .. escaped_description .. [[">
    <meta name="generator" content="whisker-core">]] .. seo_tags .. [[
    <title>]] .. escaped_title .. [[</title>
    <style>
        ]] .. self:get_player_styles() .. [[
    </style>
</head>
<body>
    <div id="whisker-player">
        <div id="passage-container"></div>
        <div id="controls"></div>
    </div>
    <script>
        const STORY_DATA = ]] .. story_json .. [[;
    </script>
    <script>
        ]] .. self:get_player_script(options) .. [[
    </script>
</body>
</html>]]
end

--- Get player styles CSS
-- @return string CSS content
function StaticExporter:get_player_styles()
  return [[
:root {
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f5;
    --text-primary: #333333;
    --text-secondary: #666666;
    --accent-color: #3498db;
    --accent-hover: #2980b9;
    --border-color: #eeeeee;
    --shadow: 0 2px 10px rgba(0,0,0,0.1);
}

[data-theme="dark"] {
    --bg-primary: #1e1e1e;
    --bg-secondary: #121212;
    --text-primary: #e0e0e0;
    --text-secondary: #b0b0b0;
    --accent-color: #5dade2;
    --accent-hover: #85c1e9;
    --border-color: #333333;
    --shadow: 0 2px 10px rgba(0,0,0,0.3);
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    line-height: 1.6;
    color: var(--text-primary);
    background: var(--bg-secondary);
    padding: 20px;
    transition: background 0.3s, color 0.3s;
}

#whisker-player {
    max-width: 800px;
    margin: 0 auto;
    background: var(--bg-primary);
    border-radius: 8px;
    box-shadow: var(--shadow);
    padding: 40px;
    transition: background 0.3s, box-shadow 0.3s;
}

#passage-container {
    min-height: 300px;
    margin-bottom: 30px;
}

.passage {
    animation: fadeIn 0.3s ease-in;
}

@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}

.passage h1 {
    font-size: 2em;
    margin-bottom: 20px;
    color: var(--text-primary);
}

.passage-content {
    color: var(--text-primary);
    white-space: pre-wrap;
}

.passage-content p {
    margin-bottom: 15px;
}

.choices {
    margin-top: 30px;
}

.choice {
    display: block;
    padding: 15px 20px;
    margin: 10px 0;
    background: var(--accent-color);
    color: white;
    text-decoration: none;
    border-radius: 5px;
    transition: background 0.2s;
    cursor: pointer;
    border: none;
    width: 100%;
    text-align: left;
    font-size: 16px;
}

.choice:hover {
    background: var(--accent-hover);
}

.choice:focus {
    outline: 3px solid var(--accent-hover);
    outline-offset: 2px;
}

#controls {
    display: flex;
    gap: 10px;
    padding-top: 20px;
    border-top: 1px solid var(--border-color);
    flex-wrap: wrap;
}

.control-btn {
    padding: 10px 20px;
    background: var(--text-secondary);
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    transition: background 0.2s;
}

.control-btn:hover {
    background: var(--text-primary);
}

.control-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.control-btn.primary {
    background: var(--accent-color);
}

.control-btn.primary:hover {
    background: var(--accent-hover);
}

@media (max-width: 600px) {
    body {
        padding: 10px;
    }

    #whisker-player {
        padding: 20px;
    }
}

@media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
        --bg-primary: #1e1e1e;
        --bg-secondary: #121212;
        --text-primary: #e0e0e0;
        --text-secondary: #b0b0b0;
        --accent-color: #5dade2;
        --accent-hover: #85c1e9;
        --border-color: #333333;
        --shadow: 0 2px 10px rgba(0,0,0,0.3);
    }
}
]]
end

--- Get player script
-- @param options table Options (include_save, include_theme, include_back)
-- @return string JavaScript code
function StaticExporter:get_player_script(options)
  local include_save = options.include_save
  local include_theme = options.include_theme
  local include_back = options.include_back

  return [[
class WhiskerPlayer {
    constructor(storyData) {
        this.story = storyData;
        this.currentPassageId = storyData.startPassage;
        this.history = [];
        this.variables = {};
        this.saveKey = 'whisker_save_' + (storyData.metadata?.title || 'story').replace(/\s+/g, '_');

        // Initialize variables
        if (this.story.variables) {
            this.story.variables.forEach(v => {
                this.variables[v.name] = v.default;
            });
        }

        // Load theme preference
        this.loadTheme();

        // Check for saved game
        this.tryLoadSave();

        this.render();
    }

    loadTheme() {
        const savedTheme = localStorage.getItem('whisker_theme');
        if (savedTheme) {
            document.documentElement.setAttribute('data-theme', savedTheme);
        }
    }

    toggleTheme() {
        const current = document.documentElement.getAttribute('data-theme') || '';
        const newTheme = current === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('whisker_theme', newTheme);
    }

    saveGame() {
        const saveData = {
            currentPassageId: this.currentPassageId,
            history: this.history,
            variables: this.variables,
            timestamp: Date.now()
        };
        try {
            localStorage.setItem(this.saveKey, JSON.stringify(saveData));
            return true;
        } catch (e) {
            console.error('Failed to save game:', e);
            return false;
        }
    }

    loadGame() {
        try {
            const saveData = localStorage.getItem(this.saveKey);
            if (saveData) {
                const data = JSON.parse(saveData);
                this.currentPassageId = data.currentPassageId;
                this.history = data.history || [];
                this.variables = data.variables || {};
                this.render();
                return true;
            }
        } catch (e) {
            console.error('Failed to load game:', e);
        }
        return false;
    }

    tryLoadSave() {
        try {
            const saveData = localStorage.getItem(this.saveKey);
            this.hasSave = !!saveData;
        } catch (e) {
            this.hasSave = false;
        }
    }

    deleteSave() {
        try {
            localStorage.removeItem(this.saveKey);
            this.hasSave = false;
            return true;
        } catch (e) {
            console.error('Failed to delete save:', e);
            return false;
        }
    }

    findPassage(id) {
        return this.story.passages.find(p => p.id === id || p.name === id);
    }

    render() {
        const passage = this.findPassage(this.currentPassageId);
        if (!passage) {
            console.error('Passage not found:', this.currentPassageId);
            const container = document.getElementById('passage-container');
            container.innerHTML = '<div class="error">Passage not found: ' + this.escapeHTML(this.currentPassageId) + '</div>';
            return;
        }

        const container = document.getElementById('passage-container');
        container.innerHTML = '';

        // Create passage element
        const passageEl = document.createElement('div');
        passageEl.className = 'passage';

        // Title
        const title = document.createElement('h1');
        title.textContent = passage.title || passage.name;
        passageEl.appendChild(title);

        // Content
        const content = document.createElement('div');
        content.className = 'passage-content';
        content.innerHTML = this.processContent(passage.content);
        passageEl.appendChild(content);

        // Choices
        if (passage.choices && passage.choices.length > 0) {
            const choicesEl = document.createElement('div');
            choicesEl.className = 'choices';

            passage.choices.forEach(choice => {
                if (this.evaluateCondition(choice.condition)) {
                    const choiceBtn = document.createElement('button');
                    choiceBtn.className = 'choice';
                    choiceBtn.textContent = choice.text;
                    choiceBtn.onclick = () => this.makeChoice(choice);
                    choicesEl.appendChild(choiceBtn);
                }
            });

            passageEl.appendChild(choicesEl);
        }

        container.appendChild(passageEl);

        // Update controls
        this.updateControls();

        // Scroll to top
        window.scrollTo(0, 0);
    }

    processContent(content) {
        if (!content) return '';
        // Variable substitution
        let processed = content.replace(/\{\{(\w+)\}\}/g, (match, varName) => {
            return this.variables[varName] !== undefined ? this.escapeHTML(String(this.variables[varName])) : match;
        });
        // Convert newlines to <br>
        processed = processed.replace(/\n/g, '<br>');
        return processed;
    }

    escapeHTML(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    evaluateCondition(condition) {
        if (!condition) return true;
        try {
            // Simple condition evaluation
            let expr = condition.replace(/\{\{(\w+)\}\}/g, (m, v) => {
                const val = this.variables[v];
                if (typeof val === 'string') return '"' + val + '"';
                return val !== undefined ? String(val) : 'undefined';
            });

            // Parse simple comparisons
            const compOps = [
                { pat: /(.+)==(.+)/, fn: (a, b) => a === b },
                { pat: /(.+)!=(.+)/, fn: (a, b) => a !== b },
                { pat: /(.+)<=(.+)/, fn: (a, b) => Number(a) <= Number(b) },
                { pat: /(.+)>=(.+)/, fn: (a, b) => Number(a) >= Number(b) },
                { pat: /(.+)<(.+)/, fn: (a, b) => Number(a) < Number(b) },
                { pat: /(.+)>(.+)/, fn: (a, b) => Number(a) > Number(b) }
            ];

            for (const { pat, fn } of compOps) {
                const m = expr.match(pat);
                if (m) {
                    const left = this.parseValue(m[1].trim());
                    const right = this.parseValue(m[2].trim());
                    return fn(left, right);
                }
            }

            return Boolean(this.parseValue(expr.trim()));
        } catch (e) {
            return true;
        }
    }

    parseValue(str) {
        if (str === 'true') return true;
        if (str === 'false') return false;
        if (/^-?\d+\.?\d*$/.test(str)) return parseFloat(str);
        if (str.startsWith('"') && str.endsWith('"')) return str.slice(1, -1);
        return str;
    }

    makeChoice(choice) {
        // Execute effects
        if (choice.effects) {
            choice.effects.forEach(effect => {
                this.variables[effect.variable] = effect.value;
            });
        }

        // Add to history
        this.history.push(this.currentPassageId);

        // Navigate to target
        this.currentPassageId = choice.target;
        this.render();
    }

    goBack() {
        if (this.history.length > 0) {
            this.currentPassageId = this.history.pop();
            this.render();
        }
    }

    restart() {
        this.currentPassageId = this.story.startPassage;
        this.history = [];

        // Reset variables
        if (this.story.variables) {
            this.story.variables.forEach(v => {
                this.variables[v.name] = v.default;
            });
        }

        this.render();
    }

    updateControls() {
        const controls = document.getElementById('controls');
        controls.innerHTML = '';

        ]] .. (include_back and [[
        // Back button
        const backBtn = document.createElement('button');
        backBtn.className = 'control-btn';
        backBtn.textContent = '← Back';
        backBtn.disabled = this.history.length === 0;
        backBtn.onclick = () => this.goBack();
        controls.appendChild(backBtn);
        ]] or "") .. [[

        ]] .. (include_save and [[
        // Save button
        const saveBtn = document.createElement('button');
        saveBtn.className = 'control-btn primary';
        saveBtn.textContent = 'Save';
        saveBtn.onclick = () => {
            if (this.saveGame()) {
                this.hasSave = true;
                alert('Game saved!');
                this.updateControls();
            } else {
                alert('Failed to save game.');
            }
        };
        controls.appendChild(saveBtn);

        // Load button
        if (this.hasSave) {
            const loadBtn = document.createElement('button');
            loadBtn.className = 'control-btn';
            loadBtn.textContent = 'Load';
            loadBtn.onclick = () => {
                if (confirm('Load saved game?')) {
                    this.loadGame();
                }
            };
            controls.appendChild(loadBtn);
        }
        ]] or "") .. [[

        ]] .. (include_theme and [[
        // Theme toggle
        const themeBtn = document.createElement('button');
        themeBtn.className = 'control-btn';
        const currentTheme = document.documentElement.getAttribute('data-theme') || '';
        themeBtn.textContent = currentTheme === 'dark' ? 'Light Mode' : 'Dark Mode';
        themeBtn.onclick = () => {
            this.toggleTheme();
            this.updateControls();
        };
        controls.appendChild(themeBtn);
        ]] or "") .. [[

        // Restart button
        const restartBtn = document.createElement('button');
        restartBtn.className = 'control-btn';
        restartBtn.textContent = 'Restart';
        restartBtn.onclick = () => {
            if (confirm('Restart story?')) {
                this.restart();
                this.deleteSave();
            }
        };
        controls.appendChild(restartBtn);
    }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        new WhiskerPlayer(STORY_DATA);
    });
} else {
    new WhiskerPlayer(STORY_DATA);
}
]]
end

--- Validate export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function StaticExporter:validate(bundle)
  local errors = {}
  local warnings = {}

  -- Check content exists
  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, { message = "HTML content is empty", severity = "error" })
  end

  local html = bundle.content or ""

  -- Check HTML structure
  if not html:match("<!DOCTYPE html>") then
    table.insert(warnings, { message = "Missing DOCTYPE declaration", severity = "warning" })
  end

  if not html:match("<html") then
    table.insert(errors, { message = "Missing <html> tag", severity = "error" })
  end

  if not html:match("STORY_DATA") then
    table.insert(errors, { message = "Missing story data", severity = "error" })
  end

  if not html:match("WhiskerPlayer") then
    table.insert(errors, { message = "Missing player script", severity = "error" })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

--- Estimate export size
-- @param story table Story data
-- @return number Estimated size in bytes
function StaticExporter:estimate_size(story)
  -- Rough estimate: base HTML + styles + script + story data
  local base_size = 12000 -- ~12KB for base HTML, CSS, JS
  local per_passage_size = 300 -- ~300 bytes per passage
  local passage_count = story.passages and #story.passages or 0
  return base_size + (passage_count * per_passage_size)
end

--- Generate SEO meta tags (Open Graph, JSON-LD)
-- @param options table SEO options (title, description, author, url, type)
-- @return string HTML meta tags
function StaticExporter:generate_seo_tags(options)
  local title = options.title or "Interactive Story"
  local description = options.description or "An interactive story"
  local author = options.author or ""
  local url = options.url or "/"
  local og_type = options.type or "website"

  -- Build Open Graph tags
  local og_tags = [[
    <meta property="og:type" content="]] .. og_type .. [[">
    <meta property="og:title" content="]] .. title .. [[">
    <meta property="og:description" content="]] .. description .. [[">
    <meta property="og:url" content="]] .. url .. [[">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="]] .. title .. [[">
    <meta name="twitter:description" content="]] .. description .. [[">]]

  -- Add author if present
  if author and author ~= "" then
    og_tags = og_tags .. [[
    <meta name="author" content="]] .. ExportUtils.escape_html(author) .. [[">]]
  end

  -- Build JSON-LD structured data
  local json_ld_data = {
    ["@context"] = "https://schema.org",
    ["@type"] = "CreativeWork",
    name = title,
    description = description,
    genre = "Interactive Fiction",
  }

  if author and author ~= "" then
    json_ld_data.author = {
      ["@type"] = "Person",
      name = author,
    }
  end

  og_tags = og_tags .. [[
    <script type="application/ld+json">]] .. self:to_json(json_ld_data) .. [[</script>]]

  return og_tags
end

--- Generate multi-page static site
-- @param story table Story data
-- @param options table Generation options
-- @return table Map of filename to content
function StaticExporter:generate_multi_page_site(story, options)
  local files = {}
  local title = story.name or story.title or "Interactive Story"
  local description = story.description or "An interactive story"
  local start_passage = story.start_passage or story.start or "Start"

  -- Build passage lookup map
  local passage_map = {}
  for _, passage in ipairs(story.passages) do
    local name = passage.name or passage.id
    passage_map[name] = passage
  end

  -- Generate index.html (landing page / start passage)
  local start = passage_map[start_passage]
  if start then
    files["index.html"] = self:generate_passage_page(start, story, options, true)
  else
    -- Fallback: use first passage
    files["index.html"] = self:generate_passage_page(story.passages[1], story, options, true)
  end

  -- Generate a page for each passage
  for _, passage in ipairs(story.passages) do
    local name = passage.name or passage.id
    local safe_name = self:safe_filename(name)
    local filename = "passages/" .. safe_name .. ".html"
    files[filename] = self:generate_passage_page(passage, story, options, false)
  end

  -- Generate shared CSS file
  files["css/styles.css"] = self:get_player_styles()

  -- Generate shared JS file
  files["js/player.js"] = self:get_multi_page_player_script(story, options)

  return files
end

--- Generate a single passage page for multi-page site
-- @param passage table Passage data
-- @param story table Full story data
-- @param options table Generation options
-- @param is_index boolean Whether this is the index page
-- @return string HTML content
function StaticExporter:generate_passage_page(passage, story, options, is_index)
  local title = story.name or story.title or "Interactive Story"
  local passage_title = passage.title or passage.name or "Untitled"
  local page_title = is_index and title or (passage_title .. " - " .. title)
  local description = passage.text and passage.text:sub(1, 160) or story.description or "An interactive story"
  description = description:gsub("\n", " "):gsub("%s+", " ")

  local escaped_title = ExportUtils.escape_html(page_title)
  local escaped_passage_title = ExportUtils.escape_html(passage_title)
  local escaped_description = ExportUtils.escape_html(description)
  local escaped_content = ExportUtils.escape_html(passage.text or passage.content or "")

  -- Build SEO tags
  local seo_tags = ""
  if options.include_seo then
    local passage_name = passage.name or passage.id
    local page_url = is_index and options.site_url or (options.site_url .. "passages/" .. self:safe_filename(passage_name) .. ".html")
    seo_tags = self:generate_seo_tags({
      title = escaped_title,
      description = escaped_description,
      author = options.author,
      url = page_url,
      type = "article",
    })
  end

  -- Build choices HTML
  local choices_html = ""
  local choices = passage.choices or passage.links or {}
  if #choices > 0 then
    choices_html = '<nav class="choices" aria-label="Story choices">\n'
    for _, choice in ipairs(choices) do
      local target = choice.target or choice.passage or choice.link or ""
      local choice_text = ExportUtils.escape_html(choice.text or choice.label or "Continue")
      local target_url = "../passages/" .. self:safe_filename(target) .. ".html"
      if is_index then
        target_url = "passages/" .. self:safe_filename(target) .. ".html"
      end
      choices_html = choices_html .. '            <a href="' .. target_url .. '" class="choice">' .. choice_text .. '</a>\n'
    end
    choices_html = choices_html .. '        </nav>'
  end

  -- Determine relative paths
  local css_path = is_index and "css/styles.css" or "../css/styles.css"
  local js_path = is_index and "js/player.js" or "../js/player.js"
  local home_link = is_index and "" or '<a href="../index.html" class="control-btn">Home</a>'

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="]] .. escaped_description .. [[">
    <meta name="generator" content="whisker-core">]] .. seo_tags .. [[
    <title>]] .. escaped_title .. [[</title>
    <link rel="stylesheet" href="]] .. css_path .. [[">
</head>
<body>
    <div id="whisker-player">
        <article class="passage">
            <h1>]] .. escaped_passage_title .. [[</h1>
            <div class="passage-content">]] .. escaped_content:gsub("\n", "<br>") .. [[</div>
        ]] .. choices_html .. [[
        </article>
        <div id="controls">
            ]] .. home_link .. [[
        </div>
    </div>
    <script src="]] .. js_path .. [["></script>
</body>
</html>]]
end

--- Generate safe filename from passage name
-- @param name string Passage name
-- @return string Safe filename
function StaticExporter:safe_filename(name)
  if not name then return "unnamed" end
  return name:lower():gsub("[^%w%-_]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
end

--- Get multi-page player script
-- @param story table Story data
-- @param options table Options
-- @return string JavaScript code
function StaticExporter:get_multi_page_player_script(story, options)
  local include_theme = options.include_theme

  return [[// Whisker Multi-Page Player Script
(function() {
    'use strict';

    // Theme management
    function loadTheme() {
        const savedTheme = localStorage.getItem('whisker_theme');
        if (savedTheme) {
            document.documentElement.setAttribute('data-theme', savedTheme);
        }
    }

    function toggleTheme() {
        const current = document.documentElement.getAttribute('data-theme') || '';
        const newTheme = current === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('whisker_theme', newTheme);
        updateThemeButton();
    }

    function updateThemeButton() {
        const btn = document.getElementById('theme-toggle');
        if (btn) {
            const current = document.documentElement.getAttribute('data-theme') || '';
            btn.textContent = current === 'dark' ? 'Light Mode' : 'Dark Mode';
        }
    }

    // Initialize
    loadTheme();

    ]] .. (include_theme and [[
    // Add theme toggle button
    const controls = document.getElementById('controls');
    if (controls) {
        const themeBtn = document.createElement('button');
        themeBtn.id = 'theme-toggle';
        themeBtn.className = 'control-btn';
        themeBtn.onclick = toggleTheme;
        updateThemeButton.call(null);
        const current = document.documentElement.getAttribute('data-theme') || '';
        themeBtn.textContent = current === 'dark' ? 'Light Mode' : 'Dark Mode';
        controls.appendChild(themeBtn);
    }
    ]] or "") .. [[
})();
]]
end

--- Generate sitemap.xml for SEO
-- @param story table Story data
-- @param site_url string Base site URL
-- @return string XML sitemap content
function StaticExporter:generate_sitemap(story, site_url)
  -- Ensure site_url ends with /
  if site_url:sub(-1) ~= "/" then
    site_url = site_url .. "/"
  end

  local today = os.date("%Y-%m-%d")

  local xml = [[<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>]] .. ExportUtils.escape_html(site_url) .. [[</loc>
        <lastmod>]] .. today .. [[</lastmod>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
    </url>
]]

  -- Add each passage
  for _, passage in ipairs(story.passages) do
    local name = passage.name or passage.id
    local safe_name = self:safe_filename(name)
    xml = xml .. [[    <url>
        <loc>]] .. ExportUtils.escape_html(site_url) .. [[passages/]] .. safe_name .. [[.html</loc>
        <lastmod>]] .. today .. [[</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
    </url>
]]
  end

  xml = xml .. [[</urlset>
]]

  return xml
end

--- Generate robots.txt
-- @param site_url string Base site URL
-- @return string robots.txt content
function StaticExporter:generate_robots(site_url)
  -- Ensure site_url ends with /
  if site_url:sub(-1) ~= "/" then
    site_url = site_url .. "/"
  end

  return [[User-agent: *
Allow: /

Sitemap: ]] .. site_url .. [[sitemap.xml
]]
end

--- Generate 404 error page
-- @param title string Site title
-- @param description string Site description
-- @return string HTML content
function StaticExporter:generate_404_page(title, description)
  local escaped_title = ExportUtils.escape_html(title)

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex">
    <title>Page Not Found - ]] .. escaped_title .. [[</title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>
    <div id="whisker-player">
        <div class="passage">
            <h1>Page Not Found</h1>
            <div class="passage-content">
                <p>Sorry, the page you're looking for doesn't exist.</p>
                <p>The story may have changed, or you may have followed an old link.</p>
            </div>
            <div class="choices">
                <a href="index.html" class="choice">Return to Start</a>
            </div>
        </div>
    </div>
    <script src="js/player.js"></script>
</body>
</html>]]
end

return StaticExporter
