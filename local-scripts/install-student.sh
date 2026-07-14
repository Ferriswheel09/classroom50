#!/usr/bin/env bash
# Installs Go, gh, and the gh-student extension for students.
# Works on macOS, Linux, and Windows (Git Bash / MSYS2).
#
# Usage:
#   bash install-student.sh
#
# To point at a different fork of classroom50, change REPO_URL below.

set -euo pipefail

REPO_URL="https://github.com/foundation50/classroom50"
INSTALL_DIR="$HOME/.classroom50"
GO_VERSION="1.24.5"

###############################################################################
# Helpers
###############################################################################

info()    { echo "[install-student] $*"; }
success() { echo "[install-student] ✓ $*"; }
die()     { echo "[install-student] ✗ $*" >&2; exit 1; }

###############################################################################
# OS / arch detection
###############################################################################

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) die "Unsupported OS: $OS" ;;
esac

case "$ARCH" in
  x86_64|amd64)   GOARCH="amd64" ;;
  arm64|aarch64)  GOARCH="arm64" ;;
  *) die "Unsupported architecture: $ARCH" ;;
esac

###############################################################################
# Install GitHub CLI (gh)
###############################################################################

if command -v gh &>/dev/null; then
  success "gh already installed: $(gh --version | head -1)"
else
  info "Installing GitHub CLI..."
  case "$PLATFORM" in
    mac)
      if ! command -v brew &>/dev/null; then
        info "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew install gh
      ;;
    linux)
      if command -v apt-get &>/dev/null; then
        sudo mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update -q
        sudo apt-get install -y gh
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install -y gh
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm github-cli
      else
        die "No supported package manager found (apt/dnf/pacman). Install gh manually: https://cli.github.com and re-run."
      fi
      ;;
    windows)
      # winget.exe is available in Git Bash when installed on the system
      if command -v winget.exe &>/dev/null; then
        winget.exe install --id GitHub.cli --exact --accept-source-agreements --accept-package-agreements
      elif command -v winget &>/dev/null; then
        winget install --id GitHub.cli --exact --accept-source-agreements --accept-package-agreements
      else
        die "winget not found. Install GitHub CLI manually from https://cli.github.com, then re-run this script."
      fi
      # Update PATH so gh is found in this session
      export PATH="$PATH:/c/Program Files/GitHub CLI"
      ;;
  esac
  command -v gh &>/dev/null || die "gh installation failed. Install manually from https://cli.github.com and re-run."
  success "gh installed: $(gh --version | head -1)"
fi

###############################################################################
# Install Go from go.dev
###############################################################################

# Probe common install locations so an already-installed Go that isn't on
# PATH yet is found without re-downloading.
for _gocandidate in \
    "/usr/local/go/bin" \
    "$HOME/go-sdk/go/bin" \
    "/c/Program Files/Go/bin" \
    "$HOME/sdk/go/bin"; do
  if [[ -x "$_gocandidate/go" || -x "$_gocandidate/go.exe" ]]; then
    export PATH="$PATH:$_gocandidate"
    break
  fi
done

if command -v go &>/dev/null; then
  success "Go already installed: $(go version)"
else
  info "Installing Go $GO_VERSION..."
  case "$PLATFORM" in
    mac)
      # Download the macOS pkg installer — works on both Intel and Apple Silicon
      PKG="go${GO_VERSION}.darwin-${GOARCH}.pkg"
      curl -fsSL "https://dl.google.com/go/$PKG" -o "/tmp/$PKG"
      sudo installer -pkg "/tmp/$PKG" -target /
      rm "/tmp/$PKG"
      export PATH="$PATH:/usr/local/go/bin"
      ;;
    linux)
      TARBALL="go${GO_VERSION}.linux-${GOARCH}.tar.gz"
      curl -fsSL "https://dl.google.com/go/$TARBALL" -o "/tmp/$TARBALL"
      sudo rm -rf /usr/local/go
      sudo tar -C /usr/local -xzf "/tmp/$TARBALL"
      rm "/tmp/$TARBALL"
      export PATH="$PATH:/usr/local/go/bin"
      # Persist to common shell profiles
      for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$profile" ]] && ! grep -q '/usr/local/go/bin' "$profile"; then
          echo 'export PATH="$PATH:/usr/local/go/bin"' >> "$profile"
        fi
      done
      ;;
    windows)
      # Download the Windows zip and extract to $HOME/go
      GOZIP="go${GO_VERSION}.windows-amd64.zip"
      curl -fsSL "https://dl.google.com/go/$GOZIP" -o "/tmp/$GOZIP"
      mkdir -p "$HOME/go-sdk"
      unzip -q "/tmp/$GOZIP" -d "$HOME/go-sdk"
      rm "/tmp/$GOZIP"
      export PATH="$PATH:$HOME/go-sdk/go/bin"
      # Persist to .bashrc / .bash_profile so Git Bash picks it up next time
      for profile in "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [[ -f "$profile" ]] && ! grep -q 'go-sdk/go/bin' "$profile"; then
          echo "export PATH=\"\$PATH:\$HOME/go-sdk/go/bin\"" >> "$profile"
        fi
      done
      ;;
  esac

  command -v go &>/dev/null || die "Go installation failed. Install manually from https://go.dev/dl and re-run."
  success "Go installed: $(go version)"
fi

###############################################################################
# Clone or update the classroom50 repo
###############################################################################

mkdir -p "$INSTALL_DIR"
REPO_DIR="$INSTALL_DIR/classroom50"

if [[ -d "$REPO_DIR/.git" ]]; then
  info "Updating existing checkout at $REPO_DIR..."
  git -C "$REPO_DIR" pull --ff-only
else
  info "Cloning $REPO_URL into $REPO_DIR..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

###############################################################################
# Build and install gh-student (README steps)
###############################################################################

STUDENT_DIR="$REPO_DIR/cli/gh-student"
cd "$STUDENT_DIR"

info "Running: go mod tidy"
go mod tidy

info "Running: go build -o gh-student ."
go build -o gh-student .

info "Running: gh extension install . --force"
gh extension install . --force

success "gh-student installed."

###############################################################################
# Done
###############################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  gh-student is ready!"
echo ""
echo "  Next: log in with GitHub:"
echo "    gh student login"
echo ""
echo "  Then accept an assignment:"
echo "    gh student accept <org> <classroom> <assignment>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
