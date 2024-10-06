#!/bin/ash

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

    # Remove the user from UCI system
    uci show system | grep "system.@user" | grep "username='$user_name'" | cut -d'[' -f2 | cut -d']' -f1 | while read -r user_index; do
        uci delete system.@user[$user_index]
    done
    uci commit system

    # Remove user's home directory
    rm -rf /home/$user_name

    # Remove the user from /etc/passwd
    sed -i "/^$user_name:/d" /etc/passwd

    echo "User $user_name removed."
}

# Function to create or update users
create_or_update_user() {
    user_name=$1
    user_key=$2

    # Check if the user already exists
    existing_user=$(uci show system | grep "system.@user" | grep "username='$user_name'")

    if [ -n "$existing_user" ]; then
        echo "User $user_name already exists. Updating public key..."
    else
        # Add the user if it does not exist
        echo "Creating user $user_name..."
        uci add system user
        uci set system.@user[-1].username="$user_name"
        uci set system.@user[-1].home="/home/$user_name"
        uci set system.@user[-1].shell='/bin/false'
        uci commit system

        # Create home directory for the user
        mkdir -p /home/$user_name/.ssh
    fi

    # Update or add public key with SSH proxy command
    echo "command=\"/usr/bin/nc -q0 target-server 22\",no-agent-forwarding,no-X11-forwarding,no-pty $user_key" > /home/$user_name/.ssh/authorized_keys

    # Set permissions for the directory and the file
    chmod 600 /home/$user_name/.ssh/authorized_keys
    chmod 700 /home/$user_name/.ssh

    # Ensure user is added to /etc/passwd
    grep -q "$user_name" /etc/passwd || echo "$user_name:x:1000:1000:$user_name:/home/$user_name:/bin/ash" >> /etc/passwd

    # Set ownership for the user's files
    chown -R 1000:1000 /home/$user_name

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
    # Configure Dropbear
    uci set dropbear.@dropbear[0].Port='22'
    uci set dropbear.@dropbear[0].PasswordAuth='off'
    uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    uci commit dropbear

    # Disable ttylogin
    uci set system.@system[0].ttylogin='0'
    uci commit system

    while read -r line; do
        user_key=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user_name=$(echo "$line" | awk '{print $3}' | cut -d'@' -f1)
        create_or_update_user "$user_name" "$user_key"
    done < "$users_file"
fi

# Restart Dropbear to apply changes
/etc/init.d/dropbear restart

echo "Process complete."
