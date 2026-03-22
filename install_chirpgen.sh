#!/usr/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  Chirp Generator — installer & launcher
#  Run once to install, then use the desktop icon or re-run to launch.
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✘ $*${RESET}"; exit 1; }

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║        Chirp Generator Setup         ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_FILE="$SCRIPT_DIR/chirp_generator.py"
VENV_DIR="$SCRIPT_DIR/.venv"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/chirp-generator.desktop"
ICON_DIR="$HOME/.local/share/icons"
ICON_FILE="$ICON_DIR/chirp-generator.png"

# ── Sanity check ──────────────────────────────────────────────────────────────
if [[ ! -f "$APP_FILE" ]]; then
    error "chirp_generator.py not found in $SCRIPT_DIR\nMake sure this script is in the same folder as chirp_generator.py"
fi

# ── 1. Python ─────────────────────────────────────────────────────────────────
info "Checking for Python 3..."

PYTHON=""
for candidate in python3 python3.12 python3.11 python3.10 python3.9; do
    if command -v "$candidate" &>/dev/null; then
        VER=$("$candidate" -c "import sys; print(sys.version_info[:2])")
        PYTHON="$candidate"
        success "Found $candidate  ($VER)"
        break
    fi
done

if [[ -z "$PYTHON" ]]; then
    warn "Python 3 not found — attempting to install..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y python3 python3-venv python3-pip
        PYTHON="python3"
        success "Python 3 installed"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 python3-venv
        PYTHON="python3"
        success "Python 3 installed"
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm python python-virtualenv
        PYTHON="python3"
        success "Python 3 installed"
    else
        error "Cannot install Python automatically.\nPlease install Python 3.9+ manually and re-run this script."
    fi
fi

# ── 2. System packages (venv, tkinter, ffmpeg) ────────────────────────────────
info "Checking system packages..."

if command -v apt-get &>/dev/null; then
    MISSING_PKGS=()
    $PYTHON -c "import venv"    2>/dev/null || MISSING_PKGS+=(python3-venv)
    $PYTHON -c "import tkinter" 2>/dev/null || MISSING_PKGS+=(python3-tk)
    command -v ffmpeg &>/dev/null           || MISSING_PKGS+=(ffmpeg)
    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        info "Installing missing system packages: ${MISSING_PKGS[*]}"
        sudo apt-get install -y "${MISSING_PKGS[@]}"
    fi
elif command -v dnf &>/dev/null; then
    MISSING_PKGS=()
    $PYTHON -c "import tkinter" 2>/dev/null || MISSING_PKGS+=(python3-tkinter)
    command -v ffmpeg &>/dev/null           || MISSING_PKGS+=(ffmpeg)
    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        info "Installing missing system packages: ${MISSING_PKGS[*]}"
        sudo dnf install -y "${MISSING_PKGS[@]}"
    fi
elif command -v pacman &>/dev/null; then
    MISSING_PKGS=()
    $PYTHON -c "import tkinter" 2>/dev/null || MISSING_PKGS+=(tk)
    command -v ffmpeg &>/dev/null           || MISSING_PKGS+=(ffmpeg)
    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        info "Installing missing system packages: ${MISSING_PKGS[*]}"
        sudo pacman -Sy --noconfirm "${MISSING_PKGS[@]}"
    fi
fi

# Verify critical ones
if ! $PYTHON -c "import tkinter" 2>/dev/null; then
    error "tkinter is still not available.\nTry manually: sudo apt install python3-tk"
fi
if ! command -v ffmpeg &>/dev/null; then
    warn "ffmpeg could not be installed — MP3 export will be disabled in the app."
else
    success "ffmpeg OK ($(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f3))"
fi

success "System packages OK"

# ── 3. Virtual environment ────────────────────────────────────────────────────
info "Setting up virtual environment at $VENV_DIR..."

# If venv exists but pip or python are missing, it's broken — wipe and recreate
if [[ -d "$VENV_DIR" ]]; then
    if [[ ! -f "$VENV_DIR/bin/python" ]] || [[ ! -f "$VENV_DIR/bin/pip" ]]; then
        warn "Existing venv is broken (missing pip or python) — recreating..."
        rm -rf "$VENV_DIR"
    fi
fi

if [[ ! -d "$VENV_DIR" ]]; then
    $PYTHON -m venv "$VENV_DIR"
    success "Virtual environment created"
else
    success "Virtual environment already exists"
fi

VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

[[ -f "$VENV_PYTHON" ]] || error "venv python not found at $VENV_PYTHON"
[[ -f "$VENV_PIP"    ]] || error "venv pip not found at $VENV_PIP"

# ── 4. Python dependencies ────────────────────────────────────────────────────
info "Checking Python dependencies..."

info "Upgrading pip..."
"$VENV_PIP" install --upgrade pip || warn "pip upgrade failed — continuing anyway"

install_required() {
    local pkg="$1"
    local import_name="${2:-$1}"
    if "$VENV_PYTHON" -c "import $import_name" 2>/dev/null; then
        success "$pkg already installed"
        return
    fi
    info "Installing $pkg..."
    if "$VENV_PIP" install "$pkg"; then
        success "$pkg installed"
    else
        error "Failed to install $pkg — cannot continue."
    fi
}

install_required numpy
install_required pydub

# ── 5. Desktop entry ──────────────────────────────────────────────────────────
info "Creating desktop entry..."

mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR"

SVG_ICON="$ICON_DIR/chirp-generator.svg"
cat > "$SVG_ICON" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="12" fill="#1a1a2a"/>
  <polyline points="4,32 10,32 14,16 18,48 22,24 26,40 30,20 34,44 38,28 42,36 46,32 52,32 60,32"
            fill="none" stroke="#89b4fa" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
SVGEOF

ICON_PATH="$SVG_ICON"
if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 64 -h 64 "$SVG_ICON" -o "$ICON_FILE" 2>/dev/null && ICON_PATH="$ICON_FILE"
elif command -v inkscape &>/dev/null; then
    inkscape --export-png="$ICON_FILE" -w 64 -h 64 "$SVG_ICON" 2>/dev/null && ICON_PATH="$ICON_FILE"
elif command -v convert &>/dev/null; then
    convert "$SVG_ICON" "$ICON_FILE" 2>/dev/null && ICON_PATH="$ICON_FILE"
fi

cat > "$DESKTOP_FILE" << DESKTOPEOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Chirp Generator
GenericName=Sound Designer
Comment=FM synthesis chirp sound designer
Exec=$VENV_PYTHON $APP_FILE
Icon=$ICON_PATH
Terminal=false
Categories=Audio;AudioVideo;Utility;
Keywords=sound;synth;audio;chirp;fm;
StartupNotify=true
StartupWMClass=chirp_generator
DESKTOPEOF

chmod +x "$DESKTOP_FILE"

if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi
if command -v xdg-desktop-menu &>/dev/null; then
    xdg-desktop-menu forceupdate 2>/dev/null || true
fi

success "Desktop entry created: $DESKTOP_FILE"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  All done! Launching Chirp Generator...${RESET}"
echo ""

# ── 6. Launch ─────────────────────────────────────────────────────────────────
exec "$VENV_PYTHON" "$APP_FILE"
