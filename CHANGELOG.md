# Changelog

ProcessBasedModelling.jl follows semver 2.0.
Changelog is kept with respect to v1 release.

## 1.2

The API for default processes has been drastically improved.
Now, each `Module` can track its own default processes via the new function
`register_default_process!`. This allows creating submodules dedicated to
physical "subsystems" which need to track their own list of variables,
parameters, and default processes.

## 1.1

- New keyword `warn_default` in `processes_to_mtkmodel`.
- Now `processes_to_mtkmodel` allows for `XDESystems` as elements of the input vector.
- Detection of LHS-variable in `Equation` has been improved significantly.
  Now, LHS can be any of: `x`, `Differential(t)(x)`, `Differential(t)(x)*p`, `p*Differential(t)(x)`.