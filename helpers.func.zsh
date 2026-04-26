# backup_helper.sh

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi

# Function to backup and symlink a file or directory with a timestamped backup
install_config() {
    local source="$1"
    local destination="$2"

    # Get the current timestamp
    local timestamp=$(date +'%Y%m%d%H%M%S')

    # Construct the backup file or directory name with a timestamp
    local backup="${DOTFILES}/backups/${BACKUP_PREFIX}$(basename ${destination}).${timestamp}}"

    # Check if the destination exists
    if [ -e "$destination" ]; then
        # If the destination is a directory, move it to the timestamped backup directory
        if [ -d "$destination" ]; then
            # echo "\033[0;34mLooking for an existing directory $(basename "$destination")...\033[0m"
            echo "\033[0;33mFound directory $(basename "$destination").\033[0m \033[0;32mBacking up to $backup\033[0m";
            mv "$destination" "$backup"
        else
            # If the destination is a file or a symbolic link, move it to the timestamped backup file
            # echo "\033[0;34mLooking for an existing file $(basename "$destination")...\033[0m"
            echo "\033[0;33mFound file $(basename "$destination").\033[0m \033[0;32mBacking up to $backup\033[0m";
            mv "$destination" "$backup"
        fi
    fi

    # Create a symlink from the source to the destination
    echo "\033[0;34mSymlinking $(basename "$destination")...\033[0m"
    ln -s "$source" "$destination"
}

# Generate a per-machine config file from a generator function.
#
# The generator writes file content to stdout and returns 0 on success;
# on failure it should emit a reason to stderr and return non-zero — the
# helper then skips writing and prints a "Skipping…" line. Generator stderr
# passes through to the terminal, so probe failures stay visible.
#
# Destinations should follow the *.local.* convention so they're gitignored.
# Drop generated zsh files into zsh/zshenv.d/ for non-interactive subshells
# (Claude tool calls) or zsh/zshrc.d/ for interactive shells only — both are
# auto-sourced.
#
# Usage: generate_config <destination> <generator-fn>
generate_config() {
    local destination="$1"
    local generator="$2"
    local content

    mkdir -p "$(dirname "$destination")"

    if ! content=$("$generator"); then
        echo "\033[0;33mSkipping $(basename "$destination") (generator failed)\033[0m"
        return 0
    fi

    print -r -- "$content" > "$destination"
    echo "\033[0;34mGenerated $(basename "$destination")\033[0m"
}
