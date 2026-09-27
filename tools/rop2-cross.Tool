# x86-hosted ROP2 cross tools for MIPS and RISC-V (objects in obj/x86/). x86 only.
# Usage: make mips, make riscv   (run this, then tools/mips.Tool or tools/riscv.Tool)

# shared front end, compiler frontend and boot linker
compiler.Compile /s src/cli/rop2/ROPM.Mod
compiler.Compile /s src/cli/rop2/ROPS.Mod
compiler.Compile /s src/cli/rop2/ROPT.Mod
compiler.Compile /s src/cli/rop2/ROPB.Mod
compiler.Compile /s src/cli/rop2/ROPP.Mod
compiler.Compile /s src/cli/rop2/rcompiler.Mod
compiler.Compile /s src/cli/rop2/rlinker.Mod

# RISC-V back end
compiler.Compile /s src/cli/riscv/VOPL.Mod
compiler.Compile /s src/cli/riscv/VOPC.Mod
compiler.Compile /s src/cli/riscv/VOPV.Mod
compiler.Compile /s src/cli/riscv/rvcompiler.Mod

# MIPS back end
compiler.Compile /s src/cli/mips/MOPL.Mod
compiler.Compile /s src/cli/mips/MOPC.Mod
compiler.Compile /s src/cli/mips/MOPV.Mod
compiler.Compile /s src/cli/mips/mcompiler.Mod
