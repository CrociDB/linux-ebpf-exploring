{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "kernel-ebpf-dev";

  nativeBuildInputs = with pkgs; [
    # Kernel build essentials
    gnumake
    gcc
    flex
    bison
    bc
    perl
    python3
    cpio
    pkg-config
    openssl
    elfutils
    ncurses

    # BPF toolchain
    clang
    llvm
    lld
    pahole

    # VM
    qemu

    # Rootfs handling
    zstd

    # Debugging
    gdb
  ];

  shellHook = ''
    echo "=== Linux Kernel eBPF Development Shell ==="
    echo "Kernel: $(make -s kernelversion 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Build & test commands:"
    echo "  Build kernel + run BPF selftests:"
    echo "    ./tools/testing/selftests/bpf/vmtest.sh"
    echo ""
    echo "  Build kernel + drop into VM shell:"
    echo "    ./tools/testing/selftests/bpf/vmtest.sh -s"
    echo ""
    echo "  Run specific tests:"
    echo "    ./tools/testing/selftests/bpf/vmtest.sh -- ./test_progs -t <test_name>"
    echo ""
    echo "  Build BPF samples:"
    echo "    make headers_install && make M=samples/bpf"
    echo ""
    echo "  Kernel menuconfig:"
    echo "    make menuconfig"
    echo "=========================================="
  '';
}
