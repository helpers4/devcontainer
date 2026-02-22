# DevContainer Features Development

## Structure
- `features/` - Contains the features
- `test/` - Contains test scripts for each feature
- `.github/workflows/` - CI/CD pipelines

## Development workflow
1. Create feature in `features/<feature-name>/`
2. Add test script in `test/<feature-name>/`
3. Test locally with devcontainer CLI
4. Submit PR for review
5. Tag release to publish to GHCR

## Testing
Run tests locally:
```bash
devcontainer features test --features <feature-name> .
```

## Publishing
Create a git tag to trigger release:
```bash
git tag v1.0.0
git push origin v1.0.0
```
