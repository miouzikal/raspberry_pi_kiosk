#!/usr/bin/bash

# Function to display help message
usage() {
    cat <<-EOF
    Usage: $0 <argument>
    Arguments:
      init          Initialize or update the project environment
      check         Run pre-commit checks
      bump          Bump the project version and update the changelog.
      -h/--help     Display this help message
EOF
}

# Check for help flags anywhere in the arguments
if [[ " $* " =~ " --help " ]] || [[ " $* " =~ " -h " ]]; then
    usage
    exit 0
fi

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
    echo "Error: You must provide exactly one argument."
    usage
    exit 1
fi
# Function to run a command quietly
quiet_run() {
    local command=("$@")
    local output
    eval "${command[*]} > /dev/null 2>&1"
    local status=$?
    if [ $status -ne 0 ]; then
        echo -e "\nAn error occurred while running: \n\n❯ ${command[*]}\n"
        exit 1
    fi
}

# Set base paths
CARGO_PATH="${WORKSPACE_PATH}/Cargo.toml"
DEVCONTAINER_PATH="${WORKSPACE_PATH}/.devcontainer"
PRECOMMIT_CONFIG_PATH="${DEVCONTAINER_PATH}/git_hooks/rust/pre_commit_config.yaml"
COMMIT_MESSAGE_CONFIG_PATH="${DEVCONTAINER_PATH}/git_hooks/commit_msg_config.yaml"

# Load and parse project settings
CARGO=$(toml2json "${CARGO_PATH}")
RUST_VERSION=$(echo "$CARGO" | jq -r '.workspace.metadata.project_manager.["rust-toolchain"] // .package.metadata.project_manager.["rust-toolchain"]' | sed 's/["'\'']//g')
CONDA_DEPENDENCIES=$(echo "$CARGO" | jq -r '.workspace.metadata.project_manager.conda_dependencies | to_entries | map("\"" + .key + .value + "\"") | join(" ")')
CARGO_DEPENDENCIES=$(echo "$CARGO" | jq -r '.workspace.metadata.project_manager.cargo_dependencies | to_entries | map(.key + " --version \"" + .value + "\"") | .[]')

# Handle command based on argument
case "$1" in
init)
    echo -e "\nCreating environment... "
    quiet_run "${DEVCONTAINER_PATH}/scripts/postCreateCommand.sh"
    quiet_run rustup install "$RUST_VERSION"
    quiet_run rustup default "$RUST_VERSION"
    quiet_run rustup toolchain install nightly
    quiet_run micromamba install --name base "$CONDA_DEPENDENCIES" --allow-downgrade --yes --quiet
    echo "$CARGO_DEPENDENCIES" | while IFS= read -r dependency; do
        quiet_run cargo install "${dependency}"
    done
    echo -e "\nSetting up git parameters..."
    quiet_run git config core.autocrlf false
    quiet_run git config core.filemode false
    quiet_run pre-commit install --config "${PRECOMMIT_CONFIG_PATH}"
    quiet_run pre-commit install --hook-type commit-msg --config "${COMMIT_MESSAGE_CONFIG_PATH}"
    echo -e "\nAll Done!"
    echo -e "\n - You may want to 'Reload Window' for changes to take effect.\n"
    ;;
check)
    pre-commit run --all-files --config "${PRECOMMIT_CONFIG_PATH}"
    ;;
bump)
    echo "Not implemented yet."
    ;;
*)
    echo "Error: Invalid argument '$1'"
    usage
    ;;
esac
