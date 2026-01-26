#!/bin/bash
set -e

echo "🔍 Validating repository structure..."

ERRORS=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Normalize path function
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

# Check domain README files
echo "📁 Checking domain structure..."
DOMAIN_DIRS=(
  "domains/01-argo-cd"
  "domains/02-argo-workflows"
  "domains/03-argo-rollouts"
  "domains/04-argo-events"
)

for dir in "${DOMAIN_DIRS[@]}"; do
  if [ ! -f "$dir/README.md" ]; then
    echo -e "${RED}❌ Missing README.md in $dir${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}✓${NC} $dir/README.md exists"
  fi
done

# Check lab directories
echo ""
echo "🧪 Checking lab structure..."
LAB_DIRS=(
  "labs/01-argo-cd"
  "labs/02-argo-workflows"
  "labs/03-argo-rollouts"
  "labs/04-argo-events"
)

for dir in "${LAB_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo -e "${RED}❌ Missing lab directory: $dir${NC}"
    ERRORS=$((ERRORS + 1))
  else
    LAB_COUNT=$(find "$dir" -name "lab-*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} $dir exists with $LAB_COUNT lab files"
  fi
done

# Check required root files
echo ""
echo "📄 Checking required root files..."
REQUIRED_FILES=(
  "README.md"
  "CAPA_CHEATSHEET.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ Missing required file: $file${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}✓${NC} $file exists"
  fi
done

# Check mock questions directory
echo ""
echo "📝 Checking mock questions..."
if [ ! -d "mock-questions" ]; then
  echo -e "${RED}❌ Missing mock-questions directory${NC}"
  ERRORS=$((ERRORS + 1))
else
  MOCK_COUNT=$(find mock-questions -name "mock-exam-*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}✓${NC} mock-questions directory exists with $MOCK_COUNT exam files"
fi

# Final report
echo ""
echo "========================================"
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}✅ Structure validation passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Structure validation failed with $ERRORS error(s)${NC}"
  exit 1
fi
