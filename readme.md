# POLPO
## platform orbiting linux: project oberon

This is an attempt to contunie development of ETH Linux Oberon in some way.

### Goals

* Create minimal set of CLI modules, working compiler, and loader of Obj files - done.
* Create a minimal Oberon OS that runs over Linux - only minimal set of modules. - done.
* Add package manager to add packages over the network.
* Create a ports tree of package recipies.
* Also integrate ARM and other existing compilers.
* Add support for aarch64 and x86_64.
* Build also bootable on X86 machine version of Oberon on Linux
* Build also bootable on some ARM devices version of Oberon on Linux

## How to play

Type `make` and `wishup` shell will load object files from x86 directory and rebuild link itself as static Linux binary.

Look at [compiler options](compiler_options.md) or do

```
./wishup nXCompiler.Help
```

Compile hello world example:

```
./wishup nXCompiler.Compile hello.Mod
```

Run:

```
./wishup hello.world
```

### X11 Oberon

Currently whole Oberon system gets build with minimal set of modules. So after you built with `make` you will find `xoberon` binary.

```
./xoberon
```

That is a statically linked x86 executable that will start loading modules and form whole Oberon operating system.

Now it can draw itself in an X11 window.
But wait, it can also draw itself in other ways! Just replace the Display module.

### xterm Oberon

![](polpo.png)

Oberon can draw itself not only in X11, but in a bitmap graphics capable Unix terminal, such as xterm.
For that you need to compile other version of Display and Input modules.

```
make sixel
```

This will replace compiled Display.Obj and Input.Obj with the versions that work in xterm.

After that we suggest to use supplied `run.vt.sh` script that will open a conveniently big xterm and load oberon that would draw itself in it.

Same xoberon binary (no need for recompilation) will load modules, including Display and Input(but those are different Display and Input now), and the OS will now work in the terminal.

Since Oberon now draws itself in the VT320 capable Unix terminal, you can also run it via ssh.

To use X11 mode again, type:

```
make x11
```

#### Other terminals

In theory, mlterm should also work, at least they claim they support sixel mode.

And we don't know how xterm of your OS is compiled. We tested with xterm on Gentoo that is compiled with 'sixel' USE flag. Our friend confirmed that it worked on their Arch. Our other friend confirmed it didn't work on their Debian.

### ARM

polpo also runs on 32-bit ARM Linux. The ARM compiler is the ETH/OLR ARM
compiler (Oberon-1). Object files are in `obj/arm/`, the static executable is
`bin/arm/loksh`.

```
make arm            # on x86: cross compile the ARM system
make arm-native     # on ARM: rebuild it with the ARM compiler (on x86: under qemu-arm)
make arm-run        # start the ARM desktop (System.Init); on x86 through qemu-arm
make arm-shell      # ARM console
```

`make arm` runs `tools/arm-cross.Tool` (the x86-hosted cross tools `acompiler`
and `alinker`) and then `tools/arm.Tool` (the ARM system). `make arm-native`
runs only `tools/arm.Tool`, with the ARM compiler. Both link
`bin/arm/loksh.new` and move it to `bin/arm/loksh`.

Directly, from the polpo directory (prefix `qemu-arm` on x86):

```
bin/arm/loksh cat.Cat texts/UserGuide.Text
bin/arm/loksh compiler.Compile hello.Mod     # native ARM compiler
bin/arm/loksh hello.world
bin/arm/loksh System.Init                    # the Oberon desktop
```

On ARM, `compiler.Compile` and `linker.Link` are the ARM compiler and boot
linker. `make arm-sixel` and `make arm-x11` switch the ARM Display and Input
modules, like `make sixel` and `make x11` for x86.

### RISC-V

polpo runs on 32-bit RISC-V (RV32) Linux too. The compiler is OLR's OP2-based
ROP2 compiler (shared front end `ROPM`..`ROPP`, RISC-V back end `VOPL`..`VOPV`).
Object files are in `obj/riscv/`, the static executable is `bin/riscv/loksh`.

```
make riscv          # on x86: cross compile the RISC-V system
make riscv-native   # rebuild it with the RISC-V compiler (on x86: under qemu-riscv32)
make riscv-run      # start the RISC-V desktop (System.Init); on x86 through qemu-riscv32
make riscv-shell    # RISC-V console
```

`make riscv` runs `tools/riscv-cross.Tool` (the x86-hosted `rvcompiler` and
`rvlinker`) and then `tools/riscv.Tool`. On RISC-V, `compiler.Compile` and
`linker.Link` are the RISC-V compiler and boot linker. The runtime uses the
Linux RV32 system calls (64-bit time, statx).

### Layout

* `bin/<arch>/loksh` - static executables; run them from the polpo directory
* `obj/<arch>/` - object files loaded by `bin/<arch>/loksh`
* `src/cli` - console modules shared by all architectures; `src/cli/<arch>` - runtime
  (Linux0, Kernel, Modules0), compiler and linker of that architecture
* `src/common` - modules shared by console and desktop (Files, Texts0, Oberon0, ...)
* `src/desktop` - desktop modules shared by all architectures; `src/desktop/<arch>` -
  architecture dependent desktop modules (XCompiler, ACompiler, RCompiler, decoders, browsers, System on RISC-V)
* `tools/` - `.Tool` texts, including the build recipes `build.Tool`, `arm-cross.Tool`, `arm.Tool`, `riscv-cross.Tool` and `riscv.Tool`
* `share/` - data files (`Default.Pal`, `OPA.Data`, `System.Text`, ...)
* `fonts/`, `texts/` - fonts and documentation texts; `Oberon.Text` is the configuration

`Files.Old` looks for a plain file name in the current directory, then in `share/`
and `tools/`, so `Edit.Open System.Tool` and the like work from the polpo directory.

---



Wait for us for updates, or join #oberon on irc.libera.chat and help with development!
At least, we want to add ARM and other compilers, integrate vipak package manager, and run the os also natively. We also want to have 64-bit compiler backends.

Till.
