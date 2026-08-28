# Before every tool below: they can be mise-managed, and mise's shims are not
# on PATH until this runs. Matches sh/rc.d/25-mise.sh.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    (&mise activate pwsh) | Out-String | Invoke-Expression
}
