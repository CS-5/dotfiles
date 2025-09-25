#!/bin/bash

set -eufo pipefail

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

mkdir -p ~/.local/bin

case $OS in
    linux)
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null
            sudo apt-get install -y wget >/dev/null
            
            wget -O zellij.tar.gz "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH}-unknown-linux-musl.tar.gz"
            tar -xzf zellij.tar.gz
            mv zellij ~/.local/bin/
            rm zellij.tar.gz
        else
            echo "Unsupported Linux distribution"
            exit 1
        fi
        ;;
    darwin)
        if ! command -v brew >/dev/null 2>&1; then
            echo "Homebrew is required on macOS"
            exit 1
        fi
        brew install zellij
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

echo "Zellij installed successfully!"