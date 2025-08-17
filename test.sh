#!/usr/bin/env bash

# Comprehensive Dotfiles Testing Script
# Tests chezmoi dotfiles installation across all target environments using Docker containers
# NEVER run chezmoi commands on the host machine - all testing happens in containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_TIMEOUT=300  # 5 minutes timeout per test
CLEANUP_ON_EXIT=true

# Test environments configuration
AVAILABLE_ENVIRONMENTS="debian-basic debian-work-devcontainer"

get_base_image() {
    case "$1" in
        debian-basic|debian-work-devcontainer)
            echo "debian:bookworm"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_env_vars() {
    case "$1" in
        debian-basic)
            echo ""
            ;;
        debian-work-devcontainer)
            echo "REMOTE_CONTAINERS_IPC=1 USER=vscode"
            ;;
    esac
}

get_install_script() {
    case "$1" in
        debian-basic)
            echo "./install.sh"
            ;;
        debian-work-devcontainer)
            echo "./install-work-dc.sh"
            ;;
    esac
}

usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT]

Test dotfiles installation in Docker containers for various environments.

Environments:
  debian-basic              Basic Debian installation (uses install.sh)
  debian-work-devcontainer  Debian work dev container simulation (uses install-work-dc.sh)
  all                       Run all tests (default)

Options:
  -h, --help          Show this help message
  --no-cleanup        Don't cleanup containers after testing
  --timeout SECONDS   Set timeout per test (default: 300)

Examples:
  $0                                        # Run all tests
  $0 debian-basic                           # Test only Debian basic
  $0 debian-work-devcontainer --no-cleanup  # Test work dev container, keep container

EOF
}

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $*"
}

cleanup_container() {
    local container_name="$1"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log "Cleaning up container: $container_name"
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
}

cleanup_all_test_containers() {
    for env in $AVAILABLE_ENVIRONMENTS; do
        cleanup_container "dotfiles-test-$env"
    done
}

# Cleanup on exit if enabled
trap 'if [ "$CLEANUP_ON_EXIT" = true ]; then cleanup_all_test_containers; fi' EXIT

validate_installation() {
    local container_name="$1"
    local env_name="$2"
    local validation_errors=0

    # Determine user home directory
    local user_home
    case "$env_name" in
        debian-work-devcontainer)
            user_home="/home/vscode"
            ;;
        *)
            user_home="/home/test"
            ;;
    esac

    log "Validating installation in $env_name (user: $user_home)..."

    # Check if chezmoi is installed and working
    if ! docker exec "$container_name" "$user_home/.local/bin/chezmoi" --version >/dev/null 2>&1; then
        log_error "chezmoi not installed or not working"
        ((validation_errors++))
    else
        log_success "chezmoi installed successfully"
    fi

    # Check if dotfiles are applied
    local expected_files=(
        ".gitconfig"
        ".bashrc" 
        ".config/fish/config.fish"
        ".config/starship.toml"
        ".config/mise/config.toml"
    )

    for file in "${expected_files[@]}"; do
        if docker exec "$container_name" test -f "$user_home/$file" 2>/dev/null; then
            log_success "File exists: $file"
        else
            log_warning "File missing: $file"
            ((validation_errors++))
        fi
    done

    # Check if scripts created expected directories
    local expected_dirs=(
        ".local/bin"
        ".config"
    )
    
    # .local/share is only expected for work dev container (created by chezmoi init)
    case "$env_name" in
        *work*)
            expected_dirs+=(".local/share")
            ;;
    esac

    for dir in "${expected_dirs[@]}"; do
        if docker exec "$container_name" test -d "$user_home/$dir" 2>/dev/null; then
            log_success "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
            ((validation_errors++))
        fi
    done

    # Environment-specific validations
    case "$env_name" in
        *work*)
            # Check work dev container specific configurations
            if docker exec "$container_name" test -f "$user_home/.gitconfig" 2>/dev/null; then
                local git_config
                git_config=$(docker exec "$container_name" cat "$user_home/.gitconfig" 2>/dev/null || echo "")
                if [[ "$git_config" == *"carson@journalytic.com"* ]]; then
                    log_success "Work dev container git config detected"
                else
                    log_warning "Work-specific git config not found"
                fi
            fi
            
            # Check if additional tools were installed by install-work-dc.sh
            if docker exec "$container_name" which gh >/dev/null 2>&1; then
                log_success "GitHub CLI installed"
            else
                log_warning "GitHub CLI not found"
                ((validation_errors++))
            fi
            
            if docker exec "$container_name" test -f "$user_home/.local/bin/mise" 2>/dev/null; then
                log_success "Mise installed via install-work-dc.sh"
            else
                log_warning "Mise not found"
                ((validation_errors++))
            fi
            ;;
        debian-basic)
            # For basic installation, just check standard configuration
            if docker exec "$container_name" test -f "$user_home/.gitconfig" 2>/dev/null; then
                log_success "Git config applied"
            fi
            ;;
    esac

    # Check if mise/fish/starship are functional (if installed)
    if docker exec "$container_name" which fish >/dev/null 2>&1; then
        log_success "Fish shell installed"
        # Test fish config loads without errors
        if docker exec "$container_name" fish -c "echo 'Fish config test'" >/dev/null 2>&1; then
            log_success "Fish configuration loads successfully"
        else
            log_warning "Fish configuration has issues"
            ((validation_errors++))
        fi
    fi

    if docker exec "$container_name" which starship >/dev/null 2>&1; then
        log_success "Starship prompt installed"
    fi

    if docker exec "$container_name" which mise >/dev/null 2>&1; then
        log_success "Mise (tool version manager) installed"
    fi

    return $validation_errors
}

run_test() {
    local env_name="$1"
    local base_image
    local env_vars
    local container_name="dotfiles-test-$env_name"
    
    base_image=$(get_base_image "$env_name")
    env_vars=$(get_env_vars "$env_name")
    
    if [ -z "$base_image" ]; then
        log_error "Unknown environment: $env_name"
        return 1
    fi
    
    log "Starting test: $env_name (image: $base_image)"
    
    # Cleanup any existing container
    cleanup_container "$container_name"
    
    # Build test dockerfile content
    local dockerfile_content
    case "$env_name" in
        debian-work-devcontainer)
            dockerfile_content=$(cat << EOF
FROM $base_image

# Install basic dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    sudo \\
    coreutils \\
    && rm -rf /var/lib/apt/lists/*

# Create vscode user to emulate dev container environment
RUN useradd -m -s /bin/bash vscode && \\
    echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER vscode
WORKDIR /home/vscode

# Set environment variables for dev container scenario
$(if [ -n "$env_vars" ]; then echo "$env_vars" | tr ' ' '\n' | sed 's/^/ENV /' | sed 's/=/=/'; fi)

EOF
)
            ;;
        *)
            dockerfile_content=$(cat << EOF
FROM $base_image

# Install basic dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    sudo \\
    coreutils \\
    && rm -rf /var/lib/apt/lists/*

# Create test user with sudo privileges
RUN useradd -m -s /bin/bash test && \\
    echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER test
WORKDIR /home/test

# Set environment variables for this test scenario
$(if [ -n "$env_vars" ]; then echo "$env_vars" | tr ' ' '\n' | sed 's/^/ENV /' | sed 's/=/=/'; fi)

EOF
)
            ;;
    esac

    # Create temporary dockerfile
    local temp_dockerfile
    temp_dockerfile=$(mktemp)
    echo "$dockerfile_content" > "$temp_dockerfile"
    
    # Build and run container
    log "Building container for $env_name..."
    if ! docker build -t "dotfiles-test-$env_name" -f "$temp_dockerfile" . 2>&1; then
        log_error "Failed to build container for $env_name"
        rm -f "$temp_dockerfile"
        return 1
    fi
    rm -f "$temp_dockerfile"
    
    log "Running container for $env_name..."
    if ! docker run -d --name "$container_name" \
        -v "$SCRIPT_DIR:/dotfiles:ro" \
        "dotfiles-test-$env_name" \
        sleep infinity >/dev/null 2>&1; then
        log_error "Failed to start container for $env_name"
        return 1
    fi
    
    # Wait for container to be ready
    sleep 2
    
    # Get the appropriate install script and user home directory
    local install_script
    local user_home
    install_script=$(get_install_script "$env_name")
    
    case "$env_name" in
        debian-work-devcontainer)
            user_home="/home/vscode"
            ;;
        *)
            user_home="/home/test"
            ;;
    esac
    
    # Copy install script and run it
    log "Installing dotfiles in $env_name using $install_script..."
    if ! docker exec "$container_name" bash -c "
        cd /dotfiles && 
        export DOTFILES_SOURCE_DIR=/dotfiles/root &&
        timeout $TEST_TIMEOUT bash $install_script
    " 2>&1; then
        log_error "Dotfiles installation failed for $env_name"
        # Show last few lines of output for debugging
        log "Container logs:"
        docker logs --tail 30 "$container_name" 2>&1 | sed 's/^/  /'
        return 1
    fi
    
    log_success "Installation completed for $env_name"
    
    # Validate the installation
    local validation_result=0
    validate_installation "$container_name" "$env_name" || validation_result=$?
    
    if [ $validation_result -eq 0 ]; then
        log_success "All validations passed for $env_name"
        return 0
    else
        log_error "$validation_result validation errors found for $env_name"
        return 1
    fi
}

main() {
    local target_env="all"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT=false
                shift
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            all|debian-basic|debian-work-devcontainer)
                target_env="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check dependencies
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Determine which tests to run
    local tests_to_run
    if [ "$target_env" = "all" ]; then
        tests_to_run="$AVAILABLE_ENVIRONMENTS"
    else
        # Check if target_env is valid
        local env_found=false
        for env in $AVAILABLE_ENVIRONMENTS; do
            if [ "$env" = "$target_env" ]; then
                env_found=true
                break
            fi
        done
        
        if [ "$env_found" = true ]; then
            tests_to_run="$target_env"
        else
            log_error "Unknown environment: $target_env"
            usage
            exit 1
        fi
    fi
    
    log "Starting dotfiles testing..."
    log "Test timeout: ${TEST_TIMEOUT}s"
    log "Cleanup on exit: $CLEANUP_ON_EXIT"
    echo
    
    # Run tests
    local failed_tests=""
    local passed_tests=""
    
    for env in $tests_to_run; do
        echo
        log "=" "Testing environment: $env" "="
        if run_test "$env"; then
            passed_tests="$passed_tests $env"
        else
            failed_tests="$failed_tests $env"
        fi
        
        if [ "$CLEANUP_ON_EXIT" = true ]; then
            cleanup_container "dotfiles-test-$env"
        fi
    done
    
    # Print summary
    echo
    log "=" "Test Summary" "="
    
    if [ -n "$passed_tests" ]; then
        local passed_count
        passed_count=$(echo "$passed_tests" | wc -w)
        log_success "Passed ($passed_count):$passed_tests"
    fi
    
    if [ -n "$failed_tests" ]; then
        local failed_count
        failed_count=$(echo "$failed_tests" | wc -w)
        log_error "Failed ($failed_count):$failed_tests"
        echo
        log_error "Some tests failed. Check the output above for details."
        exit 1
    fi
    
    echo
    log_success "All tests passed! Your dotfiles are ready for deployment."
    exit 0
}

main "$@"