"""Remove empty lines from a file and format it with isort and black."""
from pathlib import Path
from subprocess import DEVNULL, CalledProcessError, run
from sys import argv
from typing import Tuple


def remove_empty_lines(text: str) -> str:
    """Remove empty lines from a text."""
    return "\n".join(line for line in text.split("\n") if line.strip())


def format_file(file_path: str, formatter: str) -> bool:
    """Format a file with a given formatter."""
    try:
        run([formatter, file_path], stdout=DEVNULL, stderr=DEVNULL, check=True)
        return True
    except CalledProcessError:
        print(f"Error while formatting file {file_path} with {formatter}.")
        return False


def main(file_paths: Tuple[str, ...]) -> None:
    """Main entrypoint for the script."""
    for file_path in file_paths:
        path = Path(file_path)
        original_content = path.read_text(encoding="utf-8")
        updated_content = remove_empty_lines(original_content)
        path.write_text(updated_content, encoding="utf-8")
        if all(format_file(file_path, formatter) for formatter in ["isort", "black"]):
            formatted_content = path.read_text(encoding="utf-8")
            if original_content != formatted_content:
                print(f"fixing '{file_path}'")


if __name__ == "__main__":
    main(tuple(argv[1:]))
