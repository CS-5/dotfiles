# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://www.chezmoi.io/). It contains configuration files for various development tools including Git, Fish shell, SSH, Docker, and development environments.

## Key Scripts

### Installation Scripts

- `./scripts/install-dotfiles.sh` - Standard installation script that installs chezmoi and applies dotfiles
- `./install.sh` - Development container installation script with optional work mode

### Development Scripts  

- `./render.sh [template-file]` - Renders chezmoi templates to stdout for testing

## Architecture

### Template System

- All configuration files are in `root/` directory as chezmoi templates (`.tmpl` extension)
- `.chezmoi.toml.tmpl` defines data variables and environment detection
- Templates use Go template syntax with conditional logic for different environments

### Environment Detection

The dotfiles adapt based on environment variables:

- `REMOTE_CONTAINERS_IPC` - Detects dev container environment
- `DOTFILES_WORK_DC` - Forces work dev container configuration
- `CODESPACES` - Detects GitHub Codespaces environment (disables SSH agent, GPG signing)
- `DOTFILES_SOURCE_DIR` - Override source directory (defaults to current directory for install.sh)

### Configuration Variants

- **Personal**: Default configuration using personal email/SSH keys
- **Work Dev Container**: Uses work email, includes additional tools, separate git config

### Chezmoi Automation Scripts

Post-install scripts in `root/.chezmoiscripts/` run automatically during `chezmoi apply`:

- `run_once_after_install-starship.sh.tmpl` - Installs Starship prompt
- `run_after_install-claude-config.sh.tmpl` - Syncs Claude Code configuration
- `run_onchange_after_install-completions.sh.tmpl` - Generates fish completions for `gh` and `docker`

### External File Management

- `root/.chezmoiexternal.toml.tmpl` - Pulls external dependencies (fundle, eget binaries)
- `root/.chezmoiignore.tmpl` - Controls which files chezmoi ignores per environment

### Key Files

- `root/.chezmoi.toml.tmpl` - Main chezmoi configuration with environment variables
- `root/dot_gitconfig.tmpl` - Git configuration with conditional work includes
- `root/dot_gitconfig-work.tmpl` - Work-specific git configuration
- `root/private_dot_config/fish/config.fish.tmpl` - Fish shell configuration
- `root/dot_bashrc.tmpl` - Bash configuration (Homebrew, starship, mise, zoxide, mcfly)
- `root/dot_zshrc.tmpl` - Zsh configuration

## Common Commands

```bash
# Install dotfiles
./scripts/install-dotfiles.sh

# Install tools + dotfiles in dev container
./install.sh

# Test template rendering
./render.sh root/dot_gitconfig.tmpl

# Manual chezmoi operations (after install)
chezmoi diff                 # Show pending changes
chezmoi apply               # Apply changes
chezmoi status              # Show status
```

## Development Guidelines

### Change Management

1. **Changes must be extremely thoughtful** - Ensure any modification is thoroughly tested and validated before considering it final. No mistakes are acceptable.

2. **Keep changes simple and maintainable** - If a change grows in complexity, ask for feedback/instruction or suggest ways to refine the scope to remain simple and maintainable.

3. **Documentation maintenance** - Regularly check and update documentation (including AGENTS.md) for stale content when patterns or configurations change.

4. **Template formatting** - Template files containing Go template strings must be formatted carefully to preserve correct whitespace and avoid trimming issues.

5. **NEVER test on host machine** - Changes must never be tested on the host machine. `chezmoi apply` should be considered dangerous unless run within a Docker container.
