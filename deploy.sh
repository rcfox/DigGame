#!/bin/bash
set -e

GODOT="/c/Users/ryan/Downloads/Godot_v4.6-beta3_win64.exe/Godot_v4.6-beta3_win64_console.exe"

# Export the game locally first
echo "Exporting game..."
"$GODOT" --headless --export-release "Web" ./build/web/index.html

# Create/update gh-pages worktree in a separate directory
if [ ! -d "gh-pages-deploy" ]; then
    echo "Setting up gh-pages worktree..."
    git worktree add gh-pages-deploy gh-pages
fi

# Clear old content and copy new build
echo "Updating gh-pages content..."
rm -rf gh-pages-deploy/*
cp -r build/web/* gh-pages-deploy/

# Commit and push
cd gh-pages-deploy
git add -A
git commit -m "Deploy $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
git push origin gh-pages
cd ..

echo "Deployed to gh-pages!"
