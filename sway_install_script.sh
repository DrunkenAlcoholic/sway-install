#!/bin/bash

# Automated Sway desktop bootstrapper for minimal Arch installs.
# Lays down required packages, theming, and user configuration.

set -euo pipefail
IFS=$'\n\t'

# --- palette ---------------------------------------------------------------
PURPLE=$'\033[38;2;189;147;249m'
GREEN=$'\033[38;2;80;250;123m'
YELLOW=$'\033[38;2;241;250;140m'
CYAN=$'\033[38;2;139;233;253m'
RED=$'\033[38;2;255;85;85m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TARGET_BASHRC="$HOME/.bashrc"
readonly REPO_BASHRC="$SCRIPT_DIR/.bashrc"

PACMAN_SETS=(
  "packages/pacman-core.txt|Core system packages"
  "packages/pacman-desktop.txt|Desktop environment packages"
  "packages/pacman-audio.txt|PipeWire audio stack"
  "packages/pacman-fonts.txt|Font packages"
  "packages/pacman-extras.txt|CLI utilities and extras"
)

PARU_SETS=(
  "packages/paru-apps.txt|AUR applications"
  "packages/paru-themes.txt|AUR theming packages"
)

# --- logging helpers ------------------------------------------------------
log_info()   { printf '%b[INFO]%b %s\n'    "${CYAN}"  "${NC}" "$1"; }
log_ok()     { printf '%b[SUCCESS]%b %s\n' "${GREEN}" "${NC}" "$1"; }
log_warn()   { printf '%b[WARNING]%b %s\n' "${YELLOW}" "${NC}" "$1"; }
log_err()    { printf '%b[ERROR]%b %s\n'   "${RED}"   "${NC}" "$1"; }

show_banner() {
  if command -v clear >/dev/null 2>&1; then
    clear
  else
    printf '\033c'
  fi
  printf '%b' "${PURPLE}"
  cat <<'EOF'
███████╗██╗    ██╗ █████╗ ██╗   ██╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
███████╗██║ █╗ ██║███████║ ╚████╔╝█████╗██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
╚════██║██║███╗██║██╔══██║  ╚██╔╝ ╚════╝██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
███████║╚███╔███╔╝██║  ██║   ██║        ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝        ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝                                                   
EOF
  printf '%b\n' "${NC}"
}

# --- sanity checks --------------------------------------------------------
require_environment() {
  if [[ $EUID -eq 0 ]]; then
    log_err "Run as a regular user with sudo access, not root."
    exit 1
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    log_err "pacman not found. This script targets Arch Linux."
    exit 1
  fi
}

confirm_run() {
  if [[ ! -t 0 ]]; then
    log_warn "No interactive terminal detected; proceeding without prompt."
    return
  fi

  while true; do
    read -r -p "Proceed with Sway installation? [y/N]: " reply || {
      log_warn "No input received; aborting."
      exit 0
    }
    case ${reply} in
      [Yy]*) return ;;
      [Nn]*|"") log_warn "Installation cancelled."; exit 0 ;;
      *) log_warn "Please answer y or n." ;;
    esac
  done
}

# --- package helpers ------------------------------------------------------
read_pkg_file() {
  local file="$1"
  if [[ ! -f $file ]]; then
    log_err "Package list '$file' not found."
    exit 1
  fi
  sed -e 's/#.*//' -e 's/^[ \t]*//' -e 's/[ \t]*$//' "$file" | awk 'NF'
}

install_pkg_set() {
  local manager="$1" file="$2" label="$3"
  local pkgs
  mapfile -t pkgs < <(read_pkg_file "$file")
  if ((${#pkgs[@]} == 0)); then
    log_warn "No packages defined in $file; skipping."
    return
  fi
  log_info "$label"
  if [[ $manager == pacman ]]; then
    sudo pacman -S --noconfirm --needed "${pkgs[@]}"
  else
    paru -S --noconfirm --needed --skipreview "${pkgs[@]}"
  fi
}

install_pkg_sets() {
  local manager="$1"; shift
  local entry file label
  for entry in "$@"; do
    file="${entry%%|*}"
    label="${entry##*|}"
    install_pkg_set "$manager" "$SCRIPT_DIR/$file" "$label"
  done
}

# --- tooling installs -----------------------------------------------------
install_paru() {
  if command -v paru >/dev/null 2>&1; then
    log_warn "paru already installed; skipping build."
    return
  fi

  if pacman -Si paru >/dev/null 2>&1; then
    log_info "Installing paru from repository..."
    if sudo pacman -S --noconfirm --needed paru; then
      return
    fi
    log_warn "Repository install failed; building from AUR."
  else
    log_warn "paru not in repositories; building from AUR."
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  log_info "Cloning paru into $tmpdir"
  if git clone https://aur.archlinux.org/paru.git "$tmpdir"; then
    (cd "$tmpdir" && makepkg -si --noconfirm)
  else
    log_err "Failed to clone paru repository."
    rm -rf "$tmpdir"
    exit 1
  fi
  rm -rf "$tmpdir"

  if ! command -v paru >/dev/null 2>&1; then
    log_err "paru installation failed."
    exit 1
  fi
}

install_local_bin() {
  local repo="$1" binary="$2" post="${3:-}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  log_info "Cloning ${repo##*/}"
  if git clone "$repo" "$tmpdir"; then
    mkdir -p "$HOME/.local/bin"
    install -Dm755 "$tmpdir/bin/$binary" "$HOME/.local/bin/$binary"
    if [[ -n $post ]]; then
      if ! (cd "$tmpdir" && eval "$post"); then
        log_err "Post-install for ${repo##*/} failed."
        rm -rf "$tmpdir"
        exit 1
      fi
    fi
  else
    log_err "Failed to clone ${repo##*/}."
    rm -rf "$tmpdir"
    exit 1
  fi
  rm -rf "$tmpdir"
}

# --- theming --------------------------------------------------------------
run_gsettings() {
  command -v gsettings >/dev/null 2>&1 || return 1
  if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- gsettings "$@"
  else
    gsettings "$@"
  fi
}

apply_theme() {
  command -v gsettings >/dev/null 2>&1 || {
    log_warn "gsettings unavailable; skipping GTK theme sync."
    return
  }

  local failed=0
  run_gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'        || failed=1
  run_gsettings set org.gnome.desktop.interface icon-theme 'Dracula'       || failed=1
  run_gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || failed=1
  run_gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' || failed=1
  run_gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11' || failed=1
  run_gsettings set org.gnome.desktop.wm.preferences theme 'Dracula'       || failed=1

  if ((failed)); then
    log_warn "Could not apply all Dracula theme settings; continue manually if needed."
  else
    log_info "Applied Dracula theme via gsettings."
  fi
}

write_theme_env() {
  local env_dir="$HOME/.config/environment.d"
  mkdir -p "$env_dir"
  cat > "$env_dir/10-dracula.conf" <<'EOF'
GTK_THEME=Dracula
XCURSOR_THEME=Bibata-Modern-Ice
XCURSOR_SIZE=24
QT_QPA_PLATFORMTHEME=gtk3
GTK_USE_PORTAL=1
EOF

  command -v systemctl >/dev/null 2>&1 && \
    systemctl --user import-environment GTK_THEME XCURSOR_THEME XCURSOR_SIZE QT_QPA_PLATFORMTHEME GTK_USE_PORTAL >/dev/null 2>&1 || true

  command -v dbus-update-activation-environment >/dev/null 2>&1 && \
    dbus-update-activation-environment GTK_THEME=Dracula XCURSOR_THEME=Bibata-Modern-Ice XCURSOR_SIZE=24 QT_QPA_PLATFORMTHEME=gtk3 GTK_USE_PORTAL=1 >/dev/null 2>&1 || true
}

# --- display manager ------------------------------------------------------
configure_sddm() {
  log_info "Configuring SDDM theme"
  local theme=""
  local candidate
  for candidate in multicolor-sddm-theme multicolor-sddm multicolor; do
    if [[ -d "/usr/share/sddm/themes/$candidate" ]]; then
      theme="$candidate"
      break
    fi
  done

  if [[ -z $theme ]]; then
    log_warn "Multicolor SDDM theme assets not found; skipping theme selection."
    return
  fi

  sudo install -d -m 755 /etc/sddm.conf.d
  sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=$theme
CursorTheme=Bibata-Modern-Ice
EOF
}

# --- configuration --------------------------------------------------------
configure_virtualization() {
  log_info "Detecting virtualization..."
  local virt
  virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
  case "$virt" in
    oracle)
      log_info "VirtualBox detected; installing guest utils."
      sudo pacman -S --noconfirm --needed virtualbox-guest-utils
      sudo systemctl enable --now vboxservice
      ;;
    vmware)
      log_info "VMware detected; installing open-vm-tools."
      sudo pacman -S --noconfirm --needed open-vm-tools
      sudo systemctl enable --now vmtoolsd.service
      ;;
    qemu|kvm)
      log_info "QEMU/KVM detected; installing guest agents."
      sudo pacman -S --noconfirm --needed qemu-guest-agent spice-vdagent
      sudo systemctl enable --now qemu-guest-agent.service
      ;;
    none)
      log_info "Bare metal detected; no guest utilities required."
      ;;
    *)
      log_warn "Virtualization type '$virt' unsupported for automatic helpers."
      ;;
  esac
}

sync_configs() {
  log_info "Preparing config directories"
  mkdir -p "$HOME/.config" "$HOME/.config/gtk-4.0" ~/.themes ~/.icons ~/.config/environment.d

  log_info "Setting Bibata as cursor default"
  mkdir -p "$HOME/.icons/default"
  cat > "$HOME/.icons/default/index.theme" <<'EOF'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=Bibata-Modern-Ice
EOF

  ln -sf ../gtk-3.0/settings.ini "$HOME/.config/gtk-4.0/settings.ini"

  command -v rsync >/dev/null 2>&1 || {
    log_err "rsync is required but missing."
    exit 1
  }
  log_info "Syncing repository configs to ~/.config"
  rsync -a --exclude '.gitkeep' "$SCRIPT_DIR/.config/" "$HOME/.config/"

  apply_theme
  write_theme_env
}

install_desktop_entries() {
  log_info "Installing desktop entries"
  install -Dm644 "$SCRIPT_DIR/.local/share/applications/helix-kitty.desktop" \
    "$HOME/.local/share/applications/helix-kitty.desktop"
}

enable_services() {
  log_info "Enabling system services"
  sudo systemctl enable NetworkManager
  sudo systemctl start NetworkManager
  sudo systemctl enable bluetooth
  sudo systemctl start bluetooth
  sudo systemctl enable sddm
  log_warn "SDDM enabled; it will start after reboot."

  log_info "Enabling PipeWire user services"
  if systemctl --user list-unit-files >/dev/null 2>&1; then
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service
  else
    log_warn "systemd --user not available; skipping PipeWire enablement."
  fi
}

ensure_user_groups() {
  log_info "Adding user to video/audio/input groups"
  sudo usermod -aG video,audio,input "$USER"
}

ensure_sway_desktop_entry() {
  log_info "Ensuring sway.desktop exists"
  if [[ -f /usr/share/wayland-sessions/sway.desktop ]]; then
    log_info "Existing sway.desktop found."
    return
  fi
  log_warn "sway.desktop missing; creating minimal entry."
  sudo tee /usr/share/wayland-sessions/sway.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway
TryExec=sway
Type=Application
EOF
}

install_bashrc() {
  if [[ ! -f $REPO_BASHRC ]]; then
    log_err "Repository .bashrc missing at $REPO_BASHRC"
    exit 1
  fi
  local backup="$TARGET_BASHRC.pre-sway-install.$(date +%Y%m%d%H%M%S)"
  if [[ -e $TARGET_BASHRC ]]; then
    log_warn "Backing up existing ~/.bashrc to ${backup/#$HOME/~}"
    cp -L "$TARGET_BASHRC" "$backup"
  fi
  install -Dm644 "$REPO_BASHRC" "$TARGET_BASHRC"
  log_info "Installed repository .bashrc"
}

final_summary() {
  show_banner
  log_ok "Sway installation and configuration complete!"
  echo
  log_info "Configuration summary:"
  cat <<'EOF'
  • SDDM display manager installed and enabled
  • Sway WM with Waybar status bar (Dracula theme)
  • Kitty terminal emulator (Dracula theme)
  • Brave browser
  • NimLaunch application launcher
  • Nymph fetch utility (auto-runs in terminal)
  • Swaylock screen locker with Dracula theme
  • Mako notification daemon (Dracula theme)
  • GTK applications themed with Dracula
  • PipeWire audio system (modern replacement for PulseAudio)
  • Paru AUR helper installed
  • Nerd Fonts with icon support
  • Screenshot tools (grim + slurp)
  • Audio/brightness controls configured
  • Auto-lock after 5 minutes of inactivity
  • Consistent Dracula theme across all components
EOF
  log_warn "Please reboot to start SDDM. Select 'Sway' from the session menu."
  echo
  log_info "Basic key bindings:"
  cat <<'EOF'
  • Super + Enter: Open terminal (Kitty)
  • Super + D: NimLaunch application launcher
  • Super + B: Open Brave browser
  • Super + N: Open Thunar file manager
  • Super + Shift + I: Show keybinding helper
  • Super + I: Lock screen
  • Super + Shift + Q: Close window
  • Super + Shift + E: Exit Sway
  • Print: Screenshot
  • Super + Print: Area screenshot
EOF
  log_info "Configuration lives in ~/.config"
  log_info "Use 'paru' for additional AUR packages"
  log_ok "Installer finished. Reboot to enjoy your new desktop!"
}

# --- main flow ------------------------------------------------------------
main() {
  show_banner
  log_info "Starting Sway WM installation on minimal Arch Linux..."
  require_environment
  confirm_run

  log_info "Updating system packages"
  sudo pacman -Syu --noconfirm

  install_pkg_sets pacman "${PACMAN_SETS[@]}"
  configure_virtualization
  install_paru
  install_pkg_sets paru "${PARU_SETS[@]}"

  install_local_bin "https://github.com/DrunkenAlcoholic/NimLaunch.git" nimlaunch
  install_local_bin "https://github.com/DrunkenAlcoholic/Nymph.git" nymph \
    'rm -rf "$HOME/.local/bin/logos"; cp -r bin/logos "$HOME/.local/bin/"'

  sync_configs
  install_desktop_entries
  log_info "Creating ~/Screenshots"
  mkdir -p "$HOME/Screenshots"

  configure_sddm
  enable_services
  ensure_user_groups
  ensure_sway_desktop_entry

  log_info "Refreshing font cache"
  fc-cache -fv

  log_info "Deploying repository .bashrc"
  install_bashrc

  final_summary
}

main "$@"
