#!/bin/bash

# reference https://gitlab.com/nuccdc/tools 
# System Hardening Script
# =======================================================================================
# This script provides functionalities for system enumeration, security hardening,
# package management, account management, and more. Run with root privileges.

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Detect Linux distribution
if [ -e /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
    echo "Detected Linux distribution: $distro"
else
    echo "Unable to determine Linux distribution."
    exit 1
fi

# Helper Functions
# =======================================================================================
log_message() {
    echo -e "\n[ $1 ]"
}

# Package Management
# =======================================================================================
update_packages() {
    log_message "Updating system packages..."
    case $distro in
        ubuntu|debian|mint)
            apt update -y > /dev/null && apt upgrade -y > /dev/null
            ;;
        centos|fedora)
            yum update -y > /dev/null
            ;;
        opensuse)
            zypper refresh > /dev/null && zypper update -y > /dev/null
            ;;
        alpine)
            apk update > /dev/null && apk upgrade > /dev/null
            ;;
        *)
            echo "Unknown package manager. Skipping update."
            return
            ;;
    esac
    log_message "Package update completed."
}

clean_unused_packages() {
    log_message "Cleaning up unused packages..."
    case $distro in
        ubuntu|debian|mint)
            apt install -y deborphan > /dev/null
            deborphan --guess-data | xargs apt -y purge > /dev/null
            deborphan | xargs apt -y purge > /dev/null
            ;;
        centos|fedora)
            yum autoremove -y > /dev/null
            ;;
        opensuse)
            zypper packages --orphaned | awk '{print $5}' | xargs zypper remove -y --clean-deps > /dev/null
            ;;
        alpine)
            apk del --purge $(apk list --installed | awk '{print $1}') > /dev/null
            ;;
        *)
            echo "Unknown package manager. Skipping cleanup."
            return
            ;;
    esac
    log_message "Unused packages removed."
}

# System Enumeration
# =======================================================================================
enumerate_system() {
    log_message "Gathering system information..."
    output_file="fh.txt"

    {
        echo "========== System Information =========="
        echo "Hostname: $(hostname)"
        echo "OS: $(cat /etc/*-release 2>/dev/null)"
        echo "========== Network Interfaces =========="
        ip -o addr show | awk '/inet / {print $2, $4}'
        echo "========== Open Ports =========="
        netstat -tulpn
        echo "========== Users =========="
        getent passwd | awk -F: '/\/(bash|sh)$/ {print $1}'
        echo "========== Groups =========="
        getent group | awk -F: '{print $1}'
    } >> "$output_file"

    log_message "System information written to $output_file."
}

# User Account Management
# =======================================================================================
manage_users() {
    log_message "Managing user accounts..."
    current_user=${SUDO_USER:-$(whoami)}

    awk -F: -v current_user="$current_user" \
        '$1 != "root" && $1 != current_user && $7 ~ /(bash|sh)$/ {print $1}' /etc/passwd | \
    while read -r user; do
        new_password=$(openssl rand -base64 12)
        echo "$user:$new_password" | chpasswd
        usermod --lock "$user" --shell /sbin/nologin
    done
    log_message "User accounts managed."
}

# Firewall Setup
# =======================================================================================
setup_firewall() {
    log_message "Configuring the firewall..."
    case $distro in
        ubuntu|debian|mint|centos|fedora)
            apt install -y ufw > /dev/null
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            ufw enable
            ;;
        opensuse)
            iptables -P INPUT DROP
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            ;;
        *)
            echo "Unsupported firewall configuration."
            return
            ;;
    esac
    log_message "Firewall configuration completed."
}

# Antivirus and Rootkit Scanning
# =======================================================================================
run_antivirus() {
    log_message "Running antivirus and rootkit checks..."
    case $distro in
        ubuntu|debian|mint)
            apt install -y clamav rkhunter chkrootkit > /dev/null
            ;;
        centos|fedora)
            yum install -y clamav rkhunter chkrootkit > /dev/null
            ;;
        opensuse)
            zypper install -y clamav rkhunter chkrootkit > /dev/null
            ;;
        alpine)
            apk add clamav rkhunter chkrootkit > /dev/null
            ;;
        *)
            echo "Unsupported antivirus tools."
            return
            ;;
    esac

    freshclam > /dev/null
    clamscan -r --remove / > /dev/null
    rkhunter --check --sk > /dev/null
    chkrootkit | grep -E "INFECTED|suspicious" >> fh.txt

    log_message "Antivirus and rootkit checks completed."
}

# Main Script Logic
# =======================================================================================
log_message "Starting system hardening script."

update_packages
clean_unused_packages
enumerate_system
manage_users
setup_firewall
run_antivirus

log_message "System hardening script completed."
