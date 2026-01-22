# Commands to run in interactive sessions can go here
if status is-interactive
    function fish_greeting
        fastfetch
        echo -e "Run "(set_color --bold cyan)"keyhelp"(set_color normal)" for shortcut cheatsheet.\n"
    end

    # Aliases
    alias ls 'lsd'
    alias ll 'ls -la'

    # FZF plugin key bindings
    fzf_configure_bindings --directory=\ct

    # Key bindings help
    function keyhelp
        set_color green --bold
        echo "Keyboard Shortcuts:"
        set_color normal

        echo -e "\nSearch Shortcuts:"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+T" (set_color normal) "Search directory"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+R" (set_color normal) "Search History"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+L" (set_color normal) "Search git log"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+S" (set_color normal) "Search git status"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+P" (set_color normal) "Search processes"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+V" (set_color normal) "Search variables"

        echo -e "\nText Editing Shortcuts:"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+L"     (set_color normal) "Clear screen"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+U"     (set_color normal) "Delete to beginning of line"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+K"     (set_color normal) "Delete to end of line"
        printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+W"     (set_color normal) "Delete word backwards"
    end

    # zoxide initialization
    zoxide init --cmd cd fish | source
end

# Wrapper for bat to use batcat for the fzf plugin (must be outside is-interactive block)
function bat
    batcat $argv
end

# Ensure fzf plugin shows hidden files and ignores .gitignore
set fzf_fd_opts --hidden --no-ignore --max-depth 1 