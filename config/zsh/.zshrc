# Dependencies: eza, bat, fasd
# Updating: znap pull

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Uncomment this and the last line to enable profiling.
# zmodload zsh/zprof

bindkey -v

# Plugins
[[ -r ~/.config/znap/znap/znap.zsh ]] ||
  git clone --depth 1 -- \
  https://github.com/marlonrichert/zsh-snap.git ~/.config/znap/znap
source ~/.config/znap/znap/znap.zsh

znap source romkatv/zsh-defer
export ZSH_AI_PROVIDER="gemini"
zsh-defer znap source matheusml/zsh-ai
znap source TunaCuma/zsh-vi-man
znap source marlonrichert/zsh-autocomplete
znap source romkatv/powerlevel10k powerlevel10k.zsh-theme
ZSH_AUTOSUGGEST_STRATEGY=(history)
zsh-defer znap source zsh-users/zsh-autosuggestions

typeset -U path
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.cargo/bin
  $path
)

## Input
export EDITOR=nvim
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
# 'jk' to enter normal mode, with 150ms delay (default 400ms).
export KEYTIMEOUT=15
bindkey -r -M viins "^["
bindkey -M viins 'jk' vi-cmd-mode
# Always keep left and right for the cursor
bindkey -M menuselect  '^[[D' .backward-char  '^[OD' .backward-char
bindkey -M menuselect  '^[[C'  .forward-char  '^[OC'  .forward-char
# Ctrl+space to accept zsh-autosuggestion
bindkey "^ " autosuggest-accept
# FIXME - <C-j> and <C-k> to select suggestions. Doesn't really work for some reason.
for mode in main viins vicmd viopp visual isearch menuselect command; do
  bindkey -M $mode '^j' down-line-or-select
  bindkey -M $mode '^k' up-line-or-history
done
# Change cursor shape for normal mode.
zle-keymap-select() {
  if [[ ${KEYMAP} == vicmd ]] || [[ ${KEYMAP} == vitag ]]; then
    echo -ne '\e[1 q' # block
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} == "" ]]; then
    echo -ne '\e[5 q' # beam
  fi
}
zle -N zle-keymap-select
_fix_cursor() { echo -ne '\e[5 q' }
precmd_functions+=(_fix_cursor)

# Power <Tab> with tv for certain commands
TV_SMART_COMMANDS=( cd )
smart-tab() {
  # Get current command, after last ; | && ||.
  local current_cmd="${(z)${LBUFFER##*[;&|] }}"
  if [[ -n "${TV_SMART_COMMANDS[(r)$current_cmd]}" ]]; then
    zle tv-smart-autocomplete
  elif [[ -n "$widgets[down-line-or-select]" ]]; then
    zle down-line-or-select
  else
    zle expand-or-complete
  fi
}
zle -N smart-tab
bindkey '^I' smart-tab
bindkey -M vicmd 'j' down-line
bindkey -M vicmd 'k' up-line
bindkey -M vicmd '?' describe-key-briefly
# <C-x> to edit command line in Vim.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x' edit-command-line
# <C-g> to show current mode
function show-current-mode() {
  zle -M "Mode: $KEYMAP | zle_state: $ZLE_STATE"
}
zle -N show-current-mode
for mode in main viins vicmd viopp visual isearch menuselect command; do
  bindkey -M $mode '^g' show-current-mode
done

## Prompt
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  # os_icon               # os identifier
  context                 # user@hostname
  dir                     # current directory
  vcs                     # git status
  prompt_char             # prompt symbol
)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status                  # exit code of the last command
  command_execution_time  # duration of the last command
  background_jobs         # presence of background jobs
  time
)
typeset -g POWERLEVEL9K_STATUS_ERROR=true

## Aliases
znap eval fasd "fasd --init auto"
[ -f ~/.aliases ] && source ~/.aliases
function expand-command() {
  zle _expand_alias
  zle magic-space
}
zle -N expand-command
bindkey -M main ' ' expand-command

## History
export HISTFILE="$HOME/.zsh_history"
[[ -e $HISTFILE ]] || touch "$HISTFILE"
export HISTSIZE=1000000
export SAVEHIST=$HISTSIZE
setopt extended_history       # save timestamps
setopt inc_append_history     # add executed commands immediately
setopt share_history          # share history between terminals
setopt hist_ignore_space      # ignore commands with a space in front
setopt hist_ignore_all_dups   # ignore duplicates
setopt hist_save_no_dups      # don't save duplicate history
setopt hist_expire_dups_first # delete dups first when HISTFILE size exceeds HISTSIZE
setopt hist_verify            # show history expansion before running
# cd history tab completion
setopt auto_pushd                  # pushes the old directory onto the stack
setopt pushd_minus                 # exchange the meanings of '+' and '-'
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'

## Completion (should mostly be handled by zsh-autocomplete)
zstyle ':autocomplete:*' ignored-input '#*'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
# Fuzzy-match
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
# Include hidden files in completion
_comp_options+=(globdots)
# Exclude . and ..
zstyle ':completion:*' special-dirs false

## WSL config
if [[ -n $WSL_DISTRO_NAME || $(uname -r) == *microsoft* ]]; then
  path+=( /mnt/c/Windows/System32 )
  [[ $PWD == /mnt/c/* ]] && cd ~
fi
export PATH

export COLORTERM=truecolor
# fix NTFS directory colors being unreadable in ls
[[ -f ~/.dircolors ]] && eval $(dircolors -b ~/.dircolors)


[[ -f ~/.work-config ]] && source ~/.work-config
[[ -f ~/.secrets ]] && source ~/.secrets

znap eval tv-init "tv init zsh"

# Override tv-shell-history to include timestamps
_tv_shell_history() {
    emulate -L zsh
    zle -I
    _disable_bracketed_paste
    local current_prompt=$LBUFFER
    output=$(awk -F': |:0;' '{ if ($2 != "") { printf "[%s]%s\n", strftime("%Y-%m-%d %H:%M:%S", $2), $3 } }' ${HISTFILE:-${HOME}/.zsh_history} | \
             sed '1!G;h;$!d' | \
             tv --no-status-bar --input "$current_prompt" \
                --height 25 \
                --source-display="{split:]:0}] {split:]:1..}" \
                --source-output="{split:]:2}")
    zle reset-prompt
    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$(echo "$output")
    fi
    _enable_bracketed_paste
}
zle -N tv-shell-history _tv_shell_history

zsh-defer znap source zdharma-continuum/fast-syntax-highlighting
#zsh-defer znap source zsh-users/zsh-history-substring-search
# Up and down search through substring history
# bindkey '^[[A' history-substring-search-up
#bindkey '^[[B' history-substring-search-down

# zprof
