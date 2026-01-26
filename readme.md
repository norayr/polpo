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

Currently whole Oberon system gets build with minimal set of modules. So after you built with `make` you will find `xoberon` binary.

```
./xoberon
```

That is a statically linked x86 executable that will start loading modules and form whole Oberon operating system.

Wait for us for updates, or join #oberon on irc.libera.chat and help with development!

Till.
