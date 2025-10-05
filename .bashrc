#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '


### Sway-Install Additions
export LANG=en_AU.UTF-8
export GDK_BACKEND=wayland
export GTK_THEME="Dracula"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-sway}"
export MOZ_ENABLE_WAYLAND=1
export MANPAGER="sh -c 'awk '\''{ gsub(/\x1B\[[0-9;]*m/, \"\", \$0); gsub(/.\x08/, \"\", \$0); print }'\'' | bat -p -lman'"
man 2 select

# Paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"
export PATH="$HOME/.choosenim/current/bin:$PATH"

# Fzf
eval "$(fzf --bash)"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :500 {}'"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --icons=always --tree --color=always {} | head -200'"

# Zoxide
eval "$(zoxide init bash)"

# bat
export BAT_THEME="Dracula"
alias cat='bat --style=plain'
alias ccat='bat --style=full' 

# eza
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --level=2 --icons'
alias l='eza -lah --icons --git'

# ripgrep with fzf for content search
alias rgf='rg --line-number --no-heading --color=always . | fzf --ansi'

# Fetch
nymph
