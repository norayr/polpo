# versions

`Versions.Mod` compares version numbers like `1.2.10` or `0.3.0-rc1`, part by part as
numbers; a suffix marks a pre-release (`0.3.0-rc1` < `0.3.0`), a missing part is 0. It has
no imports. Used by portia.
