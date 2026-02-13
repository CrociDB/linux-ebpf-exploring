# AGENTS.md

## Project Overview

This is the **Linux 6.19.0** kernel source tree ("Baby Opossum Posse"), configured for **eBPF development and testing**. A `shell.nix` provides all build dependencies via Nix, and the kernel's built-in `vmtest.sh` script handles building, rootfs provisioning, and QEMU-based testing.

## Development Environment

Enter the development shell before any build or test operations:

```bash
nix-shell
```

This provides: gcc, clang, llvm, pahole, flex, bison, bc, perl, python3, elfutils, openssl, ncurses, qemu, zstd, gdb, and other kernel build dependencies.

## Build & Test Workflow

All commands assume you are inside `nix-shell`.

### Quick Start (Build + Test in VM)

```bash
# Build kernel and run the full BPF selftest suite
./tools/testing/selftests/bpf/vmtest.sh

# Build kernel and drop into an interactive VM shell
./tools/testing/selftests/bpf/vmtest.sh -s

# Run a specific test
./tools/testing/selftests/bpf/vmtest.sh -- ./test_progs -t <test_name>
```

`vmtest.sh` performs these steps automatically:
1. Merges config fragments (`config` + `config.vm` + `config.x86_64`) into `~/.bpf_selftests/latest.config`
2. Runs `make olddefconfig` then `make -j$(nproc)` to build `arch/x86/boot/bzImage`
3. Downloads a Debian rootfs from libbpf CI (cached at `~/.bpf_selftests/`)
4. Builds BPF selftests and copies them into the rootfs at `/root/bpf/`
5. Boots QEMU with 4GB RAM, virtio disk, KVM acceleration, serial console

### vmtest.sh Options

| Flag | Effect |
|------|--------|
| `-s` | Interactive shell mode (drops to bash instead of poweroff) |
| `-i` | Force re-download of rootfs image |
| `-d <dir>` | Custom output directory (default: `~/.bpf_selftests`) |
| `-j <n>` | Number of parallel compile jobs (default: `$(nproc)`) |
| `-l <path>` | Use a local rootfs image instead of downloading |

### Building BPF Samples

```bash
make headers_install
make M=samples/bpf
```

### Kernel Configuration

```bash
make menuconfig          # interactive config editor
make defconfig           # default config (not BPF-tuned)
```

The vmtest.sh config fragments enable all BPF features. Key options:
- `CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`, `CONFIG_BPF_JIT=y`, `CONFIG_BPF_JIT_ALWAYS_ON=y`
- `CONFIG_DEBUG_INFO_BTF=y` (required for CO-RE)
- `CONFIG_BPF_LSM=y`, `CONFIG_CGROUP_BPF=y`, `CONFIG_XDP_SOCKETS=y`
- `CONFIG_BPF_KPROBE_OVERRIDE=y`, `CONFIG_FPROBE=y`, `CONFIG_DYNAMIC_FTRACE=y`

## Repository Structure

### Top-Level Layout

```
Makefile            Top-level kernel Makefile (VERSION=6, PATCHLEVEL=19)
Kconfig             Root Kconfig sourcing all subsystems
shell.nix           Nix development environment
arch/               Architecture-specific code (x86, arm64, riscv, s390, powerpc, ...)
kernel/             Core kernel code, including kernel/bpf/
net/                Networking stack (BPF integration in net/core/filter.c)
include/            Kernel headers (include/linux/bpf.h, bpf_verifier.h, ...)
drivers/            Device drivers
fs/                 Filesystems (includes bpf pseudo-filesystem)
security/           Security modules (SELinux, BPF LSM)
tools/              Userspace tools (libbpf, bpftool, selftests)
samples/bpf/        Example BPF programs
Documentation/bpf/  BPF documentation (48 rst files)
```

### eBPF-Specific Code

#### `kernel/bpf/` -- Core BPF Subsystem

The in-kernel BPF implementation. Key files:

| File | Purpose |
|------|---------|
| `verifier.c` | BPF verifier (safety checker, ~26k lines) |
| `syscall.c` | `bpf()` syscall implementation |
| `core.c` | BPF interpreter and program execution |
| `btf.c` | BTF (BPF Type Format) processing |
| `helpers.c` | BPF helper function definitions |
| `trampoline.c` | BPF trampolines (fentry/fexit/fmod_ret) |
| `hashtab.c`, `arraymap.c`, `ringbuf.c`, `lpm_trie.c` | Map implementations |
| `cgroup.c` | Cgroup BPF hooks |
| `bpf_lsm.c` | BPF LSM security module |
| `bpf_struct_ops.c` | Struct ops (e.g., TCP congestion control via BPF) |
| `tcx.c`, `mprog.c` | TC/XDP express attach, multi-prog management |
| `Kconfig` | BPF config options (CONFIG_BPF, CONFIG_BPF_SYSCALL, CONFIG_BPF_JIT, ...) |

#### `tools/testing/selftests/bpf/` -- BPF Selftests

| Path | Purpose |
|------|---------|
| `progs/` | ~947 BPF C programs (compiled with Clang to BPF bytecode) |
| `prog_tests/` | ~419 test driver files for `test_progs` |
| `map_tests/` | Map-specific tests |
| `benchs/` | Benchmarks (bloom filter, hashmap, ringbuf, etc.) |
| `verifier/` | Verifier-specific tests |
| `vmtest.sh` | QEMU VM test runner |
| `config`, `config.vm`, `config.x86_64` | Kernel config fragments |
| `DENYLIST*` | Tests known to fail per-architecture |

Test runners: `test_progs`, `test_progs-no_alu32`, `test_verifier`, `test_maps`, `bench`, `veristat`.

#### `tools/lib/bpf/` -- libbpf

Userspace BPF library. Key headers for BPF programs:
- `bpf_helpers.h` -- helper function declarations
- `bpf_tracing.h` -- tracing macros (PT_REGS, etc.)
- `bpf_core_read.h` -- CO-RE read macros
- `bpf_endian.h` -- endianness helpers

#### `tools/bpf/` -- BPF Tools

- `bpftool/` -- Swiss army knife for BPF inspection and management
- `resolve_btfids/` -- BTF ID resolution for vmlinux
- `bpf_asm.c`, `bpf_dbg.c`, `bpf_jit_disasm.c` -- classic BPF tools

#### `samples/bpf/` -- Example Programs

Demonstrations of XDP, socket filtering, tracing, TC, TCP BPF, and more. Build with `make M=samples/bpf` after `make headers_install`.

## Coding Conventions

- **License**: Every file has an SPDX header (`// SPDX-License-Identifier: GPL-2.0` or variant)
- **Kernel C style**: Tabs (8-space), K&R braces, kernel coding style per `Documentation/process/coding-style.rst`
- **BPF programs** (`progs/`): Compiled with Clang, use `SEC("section_name")` macros, include `<bpf/bpf_helpers.h>`
- **Test drivers** (`prog_tests/`): Compiled with host GCC, include auto-generated `<name>.skel.h` skeletons
- **Naming**: BPF program source in `progs/<name>.c`, corresponding test in `prog_tests/<name>.c`

## Supported Architectures

`vmtest.sh` supports BPF testing on:

| Platform | QEMU Binary | Kernel Image | Notes |
|----------|-------------|-------------|-------|
| x86_64 | `qemu-system-x86_64` | `arch/x86/boot/bzImage` | KVM, 8 SMP cores |
| aarch64 | `qemu-system-aarch64` | `arch/arm64/boot/Image` | GICv3, KVM or Cortex-A76 emulation |
| s390x | `qemu-system-s390x` | `arch/s390/boot/vmlinux` | KVM, 2 SMP cores |
| riscv64 | `qemu-system-riscv64` | `arch/riscv/boot/Image` | Requires QEMU >= 7.2.0 |
| ppc64el | `qemu-system-ppc64` | `vmlinux` | POWER9, no KVM |

Cross-compile with: `PLATFORM=<arch> CROSS_COMPILE=<toolchain> ./tools/testing/selftests/bpf/vmtest.sh`

## Notes

- `vmtest.sh` uses `sudo` to mount/unmount the rootfs disk image
- First build takes 10-30 minutes; subsequent incremental builds are faster
- Rootfs and build output are cached at `~/.bpf_selftests/` by default
- Test logs are saved to `~/.bpf_selftests/bpf_selftests.<timestamp>.log`
