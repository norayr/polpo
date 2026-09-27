# The ARMv7 polpo system (console and desktop, OP2 compiler) in obj/armv7/, and bin/armv7/loksh.
# For older ARM processors see tools/arm.Tool (Oberon-1 compiler, obj/arm/).
# Uses a7compiler/rlinker: the cross tools on x86 (after tools/rop2-cross.Tool),
# the native ARMv7 compiler on ARMv7 (make armv7-native, under qemu-arm elsewhere).
# The executable is linked to bin/armv7/loksh.new; make moves it to bin/armv7/loksh.

# ARMv7 runtime
a7compiler.Compile /s src/cli/armv7/Linux0.Mod
a7compiler.Compile /s src/cli/rop2/Kernel.Mod
a7compiler.Compile /s src/common/Reals.Mod
a7compiler.Compile /s src/common/POLPO.Files.Mod
a7compiler.Compile /s src/cli/rop2/Modules0.Mod

# console modules
a7compiler.Compile /s src/cli/out.Mod
a7compiler.Compile /s src/common/Modules.Mod
a7compiler.Compile /s src/common/Objects0.Mod
a7compiler.Compile /s src/cli/objects.Mod
a7compiler.Compile /s src/cli/strings.Mod
a7compiler.Compile /s src/common/regex.Mod
a7compiler.Compile /s src/common/Utf8.Mod
a7compiler.Compile /s src/common/Texts0.Mod
a7compiler.Compile /s src/common/RXA.Mod
a7compiler.Compile /s src/cli/texts.Mod
a7compiler.Compile /s src/common/Oberon0.Mod
a7compiler.Compile /s src/cli/oberon.Mod
a7compiler.Compile /s src/cli/in.Mod
a7compiler.Compile /s src/cli/termios.Mod
a7compiler.Compile /s src/cli/rop2/system.Mod
a7compiler.Compile /s src/common/POLPO.FATFiles.Mod
a7compiler.Compile /s src/cli/shell.Mod
a7compiler.Compile /s src/cli/loksh.Mod
a7compiler.Compile /s src/cli/cat.Mod

# native ARMv7 compiler and boot linker, so the ARMv7 system can rebuild itself
a7compiler.Compile /s src/cli/rop2/ROPM.Mod
a7compiler.Compile /s src/cli/rop2/ROPS.Mod
a7compiler.Compile /s src/cli/rop2/ROPT.Mod
a7compiler.Compile /s src/cli/rop2/ROPB.Mod
a7compiler.Compile /s src/cli/rop2/ROPP.Mod
a7compiler.Compile /s src/cli/armv7/AOPL.Mod
a7compiler.Compile /s src/cli/armv7/AOPC.Mod
a7compiler.Compile /s src/cli/armv7/AOPV.Mod
a7compiler.Compile /s src/cli/rop2/rcompiler.Mod
a7compiler.Compile /s src/cli/armv7/a7compiler.Mod
a7compiler.Compile /s src/cli/rop2/rlinker.Mod
a7compiler.Compile /s src/cli/armv7/compiler.Mod
a7compiler.Compile /s src/cli/armv7/linker.Mod

# desktop (X11 Display/Input)
a7compiler.Compile /s src/desktop/POLPO.Objects.Mod
a7compiler.Compile /s src/desktop/POLPO.FileDir.Mod
a7compiler.Compile /s /x src/desktop/POLPO.Display.Mod
a7compiler.Compile /s src/desktop/POLPO.Input.Mod
a7compiler.Compile /s src/desktop/POLPO.Fonts.Mod
a7compiler.Compile /s src/desktop/POLPO.Texts.Mod
a7compiler.Compile /s src/desktop/Viewers.Mod
a7compiler.Compile /s src/desktop/Oberon.Mod
a7compiler.Compile /s src/desktop/POLPO.In.Mod
a7compiler.Compile /s src/desktop/MenuViewers.Mod
a7compiler.Compile /s src/desktop/POLPO.TextFrames.Mod
a7compiler.Compile /s src/desktop/rop2/POLPO.System.Mod
a7compiler.Compile /s src/desktop/POLPO.Bitmaps.Mod
a7compiler.Compile /s src/desktop/Out.Mod
a7compiler.Compile /s src/desktop/Pictures.Mod
a7compiler.Compile /s src/desktop/POLPO.Centronics.Mod
a7compiler.Compile /s src/desktop/POLPO.V24.Mod
a7compiler.Compile /s src/desktop/Printer.Mod

# desktop clients
a7compiler.Compile /s src/desktop/Edit.Mod
a7compiler.Compile /s src/desktop/Styles.Mod
a7compiler.Compile /s src/desktop/ScriptFrames.Mod
a7compiler.Compile /s src/desktop/Script.Mod
a7compiler.Compile /s src/desktop/Dates.Mod
a7compiler.Compile /s src/desktop/Strings.Mod
a7compiler.Compile /s src/desktop/POLPO.Compiler.Mod
a7compiler.Compile /s src/desktop/POLPO.FileTools.Mod
a7compiler.Compile /s src/desktop/rop2/RCompiler.Mod
a7compiler.Compile /s src/desktop/armv7/A32Decoder.Mod

# static ARMv7 executable: modules in import order
rlinker.Link /a bin/armv7/loksh.new Linux0 Kernel Modules0 loksh
