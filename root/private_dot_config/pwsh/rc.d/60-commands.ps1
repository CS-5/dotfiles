# Windows counterparts of the commands chezmoi installs to ~/.local/bin on
# every other platform. .chezmoiignore drops .local/bin on Windows (those are
# bash), so without these a Windows machine has no way to update itself.

# Update everything: winget packages, mise, chezmoi, the dotfiles, then the
# freshly pulled tool pins. Mirrors ~/.local/bin/update.
function update {
    function Step($m) { Write-Host "`n==> $m" -ForegroundColor Blue }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Step "Updating system packages"
        winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
    }

    if (Get-Command mise -ErrorAction SilentlyContinue) {
        Step "Updating mise"
        # A package-managed mise (scoop, winget) has self-update disabled and
        # exits nonzero; the step above is what updates those.
        mise self-update --yes
        if ($LASTEXITCODE -ne 0) { Write-Host "mise self-update skipped" }
    }

    Step "Updating chezmoi"
    chezmoi upgrade

    Step "Pulling latest dotfiles and applying"
    chezmoi update

    if (Get-Command mise -ErrorAction SilentlyContinue) {
        Step "Upgrading mise tools"
        mise upgrade
    }

    Step "Update complete"
}

# Prune what update leaves behind. Mirrors ~/.local/bin/clean.
function clean {
    function Step($m) { Write-Host "`n==> $m" -ForegroundColor Blue }

    if (Get-Command mise -ErrorAction SilentlyContinue) {
        Step "Pruning unused mise tool versions"
        mise prune --yes

        Step "Clearing mise download cache"
        mise cache clear
    }

    Step "Clean complete"
}

# Write ~/work.email and re-apply so the work identity takes effect.
# Mirrors ~/.local/bin/set-work-email.
function set-work-email {
    param([Parameter(Mandatory)][string]$Address)
    Set-Content -Path (Join-Path $HOME "work.email") -Value $Address -NoNewline
    chezmoi init --apply
}
