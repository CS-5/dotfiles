# Add .local/bin to PATH
$localBin = Join-Path $HOME ".local" "bin"
if (Test-Path $localBin) {
    $env:PATH = "$localBin;$env:PATH"
}

# Set editor
$env:VISUAL = "nvim"

# Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# Mise activation
if (Get-Command mise -ErrorAction SilentlyContinue) {
    (&mise activate pwsh) | Out-String | Invoke-Expression
}

# Zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
