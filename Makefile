
LOKSH = bin/x86/loksh

fast:
		$(LOKSH) < tools/build.Tool

sixel:
		$(LOKSH) compiler.Compile /x src/desktop/POLPO.SXL.Display.Mod
		$(LOKSH) compiler.Compile /s src/desktop/POLPO.SXL.Input.Mod

x11:
		$(LOKSH) compiler.Compile /x src/desktop/POLPO.Display.Mod
		$(LOKSH) compiler.Compile /s src/desktop/POLPO.Input.Mod

.PHONY: fast sixel x11
