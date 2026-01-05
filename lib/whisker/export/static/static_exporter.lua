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
--   - single_page: boolean (single page vs multi-page, default true for now)
--   - include_save: boolean (include save/load, default true)
--   - include_theme: boolean (include theme toggle, default true)
--   - include_back: boolean (include back button, default true)
--   - theme: string ("light", "dark", "auto", default "auto")
-- @return table Export bundle with files, manifest
function StaticExporter:export(story, options)
  options = options or {}
  local warnings = {}

  local include_save = options.include_save ~= false
  local include_theme = options.include_theme ~= false
  local include_back = options.include_back ~= false
  local theme = options.theme or "auto"

  -- Serialize story data
  local story_json = self:serialize_story(story)

  -- Generate HTML
  local title = story.name or story.title or "Interactive Story"
  local description = story.description or "An interactive story"

  local html = self:generate_html(story_json, title, description, {
    include_save = include_save,
    include_theme = include_theme,
    include_back = include_back,
    theme = theme,
  })

  -- Generate files map (for consistency with PWA exporter)
  local files = {
    ["index.html"] = html,
  }

  -- Generate filename
  local safe_title = title:lower():gsub("[^%w]", "_")
  local filename = safe_title .. ".html"

  return {
    content = html,
    files = files,
    assets = {},
    manifest = {
      format = "static",
      story_name = story.name or story.title or "Untitled",
      passage_count = #story.passages,
      exported_at = os.time(),
      filename = filename,
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
-- @param options table Options (include_save, include_theme, etc.)
-- @return string HTML content
function StaticExporter:generate_html(story_json, title, description, options)
  local escaped_title = ExportUtils.escape_html(title)
  local escaped_description = ExportUtils.escape_html(description)

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="]] .. escaped_description .. [[">
    <meta name="generator" content="whisker-core">
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

return StaticExporter
