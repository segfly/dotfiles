#!/bin/sh
#set -o xtrace
set -o errexit
set -o nounset

# Parse command line arguments
FORCE_OVERWRITE=false
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_OVERWRITE=true
            ;;
    esac
done

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

# Calculate relative path from one directory to a file
# Returns absolute path if backtracking depth > 2 or no common ancestor
# Usage: relpath <from_dir> <to_file>
relpath() {
    from_dir="$1"
    to_file="$2"
    
    result=""
    common="$from_dir"
    depth=0
    
    # Walk up from from_dir until we find a common prefix with to_file
    while [ "${to_file#$common/}" = "$to_file" ] && [ "$to_file" != "$common" ]; do
        # Move up one level
        parent="${common%/*}"
        [ "$parent" = "$common" ] && parent=""
        [ -z "$parent" ] && parent="/"
        
        common="$parent"
        result="../$result"
        depth=$((depth + 1))
        
        # If depth > 2 or we've reached root, use absolute path
        if [ "$depth" -gt 2 ] || [ "$common" = "/" ]; then
            printf '%s' "$to_file"
            return
        fi
    done
    
    # common is now the longest common prefix directory
    if [ "$to_file" = "$common" ]; then
        printf '%s' "${result}."
    else
        printf '%s%s' "$result" "${to_file#$common/}"
    fi
}

symlink() {
    src_dir="$1"
    target_dir="$2"
    
    # Get the directory where this script is located
    script_dir="$(cd "$(dirname "$0")" && pwd -P)"
    
    # Resolve src_dir: if relative, resolve from script directory
    if [ "${src_dir#/}" = "$src_dir" ]; then
        # src_dir is relative, resolve from script directory
        src_abs=$(cd -P "$script_dir/$src_dir" && pwd -P)
    else
        src_abs=$(cd -P "$src_dir" && pwd -P)
    fi
    
    # Resolve target_dir to absolute path
    target_abs=$(cd -P "$target_dir" && pwd -P)

    find "$src_abs" -type f | while read -r src_file; do
        rel_path="${src_file#$src_abs/}"
        dir_part="${rel_path%/*}"
        filename="${rel_path##*/}"
        
        # Reset dir_part if no directory structure
        [ "$dir_part" = "$rel_path" ] && dir_part=""
        
        # Convert dot- prefix to .
        new_filename="${filename#dot-}"
        [ "$new_filename" != "$filename" ] && new_filename=".$new_filename"
        
        # Construct target path and create directories
        target_file="$target_abs${dir_part:+/$dir_part}/$new_filename"
        [ -n "$dir_part" ] && mkdir -p "$target_abs/$dir_part"
        
        # Handle existing target
        if [ -L "$target_file" ]; then
            # It's a symlink - remove it to recreate
            rm "$target_file"
        elif [ -e "$target_file" ]; then
            # It's a real file/directory
            if [ "$FORCE_OVERWRITE" = "true" ]; then
                echo "Overwriting existing file: $target_file"
                rm -rf "$target_file"
            else
                echo "Skipping existing file: $target_file"
                continue
            fi
        fi
        
        # Calculate the directory where the symlink will be created
        link_dir="$target_abs${dir_part:+/$dir_part}"
        
        # Calculate proper relative path from link location to source file
        rel_link=$(relpath "$link_dir" "$src_file")
        
        ln -s "$rel_link" "$target_file"
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