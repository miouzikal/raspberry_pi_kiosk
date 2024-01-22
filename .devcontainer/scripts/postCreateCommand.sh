#!/usr/bin/bash

echo -e "\nInstalling customizations..."
[ ! -h $WORKSPACE_PATH/.vscode ] && ln -s $WORKSPACE_PATH/.devcontainer/vscode_settings $WORKSPACE_PATH/.vscode
[ ! -h ~/.p10k.zsh ] && ln -s $WORKSPACE_PATH/.devcontainer/custom_prompt/.p10k.zsh ~/.p10k.zsh

echo -e "\nCreating minimal base environment..."
micromamba self-update --yes --quiet
micromamba remove --name base --all --yes --quiet 2>/dev/null
micromamba install --name base --file $WORKSPACE_PATH/.devcontainer/scripts/base_specfile --yes --quiet

echo -e "\nCleaning-Up..."
micromamba clean --all --yes --quiet >/dev/null
