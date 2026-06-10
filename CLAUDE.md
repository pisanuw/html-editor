# Claude Code instructions for html-editor

## Commit convention

All commits must follow **Conventional Commits**. The hook in `.githooks/commit-msg` enforces this; activate it with:

```bash
git config core.hooksPath .githooks
```

Format: `type(scope): subject`

| Type | Use for |
|---|---|
| `feat` | New user-visible feature |
| `fix` | Bug fix |
| `docs` | README, comments, SETUP.md |
| `refactor` | Code restructure, no behavior change |
| `test` | Adding or fixing tests |
| `chore` | Build, CI, tooling, .gitignore |
| `ci` | GitHub Actions workflows |
| `perf` | Performance improvements |
| `style` | Formatting only |

Scope is optional but encouraged: `feat(emmet):`, `fix(folding):`, `chore(ci):`.

## Project layout

- `HTMLEditor/HTMLEditor/Core/` — pure Foundation logic, unit-tested via `swift test`
- `HTMLEditor/HTMLEditor/` — AppKit/SwiftUI shell (not testable without a display)
- `Tests/HTMLEditorCoreTests/` — XCTest suite (203 tests)
- `Package.swift` — SwiftPM package for Core + tests only
