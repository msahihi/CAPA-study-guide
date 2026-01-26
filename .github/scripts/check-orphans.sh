#!/bin/bash
set -e

echo "🔍 Checking for orphaned files..."

WARNINGS=0
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

normalize_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd)
  elif [ -f "$path" ]; then
    (cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")")
  else
    echo "$path" | sed 's|/\./|/|g' | sed 's|//|/|g' | sed 's|^\./||'
  fi
}

url_decode() {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

REFERENCED_FILES=$(mktemp)

# Find all markdown links
find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" -print0 | while IFS= read -r -d '' file; do
  grep -o '\[.*\](.*\.md)' "$file" 2>/dev/null | sed -n 's/.*](\([^)]*\.md\)).*/\1/p' | while read -r link; do
    if [[ "$link" =~ ^https?:// ]]; then
      continue
    fi
    link=$(url_decode "$link")
    # Remove anchor fragments
    link="${link%%#*}"
    dir=$(dirname "$file")
    if [[ "$link" == /* ]]; then
      resolved="$link"
    else
      resolved=$(normalize_path "$dir/$link")
    fi
    echo "$resolved" >> "$REFERENCED_FILES"
  done
done

sort -u "$REFERENCED_FILES" -o "$REFERENCED_FILES"

echo ""
echo "Checking for orphaned files..."

ENTRY_POINTS=(
  "./README.md"
  "./CAPA_CHEATSHEET.md"
  "./mock-questions/README.md"
  "./domains/01-argo-cd/README.md"
  "./domains/02-argo-workflows/README.md"
  "./domains/03-argo-rollouts/README.md"
  "./domains/04-argo-events/README.md"
  "./labs/README.md"
)

find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.claude/*" -print0 | while IFS= read -r -d '' md_file; do
  full_path=$(normalize_path "$md_file")

  is_entry_point=false
  for entry in "${ENTRY_POINTS[@]}"; do
    entry_full=$(normalize_path "$entry")
    if [ "$full_path" = "$entry_full" ]; then
      is_entry_point=true
      break
    fi
  done

  if [ "$is_entry_point" = true ]; then
    continue
  fi

  if ! grep -q "^$full_path$" "$REFERENCED_FILES"; then
    echo -e "${YELLOW}⚠️  Potentially orphaned file: $md_file${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
done

rm "$REFERENCED_FILES"

echo ""
echo "========================================"
if [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✅ No orphaned files detected!${NC}"
else
  echo -e "${YELLOW}⚠️  Found $WARNINGS potentially orphaned file(s)${NC}"
  echo "Note: This is a warning only."
fi

exit 0
