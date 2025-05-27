#!/bin/bash

# Function to ask for root password
ask_for_password() {
    sudo -v
}

# Function to list available sites and let user pick one
select_website() {
    echo "Available websites:"
    sites=($(ls -1 /var/www))
    for i in "${!sites[@]}"; do
        echo "[$i] ${sites[$i]}"
    done

    while true; do
        read -p "Select a website by number: " site_choice
        if [[ "$site_choice" =~ ^[0-9]+$ ]] && [ "$site_choice" -ge 0 ] && [ "$site_choice" -lt "${#sites[@]}" ]; then
            selected_website="${sites[$site_choice]}"
            break
        else
            echo "Invalid choice. Try again."
        fi
    done
}

# Function to check Apache status
check_apache_status() {
    systemctl status apache2
}

# Function to start Apache
start_webserver() {
    echo " "
    sudo systemctl start apache2
    echo "Webserver started"
    echo " "
}

# Function to stop Apache
stop_webserver() {
    echo " "
    sudo systemctl stop apache2
    echo "Webserver stopped"
    echo " "
}

# Function to restart Apache
reboot_webserver() {
    echo " "
    sudo systemctl restart apache2
    echo "Webserver restarted"
    echo " "
}

# Function to backup selected site
backup_webserver() {
    echo "Creating backup of $selected_website (excluding FILES directory)..."
    BACKUP_PATH="/home/$USER/Desktop/${selected_website}_Backup.zip"
    sudo zip -r "$BACKUP_PATH" "/etc/apache2" "/var/www/$selected_website" -x "/var/www/$selected_website/FILES/*"
    echo "Backup created at $BACKUP_PATH"
}

# Function to verify Apache configuration
verify_apache_config() {
    echo "Verifying Apache configuration syntax..."
    sudo apachectl configtest
}

# Function to undo last update
undo_last_update() {
    echo "Restoring previous configuration for $selected_website..."
    if [ -d "/etc/apache-undo/$selected_website" ]; then
        sudo rsync -a "/etc/apache-undo/$selected_website/" "/var/www/$selected_website/" --delete
        sudo chown -R www-data:www-data "/var/www/$selected_website"
        sudo systemctl restart apache2
        echo "Previous configuration restored."
    else
        echo "No backup found for $selected_website!"
    fi
}

# Function to update selected website
update_website() {
    echo "Backing up current website files..."
    sudo mkdir -p /etc/apache-undo
    sudo rsync -a "/var/www/$selected_website/" "/etc/apache-undo/$selected_website/" --delete

    TEMP_DIR="/tmp/$selected_website"
    sudo rm -rf "$TEMP_DIR"
    sudo mkdir -p "$TEMP_DIR"

    echo "Cloning repository..."
    case "$selected_website" in
        glitchlinux.wtf)
            repo_url="https://github.com/GlitchLinux/glitchlinux.wtf.git"
            ;;
        svenskhost.com)
            repo_url="https://github.com/GlitchLinux/svenskhost.com.git"
            ;;
        *)
            echo "No repository URL defined for $selected_website"
            return
            ;;
    esac

    sudo git clone "$repo_url" "$TEMP_DIR"

    echo "Updating website files..."
    sudo rsync -a --ignore-existing "$TEMP_DIR/" "/var/www/$selected_website/" --exclude=.git --exclude=README.md

    # Update existing files from repo
    find "$TEMP_DIR" -type f -not -path '*/.git*' -not -name 'README.md' | while read -r file; do
        rel_path="${file#$TEMP_DIR/}"
        dest_path="/var/www/$selected_website/$rel_path"
        sudo mkdir -p "$(dirname "$dest_path")"
        sudo cp -f "$file" "$dest_path"
    done

    if [ -f "$TEMP_DIR/glitch-icon.zip" ]; then
        echo "Processing glitch-icon.zip..."
        sudo mkdir -p "/var/www/$selected_website/glitch-icon"
        sudo unzip -o "$TEMP_DIR/glitch-icon.zip" -d "/var/www/$selected_website/glitch-icon/"
    fi

    if [ -f "/var/www/$selected_website/apache-utility.sh" ]; then
        echo "Updating apache-utility.sh in home directory..."
        sudo cp -f "/var/www/$selected_website/apache-utility.sh" "/home/$USER/"
        sudo chown "$USER:$USER" "/home/$USER/apache-utility.sh"
        sudo chmod +x "/home/$USER/apache-utility.sh"
    fi

    sudo chown -R www-data:www-data "/var/www/$selected_website"
    sudo chmod -R 755 "/var/www/$selected_website"
    sudo rm -rf "$TEMP_DIR"
    sudo systemctl restart apache2
    echo "$selected_website successfully updated, previous configuration has been saved!"
}

# Main menu
main_menu() {
    while true; do
        echo " "
        echo -e "\e[38;2;255;0;240m$selected_website\e[0m"
        echo " "
        echo -e "[\e[38;2;255;0;240m1\e[0m] UPDATE $selected_website"
        echo -e "[\e[38;2;255;0;240m2\e[0m] UNDO LAST UPDATE"
        echo -e "[\e[38;2;255;0;240m3\e[0m] APACHE STATUS"
        echo -e "[\e[38;2;255;0;240m4\e[0m] APACHE RESTART"
        echo -e "[\e[38;2;255;0;240m5\e[0m] CREATE BACKUP"
        echo -e "[\e[38;2;255;0;240m6\e[0m] SYNTAX VERIFY"
        echo -e "[\e[38;2;255;0;240m7\e[0m] APACHE START"
        echo -e "[\e[38;2;255;0;240m8\e[0m] APACHE STOP"
        echo -e "[\e[38;2;255;0;240m9\e[0m] EXIT"
        echo " "

        read -p "Enter your choice: " choice

        case $choice in
            1) update_website ;;
            2) undo_last_update ;;
            3) check_apache_status ;;
            4) reboot_webserver ;;
            5) backup_webserver ;;
            6) verify_apache_config ;;
            7) start_webserver ;;
            8) stop_webserver ;;
            9) echo "Exiting script."; cd /home/x; break ;;
            *) echo "Invalid choice. Try again." ;;
        esac
    done
}

ask_for_password
select_website
main_menu
