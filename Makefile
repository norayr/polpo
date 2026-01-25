

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

