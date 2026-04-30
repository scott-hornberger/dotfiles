#!/bin/bash
set -e

# Bootstrap rcm if rcup isn't already on PATH.
#
# Most machines won't have rcm packaged (Uber devpods, restricted apt, etc.)
# so we build it from source into ~/.local. rcm is just Perl/shell scripts —
# the build needs perl + autoconf + automake + make (all near-universal).
# We skip the man-page step because that needs python-docutils (rst2man).
if ! command -v rcup >/dev/null 2>&1; then
  echo "rcup not found — building rcm 1.3.x from source into ~/.local..."
  mkdir -p ~/src ~/.local/bin ~/.local/share/rcm
  if [ ! -d ~/src/rcm ]; then
    git clone --depth=1 https://github.com/thoughtbot/rcm.git ~/src/rcm
  fi
  ( cd ~/src/rcm && ./autogen.sh && ./configure --prefix="$HOME/.local" )
  install -m 755 ~/src/rcm/bin/{rcup,rcdn,mkrc,lsrc} ~/.local/bin/
  install -m 644 ~/src/rcm/share/rcm.sh                ~/.local/share/rcm/
  export PATH="$HOME/.local/bin:$PATH"
fi

# Bootstrap ~/.rcrc — rcup reads this BEFORE doing anything, so if we let
# rcup manage it as a normal dotfile we hit a chicken-and-egg: rcup wouldn't
# know about DIRS="claude" on first run and would try to symlink ~/.claude
# whole, clobbering Claude Code's runtime state. Pre-seed the symlink here
# so rcup sees the right config from the very first invocation.
if [ ! -e ~/.rcrc ]; then
  ln -s "$(pwd)/rcrc" ~/.rcrc
fi

# Symlink all dotfiles into $HOME (rcup recurses into dirs listed in ~/.rcrc).
rcup -f

# download and install the required plugins
ZSH_CUSTOM=~/.oh-my-zsh-custom

git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
