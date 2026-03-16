#!/bin/bash
set -e

DATE=$(date +%Y-%m-%d)

# Navigate to PuzzleTool (relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/PuzzleTool"

swift run PuzzleTool generate --date $DATE
swift run PuzzleTool preview "../puzzles/puzzle-$DATE.json"
swift run PuzzleTool validate "../puzzles/puzzle-$DATE.json"

cd ../
git add "puzzles/puzzle-$DATE.json"
git commit -m "puzzle: $DATE"
git push origin main

echo "✅ Puzzle $DATE pushed successfully"
