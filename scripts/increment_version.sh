#!/bin/bash

# Script to increment build number for TestFlight deployments
# Usage: ./increment_version.sh [patch|minor|major]

set -e

# Change to project root
cd "$(dirname "$0")/.."

# Get current version from pubspec.yaml
current_version=$(grep '^version:' pubspec.yaml | cut -d' ' -f2)
version_name=$(echo $current_version | cut -d'+' -f1)
build_number=$(echo $current_version | cut -d'+' -f2)

# Increment build number
new_build_number=$((build_number + 1))

# Update version based on argument
if [ "$1" = "patch" ]; then
    IFS='.' read -r major minor patch <<< "$version_name"
    new_version="${major}.${minor}.$((patch + 1))"
    new_build_number=1
elif [ "$1" = "minor" ]; then
    IFS='.' read -r major minor patch <<< "$version_name"
    new_version="${major}.$((minor + 1)).0"
    new_build_number=1
elif [ "$1" = "major" ]; then
    IFS='.' read -r major minor patch <<< "$version_name"
    new_version="$((major + 1)).0.0"
    new_build_number=1
else
    new_version=$version_name
fi

# Update pubspec.yaml
sed -i '' "s/^version: .*/version: ${new_version}+${new_build_number}/" pubspec.yaml

echo "Version updated from ${current_version} to ${new_version}+${new_build_number}"