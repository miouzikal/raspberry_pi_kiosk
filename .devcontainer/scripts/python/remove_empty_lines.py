"""
Remove unnecessary empty lines from Python files, while preserving empty lines within docstrings.
The script will also format the files with isort and black.
"""

from pathlib import Path
from subprocess import DEVNULL, CalledProcessError, run
from typing import Iterator


def remove_empty_lines(text: str) -> str:
    """Remove empty lines from a text while preserving empty lines within docstrings."""
    lines: list[str] = text.split("\n")
    inside_docstring: bool = False
    result_lines: list[str] = []
    for line in lines:
        stripped_line = line.strip()
        if stripped_line.startswith('"""'):
            if stripped_line.count('"""') == 2:
                result_lines.append(line)
                continue
            inside_docstring = not inside_docstring
            result_lines.append(line)
        elif inside_docstring:
            result_lines.append(line)
        elif stripped_line:
            result_lines.append(line)
    return "\n".join(result_lines)


def format_file(file_path: Path, formatter: str) -> bool:
    """
    Format a file with a given formatter and options.

    Args:
        file_path: The path to the file to format.
        formatter: The formatter to use.

    Returns:
        True if the file was formatted successfully, False otherwise.
    """
    try:
        run([formatter, file_path], stdout=DEVNULL, stderr=DEVNULL, check=True)
        return True
    except CalledProcessError:
        print(f"Error while formatting file {file_path} with {formatter}.")
        return False


def main(file_paths: Iterator[Path]) -> None:
    """Main entrypoint for the script."""
    for file_path in file_paths:
        original_content = file_path.read_text(encoding="utf-8")
        updated_content = remove_empty_lines(original_content)
        file_path.write_text(updated_content, encoding="utf-8")
        for formatter in ["isort", "black"]:
            format_file(file_path, formatter)
        formatted_content = file_path.read_text(encoding="utf-8")
        if original_content != formatted_content:
            print(f"File modified: '{file_path}'")


if __name__ == "__main__":
    import sys

    main(map(Path, sys.argv[1:]))
