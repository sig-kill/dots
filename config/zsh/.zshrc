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

typeset -U path
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.cargo/bin
  $path
)

# Plugins
[[ -r ~/.config/znap/znap/znap.zsh ]] ||
  git clone --depth 1 -- \
  https://github.com/marlonrichert/zsh-snap.git ~/.config/znap/znap
source ~/.config/znap/znap/znap.zsh

znap source romkatv/zsh-defer
znap source romkatv/powerlevel10k powerlevel10k.zsh-theme
znap source TunaCuma/zsh-vi-man
znap source marlonrichert/zsh-autocomplete
znap source zsh-users/zsh-autosuggestions
export ZSH_AI_PROVIDER="gemini"
zsh-defer znap source matheusml/zsh-ai

# cargo install --locked zsh-patina
(( $+commands[zsh-patina] )) && znap eval zsh-patina 'zsh-patina activate'
# cargo install --locked navi
(( $+commands[navi] )) && znap eval navi 'navi widget zsh'
bindkey ^_ _navi_widget

## Input
export EDITOR=nvim
# consider '/' a wordbreak
export WORDCHARS=${WORDCHARS//[\/]}
bindkey '^[[3~'   delete-char # <Del>
for m (main menuselect); do
  bindkey -M $m "^[[1;5C" forward-word # <C-right>
  bindkey -M $m "^[[1;5D" backward-word # <C-left>
  bindkey -M $m "^[[H"    beginning-of-line # <Home>
  bindkey -M $m "^[[F"    end-of-line # <End>
  bindkey -M $m "^[[1~"   beginning-of-line # <Home> (tmux)
  bindkey -M $m "^[[4~"   end-of-line # <End> (tmux)
done
# 'jk' to enter normal mode, with 150ms delay (default 400ms).
export KEYTIMEOUT=15
bindkey -r -M viins "^["
bindkey -M viins 'jk' vi-cmd-mode
# Always keep left and right for the cursor
bindkey -M menuselect  '^[[D' .backward-char  '^[OD' .backward-char
bindkey -M menuselect  '^[[C'  .forward-char  '^[OC'  .forward-char
# Ctrl+space to accept zsh-autosuggestion
bindkey "^ " autosuggest-accept
# Use <C-j> and <C-k> to navigate completion menus.
bindkey -M menuselect '^j' menu-complete
bindkey -M menuselect '^k' reverse-menu-complete
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
# Reclaim <C-s> and <C-q>
[[ -t 1 ]] && stty -ixon

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
for m (main viins vicmd viopp visual isearch menuselect command); do
  bindkey -M $m '^g' show-current-mode
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


## WSL config
if [[ -n $WSL_DISTRO_NAME || $(uname -r) == *microsoft* ]]; then
  path+=( /mnt/c/Windows/System32 )
  [[ $PWD == /mnt/c/* ]] && cd ~
fi
export PATH
# fix NTFS directory colors being unreadable in ls
[[ -f ~/.dircolors ]] && znap eval dircolors_fix "dircolors -b ~/.dircolors"

## Completion
zstyle ':autocomplete:*' ignored-input '#*'
zstyle ':autocomplete:*' list-lines 20
zstyle ':autocomplete:history-search:*' list-lines 20
zstyle ':autocomplete:*' delay 0.1
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:*' add-semicolon no

zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Group completions and style descriptions
# zstyle ':completion:*' group-name ''
# zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
# zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
# zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
# zstyle ':completion:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'

# Modern menu selection highlighting
zstyle ':completion:*' menu select
# Use the current LS_COLORS and a purple highlight (ma) for the selection
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" "ma=48;5;61;1"

# Fuzzy-match
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*'
# Include hidden files in completion
_comp_options+=(globdots)
# Exclude . and ..
zstyle ':completion:*' special-dirs false

export COLORTERM=truecolor


[[ -f ~/.work-config ]] && source ~/.work-config
[[ -f ~/.secrets ]] && source ~/.secrets

znap eval tv-init "tv init zsh"

# Override tv-shell-history to include timestamps and prevent auto-execution
_tv_shell_history() {
    emulate -L zsh
    zle -I
    _disable_bracketed_paste
    local current_prompt=$LBUFFER
    # Use tac for fast reversal and tv --no-sort to prioritize recency
    # Strip trailing newlines with sed to prevent accidental execution
    output=$(awk -F": |:0;" "{ if (\$2 != \"\") { printf \"[%s]%s\n\", strftime(\"%Y-%m-%d %H:%M:%S\", \$2), \$3 } }" ${HISTFILE:-${HOME}/.zsh_history} | \
             tac | \
             tv --no-status-bar --no-sort --input "$current_prompt" \
                --height 25 \
                --source-display="{split:]:0}] {split:]:1..}" \
                --source-output="{split:]:2}" | sed 's/\n//g')
    zle reset-prompt
    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$(echo -n "$output")
    fi
    _enable_bracketed_paste
}
zle -N tv-shell-history _tv_shell_history

#zsh-defer znap source zdharma-continuum/fast-syntax-highlighting
#zsh-defer znap source zsh-users/zsh-history-substring-search
# Up and down search through substring history
# bindkey '^[[A' history-substring-search-up
#bindkey '^[[B' history-substring-search-down

# zprof
