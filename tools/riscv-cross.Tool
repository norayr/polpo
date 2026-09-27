# x86-hosted RISC-V cross tools (objects in obj/x86/). x86 only.
# Usage: make riscv   (runs this, then tools/riscv.Tool)

compiler.Compile /s src/cli/riscv/ROPM.Mod
compiler.Compile /s src/cli/riscv/ROPS.Mod
compiler.Compile /s src/cli/riscv/ROPT.Mod
compiler.Compile /s src/cli/riscv/ROPB.Mod
compiler.Compile /s src/cli/riscv/ROPP.Mod
compiler.Compile /s src/cli/riscv/VOPL.Mod
compiler.Compile /s src/cli/riscv/VOPC.Mod
compiler.Compile /s src/cli/riscv/VOPV.Mod
compiler.Compile /s src/cli/riscv/rvcompiler.Mod
compiler.Compile /s src/cli/riscv/rvlinker.Mod
