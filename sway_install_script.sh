#!/bin/bash

# Sway WM Installation Script for Minimal Arch Linux
# This script installs and configures a complete Sway desktop environment

set -euo pipefail
IFS=$'\n\t'

# Colors for output
PURPLE=$'\033[38;2;189;147;249m'
PINK=$'\033[38;2;255;121;198m'
GREEN=$'\033[38;2;80;250;123m'
YELLOW=$'\033[38;2;241;250;140m'
CYAN=$'\033[38;2;139;233;253m'
RED=$'\033[38;2;255;85;85m'
NC=$'\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TARGET_BASHRC="$HOME/.bashrc"
readonly REPO_BASHRC="$SCRIPT_DIR/.bashrc"

print_banner() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033c'
    fi
    printf '%s' "${PURPLE}"
    cat <<'EOF'
███████╗██╗    ██╗ █████╗ ██╗   ██╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
███████╗██║ █╗ ██║███████║ ╚████╔╝█████╗██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
╚════██║██║███╗██║██╔══██║  ╚██╔╝ ╚════╝██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
███████║╚███╔███╔╝██║  ██║   ██║        ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝        ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝                                                   
EOF
    printf '%s\n' "${NC}"
}

clone_and_install_paru() {
    if pacman -Si paru >/dev/null 2>&1; then
        print_status "Installing paru from official repositories..."
        if sudo pacman -S --noconfirm --needed paru; then
            return
        fi
        print_warning "Failed to install paru via pacman repo; falling back to AUR build."
    else
        print_warning "paru not present in official repositories; building from AUR."
    fi

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

load_package_list() {
    local file="$1"
    local -n _out="$2"

    if [[ ! -f "$file" ]]; then
        print_error "Package list '$file' not found."
        exit 1
    fi

    mapfile -t _out < <(sed -e 's/#.*//' -e 's/^[ \t]*//' -e 's/[ \t]*$//' "$file" | awk 'NF')
}

install_package_group() {
    local description="$1"
    local manager="$2"
    local file="$3"
    local packages=()

    load_package_list "$file" packages
    if (( ${#packages[@]} == 0 )); then
        print_warning "No packages defined in $file; skipping."
        return
    fi

    print_status "$description"
    if [[ $manager == "pacman" ]]; then
        sudo pacman -S --noconfirm --needed "${packages[@]}"
    else
        paru -S --noconfirm --needed --skipreview "${packages[@]}"
    fi
}

deploy_repo_bashrc() {
    if [[ ! -f "$REPO_BASHRC" ]]; then
        print_error "Repository .bashrc not found at $REPO_BASHRC"
        exit 1
    fi

    local backup="$TARGET_BASHRC.pre-sway-install.$(date +%Y%m%d%H%M%S)"
    if [[ -e "$TARGET_BASHRC" ]]; then
        print_warning "Existing ~/.bashrc detected; backing up to ${backup/#$HOME/~}"
        cp -L "$TARGET_BASHRC" "$backup"
    fi

    install -Dm644 "$REPO_BASHRC" "$TARGET_BASHRC"
    print_status "Installed repository .bashrc to ${TARGET_BASHRC/#$HOME/~}"
}

PACMAN_GROUPS=(
    "Installing core system packages::packages/pacman-core.txt"
    "Installing desktop environment packages::packages/pacman-desktop.txt"
    "Installing PipeWire audio stack::packages/pacman-audio.txt"
    "Installing font packages::packages/pacman-fonts.txt"
    "Installing CLI utilities and extras::packages/pacman-extras.txt"
)

PARU_GROUPS=(
    "Installing AUR applications::packages/paru-apps.txt"
    "Installing AUR theming packages::packages/paru-themes.txt"
)

# Function to print colored output
print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
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

print_banner
print_status "Starting Sway WM installation on minimal Arch Linux..."

if [[ -t 0 ]]; then
    while true; do
        printf "Do you want to proceed with installing the Sway environment? [y/N]: "
        if ! IFS= read -r response; then
            print_warning "No input received; installation cancelled."
            exit 0
        fi

        case "${response}" in
            [Yy]* )
                break
                ;;
            [Nn]* | "" )
                print_warning "Installation cancelled by user."
                exit 0
                ;;
            * )
                print_warning "Please answer 'y' or 'n'."
                ;;
        esac
    done
else
    print_warning "No interactive terminal detected; continuing without confirmation."
fi

# Update system
print_status "Updating system packages..."
sudo pacman -Syu --noconfirm


for entry in "${PACMAN_GROUPS[@]}"; do
    description="${entry%%::*}"
    relative_path="${entry##*::}"
    install_package_group "$description" "pacman" "$SCRIPT_DIR/$relative_path"
done


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

for entry in "${PARU_GROUPS[@]}"; do
    description="${entry%%::*}"
    relative_path="${entry##*::}"
    install_package_group "$description" "paru" "$SCRIPT_DIR/$relative_path"
done

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

print_status "Installing custom application desktop entries..."
install -Dm644 "$SCRIPT_DIR/.local/share/applications/helix-kitty.desktop" \
    "$HOME/.local/share/applications/helix-kitty.desktop"
install -Dm644 "$SCRIPT_DIR/.local/share/file-manager/actions/open-terminal.desktop" \
    "$HOME/.local/share/file-manager/actions/open-terminal.desktop"

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

print_status "Deploying repository .bashrc..."
deploy_repo_bashrc

# Final message
print_banner
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
echo "  • Super + N: Open PCManFM file manager"
echo "  • Super + I: Lock screen"
echo "  • Super + Shift + Q: Close window"
echo "  • Super + Shift + E: Exit Sway"
echo "  • Print: Screenshot"
echo "  • Super + Print: Area screenshot"
echo
print_status "Configuration files are located in ~/.config/"
print_status "AUR helper 'paru' is available for installing AUR packages"
print_success "Installation script completed successfully! Please reboot to use SDDM."
