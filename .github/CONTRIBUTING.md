# Contributing to helpers4

Thank you for your interest in contributing to helpers4! We love your input and want to make the process as easy and transparent as possible.

## Our Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Bugs

- **Search first** - Check existing issues to avoid duplicates
- **Clear description** - Include steps to reproduce, expected vs. actual behavior
- **Environment info** - Node version, OS, package versions
- **Minimal example** - Provide a small code sample if possible

### Suggesting Enhancements

- **Clear use case** - Explain why the enhancement would be useful
- **Examples** - Show how you'd use it
- **Research** - Look for existing solutions or similar features

### Pull Requests

1. **Fork and clone** the repository
2. **Create a feature branch**: `git checkout -b feat/description`
3. **Keep commits clean**: Use conventional commits
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation
   - `refactor:` - Code refactoring
   - `test:` - Tests
4. **Add tests** if applicable
5. **Update docs** if needed
6. **Push and create PR** with clear description

### Conventional Commits

We follow [Conventional Commits](https://www.conventionalcommits.org/) for better changelog generation:

```bash
feat: add new array utility
fix: correct type definition
docs: update installation guide
refactor: simplify function logic
test: add edge case coverage
```

## Development Setup

```bash
# Install dependencies
pnpm install

# Run tests
pnpm test

# Run linter
pnpm lint

# Build
pnpm build

# Type check
pnpm typecheck
```

## Project Structure

Each repository follows a consistent structure:
- `features/` - Features source code
- `test/` - Test files
- `build/` - Build output (generated)
- `.github/` - GitHub configuration
- `docs/` - Documentation

## Contributing Owners

- **@baxyz** - Owner and maintainer

## Guidelines

### Code Style

- Follow existing code patterns
- Use TypeScript with strict mode
- Ensure type safety
- Write descriptive variable/function names

### Testing

- Add tests for new features
- Ensure all tests pass locally
- Aim for good coverage on critical paths

### Documentation

- Update README for user-facing changes
- Add/update JSDoc comments
- Update CHANGELOG if applicable

### Git Workflow

1. Sync with main branch: `git fetch origin && git rebase origin/main`
2. Create feature branch: `git checkout -b feat/description`
3. Make changes with clean commits
4. Push: `git push origin feat/description`
5. Create PR on GitHub

### Before Submitting

- ✅ Tests pass locally
- ✅ Code lints without errors
- ✅ No unnecessary comments or console logs
- ✅ Changes follow conventions
- ✅ Commit messages are clear

## Questions or Need Help?

Open an issue with your question. We're here to help!

---

**Happy contributing!** 🎉
