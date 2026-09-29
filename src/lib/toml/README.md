# toml

`TOML.Mod`, a small TOML reader (sections, `key = value`, quoted strings), from
https://github.com/norayr/toml, the reader vipak uses.

Changed for polpo: the only import (`Strings`, for its length function) is replaced by a
local `Length`, so the module has no imports and compiles unchanged with polpo and voc.
Keep this copy identical to upstream when syncing.
