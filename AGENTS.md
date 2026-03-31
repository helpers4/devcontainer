# AGENTS.md - AI Coding Agent Instructions

This file provides context and guidelines for AI coding agents (GitHub Copilot, Claude, etc.) working on helpers4 repositories.

## ⛔ CRITICAL RESTRICTIONS

### Forbidden Actions
- **NEVER execute `git push`** - The user will push manually after review
- **NEVER use GPT models** - Use Claude models only (claude-sonnet-4, Claude Opus 4.5)

### Model Restriction Rationale
Claude models have shown consistent behavior with this codebase's coding conventions and TypeScript strict mode requirements. GPT models are not preferred for this project.

## Organization Overview

**helpers4** is a collection of open-source utilities:
- **typescript**: Tree-shakable TypeScript utility functions (12+ categories)
- **devcontainer**: Development container features for consistent environments
- **action**: GitHub Actions for automation and CI/CD workflows
- **website**: Documentation and landing page

## General Principles

### Code Style
- Use TypeScript with strict mode enabled
- Avoid `any` type - use `unknown` or specific types instead
- Include JSDoc comments with `@param`, `@returns`, `@example`
- Use 2-space indentation
- Use single quotes for strings
- Prefer descriptive variable and function names

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) with a gitmoji between the scope and the description.

**Format:** `<type>(<scope>): <emoji> <description>`

**Examples:**
- `feat(git-absorb): ✨ add version selection option`
- `fix(local-mounts): 🐛 fix symlink creation`
- `docs(typescript-dev): 📝 update README`
- `chore(CI-CD): 🔧 update dependencies`

**Scopes:** angular-dev, git-absorb, local-mounts, package-auto-install, shell-history-per-project, typescript-dev, vite-plus, CI-CD

**Types:**
| Emoji | Type | Description |
|-------|------|-------------|
| ✨ | feat | New feature |
| 🐛 | fix | Bug fix |
| 📝 | docs | Documentation |
| ♻️ | refactor | Code refactoring |
| ✅ | test | Tests |
| 🔧 | chore | Maintenance |
| 🚀 | perf | Performance |
| 💄 | style | Code style |
| 👷 | ci | CI/CD |
| 📦 | build | Build system |
| ⏪ | revert | Revert |

### Testing

- Add tests for new features
- Ensure all tests pass locally
- Use the test framework specified in each repository
- Aim for good coverage on critical paths

### Documentation

- Update README for user-facing changes
- Add/update comments for complex logic
- Update CHANGELOG if provided

## Repository-Specific Guidelines

### TypeScript (`helpers4/typescript`)

**Purpose**: Utility functions organized by category (array, date, object, promise, string, etc.)

**Tech Stack**:
- Node.js >= 24.0.0
- TypeScript 5.x
- Vite + Rollup for builds
- Vitest for testing
- oxlint for linting

**Key Rules**:
- Tree-shakable exports only
- One helper function per file
- Tests colocated (`.test.ts` or `.spec.ts`)
- Each category has `index.ts` for re-exports
- License header required on all source files

**Commands**:
```bash
pnpm test              # Run tests
pnpm build             # Build all packages
pnpm typecheck         # TypeScript check
pnpm lint              # Lint with oxlint
```

### DevContainer (`helpers4/devcontainer`)

**Purpose**: Development container features for consistent dev environments

**Tech Stack**:
- Docker-based dev containers
- Various feature packages (typescript-dev, vite-plus, git-absorb, etc.)

**Key Files**:
- `devcontainer-feature.json` - Feature metadata
- `install.sh` - Feature installation script
- `test.sh` - Feature tests

### Action (`helpers4/action`)

**Purpose**: GitHub Actions for workflow automation

**Key Files**:
- `action.yml` - Action metadata
- `scripts/` - Implementation scripts
- `README.md` - Usage documentation

### Website (`helpers4/website`)

**Purpose**: Documentation portals and landing page

**Tech Stack**:
- Qwik (landing page)
- Docusaurus (documentation portals)
- Vite for builds

**Sections**:
- `/`: Landing page
- `/ts`: TypeScript documentation
- `/dev-container`: DevContainer documentation
- `/action`: GitHub Actions documentation

## Common Tasks

### Adding a Feature
1. Create your changes
2. Add tests
3. Follow commit conventions
4. Ensure tests pass locally
5. Create clear PR description

### Fixing a Bug
1. Identify root cause
2. Write minimal fix
3. Add test case for the bug
4. Verify no regressions

### Updating Documentation
1. Keep changes accurate and current
2. Use clear, concise language
3. Include code examples where helpful
4. Test links and examples

## Contributing Owners

- **@baxyz** - Organization owner and maintainer

## Important Notes

- **Open communication**: Ask questions in issues/PRs if unclear
- **Test locally**: Always verify changes work locally first
- **Review existing code**: Understand patterns before implementing
- **Backward compatibility**: Consider implications for existing users
- **Type safety**: Maintain strong typing across the project

## Repository Links

- TypeScript: https://github.com/helpers4/typescript
- DevContainer: https://github.com/helpers4/devcontainer
- Actions: https://github.com/helpers4/action
- Website: https://github.com/helpers4/website
- Organization: https://github.com/helpers4

## Questions?

If you need clarification on any aspect, open an issue or comment on the PR. We're here to help!
