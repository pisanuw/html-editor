
2026-05-22 code Implement 6 remaining features: word wrap wiring, breadcrumb bar UI, HTML validation, diff gutter markers, CSS color swatches, minimap

2026-05-22 note Session close — all 12 gap features implemented; README updated; build fix: added import Combine to FileSidebarView.swift

2026-06-10 [code] audit-repo-artifacts: added .gitignore, untracked .build/ .app bundles AI-log.md; purged history with git-filter-repo; .git shrank from 225MB to 360KB

2026-06-10 [code] audit-ci-gates: created .github/workflows/ci.yml (swift build + swift test on macos-latest); fixed 3 pre-existing test compilation failures; 191 tests green on first CI run

2026-06-10 [doc] audit-history-and-presentation: fixed README duplicate entry, updated SETUP.md file lists, added CLAUDE.md with commit convention, added .githooks/commit-msg Conventional Commits hook, set GitHub description and topics

2026-06-10 [code] report fixes: removed HTMLEditor/.DS_Store, added TextMetrics.offset(ofLine:in:), IDKeyedStore<V>, 12 new tests (203 total), CI pinned to macos-14 with coverage
