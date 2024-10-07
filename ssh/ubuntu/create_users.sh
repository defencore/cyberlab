#!/bin/bash

# Function to display help message
display_help() {
    echo "Usage: $0 -u <users_file> [-r]"
    echo
    echo "Options:"
    echo "  -u <users_file>  Specify the file containing public keys and usernames."
    echo "  -r               Remove users listed in the users_file."
    echo "  -h               Display this help message."
    echo
    echo "The users_file should be in the format:"
    echo "ssh-rsa <public_key> <username@mail>"
    echo
    echo "Example of a users.txt file:"
    echo "ssh-rsa AAAAB3Nza... user1@mail"
    echo "ssh-rsa AAAAB3Nza... user2@mail"
    exit 1
}

# Check if the script is run without parameters
if [ "$#" -eq 0 ]; then
    display_help
fi

# Parse command-line options
remove_users=false
while getopts "u:rh" opt; do
    case $opt in
        u)
            users_file="$OPTARG"
            ;;
        r)
            remove_users=true
            ;;
        h)
            display_help
            ;;
        *)
            display_help
            ;;
    esac
done

# Check if the users file is provided and exists
if [ -z "$users_file" ]; then
    echo "Error: users file not specified. Use -u to provide the file."
    display_help
elif [ ! -f "$users_file" ]; then
    echo "Error: File '$users_file' not found."
    exit 1
fi

# Function to remove a user
remove_user() {
    user_name=$1
    echo "Removing user $user_name..."

    # Delete user and their home directory
    userdel -r $user_name

    echo "User $user_name removed."
}

# Function to create or update users
create_or_update_user() {
    user_name=$1
    user_key=$2

    # Check if the user already exists
    if id "$user_name" &>/dev/null; then
        echo "User $user_name already exists. Updating public key..."
    else
        # Add the user if it does not exist, set /usr/sbin/nologin as shell
        echo "Creating user $user_name..."
        useradd -m -s /usr/sbin/nologin "$user_name"
    fi

    # Create the .ssh directory if it doesn't exist
    home_dir=$(eval echo ~$user_name)
    ssh_dir="$home_dir/.ssh"
    mkdir -p "$ssh_dir"

    # Add or update public key with SSH proxy command
    echo "$user_key" > "$ssh_dir/authorized_keys"

    # Set correct permissions
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$user_name":"$user_name" "$ssh_dir"

    echo "User $user_name has been updated/created."
}

# Remove users if -r flag is provided
if [ "$remove_users" = true ]; then
    while read -r line; do
        user_name=$(echo "$line" | awk '{print $3}' | cut -d'@' -f1)
        remove_user "$user_name"
    done < "$users_file"
else
    # Create or update users from the file
    while read -r line; do
        user_key=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user_name=$(echo "$line" | awk '{print $3}' | cut -d'@' -f1)
        create_or_update_user "$user_name" "$user_key"
    done < "$users_file"
fi

# Restart OpenSSH to apply changes
systemctl restart ssh

echo "Process complete."
