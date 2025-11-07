#!/bin/bash

# Build script for Mouse Guide app

echo "Building Mouse Guide..."
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed or xcodebuild is not in PATH"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Build the project
xcodebuild -project MouseCrosshairs.xcodeproj \
    -scheme MouseCrosshairs \
    -configuration Debug \
    clean build

if [ $? -eq 0 ]; then
    echo ""
    echo "Build succeeded!"
    echo "The app is located in build/Debug/MouseCrosshairs.app"
else
    echo ""
    echo "Build failed. Please check the errors above."
    exit 1
fi
