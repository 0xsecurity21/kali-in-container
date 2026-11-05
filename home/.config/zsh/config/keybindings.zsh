bindkey -e

# Up/down search history entries that begin with the current command line.
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
if [[ -n "${terminfo[kcuu1]:-}" && -n "${terminfo[kcud1]:-}" ]]; then
  bindkey "$terminfo[kcuu1]" history-beginning-search-backward-end
  bindkey "$terminfo[kcud1]" history-beginning-search-forward-end
fi
