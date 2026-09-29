# The MIPS (32-bit little-endian, mipsel) polpo system (console and desktop) in obj/mips/, and bin/mips/loksh.
# Uses mcompiler/rlinker: the cross tools on x86 (after tools/rop2-cross.Tool),
# the native MIPS compiler on MIPS (make mips-native, under qemu-mipsel elsewhere).
# The executable is linked to bin/mips/loksh.new; make moves it to bin/mips/loksh.

# MIPS runtime
mcompiler.Compile /s src/cli/mips/Linux0.Mod
mcompiler.Compile /s src/cli/rop2/Kernel.Mod
mcompiler.Compile /s src/common/Root.Mod
mcompiler.Compile /s src/common/Reals.Mod
mcompiler.Compile /s src/common/POLPO.Files.Mod
mcompiler.Compile /s src/cli/rop2/Modules0.Mod

# console modules
mcompiler.Compile /s src/cli/out.Mod
mcompiler.Compile /s src/common/Modules.Mod
mcompiler.Compile /s src/common/Objects0.Mod
mcompiler.Compile /s src/cli/objects.Mod
mcompiler.Compile /s src/cli/strings.Mod
mcompiler.Compile /s src/common/regex.Mod
mcompiler.Compile /s src/common/Utf8.Mod
mcompiler.Compile /s src/common/Texts0.Mod
mcompiler.Compile /s src/common/RXA.Mod
mcompiler.Compile /s src/common/Oberon0.Mod
mcompiler.Compile /s src/cli/texts.Mod
mcompiler.Compile /s src/cli/oberon.Mod
mcompiler.Compile /s src/cli/in.Mod
mcompiler.Compile /s src/cli/termios.Mod
mcompiler.Compile /s src/cli/rop2/system.Mod
mcompiler.Compile /s src/common/POLPO.FATFiles.Mod
mcompiler.Compile /s src/cli/shell.Mod
mcompiler.Compile /s src/cli/loksh.Mod
mcompiler.Compile /s src/cli/cat.Mod
mcompiler.Compile /s src/cli/xxs.Mod
mcompiler.Compile /s src/lib/toml/TOML.Mod
mcompiler.Compile /s src/lib/versions/Versions.Mod
mcompiler.Compile /s src/cli/portia.Mod
mcompiler.Compile /s src/lib/sockets/Sockets.Mod
mcompiler.Compile /s src/cli/net.Mod

# native MIPS compiler and boot linker, so the MIPS system can rebuild itself
mcompiler.Compile /s src/cli/rop2/ROPM.Mod
mcompiler.Compile /s src/cli/rop2/ROPS.Mod
mcompiler.Compile /s src/cli/rop2/ROPT.Mod
mcompiler.Compile /s src/cli/rop2/ROPB.Mod
mcompiler.Compile /s src/cli/rop2/ROPP.Mod
mcompiler.Compile /s src/cli/mips/MOPL.Mod
mcompiler.Compile /s src/cli/mips/MOPC.Mod
mcompiler.Compile /s src/cli/mips/MOPV.Mod
mcompiler.Compile /s src/cli/rop2/rcompiler.Mod
mcompiler.Compile /s src/cli/mips/mcompiler.Mod
mcompiler.Compile /s src/cli/rop2/rlinker.Mod
mcompiler.Compile /s src/cli/mips/compiler.Mod
mcompiler.Compile /s src/cli/mips/linker.Mod

# desktop (X11 Display/Input)
mcompiler.Compile /s src/desktop/POLPO.Objects.Mod
mcompiler.Compile /s src/desktop/POLPO.FileDir.Mod
mcompiler.Compile /s /x src/desktop/POLPO.Display.Mod
mcompiler.Compile /s src/desktop/POLPO.Input.Mod
mcompiler.Compile /s src/desktop/POLPO.Fonts.Mod
mcompiler.Compile /s src/desktop/POLPO.Texts.Mod
mcompiler.Compile /s src/desktop/Viewers.Mod
mcompiler.Compile /s src/desktop/Oberon.Mod
mcompiler.Compile /s src/desktop/POLPO.In.Mod
mcompiler.Compile /s src/desktop/MenuViewers.Mod
mcompiler.Compile /s src/desktop/POLPO.TextFrames.Mod
mcompiler.Compile /s src/desktop/rop2/POLPO.System.Mod
mcompiler.Compile /s src/desktop/POLPO.Bitmaps.Mod
mcompiler.Compile /s src/desktop/Out.Mod
mcompiler.Compile /s src/desktop/Pictures.Mod
mcompiler.Compile /s src/desktop/POLPO.Centronics.Mod
mcompiler.Compile /s src/desktop/POLPO.V24.Mod
mcompiler.Compile /s src/desktop/Printer.Mod

# desktop clients
mcompiler.Compile /s src/desktop/Edit.Mod
mcompiler.Compile /s src/desktop/Styles.Mod
mcompiler.Compile /s src/desktop/ScriptFrames.Mod
mcompiler.Compile /s src/desktop/Script.Mod
mcompiler.Compile /s src/desktop/Dates.Mod
mcompiler.Compile /s src/desktop/Strings.Mod
mcompiler.Compile /s src/desktop/POLPO.Compiler.Mod
mcompiler.Compile /s src/desktop/POLPO.FileTools.Mod
mcompiler.Compile /s src/desktop/rop2/RCompiler.Mod
mcompiler.Compile /s src/desktop/mips/M2Decoder.Mod

# static MIPS executable: modules in import order
rlinker.Link /m bin/mips/loksh.new Linux0 Kernel Root Modules0 loksh
