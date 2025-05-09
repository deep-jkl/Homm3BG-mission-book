#!/usr/bin/env bash

# Check if input is provided
if [[ -z "$1" ]]; then
  echo "Usage: $0 <search_term>"
  exit 1
fi

INPUT=$1
SEARCH_DIRS="campaigns clash coops sections draft-scenarios"
SEARCH_PATTERN="addscenariosection{\|addsection{\|addscenariosection\[subsection\]{"

find_latex_references() {
  local FILENAME="$1"
  local SEARCH_DIRS="$2"
  local FILE_PATH="$3"

  # Look for \input{...} or \include{...} references to this file in the search directories
  local INPUT_REFERENCES
  INPUT_REFERENCES=$(grep -r ".\(input\|include\){.*$FILENAME" $SEARCH_DIRS structure.tex --include="*.tex" --exclude-dir "*translated*")

  if [[ -n "$INPUT_REFERENCES" ]]; then
    # Extract the path from the first reference
    local REFERENCED_PATH
    REFERENCED_PATH=$(echo "$INPUT_REFERENCES" | head -1 | grep -E '(\\input|\\include)\{[^}]*\}' | sed -E 's/.*\\(input|include)\{([^}]*)\}.*/\2/')

    # Check if file path is in draft-scenarios
    if [[ "$FILE_PATH" == draft-scenarios/* ]]; then
      if [[ "$REFERENCED_PATH" != draft-scenarios/* ]]; then
        REFERENCED_PATH="draft-scenarios/$REFERENCED_PATH"
      fi
    fi

    echo "Found reference: $REFERENCED_PATH"
    echo "\\include{$REFERENCED_PATH}" > structure.tex
    return 0
  else
    # Should never happen
    echo "No reference found!"
    return 1
  fi
}

mapfile -t RESULTS < <(grep -rn "$SEARCH_PATTERN" $SEARCH_DIRS --include="*.tex" --exclude-dir "*translated*" | grep -i "$INPUT")
COUNT=${#RESULTS[@]}

# Handle based on number of results
if [[ "$COUNT" -eq 0 ]]; then
  echo "No files found matching '$INPUT'."
  exit 1
elif [[ "$COUNT" -eq 1 ]]; then
  # Extract just the file path (everything before the first colon)
  FILE_PATH=$(echo "${RESULTS[0]}" | cut -d':' -f1)
  FILENAME=$(basename "$FILE_PATH")

  find_latex_references "$FILENAME" "$SEARCH_DIRS" "$FILE_PATH"
else
  echo "Found $COUNT files matching '$INPUT':"
  echo ""

  # Display numbered list of results
  for i in "${!RESULTS[@]}"; do
    # Extract just the file path (everything before the first colon)
    FILE_PATH=$(echo "${RESULTS[$i]}" | cut -d':' -f1)
    CONTENT=$(echo "${RESULTS[$i]}" | cut -d':' -f3)
    echo -e "[$((i+1))] \033[1;32m$FILE_PATH\033[0m"
    echo "    $CONTENT" | grep -i "$INPUT" --color=always
    echo ""
  done

  # Prompt for selection
  echo -n "Select a file (1-$COUNT) or press Enter to cancel: "
  read -r SELECTION
  if [[ "$SELECTION" =~ ^[0-9]+$ && "$SELECTION" -ge 1 && "$SELECTION" -le "$COUNT" ]]; then
    FILE_PATH=$(echo "${RESULTS[$((SELECTION-1))]}" | cut -d':' -f1)
    if [[ "$FILE_PATH" == */sections/* ]]; then
      echo "Found reference: $FILE_PATH"
      echo "\\include{$FILE_PATH}" > structure.tex
      exit 0
    fi

    FILENAME=$(basename "$FILE_PATH")
    find_latex_references "$FILENAME" "$SEARCH_DIRS" "$FILE_PATH"
  else
    echo "Selection cancelled or invalid."
    exit 1
  fi
fi
