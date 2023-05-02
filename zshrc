# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Start tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# autojump j
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/sth/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git 
  zsh-autosuggestions
  zsh-completions
  bazel
  zsh-syntax-highlighting # must be last 
)
autoload -U compinit && compinit


# Load pure prompt
#autoload -U promptinit; promptinit
#prompt pure

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true
bindkey "^[^[[C" forward-word

# fuzzy finder
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# DIRENV (needed for multiple gopaths)
# Hook direnv into the shell
# echo -e "`date +"%Y-%m-%d %H:%M:%S"` direnv hooking bash"
eval "$(direnv hook zsh)"

# BAZEL AUTO-COMPLETION
# This way the completion script does not have to parse Bazel's options
# repeatedly.  The directory in cache-path must be created manually.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# GOLAND
alias goland='/usr/local/bin/goland'

# WEBSTORM
alias webstorm='/usr/local/bin/webstorm'

# EDIT/VIEW ZSHRC
alias ez='vim ~/.zshrc'
alias sz='source ~/.zshrc'

# GIT
alias gs='g s -uno'


# set EDITOR to vim
export VISUAL=vim
export EDITOR="$VISUAL"

# aurora
alias aurora-tunnel="ssh -D 8127 -f -C -q -N bastion.uber.com"

# coconut-web
alias weblint="yarn lint --fix && npx flow"
export PATH="/usr/local/opt/go@1.16/bin:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"


# JDK
unset JAVA_HOME
export JAVA8_HOME="$(/usr/libexec/java_home -v1.8)"
export JAVA11_HOME="$(/usr/libexec/java_home -v11)"
alias jdk_11='export JAVA_HOME="$JAVA11_HOME" && export PATH="$JAVA_HOME/bin:$PATH"'
alias jdk_8='export JAVA_HOME="$JAVA8_HOME" && export PATH="$JAVA_HOME/bin:$PATH"'
jdk_11 # Use jdk 11 as the default jdk

source $ZSH/oh-my-zsh.sh

alias diffnow="arc diff --use-commit-message HEAD --nointeractive"

# MINECRAFT
alias ssh-minecraft="ssh opc@129.151.197.212 -i ~/.ssh/ocp_minecraft/ssh-key-2022-09-24.key"
# On minecraft host, `java -Xmx1024M -Xms1024M -jar server.jar nogui`



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
