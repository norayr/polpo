# x86-hosted ROP2 cross tools for MIPS, RISC-V and ARMv7 (objects in obj/x86/). x86 only.
# Usage: make mips, make riscv, make armv7   (run this, then tools/<arch>.Tool)

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

# ARMv7 back end
compiler.Compile /s src/cli/armv7/AOPL.Mod
compiler.Compile /s src/cli/armv7/AOPC.Mod
compiler.Compile /s src/cli/armv7/AOPV.Mod
compiler.Compile /s src/cli/armv7/a7compiler.Mod
