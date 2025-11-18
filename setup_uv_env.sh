#!/bin/bash
set -e

echo "Setting up UV environment for boltzGen..."
echo "=========================================="
echo ""

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$REPO_ROOT"

# Install uv if missing
if ! command -v uv &> /dev/null; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
fi

echo "✓ UV available: $(uv --version)"
echo ""

# Always use Python 3.11 per README recommendation
echo "Installing Python 3.11..."
uv python install 3.11

echo ""
echo "Creating virtual environment..."
uv venv --python 3.11 .venv

echo ""
echo "Activating virtual environment..."
source .venv/bin/activate

echo ""
echo "Installing pip..."
python -m ensurepip --upgrade || uv pip install pip

echo ""
echo "Upgrading pip, setuptools, wheel..."
python -m pip install --upgrade pip setuptools wheel

echo ""
echo "Installing boltzgen in editable mode..."
pip install -e .

echo ""
echo "Verifying installation..."
python -c "import boltzgen; print('✓ boltzgen imported successfully')" || {
    echo "✗ boltzgen import failed"
    exit 1
}

echo ""
echo "Checking CUDA availability..."
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}')" || {
    echo "⚠ PyTorch check failed (may be normal)"
}

echo ""
echo "Creating cache directory..."
mkdir -p cache

echo ""
echo "Downloading models (this may take a while, ~6GB)..."
echo "Models will be downloaded to: $REPO_ROOT/cache"
boltzgen download all --cache ./cache || {
    echo "✗ Model download failed"
    echo "  You can retry later with: boltzgen download all --cache ./cache"
    exit 1
}

echo ""
echo "Verifying models..."
MODEL_COUNT=$(find cache -type f \( -name "*.ckpt" -o -name "*.pt" -o -name "*.zip" \) 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -gt 0 ]; then
    echo "✓ Found $MODEL_COUNT model/data files"
    echo ""
    echo "Model files:"
    find cache -type f \( -name "*.ckpt" -o -name "*.pt" -o -name "*.zip" \) 2>/dev/null | head -10 | while read -r model; do
        size=$(du -h "$model" | cut -f1)
        echo "  - $(basename $model): $size"
    done
else
    echo "⚠ No model files found (download may have failed)"
fi

echo ""
echo "=========================================="
echo "UV setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Activate environment: source .venv/bin/activate"
echo "  2. Run tests: bash test/run_local.sh"
echo ""

