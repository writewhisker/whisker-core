--- PWA Exporter
-- Export stories as Progressive Web Apps with offline support
-- @module whisker.export.pwa.pwa_exporter
-- @author Whisker Core Team
-- @license MIT
--
-- Exports stories as PWAs with:
-- - Installable web app manifest
-- - Service worker for offline support
-- - Icon generation placeholders
-- - Cache-first strategy for assets

local ExportUtils = require("whisker.export.utils")
local Runtime = require("whisker.export.html.runtime")

local PWAExporter = {}
PWAExporter.__index = PWAExporter
PWAExporter._dependencies = {}

--- Create a new PWA exporter instance
-- @param deps table Optional dependencies
-- @return PWAExporter A new exporter
function PWAExporter.new(deps)
  deps = deps or {}
  local self = setmetatable({}, PWAExporter)
  return self
end

--- Get exporter metadata
-- @return table Metadata
function PWAExporter:metadata()
  return {
    format = "pwa",
    version = "1.0.0",
    description = "Progressive Web App export with offline support",
    file_extension = ".zip",
    mime_type = "application/zip",
  }
end

--- Check if story can be exported
-- @param story table Story data
-- @param options table Export options
-- @return boolean, string Whether export is possible and any error
function PWAExporter:can_export(story, options)
  if not story then
    return false, "No story provided"
  end
  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end
  return true
end

--- Export story to PWA
-- @param story table Story data
-- @param options table Export options:
--   - app_name: string (app name, defaults to story title)
--   - short_name: string (short name for icons, max 12 chars)
--   - description: string (app description)
--   - theme_color: string (theme color, default "#3498db")
--   - background_color: string (background color, default "#ffffff")
--   - display: string ("standalone", "fullscreen", "minimal-ui", "browser")
--   - orientation: string ("any", "portrait", "landscape")
--   - cache_version: string (service worker cache version)
--   - show_install_button: boolean (show install button, default true)
--   - splash_screen: table (splash screen config: background_color, icon_url)
-- @return table Export bundle with files, manifest
function PWAExporter:export(story, options)
  options = options or {}
  local warnings = {}

  -- Check for start passage
  local start_name = story.start_passage or story.start or "Start"
  local has_start = false
  for _, passage in ipairs(story.passages) do
    if passage.name == start_name then
      has_start = true
      break
    end
  end
  if not has_start then
    table.insert(warnings, "Story has no start passage set")
  end

  -- Generate app metadata
  local app_name = options.app_name or story.name or story.title or "Interactive Story"
  local short_name = options.short_name or app_name:sub(1, 12)
  local description = options.description or story.description or "An interactive story"
  local theme_color = options.theme_color or "#3498db"
  local background_color = options.background_color or "#ffffff"
  local display = options.display or "standalone"
  local orientation = options.orientation or "any"
  local cache_version = options.cache_version or ("v" .. tostring(os.time()))
  local show_install_button = options.show_install_button ~= false
  local splash_screen = options.splash_screen or {
    background_color = background_color,
  }

  -- Generate story JSON
  local story_json = self:serialize_story(story)

  -- Generate all files
  local files = {}

  -- index.html
  files["index.html"] = self:generate_index_html(story_json, app_name, {
    theme_color = theme_color,
    description = description,
    show_install_button = show_install_button,
  })

  -- manifest.json
  files["manifest.json"] = self:generate_manifest({
    name = app_name,
    short_name = short_name,
    description = description,
    theme_color = theme_color,
    background_color = background_color,
    display = display,
    orientation = orientation,
    splash_screen = splash_screen,
  })

  -- sw.js (service worker)
  files["sw.js"] = self:generate_service_worker(cache_version)

  -- offline.html
  files["offline.html"] = self:generate_offline_page(app_name)

  -- Placeholder icons
  files["icons/icon-192.png"] = self:generate_placeholder_icon(192)
  files["icons/icon-512.png"] = self:generate_placeholder_icon(512)

  -- Asset manifest for cache busting
  files["asset-manifest.json"] = self:generate_asset_manifest(files, cache_version)

  -- Generate filename
  local safe_title = app_name:lower():gsub("[^%w]", "_")
  local filename = safe_title .. "_pwa.zip"

  -- Calculate total size
  local total_size = 0
  for _, content in pairs(files) do
    total_size = total_size + #content
  end

  return {
    content = files["index.html"], -- Primary content for compatibility
    files = files,
    assets = {},
    manifest = {
      format = "pwa",
      app_name = app_name,
      short_name = short_name,
      story_name = story.name or story.title or "Untitled",
      passage_count = #story.passages,
      file_count = 0, -- Will be counted
      exported_at = os.time(),
      filename = filename,
      theme_color = theme_color,
      display = display,
    },
    warnings = #warnings > 0 and warnings or nil,
  }
end

--- Serialize story to JSON string
-- @param story table Story data
-- @return string JSON string
function PWAExporter:serialize_story(story)
  return self:to_json({
    title = story.title or story.name or "Untitled",
    author = story.author or "Anonymous",
    start = story.start_passage or story.start or "start",
    ifid = story.ifid,
    passages = self:serialize_passages(story.passages or {}),
  })
end

--- Serialize passages array
-- @param passages table Array of passages
-- @return table Serialized passages
function PWAExporter:serialize_passages(passages)
  local result = {}
  for _, passage in ipairs(passages) do
    table.insert(result, {
      name = passage.name or passage.id,
      text = passage.text or passage.content or "",
      tags = passage.tags,
      choices = self:serialize_choices(passage.choices or passage.links or {}),
    })
  end
  return result
end

--- Serialize choices array
-- @param choices table Array of choices
-- @return table Serialized choices
function PWAExporter:serialize_choices(choices)
  local result = {}
  for _, choice in ipairs(choices) do
    table.insert(result, {
      text = choice.text or choice.label or "",
      target = choice.target or choice.passage or choice.link or "",
    })
  end
  return result
end

--- Convert Lua table to JSON string
-- @param data any Data to convert
-- @return string JSON string
function PWAExporter:to_json(data)
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
      -- Array
      local parts = {}
      for i, v in ipairs(data) do
        parts[i] = self:to_json(v)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Object
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

--- Generate the main index.html with PWA meta tags
-- @param story_json string Story JSON data
-- @param title string App title
-- @param options table Options (theme_color, description, show_install_button)
-- @return string HTML content
function PWAExporter:generate_index_html(story_json, title, options)
  local escaped_title = ExportUtils.escape_html(title)
  local escaped_description = ExportUtils.escape_html(options.description)

  -- Install button HTML (only if enabled)
  local install_button_html = ""
  local install_script = ""
  if options.show_install_button then
    install_button_html = [[
                <button id="install-btn" class="install-button" style="display:none" aria-label="Install app">
                    <span class="install-icon">&#11015;</span> Install App
                </button>]]
    install_script = self:get_install_prompt_script()
  end

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="]] .. escaped_description .. [[">
    <meta name="theme-color" content="]] .. options.theme_color .. [[">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="default">
    <meta name="apple-mobile-web-app-title" content="]] .. escaped_title .. [[">
    <meta name="generator" content="whisker-core">

    <title>]] .. escaped_title .. [[</title>

    <link rel="manifest" href="manifest.json">
    <link rel="icon" type="image/png" sizes="192x192" href="icons/icon-192.png">
    <link rel="apple-touch-icon" href="icons/icon-192.png">

    <style>
        ]] .. self:get_player_styles() .. [[
    </style>
</head>
<body>
    <div id="whisker-player">
        <div id="story-container">
            <header class="story-header">
                <h1>]] .. escaped_title .. [[</h1>]] .. install_button_html .. [[
            </header>
            <main id="story" role="main" aria-live="polite">
                <div id="passage"></div>
                <ul id="choices" class="choices" role="navigation" aria-label="Story choices"></ul>
            </main>
            <footer class="story-footer">
                <p><small>Created with <a href="https://github.com/writewhisker/whisker-core">whisker-core</a></small></p>
            </footer>
        </div>
    </div>

    <script>
        var WHISKER_STORY_DATA = ]] .. story_json .. [[;
        ]] .. Runtime.get_runtime_code() .. [[
    </script>
    <script>
        // Register service worker
        if ('serviceWorker' in navigator) {
            window.addEventListener('load', function() {
                navigator.serviceWorker.register('sw.js')
                    .then(function(reg) { console.log('SW registered:', reg.scope); })
                    .catch(function(err) { console.error('SW registration failed:', err); });
            });
        }
        ]] .. install_script .. [[
    </script>
</body>
</html>]]
end

--- Get player styles CSS
-- @return string CSS content
function PWAExporter:get_player_styles()
  return [[
* {
    box-sizing: border-box;
}
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    background: #f5f5f5;
    color: #333;
}
#whisker-player {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
    min-height: 100vh;
}
#story-container {
    background: white;
    border-radius: 8px;
    padding: 2rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.story-header {
    border-bottom: 2px solid #3498db;
    margin-bottom: 2rem;
    padding-bottom: 1rem;
}
.story-header h1 {
    margin: 0;
    color: #3498db;
}
#passage {
    margin-bottom: 1.5rem;
    min-height: 100px;
}
.choices {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}
.choice-link {
    display: block;
    padding: 1rem 1.5rem;
    font-size: 1rem;
    background: #3498db;
    color: white;
    text-decoration: none;
    border-radius: 6px;
    cursor: pointer;
    text-align: left;
    transition: background 0.2s;
}
.choice-link:hover {
    background: #2980b9;
}
.story-footer {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #ddd;
    text-align: center;
    color: #666;
    font-size: 0.9em;
}
.story-footer a {
    color: #3498db;
}
.error {
    color: #dc3545;
    padding: 1rem;
    background: #f8d7da;
    border: 1px solid #f5c6cb;
    border-radius: 4px;
}
.install-button {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    font-size: 0.9rem;
    background: #27ae60;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    margin-left: auto;
    transition: background 0.2s;
}
.install-button:hover {
    background: #219a52;
}
.install-icon {
    font-size: 1.1rem;
}
.story-header {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}
@media (prefers-color-scheme: dark) {
    body {
        background: #1a1a1a;
        color: #e0e0e0;
    }
    #story-container {
        background: #2a2a2a;
    }
    .story-footer {
        border-top-color: #444;
    }
    .install-button {
        background: #2ecc71;
    }
    .install-button:hover {
        background: #27ae60;
    }
}
.update-notification {
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: #2c3e50;
    color: white;
    padding: 1rem 1.5rem;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 1rem;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    z-index: 1000;
    animation: slideUp 0.3s ease-out;
}
@keyframes slideUp {
    from { transform: translateX(-50%) translateY(100%); opacity: 0; }
    to { transform: translateX(-50%) translateY(0); opacity: 1; }
}
.update-notification button {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9rem;
}
.update-notification button:first-of-type {
    background: #27ae60;
    color: white;
}
.update-notification button:last-of-type {
    background: transparent;
    color: #bdc3c7;
}
]]
end

--- Get install prompt JavaScript
-- @return string JavaScript code for install prompt handling
function PWAExporter:get_install_prompt_script()
  return [[
        // PWA Install Prompt Handling
        let deferredPrompt;
        const installBtn = document.getElementById('install-btn');

        // Listen for the beforeinstallprompt event
        window.addEventListener('beforeinstallprompt', function(e) {
            // Prevent Chrome 67+ from automatically showing the prompt
            e.preventDefault();
            // Stash the event so it can be triggered later
            deferredPrompt = e;
            // Show the install button
            if (installBtn) {
                installBtn.style.display = 'inline-flex';
            }
        });

        // Handle install button click
        if (installBtn) {
            installBtn.addEventListener('click', async function() {
                if (!deferredPrompt) {
                    return;
                }
                // Show the install prompt
                deferredPrompt.prompt();
                // Wait for the user to respond to the prompt
                const { outcome } = await deferredPrompt.userChoice;
                console.log('User response to install prompt:', outcome);
                // Clear the deferred prompt
                deferredPrompt = null;
                // Hide the install button
                installBtn.style.display = 'none';
            });
        }

        // Hide install button when app is installed
        window.addEventListener('appinstalled', function() {
            console.log('PWA was installed');
            if (installBtn) {
                installBtn.style.display = 'none';
            }
            deferredPrompt = null;
        });

        // Check if app is running in standalone mode (already installed)
        if (window.matchMedia('(display-mode: standalone)').matches) {
            if (installBtn) {
                installBtn.style.display = 'none';
            }
        }

        // Update notification handling
        let updateNotification = null;

        // Listen for service worker updates
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.addEventListener('message', function(event) {
                if (event.data && event.data.type === 'SW_UPDATED') {
                    showUpdateNotification();
                }
            });

            // Check for updates on registration
            navigator.serviceWorker.ready.then(function(registration) {
                registration.addEventListener('updatefound', function() {
                    const newWorker = registration.installing;
                    newWorker.addEventListener('statechange', function() {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            showUpdateNotification();
                        }
                    });
                });
            });
        }

        function showUpdateNotification() {
            if (updateNotification) return;

            updateNotification = document.createElement('div');
            updateNotification.className = 'update-notification';
            updateNotification.innerHTML = '<span>A new version is available!</span>' +
                '<button onclick="updateApp()">Update Now</button>' +
                '<button onclick="dismissUpdate()">Later</button>';
            document.body.appendChild(updateNotification);
        }

        function updateApp() {
            if (navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' });
            }
            window.location.reload();
        }

        function dismissUpdate() {
            if (updateNotification) {
                updateNotification.remove();
                updateNotification = null;
            }
        }
]]
end

--- Generate web app manifest
-- @param options table Manifest options
-- @return string JSON manifest content
function PWAExporter:generate_manifest(options)
  -- Get splash screen background color (can be configured separately)
  local splash_bg = options.background_color
  if options.splash_screen and options.splash_screen.background_color then
    splash_bg = options.splash_screen.background_color
  end

  local manifest = {
    name = options.name,
    short_name = options.short_name,
    description = options.description,
    start_url = "/",
    scope = "/",
    id = "/",
    display = options.display,
    display_override = { "standalone", "minimal-ui" },
    orientation = options.orientation,
    theme_color = options.theme_color,
    background_color = splash_bg,
    icons = {
      {
        src = "icons/icon-192.png",
        sizes = "192x192",
        type = "image/png",
        purpose = "any",
      },
      {
        src = "icons/icon-512.png",
        sizes = "512x512",
        type = "image/png",
        purpose = "any",
      },
      {
        src = "icons/icon-512.png",
        sizes = "512x512",
        type = "image/png",
        purpose = "maskable",
      },
    },
    categories = { "games", "entertainment" },
    launch_handler = {
      client_mode = { "navigate-existing", "auto" },
    },
  }

  -- Add screenshots for richer install UI if available
  if options.splash_screen and options.splash_screen.screenshots then
    manifest.screenshots = options.splash_screen.screenshots
  end

  return self:to_json(manifest)
end

--- Generate service worker for offline support
-- @param version string Cache version
-- @return string JavaScript service worker code
function PWAExporter:generate_service_worker(version)
  return [[// Whisker PWA Service Worker
const CACHE_NAME = 'whisker-story-]] .. version .. [[';
const URLS_TO_CACHE = [
    '/',
    '/index.html',
    '/manifest.json',
    '/offline.html',
    '/icons/icon-192.png',
    '/icons/icon-512.png'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('Opened cache');
                return cache.addAll(URLS_TO_CACHE);
            })
            .then(() => self.skipWaiting())
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames
                    .filter((name) => name.startsWith('whisker-story-') && name !== CACHE_NAME)
                    .map((name) => caches.delete(name))
            );
        }).then(() => self.clients.claim())
    );
});

// Fetch event - cache-first strategy
self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                // Return cached response if found
                if (response) {
                    return response;
                }

                // Clone the request
                const fetchRequest = event.request.clone();

                return fetch(fetchRequest).then((response) => {
                    // Check if valid response
                    if (!response || response.status !== 200 || response.type !== 'basic') {
                        return response;
                    }

                    // Clone the response
                    const responseToCache = response.clone();

                    caches.open(CACHE_NAME)
                        .then((cache) => {
                            cache.put(event.request, responseToCache);
                        });

                    return response;
                }).catch(() => {
                    // Return offline page for navigation requests
                    if (event.request.mode === 'navigate') {
                        return caches.match('/offline.html');
                    }
                    return new Response('Offline', { status: 503 });
                });
            })
    );
});

// Handle messages from main thread
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});

// Notify clients of updates
self.addEventListener('activate', (event) => {
    event.waitUntil(
        self.clients.matchAll({ type: 'window' }).then((clients) => {
            clients.forEach((client) => {
                client.postMessage({ type: 'SW_UPDATED', version: CACHE_NAME });
            });
        })
    );
});
]]
end

--- Generate asset manifest
-- @param files table Map of file paths to content
-- @param version string Cache version
-- @return string JSON asset manifest
function PWAExporter:generate_asset_manifest(files, version)
  local assets = {}

  for path, content in pairs(files) do
    -- Calculate simple hash (sum of bytes mod large prime)
    local hash = 0
    for i = 1, math.min(#content, 1000) do
      hash = (hash + content:byte(i)) % 999983
    end

    table.insert(assets, {
      path = path,
      size = #content,
      hash = string.format("%06x", hash),
    })
  end

  -- Sort by path for consistency
  table.sort(assets, function(a, b) return a.path < b.path end)

  local manifest = {
    version = version,
    generated = os.date("%Y-%m-%dT%H:%M:%SZ"),
    assets = assets,
  }

  return self:to_json(manifest)
end

--- Generate offline fallback page
-- @param title string App title
-- @return string HTML content
function PWAExporter:generate_offline_page(title)
  local escaped_title = ExportUtils.escape_html(title)

  return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. escaped_title .. [[ - Offline</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: #f5f5f5;
            color: #333;
        }
        .offline-container {
            text-align: center;
            padding: 2rem;
        }
        .offline-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
        h1 {
            margin: 0 0 0.5rem 0;
            font-size: 1.5rem;
        }
        p {
            margin: 0;
            color: #666;
        }
        button {
            margin-top: 1rem;
            padding: 0.75rem 1.5rem;
            font-size: 1rem;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover {
            background: #2980b9;
        }
    </style>
</head>
<body>
    <div class="offline-container">
        <div class="offline-icon">&#128244;</div>
        <h1>You're Offline</h1>
        <p>Please check your internet connection and try again.</p>
        <button onclick="window.location.reload()">Retry</button>
    </div>
</body>
</html>]]
end

--- Generate placeholder icon (minimal valid PNG)
-- @param size number Icon size
-- @return string PNG placeholder data
function PWAExporter:generate_placeholder_icon(size)
  -- Simple placeholder - in production this would be a real PNG
  return string.format("/* %dx%d PNG icon placeholder - replace with actual icon */", size, size)
end

--- Validate export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function PWAExporter:validate(bundle)
  local errors = {}
  local warnings = {}

  -- Check content exists
  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, { message = "HTML content is empty", severity = "error" })
  end

  -- Check files exist
  if not bundle.files then
    table.insert(errors, { message = "No files generated", severity = "error" })
  else
    -- Check required files
    local required = { "index.html", "manifest.json", "sw.js", "offline.html" }
    for _, name in ipairs(required) do
      if not bundle.files[name] then
        table.insert(errors, { message = "Missing required file: " .. name, severity = "error" })
      end
    end

    -- Check for icons
    if not bundle.files["icons/icon-192.png"] or not bundle.files["icons/icon-512.png"] then
      table.insert(warnings, { message = "Missing icon files", severity = "warning" })
    end
  end

  -- Check HTML structure
  local html = bundle.content or ""
  if not html:match("<!DOCTYPE html>") then
    table.insert(warnings, { message = "Missing DOCTYPE declaration", severity = "warning" })
  end
  if not html:match('rel="manifest"') then
    table.insert(errors, { message = "Missing manifest link", severity = "error" })
  end
  if not html:match("serviceWorker") then
    table.insert(errors, { message = "Missing service worker registration", severity = "error" })
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
function PWAExporter:estimate_size(story)
  -- Rough estimate: base files + story data
  local base_size = 15000 -- ~15KB for base files (HTML, CSS, JS, SW)
  local per_passage_size = 500 -- ~500 bytes per passage
  local passage_count = story.passages and #story.passages or 0
  return base_size + (passage_count * per_passage_size)
end

return PWAExporter
