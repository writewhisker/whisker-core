--- Format template and engine code provider
-- Provides format-specific templates and engine embedding
--
-- lib/whisker/twine/export/format_template_provider.lua

local FormatTemplateProvider = {}

-- Path for external engine files (relative to export location)
FormatTemplateProvider.external_engine_path = "engines"

-- Bundled engines cache
FormatTemplateProvider.bundled_engines = {}

--------------------------------------------------------------------------------
-- Engine Loading
--------------------------------------------------------------------------------

--- Get format engine code
---@param format string Format name
---@param options table Options (use_external: boolean, engine_path: string)
---@return string JavaScript engine code
function FormatTemplateProvider.get_engine_code(format, options)
  options = options or {}
  local format_lower = format:lower()

  -- Try external engine first if requested
  if options.use_external and options.engine_path then
    local engine_file = string.format("%s/%s.js", options.engine_path, format_lower)
    local file = io.open(engine_file, "r")
    if file then
      local content = file:read("*a")
      file:close()
      return content
    end
  end

  -- Use bundled engine if available
  if FormatTemplateProvider.bundled_engines[format_lower] then
    return FormatTemplateProvider.bundled_engines[format_lower]
  end

  -- Return minimal functional engine
  local engines = {
    harlowe = FormatTemplateProvider._harlowe_engine,
    sugarcube = FormatTemplateProvider._sugarcube_engine,
    chapbook = FormatTemplateProvider._chapbook_engine,
    snowman = FormatTemplateProvider._snowman_engine
  }

  local engine_fn = engines[format_lower]
  if engine_fn then
    return engine_fn()
  end

  -- Fallback to generic minimal engine
  return FormatTemplateProvider._minimal_engine()
end

--------------------------------------------------------------------------------
-- Format-Specific Templates
--------------------------------------------------------------------------------

--- Get format-specific HTML wrapper
---@param format string Format name
---@return table Template with head and body parts
function FormatTemplateProvider.get_html_template(format)
  local templates = {
    harlowe = {
      head = [[
<style>
  tw-story { display: block; padding: 2em; max-width: 800px; margin: 0 auto; }
  tw-passage { display: block; }
  tw-link, .passage-link { color: #4169e1; cursor: pointer; text-decoration: underline; }
  tw-link:hover, .passage-link:hover { color: #1e90ff; }
  .error { color: #dc3545; background: #f8d7da; padding: 1em; border-radius: 4px; }
</style>]],
      body_attrs = "",
      body_prefix = '<tw-story><tw-passage id="passage-display"></tw-passage></tw-story>',
      body_suffix = ""
    },
    sugarcube = {
      head = [[
<style>
  #passages { padding: 2em; max-width: 800px; margin: 0 auto; }
  .passage { line-height: 1.6; }
  .passage a, .macro-link { color: #4169e1; cursor: pointer; text-decoration: underline; }
  .passage a:hover, .macro-link:hover { color: #1e90ff; }
  #ui-bar { display: none; }
</style>]],
      body_attrs = "",
      body_prefix = '<div id="ui-bar"></div><div id="passages"></div>',
      body_suffix = ""
    },
    chapbook = {
      head = [[
<style>
  .page { padding: 2em; max-width: 800px; margin: 0 auto; }
  .body-text { line-height: 1.6; margin-bottom: 1.5em; }
  .fork { list-style: none; padding: 0; }
  .fork li { margin: 0.5em 0; }
  .fork a { color: #4169e1; text-decoration: underline; cursor: pointer; }
  .fork a:hover { color: #1e90ff; }
</style>]],
      body_attrs = "",
      body_prefix = '<div class="page"><article class="body-text" id="passage-display"></article><nav class="fork" id="choices"></nav></div>',
      body_suffix = ""
    },
    snowman = {
      head = [[
<style>
  #passage { padding: 2em; max-width: 800px; margin: 0 auto; line-height: 1.6; }
  #passage a { color: #4169e1; text-decoration: underline; cursor: pointer; }
  #passage a:hover { color: #1e90ff; }
</style>]],
      body_attrs = "",
      body_prefix = '<div id="passage"></div>',
      body_suffix = ""
    }
  }

  return templates[format:lower()] or templates.harlowe
end

--------------------------------------------------------------------------------
-- Minimal Functional Engines
--------------------------------------------------------------------------------

--- Harlowe engine (minimal functional)
---@return string JavaScript code
function FormatTemplateProvider._harlowe_engine()
  return [[
(function() {
  'use strict';

  // Harlowe Minimal Engine
  var Harlowe = {
    version: '3.3.8-minimal',
    passages: {},
    current: null,
    variables: {},
    history: [],

    init: function() {
      // Parse tw-passagedata elements
      var passages = document.querySelectorAll('tw-passagedata');
      passages.forEach(function(el) {
        Harlowe.passages[el.getAttribute('name')] = {
          content: el.textContent,
          tags: (el.getAttribute('tags') || '').split(/\s+/).filter(Boolean),
          pid: el.getAttribute('pid')
        };
      });

      // Find start passage
      var storyData = document.querySelector('tw-storydata');
      if (storyData) {
        var startPid = storyData.getAttribute('startnode');
        var startEl = document.querySelector('tw-passagedata[pid="' + startPid + '"]');
        if (startEl) {
          Harlowe.current = startEl.getAttribute('name');
        }
      }

      // Show initial passage
      if (Harlowe.current) {
        Harlowe.show(Harlowe.current);
      }
    },

    show: function(name) {
      var passage = Harlowe.passages[name];
      if (!passage) {
        console.error('Passage not found:', name);
        return;
      }

      Harlowe.history.push(Harlowe.current);
      Harlowe.current = name;

      var output = document.getElementById('passage-display') ||
                   document.querySelector('tw-passage') ||
                   document.body;

      var html = Harlowe.render(passage.content);
      output.innerHTML = html;
    },

    render: function(content) {
      var html = content;

      // Process (set:) macro for variables
      html = html.replace(/\(set:\s*\$(\w+)\s+to\s+([^)]+)\)/gi, function(m, name, value) {
        Harlowe.variables[name] = Harlowe.evalExpr(value.trim());
        return '';
      });

      // Process (print:) macro
      html = html.replace(/\(print:\s*\$(\w+)\)/gi, function(m, name) {
        return Harlowe.variables[name] !== undefined ? String(Harlowe.variables[name]) : '';
      });

      // Process $variable references
      html = html.replace(/\$(\w+)/g, function(m, name) {
        return Harlowe.variables[name] !== undefined ? String(Harlowe.variables[name]) : m;
      });

      // Process (if:) macro (simplified)
      html = html.replace(/\(if:\s*([^)]+)\)\s*\[([^\]]+)\]/gi, function(m, cond, content) {
        if (Harlowe.evalCond(cond)) {
          return content;
        }
        return '';
      });

      // Process links: [[text->target]] or [[text|target]]
      html = html.replace(/\[\[([^\]|>]+?)(?:\||->)([^\]]+?)\]\]/g, function(m, text, target) {
        return '<tw-link onclick="Harlowe.show(\'' + Harlowe.escape(target.trim()) + '\')">' + text + '</tw-link>';
      });

      // Process simple links: [[target]]
      html = html.replace(/\[\[([^\]]+?)\]\]/g, function(m, target) {
        return '<tw-link onclick="Harlowe.show(\'' + Harlowe.escape(target.trim()) + '\')">' + target + '</tw-link>';
      });

      // Convert line breaks
      html = html.replace(/\n\n+/g, '</p><p>');
      html = '<p>' + html + '</p>';

      return html;
    },

    evalExpr: function(expr) {
      // Simple expression evaluation
      expr = expr.replace(/^\s*["']|["']\s*$/g, '');
      if (/^\d+$/.test(expr)) return parseInt(expr, 10);
      if (/^\d+\.\d+$/.test(expr)) return parseFloat(expr);
      if (expr === 'true') return true;
      if (expr === 'false') return false;
      return expr;
    },

    evalCond: function(cond) {
      // Simple condition evaluation
      cond = cond.replace(/\$(\w+)/g, function(m, name) {
        var v = Harlowe.variables[name];
        return typeof v === 'string' ? '"' + v + '"' : String(v);
      });
      try {
        return Function('"use strict"; return (' + cond + ')')();
      } catch(e) {
        return false;
      }
    },

    escape: function(s) {
      return s.replace(/'/g, "\\'").replace(/"/g, '\\"');
    }
  };

  window.Harlowe = Harlowe;
  document.addEventListener('DOMContentLoaded', function() { Harlowe.init(); });
})();
]]
end

--- SugarCube engine (minimal functional)
---@return string JavaScript code
function FormatTemplateProvider._sugarcube_engine()
  return [[
(function() {
  'use strict';

  // SugarCube Minimal Engine
  var SugarCube = {
    version: '2.36.1-minimal',
    passages: {},
    current: null,

    State: {
      variables: {},
      active: { title: '' },
      history: []
    },

    init: function() {
      // Parse tw-passagedata elements
      var passages = document.querySelectorAll('tw-passagedata');
      passages.forEach(function(el) {
        SugarCube.passages[el.getAttribute('name')] = {
          element: el,
          content: el.textContent,
          tags: (el.getAttribute('tags') || '').split(/\s+/).filter(Boolean),
          pid: el.getAttribute('pid')
        };
      });

      // Find start passage
      var storyData = document.querySelector('tw-storydata');
      if (storyData) {
        var startPid = storyData.getAttribute('startnode');
        var startEl = document.querySelector('tw-passagedata[pid="' + startPid + '"]');
        if (startEl) {
          SugarCube.current = startEl.getAttribute('name');
        }
      }

      // Create $ alias for variables
      window.$ = window.$ || SugarCube.State.variables;

      // Show initial passage
      if (SugarCube.current) {
        SugarCube.Engine.show(SugarCube.current);
      }
    },

    Engine: {
      show: function(name) {
        var passage = SugarCube.passages[name];
        if (!passage) {
          console.error('Passage not found:', name);
          return;
        }

        SugarCube.State.history.push(SugarCube.current);
        SugarCube.current = name;
        SugarCube.State.active.title = name;

        var output = document.getElementById('passages');
        if (output) {
          output.innerHTML = '<div class="passage" data-passage="' + name + '">' +
            SugarCube.Wikifier.wikify(passage.content) + '</div>';
        }
      }
    },

    Wikifier: {
      wikify: function(content) {
        var html = content;

        // Process <<set>> macro
        html = html.replace(/<<set\s+\$(\w+)\s+(?:to\s+)?([^>]+)>>/gi, function(m, name, value) {
          SugarCube.State.variables[name] = SugarCube.Scripting.evalExpr(value.trim());
          return '';
        });

        // Process <<print>> macro
        html = html.replace(/<<print\s+\$(\w+)>>/gi, function(m, name) {
          var v = SugarCube.State.variables[name];
          return v !== undefined ? String(v) : '';
        });

        // Process <<if>> / <<else>> / <<endif>> (simplified)
        html = html.replace(/<<if\s+([^>]+)>>([\s\S]*?)(?:<<else>>([\s\S]*?))?<<\/if>>/gi,
          function(m, cond, ifContent, elseContent) {
            return SugarCube.Scripting.evalCond(cond) ? ifContent : (elseContent || '');
          });

        // Process $variable display
        html = html.replace(/\$(\w+)/g, function(m, name) {
          var v = SugarCube.State.variables[name];
          return v !== undefined ? String(v) : m;
        });

        // Process <<link>> macro
        html = html.replace(/<<link\s+"([^"]+)"\s+"([^"]+)">>/gi, function(m, text, target) {
          return '<a class="macro-link" onclick="SugarCube.Engine.show(\'' +
            target.replace(/'/g, "\\'") + '\')">' + text + '</a>';
        });

        // Process simple links [[text->target]] or [[text|target]]
        html = html.replace(/\[\[([^\]|>]+?)(?:\||->)([^\]]+?)\]\]/g, function(m, text, target) {
          return '<a onclick="SugarCube.Engine.show(\'' +
            target.trim().replace(/'/g, "\\'") + '\')">' + text + '</a>';
        });

        // Process simple links [[target]]
        html = html.replace(/\[\[([^\]]+?)\]\]/g, function(m, target) {
          return '<a onclick="SugarCube.Engine.show(\'' +
            target.trim().replace(/'/g, "\\'") + '\')">' + target + '</a>';
        });

        // Convert line breaks
        html = html.replace(/\n\n+/g, '<br><br>');

        return html;
      }
    },

    Scripting: {
      evalExpr: function(expr) {
        expr = expr.replace(/^\s*["']|["']\s*$/g, '');
        if (/^\d+$/.test(expr)) return parseInt(expr, 10);
        if (/^\d+\.\d+$/.test(expr)) return parseFloat(expr);
        if (expr === 'true') return true;
        if (expr === 'false') return false;
        return expr;
      },

      evalCond: function(cond) {
        cond = cond.replace(/\$(\w+)/g, function(m, name) {
          var v = SugarCube.State.variables[name];
          return typeof v === 'string' ? '"' + v + '"' : String(v);
        });
        try {
          return Function('"use strict"; return (' + cond + ')')();
        } catch(e) {
          return false;
        }
      }
    }
  };

  window.SugarCube = SugarCube;
  document.addEventListener('DOMContentLoaded', function() { SugarCube.init(); });
})();
]]
end

--- Chapbook engine (minimal functional)
---@return string JavaScript code
function FormatTemplateProvider._chapbook_engine()
  return [[
(function() {
  'use strict';

  // Chapbook Minimal Engine
  var Chapbook = {
    version: '1.2.3-minimal',
    passages: {},
    current: null,
    state: {},

    init: function() {
      // Parse tw-passagedata elements
      var passages = document.querySelectorAll('tw-passagedata');
      passages.forEach(function(el) {
        Chapbook.passages[el.getAttribute('name')] = {
          content: el.textContent,
          tags: (el.getAttribute('tags') || '').split(/\s+/).filter(Boolean),
          pid: el.getAttribute('pid')
        };
      });

      // Find start passage
      var storyData = document.querySelector('tw-storydata');
      if (storyData) {
        var startPid = storyData.getAttribute('startnode');
        var startEl = document.querySelector('tw-passagedata[pid="' + startPid + '"]');
        if (startEl) {
          Chapbook.current = startEl.getAttribute('name');
        }
      }

      if (Chapbook.current) {
        Chapbook.show(Chapbook.current);
      }
    },

    show: function(name) {
      var passage = Chapbook.passages[name];
      if (!passage) {
        console.error('Passage not found:', name);
        return;
      }

      Chapbook.current = name;

      // Parse passage content
      var parts = Chapbook.parsePassage(passage.content);

      // Update display
      var bodyEl = document.getElementById('passage-display') ||
                   document.querySelector('.body-text');
      var choicesEl = document.getElementById('choices') ||
                      document.querySelector('.fork');

      if (bodyEl) {
        bodyEl.innerHTML = Chapbook.renderBody(parts.body);
      }

      if (choicesEl) {
        choicesEl.innerHTML = Chapbook.renderChoices(parts.choices);
      }
    },

    parsePassage: function(content) {
      // Chapbook format: vars block at top (--), then body
      var lines = content.split('\n');
      var inVars = false;
      var body = [];
      var choices = [];

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];

        if (line.trim() === '--') {
          inVars = !inVars;
          continue;
        }

        if (inVars) {
          // Variable assignment: name: value
          var match = line.match(/^(\w+):\s*(.+)$/);
          if (match) {
            Chapbook.state[match[1]] = Chapbook.evalValue(match[2].trim());
          }
        } else {
          // Check for fork/choice syntax: > [[text->target]] or > [[target]]
          var forkMatch = line.match(/^>\s*\[\[([^\]]+)\]\]/);
          if (forkMatch) {
            var linkMatch = forkMatch[1].match(/(.+?)(?:->|\|)(.+)/);
            if (linkMatch) {
              choices.push({ text: linkMatch[1].trim(), target: linkMatch[2].trim() });
            } else {
              choices.push({ text: forkMatch[1].trim(), target: forkMatch[1].trim() });
            }
          } else {
            body.push(line);
          }
        }
      }

      return { body: body.join('\n'), choices: choices };
    },

    renderBody: function(text) {
      var html = text;

      // Variable interpolation: {name}
      html = html.replace(/\{(\w+)\}/g, function(m, name) {
        return Chapbook.state[name] !== undefined ? String(Chapbook.state[name]) : m;
      });

      // Inline links: [[text->target]] or [[target]]
      html = html.replace(/\[\[([^\]|>]+?)(?:\||->)([^\]]+?)\]\]/g, function(m, text, target) {
        return '<a onclick="Chapbook.show(\'' + target.trim().replace(/'/g, "\\'") + '\')">' + text + '</a>';
      });
      html = html.replace(/\[\[([^\]]+?)\]\]/g, function(m, target) {
        return '<a onclick="Chapbook.show(\'' + target.trim().replace(/'/g, "\\'") + '\')">' + target + '</a>';
      });

      // Paragraphs
      html = html.replace(/\n\n+/g, '</p><p>');
      html = '<p>' + html + '</p>';

      return html;
    },

    renderChoices: function(choices) {
      if (!choices.length) return '';

      var html = '';
      for (var i = 0; i < choices.length; i++) {
        var c = choices[i];
        html += '<li><a onclick="Chapbook.show(\'' +
          c.target.replace(/'/g, "\\'") + '\')">' + c.text + '</a></li>';
      }
      return html;
    },

    evalValue: function(val) {
      val = val.replace(/^\s*["']|["']\s*$/g, '');
      if (/^\d+$/.test(val)) return parseInt(val, 10);
      if (/^\d+\.\d+$/.test(val)) return parseFloat(val);
      if (val === 'true') return true;
      if (val === 'false') return false;
      return val;
    }
  };

  window.Chapbook = Chapbook;
  document.addEventListener('DOMContentLoaded', function() { Chapbook.init(); });
})();
]]
end

--- Snowman engine (minimal functional)
---@return string JavaScript code
function FormatTemplateProvider._snowman_engine()
  return [[
(function() {
  'use strict';

  // Snowman Minimal Engine
  var story = {
    passages: {},
    current: null,
    state: {},

    init: function() {
      // Parse tw-passagedata elements
      var passages = document.querySelectorAll('tw-passagedata');
      passages.forEach(function(el) {
        story.passages[el.getAttribute('name')] = {
          content: el.textContent,
          tags: (el.getAttribute('tags') || '').split(/\s+/).filter(Boolean),
          pid: el.getAttribute('pid')
        };
      });

      // Find start passage
      var storyData = document.querySelector('tw-storydata');
      if (storyData) {
        var startPid = storyData.getAttribute('startnode');
        var startEl = document.querySelector('tw-passagedata[pid="' + startPid + '"]');
        if (startEl) {
          story.current = startEl.getAttribute('name');
        }
      }

      if (story.current) {
        story.show(story.current);
      }
    },

    show: function(name) {
      var passage = story.passages[name];
      if (!passage) {
        console.error('Passage not found:', name);
        return;
      }

      story.current = name;

      var output = document.getElementById('passage');
      if (output) {
        // Snowman uses Underscore templates by default
        // We implement a simplified version
        var html = story.render(passage.content);
        output.innerHTML = '<div class="passage-content">' + html + '</div>';
      }
    },

    render: function(content) {
      var html = content;

      // Process <%= expr %> (output)
      html = html.replace(/<%=\s*(.+?)\s*%>/g, function(m, expr) {
        return story.evalExpr(expr);
      });

      // Process <% code %> (execute)
      html = html.replace(/<%\s*(.+?)\s*%>/g, function(m, code) {
        story.execCode(code);
        return '';
      });

      // Process s.variable references for display
      html = html.replace(/\bs\.(\w+)/g, function(m, name) {
        return story.state[name] !== undefined ? String(story.state[name]) : m;
      });

      // Process links: [[text->target]] or [[text|target]]
      html = html.replace(/\[\[([^\]|>]+?)(?:\||->)([^\]]+?)\]\]/g, function(m, text, target) {
        return '<a href="javascript:void(0)" onclick="story.show(\'' +
          target.trim().replace(/'/g, "\\'") + '\')">' + text + '</a>';
      });

      // Process simple links: [[target]]
      html = html.replace(/\[\[([^\]]+?)\]\]/g, function(m, target) {
        return '<a href="javascript:void(0)" onclick="story.show(\'' +
          target.trim().replace(/'/g, "\\'") + '\')">' + target + '</a>';
      });

      // Convert newlines to breaks
      html = html.replace(/\n\n+/g, '<br><br>');
      html = html.replace(/\n/g, '<br>');

      return html;
    },

    evalExpr: function(expr) {
      // Simple expression evaluation with s. state access
      try {
        var s = story.state;
        return Function('s', '"use strict"; return (' + expr + ')')(s);
      } catch(e) {
        console.error('Expression error:', e);
        return '';
      }
    },

    execCode: function(code) {
      // Execute code with s. state access
      try {
        var s = story.state;
        Function('s', '"use strict"; ' + code)(s);
      } catch(e) {
        console.error('Code error:', e);
      }
    },

    passage: function(name) {
      return story.passages[name] || null;
    }
  };

  // Create s alias for state
  var s = story.state;

  window.story = story;
  window.s = s;

  document.addEventListener('DOMContentLoaded', function() { story.init(); });
})();
]]
end

--- Fallback minimal engine
---@return string JavaScript code
function FormatTemplateProvider._minimal_engine()
  return [[
(function() {
  'use strict';

  // Generic Minimal Story Engine
  var story = {
    passages: {},
    current: null,
    variables: {},

    init: function() {
      var passages = document.querySelectorAll('tw-passagedata');
      passages.forEach(function(el) {
        story.passages[el.getAttribute('name')] = {
          content: el.textContent,
          tags: (el.getAttribute('tags') || '').split(/\s+/).filter(Boolean),
          pid: el.getAttribute('pid')
        };
      });

      var storyData = document.querySelector('tw-storydata');
      if (storyData) {
        var startPid = storyData.getAttribute('startnode');
        var startEl = document.querySelector('tw-passagedata[pid="' + startPid + '"]');
        if (startEl) {
          story.current = startEl.getAttribute('name');
        }
      }

      if (story.current) {
        story.show(story.current);
      }
    },

    show: function(name) {
      var passage = story.passages[name];
      if (!passage) {
        console.error('Passage not found:', name);
        return;
      }

      story.current = name;

      var output = document.getElementById('story-output') ||
                   document.getElementById('passage') ||
                   document.getElementById('passages') ||
                   document.body;

      var html = passage.content;

      // Process links
      html = html.replace(/\[\[([^\]|>]+?)(?:\||->)([^\]]+?)\]\]/g,
        '<a href="#" onclick="story.show(\'$2\');return false;">$1</a>');
      html = html.replace(/\[\[([^\]]+?)\]\]/g,
        '<a href="#" onclick="story.show(\'$1\');return false;">$1</a>');

      html = html.replace(/\n\n+/g, '<br><br>');

      output.innerHTML = '<div class="passage">' + html + '</div>';
    }
  };

  window.story = story;
  document.addEventListener('DOMContentLoaded', function() { story.init(); });
})();
]]
end

--------------------------------------------------------------------------------
-- Format Detection
--------------------------------------------------------------------------------

--- Check if format is supported
---@param format string Format name
---@return boolean True if supported
function FormatTemplateProvider.is_supported(format)
  local supported = { "harlowe", "sugarcube", "chapbook", "snowman" }
  for _, f in ipairs(supported) do
    if f == format:lower() then
      return true
    end
  end
  return false
end

--- Get list of supported formats
---@return table Array of format names
function FormatTemplateProvider.get_supported_formats()
  return { "harlowe", "sugarcube", "chapbook", "snowman" }
end

--- Load external engine file
---@param format string Format name
---@param path string Path to engine file
---@return boolean, string Success flag and content or error message
function FormatTemplateProvider.load_external_engine(format, path)
  local file = io.open(path, "r")
  if not file then
    return false, "Could not open engine file: " .. path
  end

  local content = file:read("*a")
  file:close()

  -- Cache for future use
  FormatTemplateProvider.bundled_engines[format:lower()] = content

  return true, content
end

return FormatTemplateProvider
