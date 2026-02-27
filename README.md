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
irm get.chezmoi.io/ps1 | powershell -c - -- init --apply CS-5
```
