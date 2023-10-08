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
