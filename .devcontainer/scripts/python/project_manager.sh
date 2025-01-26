#!/usr/bin/bash

PYPY="" # to use pypy, set to "pypy", otherwise set to ""

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
PYPROJECT_PATH="${WORKSPACE_PATH}/pyproject.toml"
DEVCONTAINER_PATH="${WORKSPACE_PATH}/.devcontainer"
PRECOMMIT_CONFIG_PATH="${DEVCONTAINER_PATH}/git_hooks/python/pre_commit_config.yaml"
COMMIT_MESSAGE_CONFIG_PATH="${DEVCONTAINER_PATH}/git_hooks/commit_msg_config.yaml"

# Load and parse project settings
PROJECT=$(toml2json "${PYPROJECT_PATH}" | jq .project)
PROJECT_NAME=$(echo "$PROJECT" | jq -r '.name')
PYTHON_VERSION=$(echo "$PROJECT" | jq -r '.["requires-python"]' | sed 's/["'\'']//g')
MAIN_DEPENDENCIES=$(echo "$PROJECT" | jq .dependencies | jq -r 'map(. | "\"\(. )\"") | join(" ")')
CONDA_DEPENDENCIES=$(echo "$PROJECT" | jq '.["optional-dependencies"]["conda"]' | jq -r 'map(. | "\"\(. )\"") | join(" ")')
PIP_DEPENDENCIES=$(echo "$PROJECT" | jq '.["optional-dependencies"]["pip"]' | jq -r 'map(. | "\"\(. )\"") | join(" ")')

# Handle command based on argument
case "$1" in
init)
    echo -e "\nCreating environment... "
    quiet_run "${DEVCONTAINER_PATH}/scripts/postCreateCommand.sh"
    quiet_run micromamba install --name base "${PYPY}" \"python"${PYTHON_VERSION}"\" "$MAIN_DEPENDENCIES" "$CONDA_DEPENDENCIES" --allow-downgrade --yes --quiet
    quiet_run micromamba run -n base python -m pip install "$PIP_DEPENDENCIES" --quiet
    quiet_run micromamba run --name base flit install --symlink --deps production
    echo -e "\nSetting up git parameters..."
    quiet_run git config core.autocrlf false
    quiet_run git config core.filemode false
    quiet_run micromamba run --name base pre-commit install --config "${PRECOMMIT_CONFIG_PATH}"
    quiet_run micromamba run --name base pre-commit install --hook-type commit-msg --config "${COMMIT_MESSAGE_CONFIG_PATH}"
    echo -e "\nAll Done!"
    echo -e "\n - You may want to 'Reload Window' for changes to take effect.\n"
    ;;
install)
    echo -e "\nInstalling '${PROJECT_NAME}' as a package..."
    quiet_run micromamba run --name base flit install --symlink --deps production
    ;;
check)
    pre-commit run --all-files --config "${PRECOMMIT_CONFIG_PATH}"
    ;;
bump)
    echo "Not implemented yet."
    ;;
build)
    echo -e "\nCleaning up workspace..."
    quiet_run rm -rf "${WORKSPACE_PATH}/src/${PROJECT_NAME}/dependencies"
    quiet_run rm -f "${WORKSPACE_PATH}/${PROJECT_NAME}.zip"
    echo -e "\nInstalling standalone '${PROJECT_NAME}' dependencies..."
    TOOLS=$(toml2json "${PYPROJECT_PATH}" | jq '.tool')
    if [ "$TOOLS" != "null" ]; then
        PROJECT_MANAGER_SECTION=$(echo "$TOOLS" | jq -r '.["project_manager"]')
        if [ "$PROJECT_MANAGER_SECTION" != "null" ]; then
            DEPENDENCIES=$(echo "$PROJECT_MANAGER_SECTION" | jq -r '.lambda_dependencies' | jq -r 'map(. | "\"\(. )\"") | join(" ")')
        else
            echo "No 'project_manager' section found in pyproject.toml"
            exit 2
        fi
        quiet_run micromamba run --name base pip install --target "${WORKSPACE_PATH}/src/${PROJECT_NAME}/dependencies" $DEPENDENCIES --quiet --upgrade
    else
        echo "No 'tool' section found in pyproject.toml"
        exit 1
    fi
    echo -e "\nCreating standalone '${PROJECT_NAME}' archive..."
    cd "${WORKSPACE_PATH}/src/"
    quiet_run zip -r "${WORKSPACE_PATH}/${PROJECT_NAME}.zip" .
    echo -e "\nCleaning up workspace..."
    quiet_run rm -rf "${WORKSPACE_PATH}/src/${PROJECT_NAME}/dependencies"
    echo -e "\nAll Done!"
    ;;
update-lambda)
    echo -e "\nUpdating AWS Lambda function..."
    if [ ! -f "${HOME}/.aws/credentials" ]; then
        echo "AWS CLI is not configured. Please run 'aws configure' to configure it."
        exit 1
    fi
    ARCHIVE="${WORKSPACE_PATH}/${PROJECT_NAME}.zip"
    if [ ! -f "$ARCHIVE" ]; then
        echo "Archive not found. Please run 'build' command first."
        exit 1
    fi
    # make user confirm before proceeding
    read -p "This will update the AWS Lambda function. Are you sure? (y/n) " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\nOperation cancelled."
        exit 0
    fi
    # update the lambda function
    quiet_run aws lambda update-function-code --function-name "${PROJECT_NAME}" --zip-file "fileb://${ARCHIVE}"
    echo -e "\nAll Done!"
    ;;
*)
    echo "Error: Invalid argument '$1'"
    usage
    ;;
esac
