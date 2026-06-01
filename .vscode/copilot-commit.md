<!-- auto-generated — source of truth: conventionalCommits.scopes in .vscode/settings.json -->
<!-- to regenerate: run `pnpm sync-copilot` in the .dev orchestrator repo -->

Commit messages for the **devcontainer** repository must use Conventional Commits + gitmoji:

`<type>(<scope>): <emoji> <description>`

**Allowed scopes** (pick one, or omit the scope entirely):
- `angular-dev`
- `auto-header`
- `claude-dev`
- `deps`
- `deps-dev`
- `CI-CD`
- `deprecated`
- `dotfiles-sync`
- `essential-dev`
- `git-absorb`
- `github-dev`
- `package-auto-install`
- `peon-ping`
- `pnpm-store`
- `shell-history-per-project`
- `typescript-dev`
- `vite-plus`

Never invent a scope that is not in the list above.

**Type → gitmoji** — pick the most specific emoji that fits the change:

| Type | Primary | More specific alternatives |
|------|---------|---------------------------|
| `feat` | ✨ | 🚸 UX · ♿️ a11y · 🌐 i18n · 💬 text/literals |
| `fix` | 🐛 | 🚑️ hotfix · 🔒️ security · 🩹 trivial · 🥅 caught errors · 🚨 linter warnings · ✏️ typo |
| `docs` | 📝 | 💡 source comments · 📄 license |
| `refactor` | ♻️ | 🎨 structure · 🔥 remove code · ⚰️ dead code · 🚚 move/rename |
| `test` | ✅ | 🧪 add failing test · 💚 fix CI test |
| `chore` | 🔧 | 🔖 tag/release · 📌 pin deps · 🩺 healthcheck · 🙈 gitignore |
| `perf` | ⚡️ | |
| `style` | 💄 | 🎨 code style |
| `ci` | 👷 | 💚 fix CI |
| `build` | 📦️ | ➕ add dep · ➖ remove dep · ⬆️ upgrade dep · ⬇️ downgrade dep |
| `revert` | ⏪️ | |

**Rules:**
- Always include exactly **one** emoji, placed between `:` and the description
- Description: ≤72 chars · English · lowercase · imperative mood · no trailing period
- Multiple logical changes → keep the dominant type in the subject line and use a bullet list in the body
