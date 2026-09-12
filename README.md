# dots
dotfiles managed by stow

* https://github.com/luanvil/lnko, then `cd config && lnko link *`.
* https://github.com/ghostty-org/ghostty
* https://github.com/BurntSushi/ripgrep (sometimes rg)
* https://github.com/michel-kraemer/zsh-patina
* https://github.com/sharkdp/bat (sometimes batcat)
* https://github.com/sharkdp/fd (sometimes fdfind or fd-find)
* https://github.com/eza-community/eza
* https://github.com/davatorium/rofi
* https://github.com/rvaiya/keyd
  * Then link to `/etc/keyd/` as this is a system-level daemon:

    ```bash
    sudo ln -sf ~/.config/keyd/default.conf /etc/keyd/default.conf
    ```
