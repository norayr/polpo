
# x86 host: bin/x86/loksh.  ARM: bin/arm/loksh, run through qemu-arm unless
# this machine is ARM.

X86 = bin/x86/loksh

HOSTARCH := $(shell uname -m)
ifneq ($(filter arm% aarch64,$(HOSTARCH)),)
ARM = bin/arm/loksh
ACOMPILE = $(ARM) compiler.Compile
else
ARM = qemu-arm bin/arm/loksh
ACOMPILE = $(X86) acompiler.Compile
endif

ifneq ($(filter riscv32,$(HOSTARCH)),)
RISCV = bin/riscv/loksh
else
RISCV = qemu-riscv32 bin/riscv/loksh
endif

# ---- x86 ----

fast:
		$(X86) < tools/build.Tool

sixel:
		$(X86) compiler.Compile /x src/desktop/POLPO.SXL.Display.Mod
		$(X86) compiler.Compile /s src/desktop/POLPO.SXL.Input.Mod

x11:
		$(X86) compiler.Compile /x src/desktop/POLPO.Display.Mod
		$(X86) compiler.Compile /s src/desktop/POLPO.Input.Mod

# ---- ARM ----

# cross compile the ARM system on x86
arm:
		$(X86) < tools/arm-cross.Tool
		$(X86) < tools/arm.Tool
		mv bin/arm/loksh.new bin/arm/loksh

# build the ARM system with the ARM compiler: natively on ARM, under qemu-arm elsewhere
arm-native:
		$(ARM) < tools/arm.Tool
		mv bin/arm/loksh.new bin/arm/loksh

# start the ARM desktop / console
arm-run:
		$(ARM) System.Init

arm-shell:
		$(ARM)

# select the ARM Display and Input: xterm sixel or X11
arm-sixel:
		$(ACOMPILE) /x src/desktop/POLPO.SXL.Display.Mod
		$(ACOMPILE) /s src/desktop/POLPO.SXL.Input.Mod

arm-x11:
		$(ACOMPILE) /x src/desktop/POLPO.Display.Mod
		$(ACOMPILE) /s src/desktop/POLPO.Input.Mod

# ---- RISC-V (RV32) ----

# cross compile the RISC-V system on x86
riscv:
		$(X86) < tools/riscv-cross.Tool
		$(X86) < tools/riscv.Tool
		mv bin/riscv/loksh.new bin/riscv/loksh

# build the RISC-V system with the RISC-V compiler: natively on RV32, under qemu-riscv32 elsewhere
riscv-native:
		$(RISCV) < tools/riscv.Tool
		mv bin/riscv/loksh.new bin/riscv/loksh

# start the RISC-V desktop / console (qemu-riscv32 unless this machine is RV32)
riscv-run:
		$(RISCV) System.Init

riscv-shell:
		$(RISCV)

.PHONY: fast sixel x11 arm arm-native arm-run arm-shell arm-sixel arm-x11 riscv riscv-native riscv-run riscv-shell
