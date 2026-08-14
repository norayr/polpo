# common files for ui and cli oberon
compiler.Compile src/polpo/POLPO.X86.Linux0.Mod
compiler.Compile src/polpo/POLPO.X86.Kernel.Mod
compiler.Compile src/ARM.Reals.Mod
compiler.Compile src/polpo/POLPO.Files.Mod

# for cli
compiler.Compile /s src/cli/out.Mod
compiler.Compile /s src/common/Modules0.Mod
compiler.Compile /s src/common/Modules.Mod
compiler.Compile /s src/polpo/POLPO.Objects.Mod
compiler.Compile /s src/cli/strings.Mod
compiler.Compile /s src/common/Texts0.Mod
compiler.Compile /s src/cli/texts.Mod
compiler.Compile /s src/common/Oberon0.Mod
compiler.Compile /s src/cli/oberon.Mod
compiler.Compile /s src/cli/in.Mod
compiler.Compile /s src/cli/termios.Mod
compiler.Compile /s src/cli/system.Mod
compiler.Compile /s src/polpo/POLPO.FATFiles.Mod
compiler.Compile /s src/cli/shell.Mod
compiler.Compile /s src/cli/loksh.Mod
compiler.Compile /s src/cli/cat.Mod

# cli compiler
compiler.Compile /s src/OPM.Mod
compiler.Compile /s src/OPS.Mod
compiler.Compile /s src/OPT.Mod
compiler.Compile /s src/OPB.Mod
compiler.Compile /s src/OPA.Mod
compiler.Compile /s src/OPP.Mod
compiler.Compile /s src/OPO.Mod
compiler.Compile /s src/OPL.Mod
compiler.Compile /s src/OPC.Mod
compiler.Compile /s src/OPV.Mod
compiler.Compile /s src/cli/compiler.Mod
compiler.Compile /s src/cli/linker.Mod
compiler.Compile /s src/cli/browser.Mod

linker.Link loksh2 /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/Modules0 x86/loksh ~

# ui oberon
compiler.Compile src/polpo/POLPO.FileDir.Mod
compiler.Compile /x src/polpo/POLPO.Display.Mod
compiler.Compile src/polpo/POLPO.Input.Mod
compiler.Compile src/polpo/POLPO.Fonts.Mod
compiler.Compile src/polpo/POLPO.Texts.Mod
compiler.Compile src/Viewers.Mod
compiler.Compile src/Oberon.Mod
compiler.Compile src/polpo/POLPO.In.Mod
compiler.Compile src/MenuViewers.Mod
compiler.Compile src/polpo/POLPO.TextFrames.Mod
compiler.Compile src/polpo/POLPO.System.Mod
compiler.Compile src/polpo/POLPO.Bitmaps.Mod
compiler.Compile src/Out.Mod
compiler.Compile src/Pictures.Mod
compiler.Compile src/polpo/POLPO.Centronics.Mod
compiler.Compile src/polpo/POLPO.V24.Mod
compiler.Compile src/Printer.Mod

# ui clients
compiler.Compile src/Edit.Mod
compiler.Compile src/Styles.Mod
compiler.Compile src/ScriptFrames.Mod
compiler.Compile src/Script.Mod
compiler.Compile src/Dates.Mod
compiler.Compile src/Strings.Mod
compiler.Compile src/polpo/POLPO.Compiler.Mod
compiler.Compile src/polpo/POLPO.FileTools.Mod
compiler.Compile src/polpo/POLPO.XCompiler.Mod
compiler.Compile src/polpo/POLPO.XBootLinker.Mod
compiler.Compile src/polpo/POLPO.XDecoder.Mod
compiler.Compile src/polpo/POLPO.XBrowser.Mod
