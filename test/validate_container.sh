#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER="$REPO_ROOT/boltzgen.sif"

echo "Validating boltzGen Apptainer Container"
echo "========================================"
echo ""

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "✗ Container not found: $CONTAINER"
    echo "  Run: bash build_apptainer.sh"
    exit 1
fi

echo "✓ Container exists: $CONTAINER"
CONTAINER_SIZE=$(du -h "$CONTAINER" | cut -f1)
echo "  Size: $CONTAINER_SIZE"
echo ""

# Check Apptainer/Singularity availability
if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
else
    echo "✗ Neither apptainer nor singularity found"
    exit 1
fi

echo "✓ Using: $CONTAINER_CMD"
echo ""

# Test 1: Python import
echo "Test 1: Python import"
echo "----------------------"
python_version=$($CONTAINER_CMD exec "$CONTAINER" python --version 2>&1 || echo "FAILED")
if [[ "$python_version" == *"Python 3"* ]]; then
    echo "✓ Python: $python_version"
else
    echo "✗ Python import failed: $python_version"
    exit 1
fi
echo ""

# Test 2: boltzgen import
echo "Test 2: boltzgen import"
echo "------------------------"
import_result=$($CONTAINER_CMD exec "$CONTAINER" python -c "import boltzgen; print('boltzgen imported successfully')" 2>&1)
if [[ "$import_result" == *"successfully"* ]]; then
    echo "✓ $import_result"
else
    echo "✗ boltzgen import failed: $import_result"
    exit 1
fi
echo ""

# Test 3: CUDA availability
echo "Test 3: CUDA availability"
echo "-------------------------"
cuda_result=$($CONTAINER_CMD exec --nv "$CONTAINER" python -c "import torch; print('CUDA:', torch.cuda.is_available())" 2>&1 || echo "CUDA: False (no GPU access)")
echo "$cuda_result"
if [[ "$cuda_result" == *"CUDA: True"* ]]; then
    echo "✓ CUDA available"
else
    echo "⚠ CUDA not available (may be normal if no GPU or --nv flag not used)"
fi
echo ""

# Test 4: Model files
echo "Test 4: Model files"
echo "-------------------"
model_count=$($CONTAINER_CMD exec "$CONTAINER" find /app/cache -type f -name "*.ckpt" -o -name "*.pt" 2>/dev/null | wc -l)
if [ "$model_count" -gt 0 ]; then
    echo "✓ Found $model_count model files in /app/cache"
    $CONTAINER_CMD exec "$CONTAINER" find /app/cache -type f -name "*.ckpt" -o -name "*.pt" 2>/dev/null | head -5 | while read -r model; do
        size=$($CONTAINER_CMD exec "$CONTAINER" du -h "$model" 2>/dev/null | cut -f1)
        echo "  - $(basename $model): $size"
    done
else
    echo "⚠ No model files found in /app/cache (may need to download)"
fi
echo ""

# Test 5: boltzgen command
echo "Test 5: boltzgen command"
echo "------------------------"
boltzgen_version=$($CONTAINER_CMD exec "$CONTAINER" boltzgen --help 2>&1 | head -1 || echo "FAILED")
if [[ "$boltzgen_version" != *"FAILED"* ]]; then
    echo "✓ boltzgen command works"
    echo "  $boltzgen_version"
else
    echo "✗ boltzgen command failed: $boltzgen_version"
    exit 1
fi
echo ""

echo "========================================"
echo "Container Validation: PASSED ✅"
echo "========================================"

