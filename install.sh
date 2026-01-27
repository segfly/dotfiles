#!/bin/sh
#set -o xtrace
set -o errexit
set -o nounset

OMZSH_PLUGINS="https://github.com/agkozak/zsh-z https://github.com/zsh-users/zsh-autosuggestions https://github.com/zsh-users/zsh-syntax-highlighting https://github.com/marlonrichert/zsh-autocomplete"
PACKAGES="tmux vim vim-gui-common eza grc fastfetch fzf thefuck fd-find bat zoxide"
# also consider: glances htop
# vim-gui-common provides advanced vim features like syntax highlighting.

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

    if [ -f /run/.containerenv ]; then
        return 0 # True
    fi

    if grep -Eq "docker|lxc|kubepods" /proc/self/cgroup; then
        return 0 # True
    fi

    if grep -Eq "^docker-init" /proc/1/sched; then
        return 0 # True
    fi

    if [ -n "${container:-}" ] || [ -n "${DOCKER_CONTAINER:-}" ]; then
        return 0 # True
    fi

    return 1 # False
}

symlink() {
    src_dir="$1"
    target_dir="$2"
    src_abs=$(cd -P "$src_dir" && pwd)
    target_abs=$(cd -P "$target_dir" && pwd)
    src_name="${src_abs##*/}"

    find "$src_dir" -type f | while read -r src_file; do
        rel_path="${src_file#$src_dir/}"
        dir_part="${rel_path%/*}"
        filename="${rel_path##*/}"
        
        # Reset dir_part if no directory structure
        [ "$dir_part" = "$rel_path" ] && dir_part=""
        
        # Convert dot- prefix to .
        new_filename="${filename#dot-}"
        [ "$new_filename" != "$filename" ] && new_filename=".$new_filename"
        
        # Construct target path and create directories
        target_file="$target_dir${dir_part:+/$dir_part}/$new_filename"
        [ -n "$dir_part" ] && mkdir -p "$target_dir/$dir_part"
        
        # Backup existing file
        [ -e "$target_file" ] && mv "$target_file" "$target_file.orig"
        
        # Build relative path from target to source
        if [ -n "$dir_part" ]; then
            depth=$(($(printf '%s' "$dir_part" | tr -cd '/' | wc -c) + 1))
            up_path=$(printf '../%.0s' $(seq 1 $depth))
        else
            up_path=""
        fi
        
        # Determine relative source path
        if [ "${src_abs#$target_abs/}" != "$src_abs" ]; then
            rel_to_src="${src_abs#$target_abs/}"
        else
            rel_to_src="../$src_name"
        fi
        
        ln -s "$up_path$rel_to_src/$rel_path" "$target_file"
    done
}


# Install only if running in a container.
if ! is_container; then
    echo "Not running in a container, skipping automated installation."
else
    # link dotfiles to home directory.
    echo "Linking dotfiles to home directory..."    
    symlink ./common "$HOME"
    symlink ./fish "$HOME"
    symlink ./zsh "$HOME"
    symlink ./tmux "$HOME"
    symlink ./vim "$HOME"

    # Install packages
    echo "Installing packages..."
    install_pkgs "$PACKAGES"

    # Configure fish shell and plugins
    if ! command -v fish >/dev/null 2>&1; then
        echo "Fish shell is not available. Skipping fish plugins installation."
    else
        echo "Configuring fish shell and plugins..."

        /usr/bin/env fish << 'EOF'
            # Install fisher plugin manager
            curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source                    

            # Install fish plugins from fish_plugins file
            fisher update

            # Configure tide prompt
            tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Light --show_time=No --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='Two lines, character' --prompt_connection=Disconnected --powerline_right_prompt_frame=No --prompt_spacing=Sparse --icons='Many icons' --transient=Yes
EOF
    fi # End of fish

    # Configure zsh shell and plugins
    if ! command -v zsh >/dev/null 2>&1; then
        echo "Zsh is not available. Skipping zsh plugins installation."
    else
        echo "Configuring zsh shell and plugins..."

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
    fi # End of zsh

    # Configure tmux and plugins
    if ! command -v tmux >/dev/null 2>&1; then
        echo "Tmux not found, skipping configuration."
    else
        echo "Configuring tmux and plugins..."

        if ! [ -d "$HOME/.tmux/plugins/tpm" ]; then
            echo "Installing tmux plugin manager"
            git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        else
            echo "Skipping installation of existing tmux plugin manager"
        fi

        if [ -d "$HOME/.tmux/plugins/tpm" ]; then
            ~/.tmux/plugins/tpm/bin/install_plugins
        fi
    fi # End of tmux
fi # End of container check