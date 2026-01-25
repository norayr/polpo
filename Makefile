

all:
		# common files for ui and cli oberon
		./wishup nXCompiler.Compile src/polpo/POLPO.X86.Linux0.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.X86.Kernel.Mod
		./wishup nXCompiler.Compile src/ARM.Reals.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.X86.Files.Mod

		# for cli
		./wishup nXCompiler.Compile src/cli/nOut.Mod
		./wishup nXCompiler.Compile src/cli/nModules.Mod
		./wishup nXCompiler.Compile src/cli/ooc2Strings.Mod
		./wishup nXCompiler.Compile src/cli/nTexts.Mod
		./wishup nXCompiler.Compile src/cli/nOberon.Mod
		./wishup nXCompiler.Compile src/cli/Shell.Mod

		# cli compiler
		./wishup nXCompiler.Compile src/cli/nOPM.Mod
		./wishup nXCompiler.Compile src/cli/nOPS.Mod
		./wishup nXCompiler.Compile src/cli/nOPT.Mod
		./wishup nXCompiler.Compile src/cli/nOPB.Mod
		./wishup nXCompiler.Compile src/cli/nOPA.Mod
		./wishup nXCompiler.Compile src/cli/nOPP.Mod
		./wishup nXCompiler.Compile src/cli/nOPO.Mod
		./wishup nXCompiler.Compile src/cli/nOPL.Mod
		./wishup nXCompiler.Compile src/cli/nOPC.Mod
		./wishup nXCompiler.Compile src/cli/nOPV.Mod
		./wishup nXCompiler.Compile src/cli/nXCompiler.Mod
		./wishup nXCompiler.Compile src/cli/nXBootLinker.Mod

		./wishup nXBootLinker.Link wishup2 /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/nOut x86/nModules "~"

		# ui oberon
		./wishup nXCompiler.Compile src/polpo/POLPO.X86.Modules.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.FileDir.Mod
		./wishup nXCompiler.Compile /x src/polpo/POLPO.Objects.Mod
		./wishup nXCompiler.Compile /x src/polpo/POLPO.Display.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Input.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Fonts.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Texts.Mod
		./wishup nXCompiler.Compile src/Viewers.Mod
		./wishup nXCompiler.Compile src/Oberon.Mod
		./wishup nXCompiler.Compile src/MenuViewers.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.TextFrames.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.System.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Bitmaps.Mod
		./wishup nXCompiler.Compile src/Out.Mod
		./wishup nXCompiler.Compile src/Pictures.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Centronics.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.V24.Mod
		./wishup nXCompiler.Compile src/Printer.Mod
		./wishup nXCompiler.Compile src/Edit.Mod
		./wishup nXCompiler.Compile src/Styles.Mod
		./wishup nXCompiler.Compile src/ScriptFrames.Mod
		./wishup nXCompiler.Compile src/Script.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.Compiler.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.FileTools.Mod
#
#		# ui compiler
		./wishup nXCompiler.Compile src/polpo/POLPO.OPM.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPS.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPT.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPB.Mod
		./wishup nXCompiler.Compile src/OPA.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPP.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPO.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPL.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPC.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.OPV.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.XCompiler.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.XBootLinker.Mod
		./wishup nXCompiler.Compile src/Dates.Mod
		./wishup nXCompiler.Compile src/Strings.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.XDecoder.Mod
		./wishup nXCompiler.Compile src/polpo/POLPO.XBrowser.Mod
		./wishup nXBootLinker.Link xoberon /refs /integrate 8049000H x86/Linux0 x86/Kernel x86/Files x86/Modules "~"
