

fast:
		./loksh < build.Tool && cp loksh2 loksh


slow:
		# common files for ui and cli oberon
		./loksh nXCompiler.Compile src/polpo/POLPO.X86.Linux0.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.X86.Kernel.Mod
		./loksh nXCompiler.Compile src/ARM.Reals.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.X86.Files.Mod

		# for cli
		./loksh nXCompiler.Compile src/cli/nOut.Mod
		./loksh nXCompiler.Compile src/cli/nModules.Mod
		./loksh nXCompiler.Compile src/cli/ooc2Strings.Mod
		./loksh nXCompiler.Compile src/cli/nTexts.Mod
		./loksh nXCompiler.Compile src/cli/nOberon.Mod
		./loksh nXCompiler.Compile src/cli/nIn.Mod
		./loksh nXCompiler.Compile src/cli/nTermios.Mod
		./loksh nXCompiler.Compile src/cli/nShell.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.FATFiles.Mod

		# cli compiler
		./loksh nXCompiler.Compile src/cli/nOPM.Mod
		./loksh nXCompiler.Compile src/cli/nOPS.Mod
		./loksh nXCompiler.Compile src/cli/nOPT.Mod
		./loksh nXCompiler.Compile src/cli/nOPB.Mod
		./loksh nXCompiler.Compile src/cli/nOPA.Mod
		./loksh nXCompiler.Compile src/cli/nOPP.Mod
		./loksh nXCompiler.Compile src/cli/nOPO.Mod
		./loksh nXCompiler.Compile src/cli/nOPL.Mod
		./loksh nXCompiler.Compile src/cli/nOPC.Mod
		./loksh nXCompiler.Compile src/cli/nOPV.Mod
		./loksh nXCompiler.Compile src/cli/nXCompiler.Mod
		./loksh nXCompiler.Compile src/cli/nXBootLinker.Mod

		./loksh nXBootLinker.Link loksh2 /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/nOut x86/nModules "~"
		cp loksh2 loksh

		# ui oberon
		./loksh nXCompiler.Compile src/polpo/POLPO.X86.Modules.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.FileDir.Mod
		./loksh nXCompiler.Compile /x src/polpo/POLPO.Objects.Mod
		./loksh nXCompiler.Compile /x src/polpo/POLPO.Display.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Input.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Fonts.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Texts.Mod
		./loksh nXCompiler.Compile src/Viewers.Mod
		./loksh nXCompiler.Compile src/Oberon.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.In.Mod
		./loksh nXCompiler.Compile src/MenuViewers.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.TextFrames.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.System.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Bitmaps.Mod
		./loksh nXCompiler.Compile src/Out.Mod
		./loksh nXCompiler.Compile src/Pictures.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Centronics.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.V24.Mod
		./loksh nXCompiler.Compile src/Printer.Mod
		./loksh nXCompiler.Compile src/Edit.Mod
		./loksh nXCompiler.Compile src/Styles.Mod
		./loksh nXCompiler.Compile src/ScriptFrames.Mod
		./loksh nXCompiler.Compile src/Script.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Compiler.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.FileTools.Mod
#
#		# ui compiler
		./loksh nXCompiler.Compile src/polpo/POLPO.OPM.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPS.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPT.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPB.Mod
		./loksh nXCompiler.Compile src/OPA.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPP.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPO.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPL.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPC.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.OPV.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.XCompiler.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.XBootLinker.Mod
		./loksh nXCompiler.Compile src/Dates.Mod
		./loksh nXCompiler.Compile src/Strings.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.XDecoder.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.XBrowser.Mod
		./loksh nXBootLinker.Link xoberon /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/Modules "~"



sixel:
		./loksh nXCompiler.Compile /x src/polpo/POLPO.SXL.Display.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.SXL.Input.Mod

x11:
		./loksh nXCompiler.Compile /x src/polpo/POLPO.Display.Mod
		./loksh nXCompiler.Compile src/polpo/POLPO.Input.Mod


