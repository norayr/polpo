# common files for ui and cli oberon
compiler.Compile /s src/cli/x86/Linux0.Mod
compiler.Compile src/cli/x86/Kernel.Mod
compiler.Compile /s src/common/Root.Mod
compiler.Compile src/common/Reals.Mod
compiler.Compile src/common/POLPO.Files.Mod

# for cli
compiler.Compile /s src/cli/out.Mod
compiler.Compile /s src/cli/x86/Modules0.Mod
compiler.Compile /s src/common/Modules.Mod
compiler.Compile /s src/common/Objects0.Mod
compiler.Compile /s src/cli/objects.Mod
compiler.Compile /s src/cli/strings.Mod
compiler.Compile /s src/common/regex.Mod
compiler.Compile /s src/common/Utf8.Mod
compiler.Compile /s src/common/Texts0.Mod
compiler.Compile /s src/common/RXA.Mod
compiler.Compile /s src/common/Oberon0.Mod
compiler.Compile /s src/cli/texts.Mod
compiler.Compile /s src/cli/oberon.Mod
compiler.Compile /s src/cli/in.Mod
compiler.Compile /s src/cli/termios.Mod
compiler.Compile /s src/cli/x86/system.Mod
compiler.Compile /s src/common/POLPO.FATFiles.Mod
compiler.Compile /s src/cli/shell.Mod
compiler.Compile /s src/cli/loksh.Mod
compiler.Compile /s src/cli/cat.Mod
compiler.Compile /s src/cli/xxs.Mod
compiler.Compile /s src/cli/TOML.Mod
compiler.Compile /s src/cli/portia.Mod
compiler.Compile /s src/cli/bdffont.Mod
compiler.Compile /s src/cli/grep.Mod
compiler.Compile /s src/cli/rx.Mod

# cli compiler
compiler.Compile /s src/cli/x86/OPM.Mod
compiler.Compile /s src/cli/x86/OPS.Mod
compiler.Compile /s src/cli/x86/OPT.Mod
compiler.Compile /s src/cli/x86/OPB.Mod
compiler.Compile /s src/cli/x86/OPA.Mod
compiler.Compile /s src/cli/x86/OPP.Mod
compiler.Compile /s src/cli/x86/OPO.Mod
compiler.Compile /s src/cli/x86/OPL.Mod
compiler.Compile /s src/cli/x86/OPC.Mod
compiler.Compile /s src/cli/x86/OPV.Mod
compiler.Compile /s src/cli/x86/compiler.Mod
compiler.Compile /s src/cli/x86/linker.Mod
compiler.Compile /s src/cli/x86/browser.Mod

linker.Link bin/x86/loksh2 /refs /integrate 8049000H obj/x86/Linux0 obj/x86/Kernel obj/x86/Root obj/x86/Files obj/x86/Modules0 obj/x86/loksh ~

# ui oberon
compiler.Compile /s src/desktop/POLPO.Objects.Mod
compiler.Compile src/desktop/POLPO.FileDir.Mod
compiler.Compile /x /s src/desktop/POLPO.Display.Mod
compiler.Compile /s src/desktop/POLPO.Input.Mod
compiler.Compile /s src/desktop/POLPO.Fonts.Mod
compiler.Compile src/desktop/POLPO.Texts.Mod
compiler.Compile src/desktop/Viewers.Mod
compiler.Compile /s src/desktop/Oberon.Mod
compiler.Compile src/desktop/POLPO.In.Mod
compiler.Compile src/desktop/MenuViewers.Mod
compiler.Compile /s src/desktop/POLPO.TextFrames.Mod
compiler.Compile /s src/desktop/POLPO.System.Mod
compiler.Compile src/desktop/POLPO.Bitmaps.Mod
compiler.Compile src/desktop/Out.Mod
compiler.Compile src/desktop/Pictures.Mod
compiler.Compile src/desktop/POLPO.Centronics.Mod
compiler.Compile src/desktop/POLPO.V24.Mod
compiler.Compile src/desktop/Printer.Mod

# ui clients
compiler.Compile /s src/desktop/Edit.Mod
compiler.Compile src/desktop/Styles.Mod
compiler.Compile src/desktop/ScriptFrames.Mod
compiler.Compile src/desktop/Script.Mod
compiler.Compile src/desktop/Dates.Mod
compiler.Compile src/desktop/Strings.Mod
compiler.Compile src/desktop/POLPO.Compiler.Mod
compiler.Compile src/desktop/POLPO.FileTools.Mod
compiler.Compile src/desktop/x86/XCompiler.Mod
compiler.Compile src/desktop/x86/XBootLinker.Mod
compiler.Compile src/desktop/x86/XDecoder.Mod
compiler.Compile src/desktop/x86/XBrowser.Mod

# ARM cross tools in the UI (ARM toolchain itself: ./loksh < arm.Tool)
compiler.Compile /s src/cli/arm/OBM.Mod
compiler.Compile /s src/cli/arm/OBS.Mod
compiler.Compile /s src/cli/arm/OBT.Mod
compiler.Compile /s src/cli/arm/OBC.Mod
compiler.Compile /s src/cli/arm/OBE.Mod
compiler.Compile /s src/cli/arm/OBH.Mod
compiler.Compile /s src/cli/arm/OBA.Mod
compiler.Compile /s src/cli/arm/OBP.Mod
compiler.Compile /s src/desktop/arm/ACompiler.Mod
compiler.Compile /s src/desktop/arm/ADecoder.Mod
compiler.Compile /s src/desktop/arm/ABrowser.Mod

# MIPS, RISC-V and ARMv7 cross tools in the desktop (toolchains themselves: make mips, make riscv, make armv7)
compiler.Compile /s src/cli/rop2/ROPM.Mod
compiler.Compile /s src/cli/rop2/ROPS.Mod
compiler.Compile /s src/cli/rop2/ROPT.Mod
compiler.Compile /s src/cli/rop2/ROPB.Mod
compiler.Compile /s src/cli/rop2/ROPP.Mod
compiler.Compile /s src/cli/riscv/VOPL.Mod
compiler.Compile /s src/cli/riscv/VOPC.Mod
compiler.Compile /s src/cli/riscv/VOPV.Mod
compiler.Compile /s src/desktop/rop2/RCompiler.Mod
compiler.Compile /s src/desktop/riscv/VDecoder.Mod
compiler.Compile /s src/cli/mips/MOPL.Mod
compiler.Compile /s src/cli/mips/MOPC.Mod
compiler.Compile /s src/cli/mips/MOPV.Mod
compiler.Compile /s src/desktop/mips/M2Decoder.Mod
compiler.Compile /s src/cli/armv7/AOPL.Mod
compiler.Compile /s src/cli/armv7/AOPC.Mod
compiler.Compile /s src/cli/armv7/AOPV.Mod
compiler.Compile /s src/desktop/armv7/A32Decoder.Mod
