"""
Project manager for Python projects.
This file should be kept compatible with Python 3.9.5 (see base_specfile)
"""
from argparse import ArgumentParser
from hashlib import sha256
from json import dump as json_dump
from json import loads as json_loads
from os import environ
from pathlib import Path
from re import findall
from shutil import move
from subprocess import PIPE, Popen
from sys import exit as sys_exit
from sys import stderr
from typing import Dict, List, Optional, Tuple, Union

from toml import load as toml_load

WORKSPACE_PATH = environ["WORKSPACE_PATH"]
PYPROJECT_PATH = Path(WORKSPACE_PATH, "pyproject.toml")
DEVCONTAINER_PATH = Path(WORKSPACE_PATH, ".devcontainer")
PROJECT = toml_load(PYPROJECT_PATH).get("project", {})
DEVCONTAINER = json_loads(Path(DEVCONTAINER_PATH, "devcontainer.json").read_text(encoding="utf-8"))
ORIGINAL_PYPROJECT_HASH = str(sha256(PYPROJECT_PATH.read_bytes()).hexdigest())


def run_shell_command(
    command: Union[List[str], str],
    capture: bool = False,
    ignore_errors: bool = False,
) -> Tuple[int, Optional[str]]:
    """Run a shell command and stream stdout and stderr."""
    command, output = " ".join(command) if isinstance(command, list) else command, None
    _stdout, _stderr = (PIPE, PIPE) if capture else (None, None)
    with Popen(command, stdout=_stdout, stderr=_stderr, shell=True, text=True, encoding="utf-8") as process:
        stdout_data, _ = process.communicate() if capture else ("", "")
        output = stdout_data.strip()
    if not ignore_errors and process.returncode != 0:
        print(f'\n\nError executing : "{command}"', file=stderr)
        sys_exit(process.returncode)
    return int(process.returncode), output


def get_optional_dependencies(section: Optional[str] = None) -> str:
    """Get the optional dependencies of the project."""
    optional_dependencies = PROJECT.get("optional-dependencies", {})
    dependencies = (
        [f'"{dependency}"' for dependency in optional_dependencies.get(section, [])]
        if section
        else [f'"{dependency}"' for dependencies in optional_dependencies.values() for dependency in dependencies]
    )
    return " ".join(dependencies)


PROJECT_NAME = PROJECT.get("name")
PYTHON_VERSION = PROJECT.get("requires-python")
MAIN_DEPENDENCIES = " ".join([f'"{dependency}"' for dependency in PROJECT.get("dependencies", [])])
CONDA_DEPENDENCIES = get_optional_dependencies(section="conda")
PIP_DEPENDENCIES = get_optional_dependencies(section="pip")


def update():
    """Update the project environment."""
    print("\nUpdating environment... ", end="", flush=True)
    run_shell_command(f"bash -c '{DEVCONTAINER_PATH}/scripts/postCreateCommand.sh' >/dev/null 2>&1")
    run_shell_command(
        [
            "micromamba install --name base",
            f'"python{PYTHON_VERSION}"',
            MAIN_DEPENDENCIES,
            CONDA_DEPENDENCIES,
            "--allow-downgrade",
            "--yes",
            "--quiet",
        ]
    )
    if PIP_DEPENDENCIES:
        run_shell_command(
            [
                "micromamba run --name base pip install",
                PIP_DEPENDENCIES,
                "--upgrade",
                "--quiet",
            ]
        )
        print("Done!")
    print(" - You may want to 'Reload Window' for changes to take effect.")


def check():
    """Validate the pre-commit hooks of the project."""
    print()
    run_shell_command(
        [
            "pre-commit",
            "run",
            "--all-files",
            "--config",
            f"{DEVCONTAINER_PATH}/git_hooks/pre_commit_config.yaml",
        ]
    )


def process_line(line: str, placeholders: str, user_inputs: Dict[str, str]) -> str:
    """Replace placeholders in a line with user inputs."""
    for placeholder in placeholders:
        if placeholder not in user_inputs:
            user_input = input(f"Enter the text to replace {placeholder}, or press Enter to skip: ")
            user_inputs[placeholder] = user_input
        if user_inputs[placeholder]:
            line = line.replace(placeholder, user_inputs[placeholder])
    return line


def init():
    """Initialize the project."""
    if PROJECT_NAME == "___PROJECT_NAME___":
        user_inputs: Dict[str, str] = {}
        lines = PYPROJECT_PATH.read_text(encoding="utf-8").splitlines()
        print("\033c\n", end="")  # Clear the terminal
        new_lines = [
            process_line(
                line,
                findall(r"___[A-Z_]+___", line),  # type: ignore[reportGeneralTypeIssues]
                user_inputs,
            )
            for line in lines
        ]
        PYPROJECT_PATH.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
        if _project_name := user_inputs.get("___PROJECT_NAME___"):
            DEVCONTAINER["name"] = _project_name
            with DEVCONTAINER_PATH.open(mode="w", encoding="utf-8") as file_pointer:
                json_dump(DEVCONTAINER, file_pointer, indent=4)
                file_pointer.write("\n")
            if Path(template_module := f"{WORKSPACE_PATH}/src/___PROJECT_NAME___").is_dir():
                move(template_module, f"{WORKSPACE_PATH}/src/{_project_name}")
        if ORIGINAL_PYPROJECT_HASH == str(sha256(PYPROJECT_PATH.read_bytes()).hexdigest()):
            print("\nNo changes made to the project configuration.")
        else:
            print("\nProject initialized successfully!")
            print(" - Rebuild the container to avoid unexpected behaviors.")
            project = toml_load(PYPROJECT_PATH).get("project", {})
            if (source_url := project.get("urls", {}).get("Source")) and source_url != "___PROJECT_URL___":
                print(" - Update your Git remote origin URL with:")
                print(f"   ❯ git remote set-url origin {source_url}")
                print(" - Install the module in editable mode with:")
                print("   ❯ flit install --symlink")
    else:
        print("\nProject already initialized.")
    update()
    print("\nupdating git hooks... ", end="", flush=True)
    run_shell_command("git config core.autocrlf false")
    run_shell_command("git config core.filemode false")
    run_shell_command(
        [
            "micromamba run --name base pre-commit install",
            f"--config {DEVCONTAINER_PATH}/git_hooks/pre_commit_config.yaml",
            ">/dev/null",
        ]
    )
    run_shell_command(
        [
            "micromamba run --name base pre-commit install",
            "--hook-type commit-msg",
            f"--config {DEVCONTAINER_PATH}/git_hooks/commit_msg_config.yaml",
            ">/dev/null",
        ]
    )
    print("Done!")


def install():
    """Install the project."""
    print("\nInstalling project... ", end="", flush=True)
    run_shell_command(
        [
            "micromamba run --name base flit install --symlink --deps production",
            ">/dev/null",
            "2>&1",
        ]
    )
    print("Done!")


def bump_version():
    """Bump the project version."""
    _, git_status = run_shell_command("git status --porcelain", capture=True)
    if git_status:
        print("\nThere are uncommitted changes in the repository. Please commit them before bumping the version.")
        return
    project_version = PROJECT.get("version")
    _, latest_git_tag = run_shell_command("git tag --sort=-v:refname | head -n 1", capture=True)
    if not latest_git_tag:
        print("\nNo Git tags found. Please create a Git tag before bumping the version.")
        return
    if project_version not in ("0.0.0", latest_git_tag.strip()):
        print(f"\nCurrent project version ({project_version}) does not match the latest Git tag ({latest_git_tag}).")
        return
    print("\nBumping project version... \n")
    run_shell_command("micromamba run --name base cz bump --check-consistency --changelog-to-stdout --yes")


def push():
    """Push the project to the remote repository."""
    print("\nPushing project... \n")
    run_shell_command("git push")
    print("\nPushing tags... \n")
    run_shell_command("git push --tags")
    print("\nDone!")


def parse_args():
    """Parse the command line arguments."""
    _parser = ArgumentParser(prog="project_manager")
    subparsers = _parser.add_subparsers(dest="target")
    _ = subparsers.add_parser(
        "init",
        description="This target does not expect any arguments.",
        help="Initialize the project by replacing placeholders with user inputs.",
    )
    _ = subparsers.add_parser(
        "update",
        description=f"Update the '{PROJECT_NAME}' environment or Rebuild it from scratch.",
        help=f"Update or Rebuild the '{PROJECT_NAME}' environment.",
    )
    _ = subparsers.add_parser(
        "check",
        description="This target does not expect any arguments.",
        help="Validate the pre-commit hooks of the project.",
    )
    _ = subparsers.add_parser(
        "install",
        description="This target does not expect any arguments.",
        help="Install the project.",
    )
    _ = subparsers.add_parser(
        "bump",
        description="This target does not expect any arguments.",
        help="Bump the project version and update the changelog.",
    )
    _ = subparsers.add_parser(
        "push",
        description="This target does not expect any arguments.",
        help="Push the project to the remote repository.",
    )
    return _parser.parse_args(), _parser


if __name__ == "__main__":
    args, parser = parse_args()
    try:
        if args.target == "init":
            init()
        elif args.target == "update":
            update()
        elif args.target == "check":
            check()
        elif args.target == "install":
            install()
        elif args.target == "bump":
            bump_version()
        elif args.target == "push":
            push()
        else:
            parser.print_help()
    except KeyboardInterrupt:
        print("\nUser interrupt detected. Exiting the script.")
        sys_exit(0)
