# Commands to run in interactive sessions can go here
if status is-interactive
    function fish_greeting
        if command -v fastfetch > /dev/null
            fastfetch
        end
        echo -e "Run "(set_color --bold cyan)"keyhelp"(set_color normal)" for shortcut cheatsheet.\n"
    end

    # Aliases
    if command -v uv > /dev/null
        alias ls 'eza --icons=auto --classify=always'
        alias ll 'ls -lag --smart-group --time-style=long-iso'
        alias llt 'll --total-size'
        alias tree 'll --tree --total-size'
    end

    if command -v uv > /dev/null
        alias uv_outdated 'uv tree --outdated -d 1 | grep -e "^├.*latest.*"'
    end        

    # Function to switch git origin from HTTPS to SSH
    function git_switch_origin_to_ssh
        if not command -v git >/dev/null
            return
        end

        if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
            return
        end

        set origin_url (git remote get-url origin 2>/dev/null)
        # Match any HTTPS URL and convert to SSH format (git@host:repo.git)
        if string match -qr '^https?://[^/]+/' -- $origin_url
            set host (string replace -r '^https?://([^/]+)/.*' '$1' -- $origin_url)
            set repo (string replace -r '^https?://[^/]+/(.*)' '$1' -- $origin_url)
            git remote set-url origin git@$host:$repo
        end
    end

    # Customize the pager (replace with cat for no paging)
    set -x PAGER "less -FRX --mouse --wheel-lines 3"

    # FZF plugin key bindings
    fzf_configure_bindings --directory=\ct
    
    # Sponge plugin delay
    set sponge_delay 8

    # Key bindings help
    function keyhelp
        begin
            set_color green --bold
            echo "Keyboard Shortcuts:"
            set_color normal

            echo -e "\nText Editing Shortcuts:"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+L"     (set_color normal) "Clear screen"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+U"     (set_color normal) "Delete to beginning of line"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+K"     (set_color normal) "Delete to end of line"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+W"     (set_color normal) "Delete word backwards"

            echo -e "\nFzf Search Shortcuts:"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+T" (set_color normal) "Search directory"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+R" (set_color normal) "Search History"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+L" (set_color normal) "Search git log"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+S" (set_color normal) "Search git status"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+P" (set_color normal) "Search processes"
            printf "%s%-12s%s %s\n" (set_color cyan) "Ctrl+Alt+V" (set_color normal) "Search variables"

            if command -v zoxide > /dev/null
                echo -e "\nZoxide Shortcuts (aliased as 'cd'):"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd foo" (set_color normal) "cd into highest ranked directory matching foo"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd foo bar" (set_color normal) "cd into highest ranked directory matching foo and bar"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd foo /" (set_color normal) "cd into a subdirectory starting with foo"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd ~/foo" (set_color normal) "z also works like a regular cd command"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd foo/" (set_color normal) "cd into relative path"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd -" (set_color normal) "cd into previous directory"
                printf "%s%-12s%s %s\n" (set_color cyan) "cdi foo" (set_color normal) "cd with interactive selection (using fzf)"
                printf "%s%-12s%s %s\n" (set_color cyan) "cd foo <TAB>" (set_color normal) "show interactive completions (zoxide v0.8.0+)"
            end

            if command -v thefuck > /dev/null
                echo -e "\nfix_cmd Shortcuts:"
                printf "%s%-12s%s %s\n" (set_color cyan) "Shift+Alt+F" (set_color normal) "Correct previous console command"
            end        

            if command -v uv > /dev/null
                echo -e "\nBuild aliases:"
                printf "%s%-12s%s %s\n" (set_color cyan) "uv_outdated" (set_color normal) "Check for outdated top-level python packages"
            end
        end | eval $PAGER
    end

    # zoxide initialization
    if command -v zoxide > /dev/null
        zoxide init --cmd cd fish | source
    end

    # thefuck initialization
    if command -v thefuck > /dev/null
        function fix_cmd -d "Correct your previous console command"
            set -l fucked_up_command $history[1]
            printf '\033[A\033[2K\033[A\033[2K'
            env TF_SHELL=fish TF_ALIAS=fix_cmd PYTHONIOENCODING=utf-8 thefuck $fucked_up_command THEFUCK_ARGUMENT_PLACEHOLDER $argv | read -l unfucked_command
            
            if [ "$unfucked_command" != "" ]
                printf '\033[A\033[2K\033[A\033[2K'
                commandline -r -- $unfucked_command
                builtin history delete --exact --case-sensitive -- "fix_cmd"
                builtin history delete --exact --case-sensitive -- $fucked_up_command
            end
        end
        
        # Bind Ctrl+Alt+F to execute the function
        bind \e\cF 'commandline -r "fix_cmd"; commandline -f execute'
    end
end

# Wrapper for bat to use batcat for the fzf plugin (must be outside is-interactive block)
if command -v batcat > /dev/null
    function bat
        batcat $argv
    end
end

# Ensure fzf plugin shows hidden files and ignores .gitignore
set fzf_fd_opts --hidden --no-ignore --max-depth 5 

# Configure Tide to show username@hostname (context)
set tide_context_always_display true
set tide_left_prompt_items context pwd git newline character
set tide_right_prompt_items status cmd_duration jobs direnv bun node python rustc java php pulumi ruby go gcloud kubectl distrobox toolbox terraform aws nix_shell crystal elixir zig
