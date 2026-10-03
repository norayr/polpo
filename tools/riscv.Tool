# The RISC-V (RV32) polpo system (console and desktop) in obj/riscv/, and bin/riscv/loksh.
# Uses rvcompiler/rlinker: the cross tools on x86 (after tools/rop2-cross.Tool),
# the native RISC-V compiler on RISC-V (make riscv-native, under qemu-riscv32 elsewhere).
# The executable is linked to bin/riscv/loksh.new; make moves it to bin/riscv/loksh.

# RISC-V runtime
rvcompiler.Compile /s src/cli/riscv/Linux0.Mod
rvcompiler.Compile /s src/cli/rop2/Kernel.Mod
rvcompiler.Compile /s src/common/Root.Mod
rvcompiler.Compile /s src/common/Reals.Mod
rvcompiler.Compile /s src/common/POLPO.Files.Mod
rvcompiler.Compile /s src/cli/rop2/Modules0.Mod

# console modules
rvcompiler.Compile /s src/cli/out.Mod
rvcompiler.Compile /s src/common/Modules.Mod
rvcompiler.Compile /s src/common/Objects0.Mod
rvcompiler.Compile /s src/cli/objects.Mod
rvcompiler.Compile /s src/cli/strings.Mod
rvcompiler.Compile /s src/common/regex.Mod
rvcompiler.Compile /s src/common/Utf8.Mod
rvcompiler.Compile /s src/common/Texts0.Mod
rvcompiler.Compile /s src/common/RXA.Mod
rvcompiler.Compile /s src/common/Oberon0.Mod
rvcompiler.Compile /s src/cli/texts.Mod
rvcompiler.Compile /s src/cli/oberon.Mod
rvcompiler.Compile /s src/cli/in.Mod
rvcompiler.Compile /s src/cli/termios.Mod
rvcompiler.Compile /s src/cli/rop2/system.Mod
rvcompiler.Compile /s src/common/POLPO.FATFiles.Mod
rvcompiler.Compile /s src/cli/shell.Mod
rvcompiler.Compile /s src/cli/loksh.Mod
rvcompiler.Compile /s src/cli/cat.Mod
rvcompiler.Compile /s src/cli/xxs.Mod
rvcompiler.Compile /s src/lib/toml/TOML.Mod
rvcompiler.Compile /s src/lib/versions/Versions.Mod
rvcompiler.Compile /s src/cli/portia.Mod
rvcompiler.Compile /s src/lib/sockets/Sockets.Mod
rvcompiler.Compile /s src/lib/dns/DNS.Mod
rvcompiler.Compile /s src/lib/ooc/oocAscii.Mod
rvcompiler.Compile /s src/lib/ooc/oocCharClass.Mod
rvcompiler.Compile /s src/lib/ooc/oocConvTypes.Mod
rvcompiler.Compile /s src/lib/ooc/oocStrings.Mod
rvcompiler.Compile /s src/lib/ooc/oocIntConv.Mod
rvcompiler.Compile /s src/lib/ooc/oocIntStr.Mod
rvcompiler.Compile /s src/lib/strutils/strTypes.Mod
rvcompiler.Compile /s src/lib/strutils/strUtils.Mod
rvcompiler.Compile /s src/lib/base64/Base64.Mod
rvcompiler.Compile /s src/lib/internet/Internet.Mod
rvcompiler.Compile /s src/lib/http/hexIntStr.Mod
rvcompiler.Compile /s src/lib/http/http.Mod
rvcompiler.Compile /s src/lib/tls/TLSBytes.Mod
rvcompiler.Compile /s src/lib/tls/TLSSHA256.Mod
rvcompiler.Compile /s src/lib/tls/TLSHKDF.Mod
rvcompiler.Compile /s src/lib/tls/TLSX25519.Mod
rvcompiler.Compile /s src/lib/tls/TLSAESGCM.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Records.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Handshake.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Keys.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Finished.Mod
rvcompiler.Compile /s src/lib/tls/TLSBase64.Mod
rvcompiler.Compile /s src/lib/tls/TLSPEM.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Certs.Mod
rvcompiler.Compile /s src/lib/tls/TLSASN1.Mod
rvcompiler.Compile /s src/lib/tls/TLSX509.Mod
rvcompiler.Compile /s src/lib/tls/TLSSHA512.Mod
rvcompiler.Compile /s src/lib/tls/TLSNum.Mod
rvcompiler.Compile /s src/lib/tls/TLSECDSA.Mod
rvcompiler.Compile /s src/lib/tls/TLSRSA.Mod
rvcompiler.Compile /s src/lib/tls/TLSX509Validity.Mod
rvcompiler.Compile /s src/lib/tls/TLSX509Names.Mod
rvcompiler.Compile /s src/lib/tls/TLSX509Ext.Mod
rvcompiler.Compile /s src/lib/tls/TLSSig.Mod
rvcompiler.Compile /s src/lib/tls/TLSNameConstraints.Mod
rvcompiler.Compile /s src/lib/tls/TLSX509Chain.Mod
rvcompiler.Compile /s src/lib/tls/TLS13EncHandshake.Mod
rvcompiler.Compile /s src/lib/tls/TLS13ClientFinished.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Application.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Random.Mod
rvcompiler.Compile /s src/lib/tls/TLSCABundle.Mod
rvcompiler.Compile /s src/lib/tls/TLSNow.Mod
rvcompiler.Compile /s src/lib/tls/TLS13Live.Mod
rvcompiler.Compile /s src/lib/tls/httpsPure.Mod
rvcompiler.Compile /s src/cli/fetch.Mod
rvcompiler.Compile /s src/cli/gemini.Mod
rvcompiler.Compile /s src/cli/net.Mod

# native RISC-V compiler and boot linker, so the RISC-V system can rebuild itself
rvcompiler.Compile /s src/cli/rop2/ROPM.Mod
rvcompiler.Compile /s src/cli/rop2/ROPS.Mod
rvcompiler.Compile /s src/cli/rop2/ROPT.Mod
rvcompiler.Compile /s src/cli/rop2/ROPB.Mod
rvcompiler.Compile /s src/cli/rop2/ROPP.Mod
rvcompiler.Compile /s src/cli/riscv/VOPL.Mod
rvcompiler.Compile /s src/cli/riscv/VOPC.Mod
rvcompiler.Compile /s src/cli/riscv/VOPV.Mod
rvcompiler.Compile /s src/cli/rop2/rcompiler.Mod
rvcompiler.Compile /s src/cli/riscv/rvcompiler.Mod
rvcompiler.Compile /s src/cli/rop2/rlinker.Mod
rvcompiler.Compile /s src/cli/riscv/compiler.Mod
rvcompiler.Compile /s src/cli/riscv/linker.Mod

# desktop (X11 Display/Input)
rvcompiler.Compile /s src/desktop/POLPO.Objects.Mod
rvcompiler.Compile /s src/desktop/POLPO.FileDir.Mod
rvcompiler.Compile /s /x src/desktop/POLPO.Display.Mod
rvcompiler.Compile /s src/desktop/POLPO.Input.Mod
rvcompiler.Compile /s src/desktop/POLPO.Fonts.Mod
rvcompiler.Compile /s src/desktop/POLPO.Texts.Mod
rvcompiler.Compile /s src/desktop/Viewers.Mod
rvcompiler.Compile /s src/desktop/Oberon.Mod
rvcompiler.Compile /s src/desktop/POLPO.In.Mod
rvcompiler.Compile /s src/desktop/MenuViewers.Mod
rvcompiler.Compile /s src/desktop/POLPO.TextFrames.Mod
rvcompiler.Compile /s src/desktop/rop2/POLPO.System.Mod
rvcompiler.Compile /s src/desktop/POLPO.Bitmaps.Mod
rvcompiler.Compile /s src/desktop/Out.Mod
rvcompiler.Compile /s src/desktop/Pictures.Mod
rvcompiler.Compile /s src/desktop/POLPO.Centronics.Mod
rvcompiler.Compile /s src/desktop/POLPO.V24.Mod
rvcompiler.Compile /s src/desktop/Printer.Mod

# desktop clients
rvcompiler.Compile /s src/desktop/Edit.Mod
rvcompiler.Compile /s src/desktop/Styles.Mod
rvcompiler.Compile /s src/desktop/ScriptFrames.Mod
rvcompiler.Compile /s src/desktop/Script.Mod
rvcompiler.Compile /s src/desktop/Dates.Mod
rvcompiler.Compile /s src/desktop/Strings.Mod
rvcompiler.Compile /s src/desktop/POLPO.Compiler.Mod
rvcompiler.Compile /s src/desktop/POLPO.FileTools.Mod
rvcompiler.Compile /s src/desktop/rop2/RCompiler.Mod
rvcompiler.Compile /s src/desktop/riscv/VDecoder.Mod

# static RISC-V executable: modules in import order
rlinker.Link /v bin/riscv/loksh.new Linux0 Kernel Root Modules0 loksh
