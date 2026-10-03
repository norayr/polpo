# The ARM polpo system (console and desktop) in obj/arm/, and bin/arm/loksh.
# Uses acompiler/alinker: the cross tools on x86 (after tools/arm-cross.Tool),
# the native ARM compiler on ARM.
#   on x86:  make arm          on ARM:  make arm-native
# The executable is linked to bin/arm/loksh.new; make moves it to bin/arm/loksh.

# ARM runtime (objects in obj/arm/)
acompiler.Compile /s src/cli/arm/Linux0.Mod
acompiler.Compile /s /x src/cli/arm/Kernel.Mod
acompiler.Compile /s src/common/Root.Mod
acompiler.Compile /s src/common/Reals.Mod
acompiler.Compile /s src/common/POLPO.Files.Mod
acompiler.Compile /s src/cli/arm/Modules0.Mod

# ARM console modules
acompiler.Compile /s src/cli/out.Mod
acompiler.Compile /s src/common/Modules.Mod
acompiler.Compile /s src/common/Objects0.Mod
acompiler.Compile /s src/cli/objects.Mod
acompiler.Compile /s src/cli/strings.Mod
acompiler.Compile /s src/common/regex.Mod
acompiler.Compile /s src/common/Utf8.Mod
acompiler.Compile /s src/common/Texts0.Mod
acompiler.Compile /s src/common/RXA.Mod
acompiler.Compile /s src/common/Oberon0.Mod
acompiler.Compile /s src/cli/texts.Mod
acompiler.Compile /s src/cli/oberon.Mod
acompiler.Compile /s src/cli/in.Mod
acompiler.Compile /s src/cli/termios.Mod
acompiler.Compile /s src/cli/arm/system.Mod
acompiler.Compile /s src/common/POLPO.FATFiles.Mod
acompiler.Compile /s src/cli/shell.Mod
acompiler.Compile /s src/cli/loksh.Mod
acompiler.Compile /s src/cli/cat.Mod
acompiler.Compile /s src/cli/xxs.Mod
acompiler.Compile /s src/lib/toml/TOML.Mod
acompiler.Compile /s src/lib/versions/Versions.Mod
acompiler.Compile /s src/cli/portia.Mod
acompiler.Compile /s src/lib/sockets/Sockets.Mod
acompiler.Compile /s src/lib/dns/DNS.Mod
acompiler.Compile /s src/lib/ooc/oocAscii.Mod
acompiler.Compile /s src/lib/ooc/oocCharClass.Mod
acompiler.Compile /s src/lib/ooc/oocConvTypes.Mod
acompiler.Compile /s src/lib/ooc/oocStrings.Mod
acompiler.Compile /s src/lib/ooc/oocIntConv.Mod
acompiler.Compile /s src/lib/ooc/oocIntStr.Mod
acompiler.Compile /s src/lib/strutils/strTypes.Mod
acompiler.Compile /s src/lib/strutils/strUtils.Mod
acompiler.Compile /s src/lib/base64/Base64.Mod
acompiler.Compile /s src/lib/internet/Internet.Mod
acompiler.Compile /s src/lib/http/hexIntStr.Mod
acompiler.Compile /s src/lib/http/http.Mod
acompiler.Compile /s src/lib/tls/TLSBytes.Mod
acompiler.Compile /s src/lib/tls/TLSSHA256.Mod
acompiler.Compile /s src/lib/tls/TLSHKDF.Mod
acompiler.Compile /s src/lib/tls/TLSX25519.Mod
acompiler.Compile /s src/lib/tls/TLSAESGCM.Mod
acompiler.Compile /s src/lib/tls/TLS13Records.Mod
acompiler.Compile /s src/lib/tls/TLS13Handshake.Mod
acompiler.Compile /s src/lib/tls/TLS13Keys.Mod
acompiler.Compile /s src/lib/tls/TLS13Finished.Mod
acompiler.Compile /s src/lib/tls/TLSBase64.Mod
acompiler.Compile /s src/lib/tls/TLSPEM.Mod
acompiler.Compile /s src/lib/tls/TLS13Certs.Mod
acompiler.Compile /s src/lib/tls/TLSASN1.Mod
acompiler.Compile /s src/lib/tls/TLSX509.Mod
acompiler.Compile /s src/lib/tls/TLSSHA512.Mod
acompiler.Compile /s src/lib/tls/TLSNum.Mod
acompiler.Compile /s src/lib/tls/TLSECDSA.Mod
acompiler.Compile /s src/lib/tls/TLSRSA.Mod
acompiler.Compile /s src/lib/tls/TLSX509Validity.Mod
acompiler.Compile /s src/lib/tls/TLSX509Names.Mod
acompiler.Compile /s src/lib/tls/TLSX509Ext.Mod
acompiler.Compile /s src/lib/tls/TLSSig.Mod
acompiler.Compile /s src/lib/tls/TLSNameConstraints.Mod
acompiler.Compile /s src/lib/tls/TLSX509Chain.Mod
acompiler.Compile /s src/lib/tls/TLS13EncHandshake.Mod
acompiler.Compile /s src/lib/tls/TLS13ClientFinished.Mod
acompiler.Compile /s src/lib/tls/TLS13Application.Mod
acompiler.Compile /s src/lib/tls/TLS13Random.Mod
acompiler.Compile /s src/lib/tls/TLSCABundle.Mod
acompiler.Compile /s src/lib/tls/TLSNow.Mod
acompiler.Compile /s src/lib/tls/TLS13Live.Mod
acompiler.Compile /s src/lib/tls/httpsPure.Mod
acompiler.Compile /s src/cli/fetch.Mod
acompiler.Compile /s src/cli/net.Mod

# native ARM compiler and boot linker, so the ARM system can rebuild itself
acompiler.Compile /s src/cli/arm/OBM.Mod
acompiler.Compile /s src/cli/arm/OBS.Mod
acompiler.Compile /s src/cli/arm/OBT.Mod
acompiler.Compile /s src/cli/arm/OBC.Mod
acompiler.Compile /s src/cli/arm/OBE.Mod
acompiler.Compile /s src/cli/arm/OBH.Mod
acompiler.Compile /s src/cli/arm/OBA.Mod
acompiler.Compile /s src/cli/arm/OBP.Mod
acompiler.Compile /s src/cli/arm/acompiler.Mod
acompiler.Compile /s src/cli/arm/alinker.Mod
acompiler.Compile /s src/cli/arm/compiler.Mod
acompiler.Compile /s src/cli/arm/linker.Mod

# ui oberon (X11 Display/Input; for xterm sixel see the Makefile target arm-sixel)
acompiler.Compile /s src/desktop/POLPO.Objects.Mod
acompiler.Compile /s src/desktop/POLPO.FileDir.Mod
acompiler.Compile /s /x src/desktop/POLPO.Display.Mod
acompiler.Compile /s src/desktop/POLPO.Input.Mod
acompiler.Compile /s src/desktop/POLPO.Fonts.Mod
acompiler.Compile /s src/desktop/POLPO.Texts.Mod
acompiler.Compile /s src/desktop/Viewers.Mod
acompiler.Compile /s src/desktop/Oberon.Mod
acompiler.Compile /s src/desktop/POLPO.In.Mod
acompiler.Compile /s src/desktop/MenuViewers.Mod
acompiler.Compile /s src/desktop/POLPO.TextFrames.Mod
acompiler.Compile /s src/desktop/POLPO.System.Mod
acompiler.Compile /s src/desktop/POLPO.Bitmaps.Mod
acompiler.Compile /s src/desktop/Out.Mod
acompiler.Compile /s src/desktop/Pictures.Mod
acompiler.Compile /s src/desktop/POLPO.Centronics.Mod
acompiler.Compile /s src/desktop/POLPO.V24.Mod
acompiler.Compile /s src/desktop/Printer.Mod

# ui clients
acompiler.Compile /s src/desktop/Edit.Mod
acompiler.Compile /s src/desktop/Styles.Mod
acompiler.Compile /s src/desktop/ScriptFrames.Mod
acompiler.Compile /s src/desktop/Script.Mod
acompiler.Compile /s src/desktop/Dates.Mod
acompiler.Compile /s src/desktop/Strings.Mod
acompiler.Compile /s src/desktop/POLPO.Compiler.Mod
acompiler.Compile /s src/desktop/POLPO.FileTools.Mod
acompiler.Compile /s src/desktop/arm/ACompiler.Mod
acompiler.Compile /s src/desktop/arm/ADecoder.Mod
acompiler.Compile /s src/desktop/arm/ABrowser.Mod

# static ARM executable: Linux0 Kernel Modules0 loksh
alinker.Link /q bin/arm/loksh.new loksh
