# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Install

Simply clone this repo, and run the `scripts/install-dotfiles.sh` script.

Alternatively:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply CS-5
```

### Windows

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} init --apply CS-5"
```
