#!/usr/bin/bash

# Helper function to create symlinks if they do not already exist
create_symlink_if_missing() {
    local source=$1
    local link_name=$2
    eval source="$source"
    eval link_name="$link_name"
    if [ ! -h "$link_name" ]; then
        ln -s "$source" "$link_name"
    fi
}

echo -e "\nInstalling customizations..."
create_symlink_if_missing "/workspace/.devcontainer/vscode_settings" "/workspace/.vscode"
create_symlink_if_missing "/workspace/.devcontainer/custom_prompt/.p10k.zsh" "~/.p10k.zsh"

echo -e "\nInitializing micromamba base environment..."
micromamba self-update --yes --quiet
micromamba remove --name base --all --yes --quiet 2>/dev/null

echo -e "\nCleaning-Up..."
micromamba clean --all --yes --quiet >/dev/null

echo -e "\nAdding /workspace to safe directory..."
git config --global --add safe.directory /workspace

# Copy .ssh configuration if the directory exists and is not empty
ssh_source="/workspace/.devcontainer/.ssh"
ssh_destination="~/.ssh"
eval ssh_destination="$ssh_destination"
if [ -d "$ssh_source" ]; then
    echo -e "\nInstalling keys for Git over SSH..."
    mkdir -p "$ssh_destination" && cp -r "$ssh_source/"* "$ssh_destination"
    chmod 700 "$ssh_destination"
    chmod 640 "$ssh_destination"/*
    chmod 600 "$ssh_destination"/*.pub
fi

echo -e "\nSetup completed successfully!\n"
