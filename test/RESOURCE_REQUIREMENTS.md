# boltzGen Resource Requirements and Performance Metrics

This document provides comprehensive resource requirements and performance metrics for running boltzGen protein design pipelines. Metrics are based on test runs and can be used to estimate resource needs for production workloads.

## Table of Contents
- [Hardware Requirements](#hardware-requirements)
- [Observed Performance Metrics](#observed-performance-metrics)
- [Protocol-Specific Resource Usage](#protocol-specific-resource-usage)
- [Scaling Estimates](#scaling-estimates)
- [Resource Usage by Pipeline Step](#resource-usage-by-pipeline-step)
- [Design Size Estimates](#design-size-estimates)
- [Future Protocol Tracking](#future-protocol-tracking)

---

## Hardware Requirements

### Minimum Requirements
- **GPU**: NVIDIA GPU with CUDA support (compute capability ≥ 7.0)
- **VRAM**: 8 GB minimum, 16 GB recommended, 24 GB for large designs
- **RAM**: 16 GB minimum, 32 GB recommended
- **CPU**: 4+ cores recommended
- **Storage**: ~10 GB for models + ~100 MB per design output

### Test Environment
- **GPU**: NVIDIA GeForce RTX 3090 (24 GB VRAM)
- **CUDA**: 12.2.2 with cuDNN 8
- **Python**: 3.11
- **OS**: Ubuntu 22.04

---

## Observed Performance Metrics

### Test Run Summary (2 designs each)

#### Nanobody Scaffold Design (`nanobody-anything` protocol)
- **Input**: `7eow.yaml` - Nanobody scaffold with 29 designed residues
  - Design regions: Chain B, residues 26-34, 52-59, 98-118
  - Template: Fixed nanobody scaffold framework (all of chain B except design regions)
- **Total Pipeline Time**: ~175.2 seconds (~2.9 minutes)
- **Time per Design**: ~87.6 seconds (~1.5 minutes)
- **Output Size**: 76-92 KB per final CIF file
- **GPU Memory**: 134 MB baseline (peak usage not captured in test)

**Pipeline Step Breakdown:**
| Step | Time (s) | % of Total | Notes |
|------|----------|------------|-------|
| design | 85.6 | 48.9% | Diffusion-based structure generation |
| inverse_folding | 6.5 | 3.7% | Sequence prediction from structure |
| folding | 64.1 | 36.6% | Structure prediction from sequence |
| analysis | 11.6 | 6.6% | Quality metrics computation |
| filtering | 7.4 | 4.2% | Diversity optimization and ranking |
| **Total** | **175.2** | **100%** | |

#### Vanilla Protein Design (`protein-anything` protocol)
- **Input**: `1g13prot.yaml` - Protein design with 61 designed residues
  - Design region: Chain C, sequence 80-140
- **Total Pipeline Time**: ~256.3 seconds (~4.3 minutes)
- **Time per Design**: ~128.2 seconds (~2.1 minutes)
- **Output Size**: 148-176 KB per final CIF file
- **GPU Memory**: 134 MB baseline (peak usage not captured in test)

**Pipeline Step Breakdown:**
| Step | Time (s) | % of Total | Notes |
|------|----------|------------|-------|
| design | 69.1 | 27.0% | Diffusion-based structure generation |
| inverse_folding | 7.3 | 2.8% | Sequence prediction from structure |
| folding | 90.0 | 35.1% | Structure prediction from sequence |
| design_folding | 68.9 | 26.9% | Design-only folding (protocol-specific) |
| analysis | 12.1 | 4.7% | Quality metrics computation |
| filtering | 8.9 | 3.5% | Diversity optimization and ranking |
| **Total** | **256.3** | **100%** | |

---

## Protocol-Specific Resource Usage

### Available Protocols

| Protocol | Use Case | Pipeline Steps | Key Differences |
|----------|----------|----------------|------------------|
| `protein-anything` | Design proteins to bind proteins/peptides | 6 steps | Includes `design_folding` step |
| `nanobody-anything` | Design nanobodies (single-domain antibodies) | 5 steps | No `design_folding`, avoids Cys, no hydrophobic patch analysis |
| `peptide-anything` | Design cyclic peptides or others to bind proteins | 5 steps | No `design_folding`, avoids Cys, no hydrophobic patch analysis |
| `protein-small_molecule` | Design proteins to bind small molecules | 6 steps | Includes `design_folding` + affinity prediction |

### Protocol Comparison (Estimated)

| Protocol | Avg Time/Design | VRAM Usage | Notes |
|----------|----------------|------------|-------|
| `nanobody-anything` | ~1.5-2 min | Low-Medium | Smaller designs, fewer steps |
| `protein-anything` | ~2-3 min | Medium | Includes design folding |
| `peptide-anything` | ~1.5-2 min | Low-Medium | Similar to nanobody |
| `protein-small_molecule` | ~3-4 min | Medium-High | Additional affinity prediction step |

---

## Scaling Estimates

### Time Scaling with Number of Designs

**Observed Scaling (2 designs):**
- Nanobody: ~87.6 s/design
- Vanilla Protein: ~128.2 s/design

**Estimated Scaling for Production Runs:**

| Num Designs | Nanobody Est. Time | Vanilla Protein Est. Time | Notes |
|-------------|-------------------|---------------------------|-------|
| 2 | ~3 min | ~4 min | Test runs |
| 10 | ~15 min | ~21 min | Small batch |
| 100 | ~2.5 hours | ~3.5 hours | Medium batch |
| 1,000 | ~24 hours | ~36 hours | Large batch |
| 10,000 | ~10 days | ~15 days | Production run |

**Note**: Times scale approximately linearly with `--num_designs`. Batch processing may improve efficiency slightly for larger runs.

### VRAM Scaling

**Observed**: Baseline ~134 MB (likely not capturing peak usage during model inference)

**Estimated VRAM Usage:**
- **Small designs** (<50 residues): 2-4 GB peak
- **Medium designs** (50-150 residues): 4-8 GB peak
- **Large designs** (150-300 residues): 8-16 GB peak
- **Very large designs** (>300 residues): 16-24 GB peak

**Factors affecting VRAM:**
- Number of residues in design region
- Number of residues in target/template
- Batch size (`--diffusion_batch_size`)
- Model checkpoint size (~2-3 GB per checkpoint)

### RAM Usage

**Estimated RAM Requirements:**
- **Base**: 4-8 GB (Python, PyTorch, models)
- **Per design**: ~50-200 MB (depending on structure size)
- **For 10,000 designs**: ~16-32 GB total RAM recommended

### CPU Usage

- **Design step**: High CPU usage during diffusion sampling
- **Folding steps**: Moderate CPU usage (structure prediction)
- **Analysis/Filtering**: Low CPU usage
- **Recommended**: 4-8 CPU cores for optimal performance

---

## Resource Usage by Pipeline Step

### Step 1: Design (Diffusion)
- **Time**: 40-50% of total pipeline time
- **VRAM**: Highest usage (model loading + inference)
- **CPU**: High (diffusion sampling)
- **Scaling**: Linear with `--num_designs`

### Step 2: Inverse Folding
- **Time**: 2-4% of total pipeline time
- **VRAM**: Medium (sequence prediction model)
- **CPU**: Low-Medium
- **Scaling**: Linear with number of designs

### Step 3: Folding
- **Time**: 30-40% of total pipeline time
- **VRAM**: High (structure prediction model)
- **CPU**: Medium
- **Scaling**: Linear with number of designs

### Step 4: Design Folding (protocol-specific)
- **Time**: 25-30% of total pipeline time (if applicable)
- **VRAM**: High (structure prediction model)
- **CPU**: Medium
- **Protocols**: `protein-anything`, `protein-small_molecule`

### Step 5: Analysis
- **Time**: 4-7% of total pipeline time
- **VRAM**: Low-Medium (metric computation)
- **CPU**: Low-Medium
- **Scaling**: Linear with number of designs

### Step 6: Filtering
- **Time**: 3-5% of total pipeline time
- **VRAM**: Low (ranking and diversity optimization)
- **CPU**: Low
- **Scaling**: Depends on `--budget` parameter

---

## Design Size Estimates

### Output File Sizes

| Design Type | Residues | CIF Size Range | Notes |
|-------------|----------|----------------|-------|
| Small (peptide/nanobody) | 20-50 | 50-100 KB | Compact structures |
| Medium (protein domain) | 50-150 | 100-200 KB | Typical protein designs |
| Large (multi-domain) | 150-300 | 200-500 KB | Complex structures |
| Very Large | >300 | 500 KB - 2 MB | Multi-chain complexes |

### Storage Requirements

**Per Design Output Directory:**
- Intermediate designs: ~100-500 KB
- Inverse-folded designs: ~100-500 KB
- Final ranked designs: ~100-500 KB
- Analysis outputs (CSV, PDF): ~50-200 KB
- **Total per design**: ~350 KB - 1.7 MB

**For 10,000 designs**: ~3.5-17 GB storage

---

## Future Protocol Tracking

### Template for Adding New Protocol Metrics

```markdown
#### Protocol Name (`protocol-id`)
- **Input**: Description of typical input
- **Design Size**: Typical number of designed residues
- **Total Pipeline Time**: Observed time for N designs
- **Time per Design**: Average time per design
- **VRAM Usage**: Peak VRAM observed
- **RAM Usage**: Peak RAM observed
- **GPU Utilization**: Average GPU utilization %
- **CPU Utilization**: Average CPU utilization %
- **Output Size**: Typical output file sizes
- **Notes**: Any protocol-specific observations
```

### Recommended Monitoring

For future test runs, collect:
1. **Timing**: Per-step and total pipeline time
2. **VRAM**: Peak usage during each step (using `nvidia-smi` or PyTorch memory tracking)
3. **RAM**: Peak system RAM usage
4. **GPU Utilization**: Average GPU utilization percentage
5. **CPU Utilization**: Average CPU utilization percentage
6. **Design Size**: Number of residues, output file sizes
7. **Throughput**: Designs per hour/minute

### Example Monitoring Command

```bash
# Monitor GPU during run
watch -n 1 'nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv'

# Monitor system resources
htop  # or use system monitoring tools
```

---

## Recommendations

### For Small Batches (<100 designs)
- **VRAM**: 8-16 GB sufficient
- **RAM**: 16 GB sufficient
- **Time**: Expect 1-4 hours depending on protocol

### For Medium Batches (100-1,000 designs)
- **VRAM**: 16-24 GB recommended
- **RAM**: 32 GB recommended
- **Time**: Expect 1-2 days depending on protocol
- **Consider**: Running overnight or using job schedulers

### For Production Runs (10,000+ designs)
- **VRAM**: 24 GB+ required
- **RAM**: 32-64 GB recommended
- **Time**: Expect 1-2 weeks depending on protocol
- **Consider**: 
  - Using `--reuse` flag for checkpointing
  - Running in containerized environments
  - Using HPC job schedulers (SLURM, PBS)
  - Monitoring resource usage throughout

### Optimization Tips

1. **Batch Size**: Increase `--diffusion_batch_size` for better GPU utilization (if VRAM allows)
2. **Workers**: Adjust `--num_workers` based on CPU cores available
3. **Devices**: Use multiple GPUs if available (`--devices N`)
4. **Checkpointing**: Use `--reuse` to resume interrupted runs
5. **Storage**: Ensure sufficient disk space for outputs

---

## Notes

- **GPU Memory Monitoring**: Current test runs showed baseline memory (~134 MB) but did not capture peak usage during model inference. Future runs should include continuous monitoring.
- **Scaling**: Times scale approximately linearly with number of designs. Batch processing may provide slight efficiency gains.
- **Protocol Differences**: `protein-anything` includes an additional `design_folding` step compared to `nanobody-anything`, resulting in ~30% longer runtime.
- **Design Size Impact**: Larger design regions (more residues) generally require more time and VRAM, but the relationship is not strictly linear due to model architecture constraints.

---

*Last Updated: Based on test runs from 2025-11-12*
*Test Environment: NVIDIA RTX 3090 (24 GB), CUDA 12.2.2, Python 3.11*

