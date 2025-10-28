# Whisker Master Implementation Plan

**Status:** Living Document
**Last Updated:** 2025-10-27
**Current Phase:** Phase 4 Planning
**Document Version:** 2.0

---

## Executive Summary

This master plan tracks the complete implementation roadmap for the whisker ecosystem, integrating both **whisker-core** (Lua backend) and **whisker-editor-web** (TypeScript/Svelte frontend) development.

### Overall Progress

- **Phases 1-3**: ✅ **COMPLETE** (whisker-core v2.0 data model sync)
- **Phase 4**: 📋 **PLANNING** (Advanced features & integration)
- **Phase 5+**: 🔮 **FUTURE** (To be defined)

### Key Achievements

- ✅ 3018 tests passing across both repositories
- ✅ Full whisker-core v2.0 format support
- ✅ Complete type safety and validation
- ✅ Production-ready export system
- ✅ Comprehensive test coverage

---

## Implementation History

### Phase 1: Typed Variables & v2.0 Format ✅ COMPLETE

**Timeline:** Completed 2025-10-27
**Effort:** ~40 hours
**Status:** Merged to main in both repositories

#### whisker-core Changes
- ✅ Typed variables: `{ type: "string|number|boolean", default: value }`
- ✅ Choice IDs for stable tracking
- ✅ Passage metadata system
- ✅ Passage size property (width, height)
- ✅ Asset management with `asset://` URL scheme
- ✅ Auto-migration from v1.0 to v2.0

#### whisker-editor-web Changes
- ✅ Updated type definitions to match whisker-core
- ✅ Variable model with type support
- ✅ Variable Manager UI
- ✅ Format version handling
- ✅ Migration logic for old projects

#### Deliverables
- **whisker-core:** 36 new tests (all passing)
- **whisker-editor-web:** 45 new tests (all passing)
- **Documentation:** API_REFERENCE.md updated
- **Example:** Basic v2.0 format examples

#### Files Changed
- `lib/whisker/core/story.lua` (+150 lines)
- `src/lib/models/types.ts` (+80 lines)
- `src/lib/models/Variable.ts` (new file)
- `src/lib/components/VariableManager.svelte` (new file)

---

### Phase 2: Metadata & Asset Management ✅ COMPLETE

**Timeline:** Completed 2025-10-27
**Effort:** ~45 hours
**Status:** Merged to main in both repositories

#### whisker-core Changes
- ✅ Passage metadata methods (6 methods): get/set/has/delete/clear/all
- ✅ Choice metadata methods (6 methods): get/set/has/delete/clear/all
- ✅ Asset management methods (6 methods): add/get/remove/list/has/references
- ✅ Asset serialization in Story format
- ✅ Example files with metadata and assets

#### whisker-editor-web Changes
- ✅ MetadataEditor component (full CRUD UI)
- ✅ AssetManager component (upload, preview, delete)
- ✅ Asset reference tracking
- ✅ Asset integration in content editor
- ✅ Enhanced validators for assets and metadata

#### Deliverables
- **whisker-core:** 42 new tests (all passing)
- **whisker-editor-web:** 68 new tests (all passing)
- **Documentation:** Complete API docs for metadata & assets
- **Example:** v2-metadata-assets.whisker (320 lines)

#### Files Changed
- `lib/whisker/core/passage.lua` (+120 lines)
- `lib/whisker/core/choice.lua` (+90 lines)
- `src/lib/components/editor/MetadataEditor.svelte` (new, 245 lines)
- `src/lib/components/editor/AssetManager.svelte` (new, 380 lines)
- 12 new validator files

---

### Phase 3: Story-Level Features ✅ COMPLETE

**Timeline:** Completed 2025-10-27
**Effort:** ~38 hours
**Status:** Merged to main in both repositories

#### whisker-core Changes
- ✅ Story-level tags (5 methods): add/remove/has/getAll/clear
- ✅ Story settings system (6 methods): set/get/has/delete/getAll/clear
- ✅ Variable usage tracking (3 methods): getUsage/getAllUsage/getUnused
- ✅ Enhanced serialization with tags and settings
- ✅ Comprehensive example story with all features

#### whisker-editor-web Changes
- ✅ StorySettingsPanel component (full settings UI)
- ✅ Enhanced VariableManager with usage tracking
- ✅ Expandable usage details UI
- ✅ Visual indicators for unused variables
- ✅ Story-level tag management integration

#### Deliverables
- **whisker-core:** 21 new tests (all passing)
- **whisker-editor-web:** 51 new tests (all passing)
- **Documentation:** PHASE3_IMPLEMENTATION.md (complete guide)
- **Example:** v2-story-features.whisker (492 lines, 15 passages)

#### Files Changed
- `lib/whisker/core/story.lua` (+159 lines, 17 new methods)
- `tests/test_story.lua` (+246 lines, 21 new tests)
- `src/lib/components/StorySettingsPanel.svelte` (new, 325 lines)
- `src/lib/models/Story.ts` (+106 lines, 9 new methods)
- `src/lib/models/Story.test.ts` (+296 lines, 36 new tests)

---

## Phase 4: Advanced Features & Integration 📋 PLANNING

**Status:** Planning Complete - Awaiting Direction
**Estimated Timeline:** 2-4 weeks
**Estimated Effort:** 60-120 hours (depends on option)

### Overview

Phase 4 offers multiple strategic directions. Each option provides distinct value and can be pursued independently or combined.

---

### Option A: Import & Format Conversion ⭐ RECOMMENDED

**Goal:** Enable import from other IF authoring tools (Twine, Ink, etc.)

#### Features

1. **Twine HTML Import**
   - Import Harlowe, SugarCube, Chapbook, Snowman stories
   - Automatic format detection
   - Conversion with loss reporting
   - Leverage whisker-core's existing parsers

2. **Ink Format Support**
   - Import .ink files
   - Map Ink constructs to whisker format
   - Preserve knots/stitches as passages

3. **Enhanced Import Dialog**
   - Format auto-detection
   - Preview before import
   - Merge vs. replace modes
   - Import validation with warnings

#### Implementation Approach

**Stage 1: Twine Import (4-6 hours)**
- Create TwineImporter class
- Format detection (HTML parsing)
- Basic conversion (passages + choices)

**Stage 2: Import UI (4-6 hours)**
- Enhanced ImportDialog component
- Format preview panel
- Conversion options
- Loss report display

**Stage 3: Validation & Testing (4-4 hours)**
- Conversion validators
- 30+ import tests
- Sample Twine files
- Documentation

#### Deliverables
- ✅ TwineImporter for all 4 Twine formats
- ✅ Enhanced ImportDialog UI
- ✅ Conversion preview
- ✅ Loss report system
- ✅ 30+ new tests
- ✅ Import documentation

**Total Effort:** 12-16 hours
**Impact:** HIGH - Opens whisker to existing IF communities
**Complexity:** MEDIUM - Parsers exist, need UI integration
**Risk:** LOW - Well-defined scope

---

### Option B: Advanced Scripting & Execution

**Goal:** More powerful conditional logic and story behavior

#### Features

1. **Enhanced Script Editor**
   - Lua syntax highlighting (Monaco Editor)
   - Auto-complete for story API
   - Inline error checking
   - Script snippets library

2. **Custom Functions System**
   - Define reusable story functions
   - Function library management
   - Import/export function modules
   - Scope management (global vs. story)

3. **Advanced Conditions**
   - Visual condition builder
   - Template expressions
   - Computed variables
   - Event system (on story start, on passage enter, etc.)

#### Implementation Approach

**Stage 1: Script Editor (8-10 hours)**
- Integrate Monaco Editor
- Lua language support
- Basic syntax checking

**Stage 2: Function System (6-8 hours)**
- Function library store
- Function editor UI
- Import/export functionality

**Stage 3: Execution Engine (4-6 hours)**
- Safe Lua executor (wasmoon)
- Sandbox configuration
- Event system hooks

#### Deliverables
- ✅ Monaco-based script editor
- ✅ Function library system
- ✅ Visual condition builder
- ✅ Lua execution sandbox
- ✅ 40+ new tests
- ✅ Scripting guide

**Total Effort:** 18-24 hours
**Impact:** HIGH - Enables complex game mechanics
**Complexity:** HIGH - Requires runtime integration
**Risk:** MEDIUM - Security concerns with Lua execution

---

### Option C: Story Analytics & Playtesting

**Goal:** Understand how players experience your story

#### Features

1. **Playthrough Recording**
   - Record player paths through story
   - Decision frequency tracking
   - Time-per-passage metrics
   - Abandonment points

2. **Analytics Dashboard**
   - Visual decision tree with usage stats
   - Popular/unpopular paths
   - Variable value distributions
   - Completion rate by path

3. **Testing Tools**
   - Automated story walkthrough (test all paths)
   - Edge case detection
   - Choice coverage report
   - Dead end finder

#### Implementation Approach

**Stage 1: Recording System (8-10 hours)**
- Playthrough data model
- Recording service
- Storage adapter

**Stage 2: Analytics Dashboard (8-10 hours)**
- Visualization components
- Statistics calculations
- Report generation

**Stage 3: Testing Tools (4-6 hours)**
- Auto-walkthrough algorithm
- Coverage analysis
- Test report UI

#### Deliverables
- ✅ Playthrough recording system
- ✅ Analytics dashboard
- ✅ Coverage reports
- ✅ Auto-testing tools
- ✅ 35+ new tests
- ✅ Analytics guide

**Total Effort:** 20-26 hours
**Impact:** MEDIUM-HIGH - Helps authors improve stories
**Complexity:** MEDIUM - Data collection + visualization
**Risk:** LOW - No external dependencies

---

### Option D: Publishing & Hosting

**Goal:** One-click publishing to the web

#### Features

1. **Built-in Web Hosting**
   - Export to static site
   - Custom domain support
   - Password protection
   - Version management

2. **Platform Integrations**
   - itch.io direct upload
   - Philomena (IF Archive) submission
   - GitHub Pages deployment
   - Netlify/Vercel integration

3. **Sharing Features**
   - Public story links
   - Embed code generation
   - Social media preview cards
   - QR code for mobile access

#### Implementation Approach

**Stage 1: Static Site Generator (6-8 hours)**
- HTML template with player
- Build pipeline
- Asset bundling

**Stage 2: Platform Integrations (6-8 hours)**
- itch.io API client
- GitHub API client
- OAuth flows

**Stage 3: Sharing UI (4-6 hours)**
- Publish dialog
- Link management
- Embed code generator

#### Deliverables
- ✅ Static site generator
- ✅ itch.io integration
- ✅ GitHub Pages deploy
- ✅ Sharing tools
- ✅ 25+ new tests
- ✅ Publishing guide

**Total Effort:** 16-22 hours
**Impact:** HIGH - Removes publishing friction
**Complexity:** MEDIUM - Mostly API integration
**Risk:** MEDIUM - Depends on external services

---

### Option E: Plugin System & Extensibility

**Goal:** Allow community extensions

#### Features

1. **Plugin Architecture**
   - Plugin manifest format
   - Hot-loading plugins
   - Plugin marketplace
   - Version management

2. **Extension Points**
   - Custom validators
   - Custom exporters
   - Custom graph layouts
   - Custom UI panels
   - Custom story formats

3. **Developer Tools**
   - Plugin SDK/API docs
   - Plugin template generator
   - Testing framework for plugins
   - Plugin debugging tools

#### Implementation Approach

**Stage 1: Architecture (10-12 hours)**
- Plugin manifest schema
- Plugin loader service
- Extension point system

**Stage 2: Extension Points (8-10 hours)**
- Validator plugins
- Exporter plugins
- UI panel plugins

**Stage 3: Developer Tools (6-8 hours)**
- Plugin SDK
- Template generator
- Documentation

#### Deliverables
- ✅ Plugin system architecture
- ✅ 5 extension points
- ✅ Plugin SDK
- ✅ Example plugins
- ✅ 45+ new tests
- ✅ Plugin development guide

**Total Effort:** 24-30 hours
**Impact:** VERY HIGH - Enables community growth
**Complexity:** VERY HIGH - Architecture change
**Risk:** HIGH - Requires careful API design

---

### Option F: Internationalization (i18n)

**Goal:** Multi-language story support

#### Features

1. **Translation Management**
   - Define translation keys
   - Translation editor UI
   - Import/export translations (PO, JSON, XLIFF)
   - Missing translation detection

2. **Runtime i18n**
   - Language switching at runtime
   - Pluralization rules
   - Date/number formatting
   - RTL language support

3. **Multi-language Stories**
   - Parallel passage translations
   - Language-specific content
   - Translation coverage report
   - Translation testing tools

#### Implementation Approach

**Stage 1: Translation System (8-10 hours)**
- Translation data model
- Key extraction
- Translation store

**Stage 2: UI Integration (6-8 hours)**
- Translation editor
- Language switcher
- Format support

**Stage 3: Runtime Support (4-6 hours)**
- Runtime language switching
- Pluralization
- RTL support

#### Deliverables
- ✅ Translation management system
- ✅ Translation editor UI
- ✅ Runtime i18n support
- ✅ Export formats
- ✅ 30+ new tests
- ✅ i18n guide

**Total Effort:** 18-24 hours
**Impact:** MEDIUM - Opens global market
**Complexity:** MEDIUM-HIGH - Complex text handling
**Risk:** MEDIUM - Requires format changes

---

## Phase 4 Decision Matrix

| Option | Effort | Impact | Complexity | Risk | Recommendation |
|--------|--------|--------|------------|------|----------------|
| **A: Import/Conversion** | 12-16h | HIGH | MEDIUM | LOW | ⭐ **RECOMMENDED** |
| **B: Scripting** | 18-24h | HIGH | HIGH | MEDIUM | Consider for Phase 5 |
| **C: Analytics** | 20-26h | MED-HIGH | MEDIUM | LOW | Good secondary choice |
| **D: Publishing** | 16-22h | HIGH | MEDIUM | MEDIUM | Strong alternative |
| **E: Plugins** | 24-30h | VERY HIGH | VERY HIGH | HIGH | Future (Phase 6+) |
| **F: i18n** | 18-24h | MEDIUM | MED-HIGH | MEDIUM | Future (Phase 7+) |

---

## Recommended Path Forward

### Primary Recommendation: **Option A (Import & Conversion)**

**Rationale:**
1. **Immediate Value** - Many IF authors already have Twine stories they want to convert
2. **Low Risk** - Parsers already exist in whisker-core, just need UI integration
3. **Clear Scope** - Well-defined deliverables with minimal unknowns
4. **Community Growth** - Lowers barrier to entry for existing IF community
5. **Foundation** - Enables future format support (Ink, ChoiceScript, etc.)

### Alternative: **Hybrid Approach**

**Phase 4a:** Import/Conversion (Option A) - 12-16 hours
**Phase 4b:** Scripting OR Publishing (Option B or D) - 18-24 hours

This provides both **breadth** (import capabilities) and **depth** (advanced features) in a single phase cycle.

---

## Testing Strategy

### Unit Tests
- All new components (100% coverage target)
- All new services and stores
- All format converters
- All validation logic

### Integration Tests
- Import → Edit → Export workflows
- End-to-end conversion tests
- Cross-format compatibility

### End-to-End Tests
- Complete user workflows
- Performance benchmarks
- Accessibility compliance

### Regression Tests
- Backward compatibility
- Migration from old versions
- Edge cases and error handling

---

## Success Criteria

### Phase 4 Success Metrics

**Option A (Import):**
- [ ] Import Twine stories in all 4 formats with >90% accuracy
- [ ] Loss report correctly identifies unconverted features
- [ ] Import dialog provides clear preview and options
- [ ] All tests pass (30+ new tests)

**Option B (Scripting):**
- [ ] Monaco editor integrated with Lua syntax
- [ ] Lua execution in sandbox with security guarantees
- [ ] Function library system working end-to-end
- [ ] All tests pass (40+ new tests)

**Option C (Analytics):**
- [ ] Record complete playthrough data
- [ ] Analytics dashboard visualizes all key metrics
- [ ] Auto-testing covers 100% of story paths
- [ ] All tests pass (35+ new tests)

**Option D (Publishing):**
- [ ] One-click publish to itch.io
- [ ] GitHub Pages deployment working
- [ ] Generated sites fully functional
- [ ] All tests pass (25+ new tests)

### Overall Success
- [ ] No regressions in existing functionality
- [ ] Performance meets targets (< 100ms for operations)
- [ ] Documentation complete and published
- [ ] User feedback positive (if applicable)

---

## Dependencies

### Option A Dependencies
```json
{
  "dependencies": {
    "jsdom": "^23.0.0"         // HTML parsing for Twine import
  }
}
```

### Option B Dependencies
```json
{
  "dependencies": {
    "wasmoon": "^1.16.0",      // Lua VM in WebAssembly
    "monaco-editor": "^0.45.0" // Code editor
  }
}
```

### Option C Dependencies
```json
{
  "dependencies": {
    "d3": "^7.8.0",            // Data visualization
    "recharts": "^2.10.0"      // Charts library (alternative)
  }
}
```

### Option D Dependencies
```json
{
  "dependencies": {
    "@octokit/rest": "^20.0.0" // GitHub API client
  }
}
```

---

## Risk Assessment

### Common Risks (All Options)

**Risk: Feature Creep**
- **Mitigation:** Strict scope control, well-defined deliverables
- **Severity:** MEDIUM
- **Likelihood:** HIGH

**Risk: Testing Gaps**
- **Mitigation:** Test-driven development, 100% coverage target
- **Severity:** HIGH
- **Likelihood:** MEDIUM

**Risk: Performance Degradation**
- **Mitigation:** Benchmarking, performance budgets
- **Severity:** MEDIUM
- **Likelihood:** LOW

### Option-Specific Risks

See individual option sections above for specific risks and mitigations.

---

## Timeline Estimates

### Single-Option Timeline (Option A Recommended)
- **Week 1:** Implementation (Stage 1-2)
- **Week 2:** Testing + Documentation (Stage 3)
- **Week 3:** Polish + Bug fixes

### Hybrid Timeline (Option A + B or D)
- **Week 1-2:** Option A (Import)
- **Week 3-4:** Option B or D (Advanced features)
- **Week 5:** Integration testing + Polish

---

## Next Steps

1. **Choose Direction** - Select primary option(s) for Phase 4
2. **Create Feature Branch** - `feature/phase-4-[option-name]`
3. **Set Up Project Board** - Track tasks and progress
4. **Begin Implementation** - Start with Stage 1 of chosen option
5. **Iterate** - Regular testing and refinement

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-10-27 | Initial alignment plan | Claude Code |
| 2.0 | 2025-10-27 | Updated with Phase 1-3 completion, Phase 4 options | Claude Code |

---

## References

- **Original Alignment Plan:** `WHISKER_CORE_ALIGNMENT_PLAN.md` (now superseded by this document)
- **Phase 3 Implementation:** `whisker-editor-web/PHASE3_IMPLEMENTATION.md`
- **whisker-core Changelog:** `whisker-core/CHANGELOG.md`
- **API Reference:** `whisker-core/docs/API_REFERENCE.md`

---

**Document Status:** ✅ Complete - Ready for Decision
**Approval Required:** Choose Phase 4 direction
**Next Review:** After Phase 4 completion
