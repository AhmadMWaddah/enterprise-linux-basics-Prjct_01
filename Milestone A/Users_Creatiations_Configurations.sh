#!/bin/bash

# Rocky Linux User Management Script
# Description: Creates users with shell selection, optional sudo privileges and copies SSH keys from main user

# Configuration Section (modify as needed)
# Set the main user whose SSH keys will be copied (change this to your main user)
CURRENT_USER="<Main User>"
DEFAULT_SHELL="/bin/bash"
DEFAULT_GROUP="users"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Error: This script must be run with sudo privileges"
        print_message $YELLOW "Usage: sudo $0"
        exit 1
    fi
}

# Function to validate username
validate_username() {
    local username=$1
    if [[ ! $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        print_message $RED "Invalid username: $username"
        print_message $YELLOW "Username must start with lowercase letter, contain only lowercase letters, numbers, hyphens, and underscores, max 32 chars"
        return 1
    fi
    return 0
}

# Function to check if user already exists
user_exists() {
    local username=$1
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}



# Function to create user
create_user() {
    local username=$1
    local has_sudo=$2
    
    print_message $BLUE "Creating user: $username with shell: $DEFAULT_SHELL"
    
    # Create user with home directory and default shell
    if useradd -m -s "$DEFAULT_SHELL" -g "$DEFAULT_GROUP" "$username"; then
        print_message $GREEN "✓ User $username created successfully with shell $DEFAULT_SHELL"
    else
        print_message $RED "✗ Failed to create user $username"
        return 1
    fi
    
    # Set password (prompt for each user)
    print_message $YELLOW "Setting password for user: $username"
    if passwd "$username"; then
        print_message $GREEN "✓ Password set for $username"
    else
        print_message $RED "✗ Failed to set password for $username"
        return 1
    fi
    
    # Add to sudo group if requested
    if [[ $has_sudo == "y" || $has_sudo == "yes" ]]; then
        if usermod -aG wheel "$username"; then
            print_message $GREEN "✓ Added $username to sudo group (wheel)"
        else
            print_message $RED "✗ Failed to add $username to sudo group"
        fi
    fi
    
    return 0
}

# Function to copy SSH keys
copy_ssh_keys() {
    local username=$1
    local main_user_home="/home/$CURRENT_USER"
    local target_user_home="/home/$username"
    
    # Check if main user has SSH keys
    if [[ ! -d "$main_user_home/.ssh" ]]; then
        print_message $YELLOW "Warning: No .ssh directory found for main user ($CURRENT_USER) at $main_user_home"
        print_message $YELLOW "Make sure $CURRENT_USER exists and has SSH configuration"
        return 1
    fi
    
    print_message $BLUE "Copying SSH keys from $CURRENT_USER to $username"
    
    # Create .ssh directory for new user
    mkdir -p "$target_user_home/.ssh"
    
    # Copy SSH keys if they exist
    if [[ -f "$main_user_home/.ssh/authorized_keys" ]]; then
        cp "$main_user_home/.ssh/authorized_keys" "$target_user_home/.ssh/"
        print_message $GREEN "✓ Copied authorized_keys"
    fi
    
    if [[ -f "$main_user_home/.ssh/id_rsa" ]]; then
        cp "$main_user_home/.ssh/id_rsa" "$target_user_home/.ssh/"
        print_message $GREEN "✓ Copied private key (id_rsa)"
    fi
    
    if [[ -f "$main_user_home/.ssh/id_rsa.pub" ]]; then
        cp "$main_user_home/.ssh/id_rsa.pub" "$target_user_home/.ssh/"
        print_message $GREEN "✓ Copied public key (id_rsa.pub)"
    fi
    
    # Copy other common SSH files
    for file in config known_hosts; do
        if [[ -f "$main_user_home/.ssh/$file" ]]; then
            cp "$main_user_home/.ssh/$file" "$target_user_home/.ssh/"
            print_message $GREEN "✓ Copied $file"
        fi
    done
    
    # Set proper ownership and permissions
    chown -R "$username:$DEFAULT_GROUP" "$target_user_home/.ssh"
    chmod 700 "$target_user_home/.ssh"
    chmod 600 "$target_user_home/.ssh"/* 2>/dev/null
    
    print_message $GREEN "✓ SSH keys copied and permissions set for $username"
}

# Function to get user input for single user
get_single_user_input() {
    local username
    local has_sudo
    local copy_keys
    
    # Step 1: Get username
    while true; do
        read -p "Enter username: " username
        if validate_username "$username"; then
            if user_exists "$username"; then
                print_message $RED "User $username already exists!"
                continue
            else
                break
            fi
        fi
    done
    
    # Step 2: Get sudo privileges
    while true; do
        read -p "Give sudo privileges to $username? (y/n): " has_sudo
        case $has_sudo in
            [Yy]|[Yy][Ee][Ss]) has_sudo="y"; break;;
            [Nn]|[Nn][Oo]) has_sudo="n"; break;;
            *) print_message $RED "Please answer y or n";;
        esac
    done
    
    # Step 3: Create the user (this will prompt for password)
    if create_user "$username" "$has_sudo"; then
        # Step 4: Ask about SSH keys
        while true; do
            read -p "Copy SSH keys from $CURRENT_USER to $username? (y/n): " copy_keys
            case $copy_keys in
                [Yy]|[Yy][Ee][Ss]) copy_keys="y"; break;;
                [Nn]|[Nn][Oo]) copy_keys="n"; break;;
                *) print_message $RED "Please answer y or n";;
            esac
        done
        
        if [[ $copy_keys == "y" ]]; then
            copy_ssh_keys "$username"
        fi
        print_message $GREEN "✓ User $username setup completed!"
    else
        print_message $RED "✗ Failed to setup user $username"
    fi
}

# Function to get multiple users input
get_multiple_users_input() {
    # Step 1: Get usernames
    print_message $BLUE "Enter usernames separated by spaces:"
    read -p "Users: " -a usernames
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        print_message $RED "No usernames provided!"
        return 1
    fi
    
    # Validate all usernames first
    for username in "${usernames[@]}"; do
        if ! validate_username "$username"; then
            return 1
        fi
        if user_exists "$username"; then
            print_message $RED "User $username already exists!"
            return 1
        fi
    done
    
    # Step 2: Get sudo privileges for each user
    declare -A sudo_privileges
    print_message $BLUE "\nConfiguring sudo privileges for each user:"
    for username in "${usernames[@]}"; do
        while true; do
            read -p "Give sudo privileges to $username? (y/n): " user_sudo
            case $user_sudo in
                [Yy]|[Yy][Ee][Ss]) sudo_privileges[$username]="y"; break;;
                [Nn]|[Nn][Oo]) sudo_privileges[$username]="n"; break;;
                *) print_message $RED "Please answer y or n";;
            esac
        done
    done
    
    # Step 3: Create all users (this will prompt for passwords)
    print_message $BLUE "\nCreating users (you will be prompted for passwords):"
    for username in "${usernames[@]}"; do
        print_message $BLUE "\n--- Processing user: $username ---"
        if ! create_user "$username" "${sudo_privileges[$username]}"; then
            print_message $RED "✗ Failed to setup user $username"
            continue
        fi
    done
    
    # Step 4: Get SSH keys preference for all users
    while true; do
        read -p "Copy SSH keys from $CURRENT_USER to ALL users? (y/n): " global_copy_keys
        case $global_copy_keys in
            [Yy]|[Yy][Ee][Ss]) global_copy_keys="y"; break;;
            [Nn]|[Nn][Oo]) global_copy_keys="n"; break;;
            *) print_message $RED "Please answer y or n";;
        esac
    done
    
    # Copy SSH keys if requested
    if [[ $global_copy_keys == "y" ]]; then
        for username in "${usernames[@]}"; do
            if user_exists "$username"; then
                copy_ssh_keys "$username"
            fi
        done
    fi
    
    print_message $GREEN "✓ All users setup completed!"
}

# Function to display main menu
show_menu() {
    print_message $BLUE "\n=== Rocky Linux User Management Script ==="
    print_message $YELLOW "Main user (SSH keys source): $CURRENT_USER"
    echo "1. Create single user (interactive)"
    echo "2. Create multiple users (batch)"
    echo "3. Exit"
    echo ""
}

# Main script execution
main() {
    # Check if running as root
    check_root
    
    print_message $GREEN "Rocky Linux User Management Script"
    print_message $BLUE "This script will create users and optionally copy SSH keys from: $CURRENT_USER"
    
    while true; do
        show_menu
        read -p "Select option (1-3): " choice
        
        case $choice in
            1)
                print_message $BLUE "\n--- Single User Creation ---"
                get_single_user_input
                ;;
            2)
                print_message $BLUE "\n--- Multiple Users Creation ---"
                get_multiple_users_input
                ;;
            3)
                print_message $GREEN "Exiting script. Goodbye!"
                exit 0
                ;;
            *)
                print_message $RED "Invalid option. Please select 1, 2, or 3."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run the main function
main "$@"

