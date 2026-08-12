#!/bin/sh

# Fail on any error
set -e

# The default execution directory of this script is the ci_scripts directory.
# Traverse up to find the root of the flutter project (nlpa2)
if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    cd "$CI_PRIMARY_REPOSITORY_PATH/nlpa2"
else
    echo "Warning: CI_PRIMARY_REPOSITORY_PATH not set, assuming project root is two levels up from script."
    cd "$(dirname "$0")/../.."
fi

echo "Current directory: $(pwd)"

# Update build number if running in Xcode Cloud
if [ -n "$CI_BUILD_NUMBER" ]; then
  echo "Updating build number to $CI_BUILD_NUMBER..."
  # Replace version: x.y.z+n with version: x.y.z+$CI_BUILD_NUMBER
  # sed -i '' -E "s/(version: [0-9]+\.[0-9]+\.[0-9]+\+)[0-9]+/\1$CI_BUILD_NUMBER/" pubspec.yaml
  
  # Update version.dart build number
  if [ -f "lib/version.dart" ]; then
    # echo "Updating lib/version.dart with build number $CI_BUILD_NUMBER..."
    # sed -i '' -E "s/(const String kAppBuildNumber = ')[0-9]+(';)/\1$CI_BUILD_NUMBER\2/" lib/version.dart

    SHORT_COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "Updating lib/version.dart with commit hash $SHORT_COMMIT_HASH..."
    sed -i '' -E "s/(const String kCommitHash = ')[^']+(';)/\1$SHORT_COMMIT_HASH\2/" lib/version.dart
  fi
  
  echo "New version in pubspec.yaml:"
  grep "^version:" pubspec.yaml

  # Record Git relation to update-server
  if [ -n "$UPDATE_WORKER_URL" ] && [ -n "$UPDATE_WORKER_KEY" ]; then
    VERSION=$(awk '/^version:/ {print $2}' pubspec.yaml | tr -d '\r')
    VERSION_NAME=$(echo "$VERSION" | cut -d'+' -f1)
    BUILD_NUMBER=$(echo "$VERSION" | cut -d'+' -f2)
    FULL_COMMIT_HASH=$(git rev-parse HEAD)
    APP_NAME=$(awk '/^name:/ {print $2}' pubspec.yaml | tr -d '\r')

    echo "Recording Git relation: $APP_NAME / $FULL_COMMIT_HASH -> $VERSION_NAME+$BUILD_NUMBER"
    
    curl -sSf -X POST "$UPDATE_WORKER_URL/$APP_NAME/git?key=$UPDATE_WORKER_KEY" \
         -H "Content-Type: application/json" \
         -d "{\"commit\": \"$FULL_COMMIT_HASH\", \"version\": \"$VERSION_NAME\", \"build\": \"$BUILD_NUMBER\"}" || echo "Warning: Failed to record git relation."
  fi
else
  echo "CI_BUILD_NUMBER not set, skipping build number update."
fi

# Install Flutter from storage
echo "Installing Flutter 3.41.4..."
curl -L -o $HOME/flutter.zip https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.41.4-stable.zip
unzip -q $HOME/flutter.zip -d $HOME
rm $HOME/flutter.zip
export PATH="$PATH:$HOME/flutter/bin"
export FLUTTER_ROOT="$HOME/flutter"

# Disable SPM as it causes issues in CI environments
flutter config --no-enable-swift-package-manager

# Display Flutter version
flutter --version

# Install Flutter artifacts
echo "Precaching Flutter artifacts..."
flutter precache --ios --macos --universal

# Install Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Install CocoaPods dependencies for iOS
if [ -d "ios" ]; then
    echo "Preparing iOS configuration..."
    flutter build ios --config-only
    echo "Installing iOS Pods..."
    cd ios
    pod install
    cd ..
fi

# Install CocoaPods dependencies for macOS
if [ -d "macos" ]; then
    echo "Preparing macOS configuration..."
    flutter build macos --config-only
    echo "Installing macOS Pods..."
    cd macos
    pod install
    cd ..
fi

echo "Detailed build script completed successfully."
exit 0
