#!/usr/bin/env bash
# Need node.js version 22.x (LTS)

OS="$(uname -s)"

install_linux() {
  echo "Detected Linux — installing Node.js via NodeSource (apt)..."
  sudo apt install -y curl
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt install -y nodejs
}

install_mac() {
  echo "Detected macOS — installing Node.js via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install node@22
  brew link --overwrite node@22
}

install_windows() {
  echo "Detected Windows — installing Node.js via winget..."
  if command -v winget &>/dev/null; then
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
  else
    echo "winget not available."
    echo "Please install Node.js manually from: https://nodejs.org/en/download"
    echo "  1. Download the Windows Installer (.msi) for the LTS version."
    echo "  2. Run the installer and follow the prompts."
    echo "  3. Restart your terminal and run: node -v"
    exit 1
  fi
}

case "$OS" in
  Linux*)   install_linux ;;
  Darwin*)  install_mac ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT*)  install_windows ;;
  *)
    echo "Unsupported OS: $OS"
    echo "Please install Node.js manually from: https://nodejs.org/en/download"
    exit 1
    ;;
esac

echo ""
echo "Node.js installation complete."
echo "Reset the terminal and IDE and run 'node -v' to verify the installation."