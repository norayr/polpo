# The ARMv7 polpo system (console and desktop, OP2 compiler) in obj/armv7/, and bin/armv7/loksh.
# For older ARM processors see tools/arm.Tool (Oberon-1 compiler, obj/arm/).
# Uses a7compiler/rlinker: the cross tools on x86 (after tools/rop2-cross.Tool),
# the native ARMv7 compiler on ARMv7 (make armv7-native, under qemu-arm elsewhere).
# The executable is linked to bin/armv7/loksh.new; make moves it to bin/armv7/loksh.

# ARMv7 runtime
a7compiler.Compile /s src/cli/armv7/Linux0.Mod
a7compiler.Compile /s src/cli/rop2/Kernel.Mod
a7compiler.Compile /s src/common/Root.Mod
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
a7compiler.Compile /s src/common/Oberon0.Mod
a7compiler.Compile /s src/cli/texts.Mod
a7compiler.Compile /s src/cli/oberon.Mod
a7compiler.Compile /s src/cli/in.Mod
a7compiler.Compile /s src/cli/termios.Mod
a7compiler.Compile /s src/cli/rop2/system.Mod
a7compiler.Compile /s src/common/POLPO.FATFiles.Mod
a7compiler.Compile /s src/cli/shell.Mod
a7compiler.Compile /s src/cli/loksh.Mod
a7compiler.Compile /s src/cli/cat.Mod
a7compiler.Compile /s src/cli/xxs.Mod
a7compiler.Compile /s src/lib/toml/TOML.Mod
a7compiler.Compile /s src/lib/versions/Versions.Mod
a7compiler.Compile /s src/cli/portia.Mod
a7compiler.Compile /s src/lib/sockets/Sockets.Mod
a7compiler.Compile /s src/lib/dns/DNS.Mod
a7compiler.Compile /s src/lib/ooc/oocAscii.Mod
a7compiler.Compile /s src/lib/ooc/oocCharClass.Mod
a7compiler.Compile /s src/lib/ooc/oocConvTypes.Mod
a7compiler.Compile /s src/lib/ooc/oocStrings.Mod
a7compiler.Compile /s src/lib/ooc/oocIntConv.Mod
a7compiler.Compile /s src/lib/ooc/oocIntStr.Mod
a7compiler.Compile /s src/lib/strutils/strTypes.Mod
a7compiler.Compile /s src/lib/strutils/strUtils.Mod
a7compiler.Compile /s src/lib/base64/Base64.Mod
a7compiler.Compile /s src/lib/internet/Internet.Mod
a7compiler.Compile /s src/lib/http/hexIntStr.Mod
a7compiler.Compile /s src/lib/http/http.Mod
a7compiler.Compile /s src/lib/tls/TLSBytes.Mod
a7compiler.Compile /s src/lib/tls/TLSSHA256.Mod
a7compiler.Compile /s src/lib/tls/TLSHKDF.Mod
a7compiler.Compile /s src/lib/tls/TLSX25519.Mod
a7compiler.Compile /s src/lib/tls/TLSAESGCM.Mod
a7compiler.Compile /s src/lib/tls/TLS13Records.Mod
a7compiler.Compile /s src/lib/tls/TLS13Handshake.Mod
a7compiler.Compile /s src/lib/tls/TLS13Keys.Mod
a7compiler.Compile /s src/lib/tls/TLS13Finished.Mod
a7compiler.Compile /s src/lib/tls/TLSBase64.Mod
a7compiler.Compile /s src/lib/tls/TLSPEM.Mod
a7compiler.Compile /s src/lib/tls/TLS13Certs.Mod
a7compiler.Compile /s src/lib/tls/TLSASN1.Mod
a7compiler.Compile /s src/lib/tls/TLSX509.Mod
a7compiler.Compile /s src/lib/tls/TLSBigInt.Mod
a7compiler.Compile /s src/lib/tls/TLSRSAVerify.Mod
a7compiler.Compile /s src/lib/tls/TLSX509Validity.Mod
a7compiler.Compile /s src/lib/tls/TLSX509Trust.Mod
a7compiler.Compile /s src/lib/tls/TLSX509Chain.Mod
a7compiler.Compile /s src/lib/tls/TLSX509Names.Mod
a7compiler.Compile /s src/lib/tls/TLS13EncHandshake.Mod
a7compiler.Compile /s src/lib/tls/TLS13ClientFinished.Mod
a7compiler.Compile /s src/lib/tls/TLS13Application.Mod
a7compiler.Compile /s src/lib/tls/TLS13Random.Mod
a7compiler.Compile /s src/lib/tls/TLSCABundle.Mod
a7compiler.Compile /s src/lib/tls/TLSNow.Mod
a7compiler.Compile /s src/lib/tls/TLS13Live.Mod
a7compiler.Compile /s src/lib/tls/httpsPure.Mod
a7compiler.Compile /s src/cli/fetch.Mod
a7compiler.Compile /s src/cli/net.Mod

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
rlinker.Link /a bin/armv7/loksh.new Linux0 Kernel Root Modules0 loksh
