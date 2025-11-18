# boltzGen Test Suite

## Overview

The boltzGen test suite provides end-to-end testing of the protein design pipeline with comprehensive logging and results tracking. All outputs and logs are unified in a single timestamped directory for easy organization and analysis.

## Test Directory Structure

```
test/
├── README.md                    # This file
├── .gitignore                   # Ignore test outputs
├── run_local.sh                 # Local UV environment test runner
├── run_container.sh             # Apptainer container test runner
├── validate_container.sh        # Container validation script
└── outputs/                     # Test outputs (gitignored)
    ├── local_run_<timestamp>/   # Local test runs
    └── container_run_<timestamp>/ # Container test runs
```

## Quick Start

### Local Testing

```bash
cd /runtime/repos/boltzgen
bash setup_uv_env.sh  # One-time setup
bash test/run_local.sh
```

**Output**: `test/outputs/local_run_YYYY-MM-DD_HH-MM-SS/`

### Container Testing

```bash
cd /runtime/repos/boltzgen
bash build_apptainer.sh  # Build container (one-time)
bash test/run_container.sh
```

**Output**: `test/outputs/container_run_YYYY-MM-DD_HH-MM-SS/`

## Test Examples

### 1. Nanobody Scaffolds (7eow.yaml)

**Protocol**: `nanobody-anything`

**Description**: This test demonstrates nanobody scaffold design where:
- **Template regions**: The fixed scaffold framework (all of chain B except design regions)
- **Design regions**: Three CDR loops that are redesigned:
  - CDR1: residues 26-34 (with insertion of 1-5 residues at position 26)
  - CDR2: residues 52-59 (with insertion of 1-5 residues at position 52)
  - CDR3: residues 98-118 (with insertion of 1-14 residues at position 98)

The design uses `design_insertions` to add variable-length loops at specific positions, allowing flexible CDR loop lengths while maintaining the nanobody scaffold structure.

**Expected outputs**: CIF files in `final_ranked_designs/` directory

### 2. Vanilla Protein (1g13prot.yaml)

**Protocol**: `protein-anything`

**Description**: De novo protein design against a target structure (chain A of 1g13.cif). The designed protein (chain C) has a variable length between 80-140 residues.

**Expected outputs**: CIF files in `final_ranked_designs/` directory

## Output Structure

Each test run creates a timestamped directory containing:

```
outputs/run_YYYY-MM-DD_HH-MM-SS/
├── execution.log              # Detailed execution trace
├── config.log                 # Configuration parameters
├── results.log                # Results summary
└── pipeline_output/           # BoltzGen pipeline outputs
    ├── config/                # Configuration files
    ├── intermediate_designs/   # Initial designs
    ├── intermediate_designs_inverse_folded/  # After inverse folding
    └── final_ranked_designs/   # Final ranked designs
        ├── final_2_designs/   # Top 2 designs (matching budget)
        └── *.cif              # Structure files
```

## GPU Memory Considerations

- Tests use `--num_designs 2` to save time
- Monitor GPU memory with `nvidia-smi` during runs
- If 24GB VRAM limit is hit, consider reducing design size (sequence length) rather than num_designs
- Memory usage patterns are documented in TEST_RESULTS.md

## Troubleshooting

### No outputs generated
1. Check `execution.log` for error messages
2. Verify input YAML files exist in `example/` directory
3. Ensure models are downloaded to `cache/` directory
4. Check GPU availability: `nvidia-smi`

### CUDA errors
1. Verify CUDA is available: `python -c "import torch; print(torch.cuda.is_available())"`
2. Check NVIDIA drivers: `nvidia-smi`
3. Ensure CUDA version matches PyTorch requirements

### Container issues
1. Verify container exists: `ls -lh boltzgen.sif`
2. Run validation: `bash test/validate_container.sh`
3. Check Apptainer/Singularity version: `apptainer --version` or `singularity --version`

## Configuration

Tests use minimal parameters for speed:
- `--num_designs 2`: Generate 2 designs
- `--budget 2`: Keep top 2 designs in final set
- `--protocol`: Protocol-specific (nanobody-anything or protein-anything)

To modify test parameters, edit the test scripts directly.

## Validation

After each test run, verify:
1. CIF files exist in `final_ranked_designs/final_2_designs/`
2. Files are non-empty (check file sizes)
3. No errors in `execution.log`
4. GPU memory usage within limits (check `results.log`)

## See Also

- `TEST_RESULTS.md`: Detailed test results and observations
- `../README.md`: Main boltzGen documentation
- `../example/README.md`: Design specification guide

