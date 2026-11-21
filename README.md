# Snowball — Self-Hosted AMD/ASRock BC-250 AI Server

**Snowball** is a custom-tuned, privacy-focused local AI inference and RAG server built around the **ASRock BC-250** compute board (powered by the PlayStation 5-derived AMD *Ariel / Oberon* APU) running **CachyOS Linux**.

The system is engineered to balance high-throughput local LLM inference (**Gemma 4 26B** via `llama-server` with the Vulkan backend) with minimal idle power consumption using custom SMU frequency locking, CPU C-state power management, and automated Fish shell control functions.

> **[IMAGE PLACEHOLDER: Full Hardware & Server Build Overview]**  
> *Replace this block with a photograph of the assembled BC-250 rig, PSU, and chassis layout (`docs/images/hardware-overview.jpg`).*

---

## System Architecture & Hardware Specifications

The ASRock BC-250 utilizes a semi-custom AMD Zen 2 + RDNA 2 APU with unified **16 GB GDDR6** memory shared between the CPU and GPU.

| Component / Subsystem | Specification / Configuration |
| :--- | :--- |
| **Motherboard / APU** | ASRock BC-250 (AMD Cyan Skillfish / Oberon APU) |
| **CPU Architecture** | 8x Zen 2 Cores (Unlocked via BIOS mod) |
| **GPU Architecture** | AMD RDNA 2 — 24 Compute Units (CUs) active (hardware limit) |
| **Memory** | 16 GB Unified GDDR6 (Dynamic VRAM / GTT allocation) |
| **Operating System** | CachyOS (Arch-based, performance-optimized kernel) |
| **Inference Engine** | `llama.cpp` (`llama-server`) with Vulkan backend |
| **Primary LLM** | Gemma 4 26B (Quantized) + local RAG (`rag-mcp` / Open WebUI) |
| **Remote Access** | Tailscale VPN (`100.95.138.9`) + SSH |

---

## BIOS Modding & Hardware Unlocking (8 Cores & 24 CUs)

By default, the BC-250 ships with restricted firmware intended for headless cryptocurrency mining. To repurpose it as a general-purpose Linux AI server, the following firmware and topology configurations were applied:

1. **8-Core CPU Unlock (`P3.00 MeiMeiDXE` BIOS Mod):**
   - Flashed the modified **P3.00 MeiMeiDXE** BIOS to unlock all **8 Zen 2 CPU cores** (up from the stock 6-core lock) and expose hidden AMD CBS/PBS power and memory configuration menus.
2. **Compute Units (CUs) Topology:**
   - Verified hardware topology: while the underlying die is related to the 36/40 CU PS5 silicon, the BC-250 APU has **24 active RDNA 2 Compute Units** physically fused at the silicon level.
3. **Unified GDDR6 Memory & Vulkan GTT Tuning:**
   - Configured dynamic memory allocation so Vulkan can address the unified GDDR6 pool without triggering Out-Of-Memory (OOM) crashes during large context or multimodal processing.

> **[IMAGE PLACEHOLDER: BIOS / `neofetch` / `vulkaninfo` Verification]**  
> *Replace this block with a screenshot showing the unlocked 8 cores, 24 CUs, and GDDR6 memory allocation (`docs/images/bios-settings.png`).*

---

## GPU Frequency Locking & Power Management (`cyan-skillfish-governor-smu`)

Because standard `amdgpu` DPM (Dynamic Power Management) tables do not natively scale clocks properly on the BC-250 APU under Linux, the board requires direct System Management Unit (SMU) control:

- **SMU Governor:** Installed and configured [`cyan-skillfish-governor-smu`](https://github.com/Magnap/cyan-skillfish-governor-smu) to manage GPU clock states and voltage curves.
- **2000 MHz Boost Profile:** When AI workloads are active, the GPU is locked to **2000 MHz** for deterministic, low-latency token generation.
- **Deep Idle (`C3` C-States):** When AI services are unloaded, the GPU clock ceiling drops and the Zen 2 CPU cores enter deep **`C3` sleep states**, drastically reducing idle wall power draw and heat output.
- **Systemd Hardening:** Configured `systemd` service constraints (`MemoryMax=3.5G`, `--no-mmproj-offload`, `--ctx-checkpoints 0`, and `--reasoning-budget`) to prevent Vulkan GTT memory leaks.

---

## Cooling & Fan Configuration

The BC-250 passive server heatsink requires high static-pressure airflow, especially when sustained at 2000 MHz GPU clocks:

- **Motherboard Headers (`CPU_FAN1` & `J4003`):**
  - Mapped the board's 4-pin PWM header (`CPU_FAN1`) and auxiliary fan header (`J4003`, using custom DuPont pinouts with verified `+12V` polarity) for active chassis and heatsink cooling.
  - Evaluated and integrated multi-fan PWM distribution (Arctic 10-port PWM fan hub architecture) to push air across the GDDR6 modules and VRM stages.
- **Hardware Monitoring:**
  - Loaded kernel sensor modules (`nct6683` / `nct6687`) to expose thermal diodes and fan RPM telemetry to `lm_sensors` and CLI monitoring scripts.

> **[IMAGE PLACEHOLDER: Custom Fan Duct & PWM Wiring Setup]**  
> *Replace this block with a close-up photograph of the fan shroud, `CPU_FAN1` / `J4003` wiring, or PWM hub (`docs/images/cooling-fan-setup.jpg`).*

---

## Server Control Functions (Fish Shell)

To make switching between low-power idle mode and full AI inference seamless over SSH (including remote mobile access via Termius + Tailscale), custom **Fish shell** functions are installed in `~/.config/fish/functions/`:

### `ai-on`
- Communicates with `systemd` / D-Bus to start `llama-server` (loading **Gemma 4 26B**) and `rag-mcp`.
- Engages `cyan-skillfish-governor-smu` to lock the RDNA 2 GPU frequency at **2000 MHz**.

### `ai-off`
- Gracefully stops `llama-server` and `rag-mcp` to free unified GDDR6 memory.
- Releases the 2000 MHz GPU lock and allows CPU cores to drop back into **`C3` deep idle states**.

### `servercheck`
- Real-time terminal dashboard providing an instant health check of Snowball:
  - Active `systemd` service status (`llama-server`, `rag-mcp`, `tailscaled`)
  - Current GPU clock frequency range and SMU governor state
  - APU package temperature and real-time power draw (Watts)
  - CPU core residency in `C3` sleep states and GDDR6/GTT memory usage

> **[IMAGE PLACEHOLDER: `servercheck` Terminal Output]**  
> *Replace this block with a terminal screenshot showing `ai-on` and `servercheck` in action (`docs/images/servercheck-output.png`).*

---

## References & Community Documentation

This project builds directly upon the reverse-engineering work and documentation created by the AMD BC-250 open-source community:

- **Main Hardware & Linux Bring-Up Guide:** [AMD BC-250 Docs by elektricm](https://elektricm.github.io/amd-bc250-docs/)
- **SMU Governor & Clock Control:** [`cyan-skillfish-governor-smu`](https://github.com/Magnap/cyan-skillfish-governor-smu)
- **Inference Engine:** [`llama.cpp` (Vulkan Backend)](https://github.com/ggml-org/llama.cpp)
- **OS Distribution:** [CachyOS Linux](https://cachyos.org/)
