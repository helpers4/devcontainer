# Angular Development Environment (angular-dev)

Angular-specific development environment with port forwarding, VS Code extensions, and CLI autocompletion.

## Features

- **Port forwarding**: Port 4200 automatically forwarded for `ng serve`
- **VS Code extensions**: Essential Angular development extensions pre-installed
- **CLI autocompletion**: Tab completion for Angular CLI commands in zsh and bash
- **Optional CLI installation**: Install Angular CLI globally if needed

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {}
    }
}
```

### With Angular CLI installation

If you want to install Angular CLI as part of this feature:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {
            "installCli": true
        }
    }
}
```

### Recommended setup with Node.js

```json
{
    "features": {
        "ghcr.io/devcontainers/features/node:1": {
            "version": "20"
        },
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {
            "installCli": true
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installCli` | boolean | `false` | Install Angular CLI globally |

## VS Code Extensions Included

| Extension | Description |
|-----------|-------------|
| `angular.ng-template` | Angular Language Service |
| `johnpapa.angular2` | Angular Snippets |
| `infinity1207.angular2-switcher` | Switch between component files |
| `alexiv.vscode-angular2-files` | Generate Angular files |
| `obenjiro.arrr` | Angular Refactoring Tools |
| `john-crowson.angular-file-changer` | Quick file navigation |
| `cyrilletuzi.angular-schematics` | Angular Schematics integration |

## Port Configuration

| Port | Purpose | Auto-forward |
|------|---------|--------------|
| 4200 | Angular Dev Server | Yes (notify) |

## CLI Autocompletion

Angular CLI autocompletion is automatically configured for both zsh and bash shells. After the container starts, you can use tab completion for:

- `ng <tab>` - Show available commands
- `ng generate <tab>` - Show schematic types
- `ng add <tab>` - Show available packages

## Working with Angular

### Create a new application

```bash
ng new my-app --routing --style=scss
cd my-app
ng serve
```

### Generate components

```bash
ng generate component features/user-profile
ng generate service core/api
ng generate module shared --routing
```

### Build for production

```bash
ng build --configuration production
```

## Troubleshooting

### Angular CLI not found
If `ng` command is not available:
1. Ensure Node.js feature is installed before this feature
2. Set `installCli: true` in the feature options
3. Or install manually: `npm install -g @angular/cli`

### Autocompletion not working
- Start a new terminal session after container creation
- Ensure you're using zsh or bash shell
- Check that Angular CLI is installed: `which ng`

### Port 4200 not accessible
- Check if another process is using port 4200
- Verify the dev server is running: `ng serve`
- Check VS Code's Ports panel for forwarding status
