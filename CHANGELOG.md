# Changelog

ProcessBasedModelling.jl follows semver 2.0.
Changelog is kept with respect to v1 release.

## 1.7

- Added an additional check when constructing the raw equations that catches
  errors of typing `x = expression` instead of `x ~ expression` as a process.

## 1.6

- Added an additional step when constructing the raw equation vector to be passed into an MTK model. In this step it is also checked that the RHS for all equations is an `Expression`. Sometimes it is easy to get confused and mess up and make it be an `Equation` (i.e., assigning the LHS-variable twice). This now will give an informative error.

## 1.5

- Add docstring to `processes_to_mtkeqs` and list it in the documentation.
  (function was already exported but not made public in the docs)

## 1.4

- Allow `TimeDerivative(p::Process)`.

## 1.3

- Better error messages for duplicate processes given to `process_to_mtkmodel`.
- New exported function `equation(p::Process)` that returns `lhs(p) ~ rhs(p)`.

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
  Now, LHS can be any of: `x`, `Differential(t)(x)`, `Differential(t)(x)*p`, `p*Differential(t)(x)`. However, the multiplication versions often fail for unknown reasons.