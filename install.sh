#!/bin/sh
#set -o xtrace
set -o errexit
set -o nounset

OMZSH_PLUGINS="https://github.com/agkozak/zsh-z https://github.com/zsh-users/zsh-autosuggestions https://github.com/zsh-users/zsh-syntax-highlighting https://github.com/marlonrichert/zsh-autocomplete"
PACKAGES="tmux vim vim-gui-common"

echo "Dotfiles installation started..."

# Helper method to install packages on alpine or debian based systems.
if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get package manager found."
    install_pkgs() {
        if ! dpkg -s "$@" >/dev/null 2>&1; then
            if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
                sudo apt-get update -y
            fi
            sudo apt-get -y install --no-install-recommends $@
        fi
    }
elif command -v apk >/dev/null 2>&1; then
    echo "apk package manager found."
    install_pkgs() {
        if ! apk info "$@" >/dev/null 2>&1; then
            sudo apk update
            sudo apk add $@
        fi
    }
else
    echo "Package manager not found. Skipping package installation."
    install_pkgs() {}
fi

is_container() {
    if [ -f /.dockerenv ]; then
        return 0 # True
    fi

    if grep -Eq "docker|lxc|kubepods" /proc/self/cgroup; then
        return 0 # True
    fi

    if grep -Eq "^docker-init" /proc/1/sched; then
        return 0 # True
    fi

    if [ -n "$container" ] || [ -n "$DOCKER_CONTAINER" ]; then
        return 0 # True
    fi

    return 1 # False
}

# Install only if running in a container.
if ! is_container; then
    echo "Not running in a container, skipping automated installation."
else
    if ! command -v zsh >/dev/null 2>&1; then
        echo "Zsh is not available. Skipping zsh plugins installation."
    else
        # Copy dotfiles to home directory.
        find zsh -type f -exec cp -r {} $HOME/ \;

        if ! [ -d "$HOME/.oh-my-zsh" ]; then
            echo "Installing oh-my-zsh"
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"        
        fi

        OMZSH_PLUGINS_LOCATION="$HOME/.oh-my-zsh/custom/plugins"
        mkdir -p "$OMZSH_PLUGINS_LOCATION"

        for plugin in $OMZSH_PLUGINS; do
            plugin_name=$(basename $plugin)
            if ! [ -d "$OMZSH_PLUGINS_LOCATION/$plugin_name" ]; then
                echo "Installing plugin: $plugin_name"        
                git clone --depth 1 $plugin "$OMZSH_PLUGINS_LOCATION/$plugin_name"
            else
                echo "Skipping installation of existing plugin: $plugin_name"        
            fi
        done

        # Install powerlevel10k theme separately.
        if ! [ -d "$HOME/powerlevel10k" ]; then
            echo "Installing theme: powerlevel10k"        
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
        else
            echo "Skipping installation of existing theme: powerlevel10k"
        fi
    fi # End of zsh check

    # Install packages
    install_pkgs "$PACKAGES"

    if ! command -v tmux >/dev/null 2>&1; then
        echo "tmux not found, skipping configuration."
    else
        # Copy dotfiles to home directory.
        find tmux -type f -exec cp -r {} $HOME/ \;

        if ! [ -d "$HOME/.tmux/plugins/tpm" ]; then
            echo "Installing tmux plugin manager"
            git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        else
            echo "Skipping installation of existing tmux plugin manager"
        fi

        if [ -d "$HOME/.tmux/plugins/tpm" ]; then
            ~/.tmux/plugins/tpm/bin/install_plugins
        fi
    fi # End of tmux check

    if ! command -v vi >/dev/null 2>&1; then
        echo "vim not found, skipping configuration."
    else
        # Copy dotfiles to home directory.
        find vim -type f -exec cp -r {} $HOME/ \;
    fi # End of vim check    

fi # End of container check