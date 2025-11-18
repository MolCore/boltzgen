#!/bin/bash
set -e

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$REPO_ROOT"

echo "Building boltzGen Apptainer Container"
echo "======================================"
echo ""

# Check for Apptainer/Singularity
if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
else
    echo "✗ Neither apptainer nor singularity found"
    echo "  Install Apptainer: https://apptainer.org/docs/user/main/quick_start.html"
    echo "  Or Singularity: https://docs.sylabs.io/guides/3.0/user-guide/installation.html"
    exit 1
fi

echo "✓ Using: $CONTAINER_CMD"
echo ""

# Check if definition file exists
DEF_FILE="boltzgen.def"
if [ ! -f "$DEF_FILE" ]; then
    echo "✗ Definition file not found: $DEF_FILE"
    exit 1
fi

echo "✓ Definition file found: $DEF_FILE"
echo ""

# Build container
CONTAINER_NAME="boltzgen.sif"
echo "Building container: $CONTAINER_NAME"
echo "This may take 20-40 minutes depending on network speed..."
echo ""

# Build directly to SIF (sandbox approach can be used for development)
echo "Building SIF image (this will take 20-40 minutes)..."
$CONTAINER_CMD build --fakeroot "$CONTAINER_NAME" "$DEF_FILE" || {
    # Try without fakeroot if that fails
    echo "Build with fakeroot failed, trying without..."
    $CONTAINER_CMD build "$CONTAINER_NAME" "$DEF_FILE" || {
        echo "✗ Container build failed"
        exit 1
    }
}

# Report image size
if [ -f "$CONTAINER_NAME" ]; then
    IMAGE_SIZE=$(du -h "$CONTAINER_NAME" | cut -f1)
    echo ""
    echo "======================================"
    echo "Container build complete!"
    echo "======================================"
    echo "Image: $CONTAINER_NAME"
    echo "Size: $IMAGE_SIZE"
    echo ""
    echo "Next steps:"
    echo "  1. Validate container: bash test/validate_container.sh"
    echo "  2. Run tests: bash test/run_container.sh"
    echo ""
else
    echo "✗ Container file not found after build"
    exit 1
fi

