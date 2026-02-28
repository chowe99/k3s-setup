#!/usr/bin/env bash
# cat-files.sh: Cat specified files and all files in specified directories with optional ignore list
set -euo pipefail

usage() {
  cat <<EOF
Usage: ${0##*/} [options] <path> [<path>...]
Options:
  -e "list" Space-separated list of files or directories to ignore (relative to each <directory> for directories).
  -h Show this help message and exit.
Example:
  ${0##*/} -e "secret.txt temp/" ~/projects ~/backup/file.txt ~/backup
EOF
  exit 1
}

# Parse flags
ignores=()
while getopts ":e:h" opt; do
  case $opt in
  e) IFS=' ' read -r -a ignores <<<"$OPTARG" ;;
  h) usage ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

# Ensure at least one path argument
if [[ $# -lt 1 ]]; then
  usage
fi

# Process each path
for path in "$@"; do
  path=${path%/}
  if [[ ! -e $path ]]; then
    echo "Error: Path '$path' does not exist." >&2
    continue
  fi

  files=()
  if [[ -f $path ]]; then
    # If path is a file, add it directly
    files+=("$path")
  elif [[ -d $path ]]; then
    # If path is a directory, collect all files recursively
    while IFS= read -r -d $'\0' f; do
      files+=("$f")
    done < <(find "$path" -type f -print0)
  else
    echo "Error: Path '$path' is neither a file nor a directory." >&2
    continue
  fi

  # Apply ignores for directories (files specified directly are not ignored)
  if [[ -d $path && ${#ignores[@]} -gt 0 ]]; then
    filtered=()
    for f in "${files[@]}"; do
      skip=false
      for ign in "${ignores[@]}"; do
        ignpath="$path/${ign%/}"
        if [[ $f == "$ignpath"* ]]; then
          skip=true
          break
        fi
      done
      $skip || filtered+=("$f")
    done
    files=("${filtered[@]}")
  fi

  # Cat each file
  for f in "${files[@]}"; do
    echo "==== $f ===="
    cat "$f"
    echo
  done
done
