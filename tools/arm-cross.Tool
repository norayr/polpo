# x86-hosted ARM cross tools (objects in obj/x86/). x86 only.
# Usage: make arm   (runs this, then tools/arm.Tool)

compiler.Compile /s src/cli/arm/OBM.Mod
compiler.Compile /s src/cli/arm/OBS.Mod
compiler.Compile /s src/cli/arm/OBT.Mod
compiler.Compile /s src/cli/arm/OBC.Mod
compiler.Compile /s src/cli/arm/OBE.Mod
compiler.Compile /s src/cli/arm/OBH.Mod
compiler.Compile /s src/cli/arm/OBA.Mod
compiler.Compile /s src/cli/arm/OBP.Mod
compiler.Compile /s src/cli/arm/acompiler.Mod
compiler.Compile /s src/cli/arm/alinker.Mod
