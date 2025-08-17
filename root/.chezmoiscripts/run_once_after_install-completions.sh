#!/bin/bash

if command -v gh >/dev/null 2>&1; then
    gh completions -s fish > ~/.config/fish/completions/gh.fish
fi
