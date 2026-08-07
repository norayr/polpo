# common files for ui and cli oberon
nXCompiler.Compile src/polpo/POLPO.X86.Linux0.Mod
nXCompiler.Compile src/polpo/POLPO.X86.Kernel.Mod
nXCompiler.Compile src/ARM.Reals.Mod
nXCompiler.Compile src/polpo/POLPO.X86.Files.Mod

# for cli
nXCompiler.Compile src/cli/nOut.Mod
nXCompiler.Compile src/cli/nModules.Mod
nXCompiler.Compile src/cli/ooc2Strings.Mod
nXCompiler.Compile src/cli/nTexts.Mod
nXCompiler.Compile src/cli/nOberon.Mod
nXCompiler.Compile src/cli/nIn.Mod
nXCompiler.Compile src/cli/Shell.Mod
nXCompiler.Compile src/polpo/POLPO.FATFiles.Mod

# cli compiler
nXCompiler.Compile src/cli/nOPM.Mod
nXCompiler.Compile src/cli/nOPS.Mod
nXCompiler.Compile src/cli/nOPT.Mod
nXCompiler.Compile src/cli/nOPB.Mod
nXCompiler.Compile src/cli/nOPA.Mod
nXCompiler.Compile src/cli/nOPP.Mod
nXCompiler.Compile src/cli/nOPO.Mod
nXCompiler.Compile src/cli/nOPL.Mod
nXCompiler.Compile src/cli/nOPC.Mod
nXCompiler.Compile src/cli/nOPV.Mod
nXCompiler.Compile src/cli/nXCompiler.Mod
nXCompiler.Compile src/cli/nXBootLinker.Mod

nXBootLinker.Link wishup2 /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/nOut x86/nModules ~

# ui oberon
nXCompiler.Compile src/polpo/POLPO.X86.Modules.Mod
nXCompiler.Compile src/polpo/POLPO.FileDir.Mod
nXCompiler.Compile /x src/polpo/POLPO.Objects.Mod
nXCompiler.Compile /x src/polpo/POLPO.Display.Mod
nXCompiler.Compile src/polpo/POLPO.Input.Mod
nXCompiler.Compile src/polpo/POLPO.Fonts.Mod
nXCompiler.Compile src/polpo/POLPO.Texts.Mod
nXCompiler.Compile src/Viewers.Mod
nXCompiler.Compile src/Oberon.Mod
nXCompiler.Compile src/polpo/POLPO.In.Mod
nXCompiler.Compile src/MenuViewers.Mod
nXCompiler.Compile src/polpo/POLPO.TextFrames.Mod
nXCompiler.Compile src/polpo/POLPO.System.Mod
nXCompiler.Compile src/polpo/POLPO.Bitmaps.Mod
nXCompiler.Compile src/Out.Mod
nXCompiler.Compile src/Pictures.Mod
nXCompiler.Compile src/polpo/POLPO.Centronics.Mod
nXCompiler.Compile src/polpo/POLPO.V24.Mod
nXCompiler.Compile src/Printer.Mod
nXCompiler.Compile src/Edit.Mod
nXCompiler.Compile src/Styles.Mod
nXCompiler.Compile src/ScriptFrames.Mod
nXCompiler.Compile src/Script.Mod
nXCompiler.Compile src/polpo/POLPO.Compiler.Mod
nXCompiler.Compile src/polpo/POLPO.FileTools.Mod

# ui compiler
nXCompiler.Compile src/polpo/POLPO.OPM.Mod
nXCompiler.Compile src/polpo/POLPO.OPS.Mod
nXCompiler.Compile src/polpo/POLPO.OPT.Mod
nXCompiler.Compile src/polpo/POLPO.OPB.Mod
nXCompiler.Compile src/OPA.Mod
nXCompiler.Compile src/polpo/POLPO.OPP.Mod
nXCompiler.Compile src/polpo/POLPO.OPO.Mod
nXCompiler.Compile src/polpo/POLPO.OPL.Mod
nXCompiler.Compile src/polpo/POLPO.OPC.Mod
nXCompiler.Compile src/polpo/POLPO.OPV.Mod
nXCompiler.Compile src/polpo/POLPO.XCompiler.Mod
nXCompiler.Compile src/polpo/POLPO.XBootLinker.Mod
nXCompiler.Compile src/Dates.Mod
nXCompiler.Compile src/Strings.Mod
nXCompiler.Compile src/polpo/POLPO.XDecoder.Mod
nXCompiler.Compile src/polpo/POLPO.XBrowser.Mod

nXBootLinker.Link xoberon /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/Modules ~
