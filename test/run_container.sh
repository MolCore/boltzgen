#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER="$REPO_ROOT/boltzgen.sif"

# Create unified output directory with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_BASE="$SCRIPT_DIR/outputs/container_run_$TIMESTAMP"
mkdir -p "$OUTPUT_BASE"

# All logs and outputs go here
EXEC_LOG="$OUTPUT_BASE/execution.log"
CONFIG_LOG="$OUTPUT_BASE/config.log"
RESULTS_LOG="$OUTPUT_BASE/results.log"
PIPELINE_OUTPUT="$OUTPUT_BASE/pipeline_output"
mkdir -p "$PIPELINE_OUTPUT"

# Function to log to both console and file
log_output() {
    echo "$@" | tee -a "$EXEC_LOG"
}

log_config() {
    echo "$@" | tee -a "$CONFIG_LOG"
}

log_results() {
    echo "$@" | tee -a "$RESULTS_LOG"
}

log_output "boltzGen Pipeline Test - Apptainer Container"
log_output "============================================="
log_output "Timestamp: $TIMESTAMP"
log_output "Output directory: $OUTPUT_BASE"
log_output ""

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    log_output "✗ Container not found: $CONTAINER"
    log_output "  Run: bash build_apptainer.sh"
    exit 1
fi

log_output "✓ Container found: $CONTAINER"
log_output ""

# Check Apptainer/Singularity availability
if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
else
    log_output "✗ Neither apptainer nor singularity found"
    exit 1
fi

log_output "Using: $CONTAINER_CMD"
log_output ""

# Check CUDA availability
CUDA_AVAILABLE=$($CONTAINER_CMD exec --nv "$CONTAINER" python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")
log_config "CUDA Available: $CUDA_AVAILABLE"

if [ "$CUDA_AVAILABLE" = "True" ]; then
    GPU_FLAG="--nv"
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "N/A")
    log_config "GPU Info: $GPU_INFO"
else
    GPU_FLAG=""
    log_output "⚠ GPU not available, running in CPU mode"
fi

# Test 1: Nanobody Scaffolds
log_output ""
log_output "==========================================="
log_output "Test 1: Nanobody Scaffolds (7eow.yaml)"
log_output "==========================================="
log_output ""

NANOBODY_YAML="/data/example/nanobody_scaffolds/7eow.yaml"
NANOBODY_OUTPUT="/data/outputs/container_run_$TIMESTAMP/pipeline_output/nanobody_7eow"

log_config "Nanobody Test:"
log_config "  YAML: $NANOBODY_YAML (container path)"
log_config "  Protocol: nanobody-anything"
log_config "  Output: $NANOBODY_OUTPUT (container path)"
log_config "  Designs: 2"
log_config "  Budget: 2"
log_config ""

log_output "Template vs Design Regions:"
log_output "  Template: Fixed nanobody scaffold framework (all of chain B except design regions)"
log_output "  Design Regions:"
log_output "    - CDR1: residues 26-34 (with insertion of 1-5 residues at position 26)"
log_output "    - CDR2: residues 52-59 (with insertion of 1-5 residues at position 52)"
log_output "    - CDR3: residues 98-118 (with insertion of 1-14 residues at position 98)"
log_output ""

# Monitor GPU memory before run
if [ "$CUDA_AVAILABLE" = "True" ]; then
    GPU_MEM_BEFORE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "0")
    log_output "GPU Memory Before: ${GPU_MEM_BEFORE} MB"
fi

$CONTAINER_CMD exec $GPU_FLAG \
    --bind "$REPO_ROOT/example:/data/example" \
    --bind "$REPO_ROOT/cache:/data/cache" \
    --bind "$SCRIPT_DIR/outputs:/data/outputs" \
    --pwd /data \
    "$CONTAINER" \
    boltzgen run "$NANOBODY_YAML" \
        --output "$NANOBODY_OUTPUT" \
        --protocol nanobody-anything \
        --num_designs 2 \
        --budget 2 \
        --cache /data/cache 2>&1 | tee -a "$EXEC_LOG" || {
    log_output "✗ Nanobody test failed"
    exit 1
}

# Monitor GPU memory after run
if [ "$CUDA_AVAILABLE" = "True" ]; then
    GPU_MEM_AFTER=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "0")
    log_output "GPU Memory After: ${GPU_MEM_AFTER} MB"
    GPU_MEM_USED=$((GPU_MEM_AFTER - GPU_MEM_BEFORE))
    log_results "Nanobody Test GPU Memory Used: ${GPU_MEM_USED} MB"
fi

log_output "✓ Nanobody test completed"
log_output ""

# Test 2: Vanilla Protein
log_output "==========================================="
log_output "Test 2: Vanilla Protein (1g13prot.yaml)"
log_output "==========================================="
log_output ""

VANILLA_YAML="/data/example/vanilla_protein/1g13prot.yaml"
VANILLA_OUTPUT="/data/outputs/container_run_$TIMESTAMP/pipeline_output/vanilla_1g13"

log_config "Vanilla Protein Test:"
log_config "  YAML: $VANILLA_YAML (container path)"
log_config "  Protocol: protein-anything"
log_config "  Output: $VANILLA_OUTPUT (container path)"
log_config "  Designs: 2"
log_config "  Budget: 2"
log_config ""

# Monitor GPU memory before run
if [ "$CUDA_AVAILABLE" = "True" ]; then
    GPU_MEM_BEFORE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "0")
    log_output "GPU Memory Before: ${GPU_MEM_BEFORE} MB"
fi

$CONTAINER_CMD exec $GPU_FLAG \
    --bind "$REPO_ROOT/example:/data/example" \
    --bind "$REPO_ROOT/cache:/data/cache" \
    --bind "$SCRIPT_DIR/outputs:/data/outputs" \
    --pwd /data \
    "$CONTAINER" \
    boltzgen run "$VANILLA_YAML" \
        --output "$VANILLA_OUTPUT" \
        --protocol protein-anything \
        --num_designs 2 \
        --budget 2 \
        --cache /data/cache 2>&1 | tee -a "$EXEC_LOG" || {
    log_output "✗ Vanilla protein test failed"
    exit 1
}

# Monitor GPU memory after run
if [ "$CUDA_AVAILABLE" = "True" ]; then
    GPU_MEM_AFTER=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "0")
    log_output "GPU Memory After: ${GPU_MEM_AFTER} MB"
    GPU_MEM_USED=$((GPU_MEM_AFTER - GPU_MEM_BEFORE))
    log_results "Vanilla Protein Test GPU Memory Used: ${GPU_MEM_USED} MB"
fi

log_output "✓ Vanilla protein test completed"
log_output ""

# Verification
log_output "==========================================="
log_output "Verification"
log_output "==========================================="
log_output ""

# Count CIF files (using container path)
NANOBODY_CIFS=$($CONTAINER_CMD exec "$CONTAINER" find "$NANOBODY_OUTPUT/final_ranked_designs" -name "*.cif" 2>/dev/null | wc -l)
VANILLA_CIFS=$($CONTAINER_CMD exec "$CONTAINER" find "$VANILLA_OUTPUT/final_ranked_designs" -name "*.cif" 2>/dev/null | wc -l)

log_results "Nanobody outputs: $NANOBODY_CIFS CIF files"
log_results "Vanilla protein outputs: $VANILLA_CIFS CIF files"
log_results ""

# Verify we have outputs
if [ "$NANOBODY_CIFS" -eq 0 ]; then
    log_results "✗ No nanobody outputs found"
    exit 1
fi

if [ "$VANILLA_CIFS" -eq 0 ]; then
    log_results "✗ No vanilla protein outputs found"
    exit 1
fi

log_results "✓ All pipeline stages completed successfully"
log_results ""
log_results "Output directory: $OUTPUT_BASE"
log_results "Pipeline test PASSED ✅"
log_results ""

log_output "=== Files Generated ==="
find "$PIPELINE_OUTPUT" -name "*.cif" | head -10 | while read -r cif; do
    size=$(du -h "$cif" | cut -f1)
    log_output "  $size - $(basename $cif)"
done

log_output ""
log_output "=== Summary Files ==="
log_output "  execution.log  - Detailed execution trace"
log_output "  config.log     - Configuration parameters"
log_output "  results.log    - Results summary"

