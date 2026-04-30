#!/bin/bash
set -e

# ============================================================
# Bootstrap rcm if rcup isn't on PATH (laptop / non-Debian boxes).
# Devpods get rcm via the apt `rcm` package, so this is a no-op there.
# ============================================================
if ! command -v rcup >/dev/null 2>&1; then
  echo "rcup not found — building rcm from source into ~/.local..."
  mkdir -p ~/src ~/.local/bin ~/.local/share/rcm
  if [ ! -d ~/src/rcm ]; then
    git clone --depth=1 https://github.com/thoughtbot/rcm.git ~/src/rcm
  fi
  ( cd ~/src/rcm && ./autogen.sh && ./configure --prefix="$HOME/.local" )
  install -m 755 ~/src/rcm/bin/{rcup,rcdn,mkrc,lsrc} ~/.local/bin/
  install -m 644 ~/src/rcm/share/rcm.sh                ~/.local/share/rcm/
  export PATH="$HOME/.local/bin:$PATH"
fi

# ============================================================
# Seed ~/.rcrc BEFORE rcup runs.
# rcup reads ~/.rcrc to learn DIRS="claude" (recurse into the claude/
# subdir instead of symlinking ~/.claude whole, which would collide with
# Claude Code's runtime state). Without this seed, the first rcup -f
# would either fail or clobber ~/.claude.
# ============================================================
if [ ! -e ~/.rcrc ]; then
  ln -sfn "$(cd "$(dirname "$0")" && pwd)/rcrc" ~/.rcrc
fi

# ============================================================
# Symlink everything in ~/.dotfiles into $HOME.
# ============================================================
rcup -f

# ============================================================
# Install oh-my-zsh via its official installer.
#   --unattended   : skip interactive prompts
#   --keep-zshrc   : do NOT overwrite our dotfiles-managed ~/.zshrc
#   CHSH=no        : devpod sets shell: zsh; laptop user owns chsh
#   RUNZSH=no      : don't drop into a zsh subshell at the end
# Guarded so it only runs on a fresh box.
# ============================================================
if [ ! -d ~/.oh-my-zsh ]; then
  CHSH=no RUNZSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)" \
    "" --unattended --keep-zshrc
fi

# ============================================================
# Custom plugins + powerlevel10k theme.
# IMPORTANT: clone into ~/.oh-my-zsh-custom (NOT ~/.oh-my-zsh/custom) —
# this matches `ZSH_CUSTOM=$HOME/.oh-my-zsh-custom` set in zshrc.
# Each clone is guarded so re-runs are no-ops.
# ============================================================
ZSH_CUSTOM=~/.oh-my-zsh-custom
mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

clone_if_missing() {
  local dest="$1" url="$2"
  [ -d "$dest" ] || git clone --depth=1 "$url" "$dest"
}

clone_if_missing "$ZSH_CUSTOM/plugins/zsh-completions"         https://github.com/zsh-users/zsh-completions.git
clone_if_missing "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting.git
clone_if_missing "$ZSH_CUSTOM/plugins/zsh-autosuggestions"     https://github.com/zsh-users/zsh-autosuggestions.git
clone_if_missing "$ZSH_CUSTOM/themes/powerlevel10k"            https://github.com/romkatv/powerlevel10k.git
