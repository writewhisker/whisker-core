# Documentation Guidelines

**Purpose:** Guide for determining where to place documentation across the whisker ecosystem.

---

## Quick Reference

| Document Type | Repository | Location |
|--------------|------------|----------|
| Planning docs | whisker-implementation | `visual-editor/editor-web/` or `core/` |
| Phase plans | whisker-implementation | `visual-editor/editor-web/phases/` |
| Status tracking | whisker-implementation | `visual-editor/editor-web/` |
| Design decisions | whisker-implementation | Relevant subdirectory |
| API documentation | whisker-core | `docs/` |
| User guides | whisker-core | Root or `docs/` |
| Technical architecture | whisker-editor-web | Root |
| Testing guides | whisker-editor-web | Root or `e2e/` |
| Getting started | Public repos | `README.md` |

---

## Decision Tree

### Is this documentation about planning, design, or status?
**YES** → Place in **whisker-implementation** (private)
- Examples: Phase plans, reconciliation docs, roadmaps, design decisions, status updates
- Location: Organize by project (`visual-editor/editor-web/`, `core/`, etc.)

**NO** → Continue to next question ↓

### Is this documentation about the Lua library API or authoring stories?
**YES** → Place in **whisker-core** (public, MIT)
- Examples: API reference, format specs, authoring guides, examples
- Location: `docs/` for technical docs, root for user guides

**NO** → Continue to next question ↓

### Is this documentation about web editor implementation or testing?
**YES** → Place in **whisker-editor-web** (public, AGPL-3.0)
- Examples: Architecture docs, testing guides, E2E test README
- Location: Root for main docs, `e2e/` for E2E-specific docs

---

## Repository-Specific Guidelines

### whisker-implementation (Private)

**Purpose:** Planning, design, and strategic documentation

**Place here:**
- ✅ Phase implementation plans
- ✅ Status tracking (reconciliation docs)
- ✅ Design decisions and architecture planning
- ✅ Roadmaps and feature planning
- ✅ Development timelines
- ✅ Strategic planning documents
- ✅ Bug fix logs (historical planning context)

**Directory structure:**
```
whisker-implementation/
├── visual-editor/
│   ├── VISUAL_EDITOR_PHASES.md          # Original specification
│   ├── VISUAL_EDITOR_MULTI_PLATFORM.md  # Platform strategy
│   └── editor-web/
│       ├── README.md                    # Overview
│       ├── PHASE_RECONCILIATION.md      # Status tracking
│       └── phases/
│           ├── PHASE_5_IMPLEMENTATION_PLAN.md
│           └── PHASE_6_IMPLEMENTATION_PLAN.md (future)
├── core/
│   ├── README.md                        # Core planning overview
│   ├── CRITICAL_FIXES_APPLIED.md        # Bug fix history
│   ├── LUA_RUNTIME_FIX_SUMMARY.md       # Runtime improvements
│   └── MUSEUM_RUNTIME.md                # Feature planning
├── testing/
│   └── ... (testing strategy planning)
└── planning/
    └── ... (general planning docs)
```

**DO NOT place here:**
- ❌ API documentation (goes to whisker-core)
- ❌ User tutorials (goes to whisker-core)
- ❌ Technical architecture (goes to whisker-editor-web)
- ❌ Testing guides (goes to whisker-editor-web)

---

### whisker-core (Public, MIT License)

**Purpose:** Technical/API documentation for the Lua library

**Place here:**
- ✅ API reference documentation
- ✅ User guides and tutorials
- ✅ Format specifications
- ✅ Technical implementation details
- ✅ Code examples
- ✅ Authoring guides

**Directory structure:**
```
whisker-core/
├── README.md                 # Library overview, installation
├── AUTHORING.md              # Story creation guide
├── TESTING.md                # Testing documentation
├── CONTRIBUTING.md           # Developer guidelines
├── docs/
│   ├── API_REFERENCE.md      # Complete API documentation
│   ├── GETTING_STARTED.md    # User tutorial
│   ├── COMPACT_FORMAT.md     # Format specification
│   ├── TWINE_IMPORT_EXPORT.md
│   └── ... (other technical docs)
└── examples/
    └── *.lua                 # Code examples
```

**DO NOT place here:**
- ❌ Planning documents (goes to whisker-implementation)
- ❌ Phase implementation plans (goes to whisker-implementation)
- ❌ Web editor architecture (goes to whisker-editor-web)

---

### whisker-editor-web (Public, AGPL-3.0 License)

**Purpose:** Technical implementation and user documentation for web editor

**Place here:**
- ✅ Getting started guides (README.md)
- ✅ Technical architecture documentation
- ✅ Testing guides
- ✅ E2E test documentation
- ✅ Contributing guidelines
- ✅ Community health files

**Directory structure:**
```
whisker-editor-web/
├── README.md                 # User-focused: features, getting started
├── ARCHITECTURE.md           # Technical architecture and patterns
├── TESTING.md                # Comprehensive testing guide
├── CONTRIBUTING.md           # Developer workflow
├── e2e/
│   └── README.md             # E2E testing details
└── src/
    └── ... (source code)
```

**DO NOT place here:**
- ❌ Planning documents (goes to whisker-implementation)
- ❌ Phase implementation plans (goes to whisker-implementation)
- ❌ Status tracking (goes to whisker-implementation)
- ❌ Design decisions (goes to whisker-implementation)

---

## Common Scenarios

### Scenario 1: Creating a new phase implementation plan
**Question:** Where do I place PHASE_6_IMPLEMENTATION_PLAN.md?

**Answer:** `whisker-implementation/visual-editor/editor-web/phases/PHASE_6_IMPLEMENTATION_PLAN.md`

**Reasoning:** Phase plans are planning documents, not technical documentation.

---

### Scenario 2: Documenting a new Lua API function
**Question:** Where do I document `whisker.choice()`?

**Answer:** `whisker-core/docs/API_REFERENCE.md` (update existing file)

**Reasoning:** API documentation belongs in the public core repository.

---

### Scenario 3: Explaining the component architecture
**Question:** Where do I document the Svelte component hierarchy?

**Answer:** `whisker-editor-web/ARCHITECTURE.md` (update existing file)

**Reasoning:** Technical architecture for the web editor belongs in its public repo.

---

### Scenario 4: Tracking feature completion status
**Question:** Where do I update status for Phase 6 completion?

**Answer:** `whisker-implementation/visual-editor/editor-web/PHASE_RECONCILIATION.md`

**Reasoning:** Status tracking is planning documentation.

---

### Scenario 5: Writing a user tutorial
**Question:** Where do I place a guide on writing branching stories?

**Answer:** `whisker-core/AUTHORING.md` or `whisker-core/docs/GETTING_STARTED.md`

**Reasoning:** User guides for story authoring belong in the core library docs.

---

### Scenario 6: Documenting test infrastructure
**Question:** Where do I document how to run E2E tests?

**Answer:** `whisker-editor-web/TESTING.md` and/or `whisker-editor-web/e2e/README.md`

**Reasoning:** Testing guides are technical documentation for contributors.

---

## Document Type Definitions

### Planning Documents
- Phase implementation plans
- Reconciliation documents
- Roadmaps
- Feature planning documents
- Development timelines
- Design decisions (pre-implementation)
- Status tracking

**→ Goes to whisker-implementation**

### Technical Documents
- API reference
- Architecture explanations
- Testing guides
- Technical implementation details
- Code documentation

**→ Goes to public repos (whisker-core or whisker-editor-web)**

### User Documents
- Getting started guides
- Tutorials
- Authoring guides
- Examples
- README files

**→ Goes to public repos (whisker-core or whisker-editor-web)**

---

## Why This Separation?

### Public Repositories (whisker-core, whisker-editor-web)
**Focus:** Help users and contributors understand and use the software

**Benefits:**
- Clear onboarding for new users
- Technical depth for contributors
- Professional public presence
- SEO and discoverability

### Private Repository (whisker-implementation)
**Focus:** Track planning, design decisions, and development status

**Benefits:**
- Keep internal planning private
- Track historical design decisions
- Maintain development context
- Organize work-in-progress documentation

---

## Checklist for New Documentation

Before creating a new document, ask:

- [ ] Is this about what we're planning to build? → whisker-implementation
- [ ] Is this about how the system works? → whisker-core or whisker-editor-web
- [ ] Is this about how to use the system? → whisker-core or whisker-editor-web
- [ ] Does this track progress or status? → whisker-implementation
- [ ] Is this a design decision? → whisker-implementation
- [ ] Is this API documentation? → whisker-core
- [ ] Is this web editor architecture? → whisker-editor-web

---

## Cross-Repository References

When linking between repositories:

### From public repos to whisker-implementation
```markdown
See [full roadmap](https://github.com/writewhisker/whisker-implementation/blob/main/visual-editor/editor-web/PHASE_RECONCILIATION.md)
```

### From whisker-implementation to public repos
```markdown
**Code Repository:** [whisker-editor-web](https://github.com/writewhisker/whisker-editor-web)
**Original Specification:** [VISUAL_EDITOR_PHASES.md](../VISUAL_EDITOR_PHASES.md)
```

---

## Updating These Guidelines

These guidelines exist in all three repositories:
- `whisker-implementation/DOCUMENTATION_GUIDELINES.md`
- `whisker-core/DOCUMENTATION_GUIDELINES.md`
- `whisker-editor-web/DOCUMENTATION_GUIDELINES.md`

Update them when:
- New repositories are added
- New documentation categories emerge
- The organization structure changes
- Common mistakes are identified

**Important:** Keep all three copies synchronized when making updates.

---

## Summary

**Three Repositories, Three Purposes:**

1. **whisker-implementation (Private)** → Planning, design, status
2. **whisker-core (Public, MIT)** → Lua library API, authoring guides
3. **whisker-editor-web (Public, AGPL-3.0)** → Web editor technical docs

**Golden Rule:** If it's about what we're building or planning to build, it goes in whisker-implementation. If it's about how to use or understand what we've built, it goes in the public repos.
