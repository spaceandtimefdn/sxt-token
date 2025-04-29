#!/bin/bash
set -e

# Install Soldeer if not already installed
if ! command -v soldeer &> /dev/null; then
    echo "Installing Soldeer..."
    cargo install soldeer
fi

# Install dependencies using Soldeer
echo "Installing dependencies with Soldeer..."
soldeer install

echo "Setup complete!"
