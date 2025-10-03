#!/bin/bash

# Sway WM Installation Script for Minimal Arch Linux
# This script installs and configures a complete Sway desktop environment

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASHRC_FILE="$HOME/.bashrc"

install_packages() {
    local description="$1"
    shift
    if [[ $# -eq 0 ]]; then
        return
    fi
    print_status "$description"
    sudo pacman -S --noconfirm --needed "$@"
}

clone_and_install_paru() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    print_status "Cloning paru into $tmpdir..."
    if git clone https://aur.archlinux.org/paru.git "$tmpdir"; then
        (cd "$tmpdir" && makepkg -si --noconfirm)
    else
        print_error "Failed to clone paru repository."
        rm -rf "$tmpdir"
        exit 1
    fi
    rm -rf "$tmpdir"
}

clone_to_local_bin() {
    local repo_url="$1"
    local target_binary="$2"
    local post_copy_cmd="$3"
    local tmpdir
    tmpdir="$(mktemp -d)"
    print_status "Cloning ${repo_url##*/} into $tmpdir..."
    if git clone "$repo_url" "$tmpdir"; then
        mkdir -p "$HOME/.local/bin"
        install -Dm755 "$tmpdir/bin/$target_binary" "$HOME/.local/bin/$target_binary"
        if [[ -n $post_copy_cmd ]]; then
            if ! eval "$post_copy_cmd"; then
                print_error "Post-install step for ${repo_url##*/} failed."
                rm -rf "$tmpdir"
                exit 1
            fi
        fi
        rm -rf "$tmpdir"
    else
        print_error "Failed to clone ${repo_url##*/} repository."
        rm -rf "$tmpdir"
        exit 1
    fi
}

ensure_block_in_bashrc() {
    local marker="$1"
    local block="$2"
    local action="Appending"
    local tmp

    if grep -Fq "$marker" "$BASHRC_FILE"; then
        action="Refreshing"
        tmp="$(mktemp)"
        awk -v marker="$marker" '
            $0 == marker {skip = 1; next}
            skip && NF == 0 {skip = 0; next}
            skip {next}
            {print}
        ' "$BASHRC_FILE" > "$tmp"
        mv "$tmp" "$BASHRC_FILE"
    fi

    printf '\n%s\n\n' "$block" >> "$BASHRC_FILE"
    print_status "$action block '$marker' in ~/.bashrc..."
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check if running on Arch Linux
if ! command -v pacman &> /dev/null; then
    print_error "This script is designed for ArchLinux systems with pacman package manager."
    exit 1
fi

print_status "Starting Sway WM installation on minimal Arch Linux..."

# Update system
print_status "Updating system packages..."
if [[ ${SWAY_INSTALL_SKIP_UPGRADE:-0} == 1 ]]; then
    print_warning "SWAY_INSTALL_SKIP_UPGRADE=1 detected; skipping system upgrade."
else
    sudo pacman -Syu --noconfirm
fi

install_packages "Installing base system packages..." \
    base-devel \
    git \
    wget \
    curl \
    openssh \
    unzip

install_packages "Installing and configuring SDDM display manager..." \
    sddm \
    qt5-graphicaleffects \
    qt5-svg \
    qt5-quickcontrols2 \
    qt5-wayland

install_packages "Installing Sway and Wayland components..." \
    sway \
    swaylock \
    swayidle \
    swaybg \
    waybar \
    wl-clipboard \
    xorg-xwayland

install_packages "Installing essential utilities..." \
    kitty \
    thunar \
    thunar-volman \
    tumbler \
    ffmpegthumbnailer \
    grim \
    slurp \
    swappy \
    mako \
    brightnessctl \
    playerctl \
    pavucontrol \
    networkmanager \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    udisks2 \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    gvfs-afc \
    libnotify

install_packages "Installing polkit components..." \
    polkit \
    polkit-gnome

install_packages "Installing PipeWire audio stack..." \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber

install_packages "Installing fonts..." \
    ttf-dejavu \
    ttf-liberation \
    noto-fonts \
    noto-fonts-emoji \
    ttf-font-awesome \
    ttf-firacode-nerd \
    ttf-jetbrains-mono-nerd \
    ttf-sourcecodepro-nerd

install_packages "Installing additional useful packages..." \
    htop \
    ranger \
    helix \
    micro \
    rsync \
    tree \
    man-db \
    man-pages \
    gtk3 \
    qt5ct \
    lxappearance \
    xdg-desktop-portal-wlr \
    xdg-desktop-portal-gtk \
    iwd \
    wireless_tools \
    wpa_supplicant \
    lm_sensors \
    smartmontools \
    xdg-utils

# Detect VirtualBox environment and install guest utilities if needed
print_status "Checking virtualization environment..."
virt_type=$(systemd-detect-virt 2>/dev/null || echo "unknown")
case "$virt_type" in
    oracle)
        print_status "VirtualBox detected; installing guest additions..."
        sudo pacman -S --noconfirm --needed virtualbox-guest-utils
        sudo systemctl enable --now vboxservice
        ;;
    vmware)
        print_status "VMware detected; installing open-vm-tools..."
        sudo pacman -S --noconfirm --needed open-vm-tools
        sudo systemctl enable --now vmtoolsd.service
        ;;
    qemu|kvm)
        print_status "QEMU/KVM detected; installing guest agents..."
        sudo pacman -S --noconfirm --needed qemu-guest-agent spice-vdagent
        sudo systemctl enable --now qemu-guest-agent.service
        ;;
    none)
        print_status "No virtualization detected; skipping guest utility installation."
        ;;
    *)
        print_warning "Virtualization type '$virt_type' detected; no guest utilities configured for automatic installation."
        ;;
esac

# Install paru AUR helper
print_status "Installing paru AUR helper..."
if ! command -v paru &> /dev/null; then
    clone_and_install_paru
else
    print_warning "paru is already installed, skipping..."
fi

if ! command -v paru &> /dev/null; then
    print_error "paru installation failed; aborting."
    exit 1
fi

# Install Brave browser from AUR using paru
print_status "Installing Brave browser from AUR..."
paru -S --noconfirm --needed --skipreview brave-bin


# Install Dracula theme components from AUR
print_status "Installing Dracula theme components..."
paru -S --noconfirm --needed --skipreview \
    dracula-gtk-theme \
    dracula-icons-git

print_status "Installing Bibata cursor theme..."
paru -S --noconfirm --needed --skipreview bibata-cursor-theme

print_status "Installing Multicolor SDDM theme..."
paru -S --noconfirm --needed --skipreview multicolor-sddm-theme

print_status "Configuring SDDM theme..."
sudo install -d -m 755 /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<'EOF'
[Theme]
Current=multicolor-sddm-theme
EOF

# Install NimLaunch application launcher
print_status "Installing NimLaunch application launcher..."
clone_to_local_bin "https://github.com/DrunkenAlcoholic/NimLaunch.git" "nimlaunch" ""

# Install Nymph fetch utility
print_status "Installing Nymph fetch utility..."
clone_to_local_bin "https://github.com/DrunkenAlcoholic/Nymph.git" "nymph" \
    'rm -rf "$HOME/.local/bin/logos"; cp -r "$tmpdir/bin/logos" "$HOME/.local/bin/"'

print_status "Preparing configuration directories..."
mkdir -p "$HOME/.config" ~/.themes ~/.icons

print_status "Setting Bibata cursor theme as default..."
mkdir -p "$HOME/.icons/default"
cat > "$HOME/.icons/default/index.theme" <<'EOF'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=Bibata-Modern-Ice
EOF

# Deploy repository-managed configs
print_status "Syncing repository .config directory into ~/.config..."
if ! command -v rsync &> /dev/null; then
    print_error "rsync is required but not found."
    exit 1
fi
rsync -a --exclude='.gitkeep' "$SCRIPT_DIR/.config/" "$HOME/.config/"

# Create Screenshots directory
print_status "Creating Screenshots directory..."
mkdir -p ~/Screenshots

# Enable and start necessary services
print_status "Enabling system services..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
sudo systemctl enable sddm
print_warning "SDDM will be enabled but not started until next boot"

# Enable PipeWire services for current user
print_status "Enabling PipeWire audio services..."
if systemctl --user list-unit-files >/dev/null 2>&1; then
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service
else
    print_warning "systemd --user is not available in this session; skipping PipeWire user service enablement."
fi

# Add user to necessary groups
print_status "Adding user to necessary groups..."
sudo usermod -aG video,audio,input "$USER"

# Ensure desktop entry for Sway exists
print_status "Ensuring desktop entry for Sway..."
if [[ -f /usr/share/wayland-sessions/sway.desktop ]]; then
    print_status "Desktop entry already present; leaving existing file untouched."
else
    print_warning "Sway desktop entry missing, creating a minimal entry."
    sudo tee /usr/share/wayland-sessions/sway.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway
TryExec=sway
Type=Application
EOF
fi

# Update font cache
print_status "Updating font cache..."
fc-cache -fv

# Set environment variables for consistent theming
print_status "Setting up environment variables for theming..."
touch "$BASHRC_FILE"

ensure_block_in_bashrc "# Sway install script PATH update" "$(cat <<'EOF'
# Sway install script PATH update
export PATH="$HOME/.local/bin:$PATH"
EOF
)"

ensure_block_in_bashrc "# Sway install script theme exports" "$(cat <<'EOF'
# Sway install script theme exports
export GTK_THEME=Dracula
export QT_QPA_PLATFORMTHEME=qt5ct
export XCURSOR_THEME=Bibata-Modern-Ice
export XCURSOR_SIZE=24
EOF
)"

# Ensure Nymph fetch runs in interactive shells
print_status "Configuring Nymph fetch for shell sessions..."
ensure_block_in_bashrc "# Sway install script Nymph fetch" "$(cat <<'EOF'
# Sway install script Nymph fetch
nymph
EOF
)"

# Configure Helix alias
print_status "Adding Helix alias..."
ensure_block_in_bashrc "# Sway install script Helix alias" "$(cat <<'EOF'
# Sway install script Helix alias
alias hx='helix'
EOF
)"

# Final message
print_success "Sway installation and configuration complete!"
echo
print_status "Configuration summary:"
echo "  • SDDM display manager installed and enabled"
echo "  • Sway WM with Waybar status bar (Dracula theme)"
echo "  • Kitty terminal emulator (Dracula theme)"
echo "  • Brave browser"
echo "  • NimLaunch application launcher"
echo "  • Nymph fetch utility (auto-runs in terminal)"
echo "  • Swaylock screen locker with Dracula theme"
echo "  • Mako notification daemon (Dracula theme)"
echo "  • GTK applications themed with Dracula"
echo "  • PipeWire audio system (modern replacement for PulseAudio)"
echo "  • Paru AUR helper installed"
echo "  • Nerd Fonts with icon support"
echo "  • Screenshot tools (grim + slurp)"
echo "  • Audio/brightness controls configured"
echo "  • Auto-lock after 5 minutes of inactivity"
echo "  • Consistent Dracula theme across all components"
echo
print_warning "Please reboot your system to start SDDM display manager."
print_warning "After reboot, select 'Sway' from the session menu in SDDM."
echo
print_status "Basic key bindings:"
echo "  • Super + Enter: Open terminal (Kitty)"
echo "  • Super + D: NimLaunch application launcher"
echo "  • Super + B: Open Brave browser"
echo "  • Super + N: File manager"
echo "  • Super + I: Lock screen"
echo "  • Super + Shift + Q: Close window"
echo "  • Super + Shift + E: Exit Sway"
echo "  • Print: Screenshot"
echo "  • Super + Print: Area screenshot"
echo
print_status "Configuration files are located in ~/.config/"
print_status "AUR helper 'paru' is available for installing AUR packages"
print_success "Installation script completed successfully! Please reboot to use SDDM."
