#!/bin/bash

# test.sh - Everything that can be checked without a real machine to apply to.
#
# Runs in four stages, cheapest first:
#
#   1. render   every *.tmpl against every environment the data flags describe
#   2. apply    real `chezmoi apply` into a throwaway destination, per platform
#   3. lint     shellcheck + shfmt over every shell script
#   4. parse    JSON / TOML / JSONC that a typo would otherwise break at runtime
#
# Stage 2 is the one that earns its keep. Rendering proves a template is valid
# Go template syntax; only a real apply resolves cross-file references such as
# the `include` calls in .chezmoiscripts, which is how a stale path to a moved
# file gets caught.
#
# Nothing here touches $HOME. Every apply goes to a temp directory with its own
# chezmoi persistent state, and scripts are excluded so no package manager,
# compiler or systemctl runs.
#
# Usage: ./test.sh [stage...]     (default: all stages)
#        ./test.sh render lint

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/root"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

failures=0
checks=0

pass() { checks=$((checks + 1)); }
fail() {
    checks=$((checks + 1))
    failures=$((failures + 1))
    printf '%s  FAIL%s %s\n' "$RED" "$NC" "$1"
    [[ -n ${2:-} ]] && printf '%s\n' "$2" | sed 's/^/       /' | head -12
    return 0
}
stage() { printf '\n%s==>%s %s\n' "$BLUE" "$NC" "$1"; }
skip() { printf '%s  skip%s %s\n' "$YELLOW" "$NC" "$1"; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# The environments worth distinguishing. Each is a chezmoi --override-data
# object; the name is only used in output.
ENVIRONMENTS=(
    "omarchy-thinkpad:{\"isOmarchy\":true,\"isThinkPad\":true}"
    "omarchy-desktop:{\"isOmarchy\":true,\"isThinkPad\":false}"
    "macos:{\"isOmarchy\":false,\"isThinkPad\":false,\"isMac\":true}"
    "linux:{\"isOmarchy\":false,\"isThinkPad\":false,\"isMac\":false}"
    "devcontainer:{\"isOmarchy\":false,\"isThinkPad\":false,\"isDc\":true}"
)

require_chezmoi() {
    if ! command -v chezmoi >/dev/null 2>&1; then
        printf '%sError:%s chezmoi is required to run these tests\n' "$RED" "$NC" >&2
        exit 2
    fi
}

# A config rendered from the real .chezmoi.toml.tmpl, with the host's own
# ~/work.email neutralized so results do not depend on who is running this.
base_config() {
    local out="$TMPROOT/base.toml"
    if [[ ! -f $out ]]; then
        DOTFILES_WORK_EMAIL_FILE="$TMPROOT/no-work-email" \
            chezmoi execute-template --init --source="$SOURCE_DIR" \
            <"$SOURCE_DIR/.chezmoi.toml.tmpl" >"$out" 2>/dev/null || return 1
    fi
    printf '%s\n' "$out"
}

stage_render() {
    stage "Rendering templates"
    require_chezmoi
    local config templates count=0
    config="$(base_config)" || {
        fail "could not render .chezmoi.toml.tmpl"
        return
    }
    mapfile -t templates < <(find "$SOURCE_DIR" -name '*.tmpl' | sort)

    local env name data t out
    for env in "${ENVIRONMENTS[@]}"; do
        name="${env%%:*}"
        data="${env#*:}"
        for t in "${templates[@]}"; do
            if out=$(chezmoi execute-template --config="$config" --source="$SOURCE_DIR" \
                --override-data "$data" <"$t" 2>&1); then
                pass
            else
                fail "render [$name] ${t#"$SCRIPT_DIR"/}" "$out"
            fi
            count=$((count + 1))
        done
    done
    printf '  %d renders across %d environments\n' "$count" "${#ENVIRONMENTS[@]}"
}

stage_apply() {
    stage "Applying to throwaway destinations"
    require_chezmoi
    local config
    config="$(base_config)" || {
        fail "could not render .chezmoi.toml.tmpl"
        return
    }

    local env name data dest state cfg out residue
    for env in "${ENVIRONMENTS[@]}"; do
        name="${env%%:*}"
        data="${env#*:}"
        dest="$TMPROOT/dest-$name"
        state="$TMPROOT/state-$name.boltdb"
        cfg="$TMPROOT/config-$name.toml"
        mkdir -p "$dest"

        # --override-data is not read by `apply`, so bake the flags into a
        # per-environment config instead.
        if ! apply_config "$config" "$data" >"$cfg"; then
            fail "apply [$name] could not build config"
            continue
        fi

        # --exclude=scripts: this is a filesystem test, not a provisioning run.
        if ! out=$(chezmoi --config="$cfg" --source="$SOURCE_DIR" --destination="$dest" \
            --persistent-state="$state" --no-tty apply --exclude=scripts 2>&1); then
            fail "apply [$name]" "$out"
            continue
        fi

        # Everything that is not an excluded script should now be in sync. A
        # leftover non-script entry means the apply silently did not finish.
        residue=$(chezmoi --config="$cfg" --source="$SOURCE_DIR" --destination="$dest" \
            --persistent-state="$state" --no-tty status 2>/dev/null | grep -vc '^ R ')
        if [[ $residue -eq 0 ]]; then
            pass
            printf '  %-18s %d files\n' "$name" "$(find "$dest" -type f | wc -l)"
        else
            fail "apply [$name] left $residue unapplied non-script target(s)" \
                "$(chezmoi --config="$cfg" --source="$SOURCE_DIR" --destination="$dest" \
                    --persistent-state="$state" --no-tty status 2>/dev/null | grep -v '^ R ')"
        fi
    done
}

# Merge an environment's override object into a rendered config's [data] table,
# so `apply` (which has no --override-data) sees the same flags render does.
apply_config() {
    local config="$1" data="$2"
    python3 - "$config" "$data" <<'PY'
import json, sys, re
config, overrides = sys.argv[1], json.loads(sys.argv[2])
out = []
for line in open(config):
    m = re.match(r'^(\s*)(\w+) = ', line)
    if m and m.group(2) in overrides:
        value = overrides.pop(m.group(2))
        out.append(f"{m.group(1)}{m.group(2)} = {json.dumps(value)}\n")
    else:
        out.append(line)
for key, value in overrides.items():
    out.append(f"    {key} = {json.dumps(value)}\n")
sys.stdout.write("".join(out))
PY
}

# Shell scripts live in three shapes: plain files, chezmoi `executable_` files,
# and templates that must be rendered before they can be parsed.
stage_lint() {
    stage "Linting shell scripts"
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed (mise install shellcheck)"
    else
        local plain=()
        mapfile -t plain < <(
            find "$SCRIPT_DIR" -path "$SCRIPT_DIR/.git" -prune -o -type f \
                \( -name '*.sh' -o -name 'executable_*' \) -print | sort
        )
        local f out
        for f in "${plain[@]}"; do
            head -c2 "$f" | grep -q '^#!' || continue
            if out=$(shellcheck --shell=bash --severity=warning "$f" 2>&1); then
                pass
            else
                fail "shellcheck ${f#"$SCRIPT_DIR"/}" "$out"
            fi
        done

        # Rendered templates, checked in the Omarchy environment (the one with
        # the most script content behind `if .isOmarchy` guards).
        local config rendered t
        if config="$(base_config)"; then
            for t in "$SOURCE_DIR"/.chezmoiscripts/*.sh.tmpl "$SOURCE_DIR"/dot_local/bin/*.tmpl; do
                [[ -f $t ]] || continue
                rendered="$TMPROOT/$(basename "$t" .tmpl)"
                chezmoi execute-template --config="$config" --source="$SOURCE_DIR" \
                    --override-data '{"isOmarchy":true,"isThinkPad":true}' <"$t" >"$rendered" 2>/dev/null
                # A template that renders empty off its platform has nothing to check.
                [[ -s $rendered ]] || continue
                if out=$(shellcheck --shell=bash --severity=warning "$rendered" 2>&1); then
                    pass
                else
                    fail "shellcheck (rendered) ${t#"$SCRIPT_DIR"/}" "$out"
                fi
            done
        fi
    fi

    if ! command -v shfmt >/dev/null 2>&1; then
        skip "shfmt not installed (mise install shfmt)"
    else
        local unformatted
        # -i 4 with shfmt's default case style, which is what the repo already
        # uses; -ci would reindent every case block for no reason.
        unformatted=$(shfmt -l -i 4 \
            "$SCRIPT_DIR"/*.sh \
            "$SCRIPT_DIR"/scripts/*.sh \
            "$SOURCE_DIR"/dot_local/bin/executable_* \
            "$SOURCE_DIR"/dot_claude/*.sh \
            "$SOURCE_DIR"/dot_claude/hooks/*.sh 2>/dev/null)
        if [[ -z $unformatted ]]; then
            pass
        else
            fail "shfmt would reformat:" "$unformatted"
        fi
    fi
}

stage_parse() {
    stage "Parsing data files"
    local config
    config="$(base_config)" || {
        fail "could not render .chezmoi.toml.tmpl"
        return
    }

    local f out rendered
    # TOML that chezmoi itself loads as template data.
    for f in "$SOURCE_DIR"/.chezmoidata/*.toml; do
        [[ -f $f ]] || continue
        if out=$(python3 -c 'import tomllib,sys;tomllib.load(open(sys.argv[1],"rb"))' "$f" 2>&1); then
            pass
        else
            fail "toml ${f#"$SCRIPT_DIR"/}" "$out"
        fi
    done

    # JSON, including templated JSON, which must be valid in every environment.
    local env name data
    for f in $(find "$SOURCE_DIR" -name '*.json' -o -name '*.json.tmpl' | sort); do
        for env in "${ENVIRONMENTS[@]}"; do
            name="${env%%:*}"
            data="${env#*:}"
            if [[ $f == *.tmpl ]]; then
                rendered=$(chezmoi execute-template --config="$config" --source="$SOURCE_DIR" \
                    --override-data "$data" <"$f" 2>&1) || {
                    fail "render ${f#"$SCRIPT_DIR"/}" "$rendered"
                    continue
                }
            else
                rendered=$(cat "$f")
                [[ $env == "${ENVIRONMENTS[0]}" ]] || continue
            fi
            if out=$(printf '%s' "$rendered" | python3 -c 'import json,sys;json.load(sys.stdin)' 2>&1); then
                pass
            else
                fail "json [$name] ${f#"$SCRIPT_DIR"/}" "$out"
            fi
        done
    done

    # JSONC: comments and trailing commas are legal, so strip them first. This
    # is the same shape Omarchy's menu parser accepts.
    for f in $(find "$SOURCE_DIR" -name '*.jsonc' | sort); do
        if out=$(python3 -c '
import json, re, sys
s = open(sys.argv[1]).read()
s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
s = re.sub(r",(\s*[}\]])", r"\1", s)
json.loads(s)
' "$f" 2>&1); then
            pass
        else
            fail "jsonc ${f#"$SCRIPT_DIR"/}" "$out"
        fi
    done
}

STAGES=("$@")
[[ ${#STAGES[@]} -eq 0 ]] && STAGES=(render apply lint parse)

for s in "${STAGES[@]}"; do
    case "$s" in
    render) stage_render ;;
    apply) stage_apply ;;
    lint) stage_lint ;;
    parse) stage_parse ;;
    *)
        printf '%sError:%s unknown stage "%s" (render|apply|lint|parse)\n' "$RED" "$NC" "$s" >&2
        exit 2
        ;;
    esac
done

printf '\n'
if [[ $failures -eq 0 ]]; then
    printf '%s%d checks passed%s\n' "$GREEN" "$checks" "$NC"
else
    printf '%s%d of %d checks failed%s\n' "$RED" "$failures" "$checks" "$NC"
fi
exit $((failures > 0))
