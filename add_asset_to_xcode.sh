#!/bin/bash
# Add Asset.swift to the Xcode project

PROJECT_FILE="RoBergBoekhouding.xcodeproj/project.pbxproj"
ASSET_FILE="RoBergBoekhouding/Core/Models/Asset.swift"

# Check if already added
if grep -q "Asset.swift" "$PROJECT_FILE"; then
    echo "Asset.swift already in project"
    exit 0
fi

# Find the file reference section for Expense.swift and copy pattern for Asset.swift
# Get a unique ID for the new file reference
FILE_REF_ID=$(uuidgen | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')
BUILD_FILE_ID=$(uuidgen | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')

echo "Adding Asset.swift with IDs: $FILE_REF_ID, $BUILD_FILE_ID"

# This is complex - just report that manual addition is needed
echo "Please add Asset.swift to the Xcode project manually:"
echo "1. Open RoBergBoekhouding.xcodeproj in Xcode"
echo "2. Right-click on Core/Models folder"
echo "3. Select 'Add Files to RoBergBoekhouding'"
echo "4. Select Asset.swift"
