# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://www.chezmoi.io/). It contains configuration files for various development tools including Git, Fish shell, SSH, Docker, and development environments.

For comprehensive chezmoi documentation, reference guides, and tutorials, visit: <https://www.chezmoi.io/>

## Key Scripts

### Installation Scripts

- `./install.sh` - Standard installation script that installs chezmoi and applies dotfiles
- `./devcontainer.sh` - Development container installation script with optional work mode

### Development Scripts  

- `./render.sh [template-file]` - Renders chezmoi templates to stdout for testing
- `./test.sh [environment] [options]` - Comprehensive testing script using Docker containers to validate installations

## Architecture

### Template System

- All configuration files are in `root/` directory as chezmoi templates (`.tmpl` extension)
- `.chezmoi.toml.tmpl` defines data variables and environment detection
- Templates use Go template syntax with conditional logic for different environments

### Environment Detection

The dotfiles adapt based on environment variables:

- `REMOTE_CONTAINERS_IPC` - Detects dev container environment
- `DOTFILES_WORK_DC` - Forces work dev container configuration
- `DOTFILES_SOURCE_DIR` - Override source directory (defaults to current directory for install.sh)

### Configuration Variants

- **Personal**: Default configuration using personal email/SSH keys
- **Work Dev Container**: Uses work email, includes additional tools, separate git config

### Key Files

- `root/.chezmoi.toml.tmpl` - Main chezmoi configuration with environment variables
- `root/dot_gitconfig.tmpl` - Git configuration with conditional work includes
- `root/dot_gitconfig-work.tmpl` - Work-specific git configuration
- `root/private_dot_config/fish/config.fish.tmpl` - Fish shell configuration

## Common Commands

```bash
# Install dotfiles
./install.sh

# Install dev container variants
./devcontainer.sh            # Personal dev container
./devcontainer.sh --work     # Work dev container (includes GitHub CLI)

# Test template rendering
./render.sh root/dot_gitconfig.tmpl

# Run comprehensive tests
./test.sh                    # All environments
./test.sh debian-basic       # Basic Debian only
./test.sh debian-work-devcontainer  # Work dev container only

# Test with interactive shell access
./test.sh debian-basic --interactive              # Drop into shell after test
./test.sh debian-work-devcontainer --interactive  # Debug in container

# Test options
./test.sh --no-cleanup       # Keep containers after testing
./test.sh --timeout 600      # Set custom timeout (seconds)

# Manual chezmoi operations (after install)
chezmoi diff                 # Show pending changes
chezmoi apply               # Apply changes
chezmoi status              # Show status
```

## Testing

The repository includes comprehensive Docker-based testing via `test.sh`:

- Tests multiple environments (debian-basic, debian-work-devcontainer)
- Validates file installation, directory creation, and tool functionality
- Uses timeout protection and proper cleanup
- Provides detailed validation output
- Supports interactive mode for debugging and manual validation
- Automatic cleanup can be disabled for container inspection
- Failures in any scripts (`test.sh`, `devcontainer.sh`, etc.) and/or failures in the container config should be considered test failures, even if the tests did not run and explicitly fail.

### Testing Features

- `--interactive` - Drop into container shell after test completion for manual validation
- `--no-cleanup` - Keep containers running after tests for inspection
- `--timeout SECONDS` - Custom timeout per test (default: 300 seconds)

When making changes, always run `./test.sh` to ensure compatibility across environments. Use `--interactive` mode to manually verify functionality.

## Development Guidelines

### Change Management

1. **Changes must be extremely thoughtful** - Ensure any modification is thoroughly tested and validated before considering it final. No mistakes are acceptable.

2. **Keep changes simple and maintainable** - If a change grows in complexity, ask for feedback/instruction or suggest ways to refine the scope to remain simple and maintainable.

3. **Documentation maintenance** - Regularly check and update documentation (including AGENT.md) for stale content when patterns or configurations change.

4. **Template formatting** - Template files containing Go template strings must be formatted carefully to preserve correct whitespace and avoid trimming issues.

5. **NEVER test on host machine** - Changes must never be tested on the host machine. `chezmoi apply` should be considered dangerous unless run within a Docker container. Always use `./test.sh` for validation.
