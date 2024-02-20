```@docs
ProcessBasedModelling
```

!!! note "Basic familiarity with ModelingToolkit.jl"
    These docs assume that you have some basic familiarity with ModelingToolkit.jl. If you don't going through the introductory tutorial of [ModelingToolkit.jl](https://docs.sciml.ai/ModelingToolkit/stable/) should be enough to get you started!


## Usage

In ProcessBasedModelling.jl, each variable is governed by a "process".
Conceptually this is just an equation that _defines_ the given variable.
To couple the variable with the process it is governed by, a user either defines simple equations of the form "variable = expression", or creates an instance of [`Process`](@ref) if the left-hand-side of the equation needs to be anything more complex. In either case, the variable and the expression are both _symbolic expressions_ created via ModellingToolkit.jl (more specifically, via Symbolics.jl).

Once all the processes about the physical system are collected, they are given as a `Vector` to the [`processes_to_mtkmodel`](@ref) central function, similarly to how one gives a `Vector` of `Equation`s to e.g., `ModelingToolkit.ODESystem`. This function also defines what quantifies as a "process" in more specificity.

## Example

Let's say we want to build the system of equations

```math
\dot{z} = x^2 - z \\
\dot{x} = 0.1y \\
y = z - x
```

symbolically using ModelingToolkit.jl (**MTK**). We define

```@example MAIN
using ModelingToolkit
using OrdinaryDiffEq: Tsit5

@variables t # independent variable
@variables z(t) = 0.0
@variables x(t) # no default value
@variables y(t) = 0.0
```
ProcessBasedModelling.jl (**PBM**) strongly recommends that all defined variables have a default value at definition point. Here we didn't do this for ``x`` to illustrate what how such an "omission" will be treated by **PBM**.

To make the equations we want, we can use MTK directly, and call
```@example MAIN
eqs = [
  Differential(t)(z) ~ x^2 - z
  Differential(x) ~ 0.1y
  y ~ z - x
]

model = ODESystem(eqs, t; name = :example)

equations(model)
```

All good. Now, if we missed the process for one variable (because of our own error/sloppyness/very-large-codebase), MTK will not throw an error at model construction,

```@example MAIN
model = ODESystem(eqs[1:2], t; name = :example)
model = structural_simplify(model)
equations(model)
```

only at the construction of the "problem" (here the `ODEProblem`)

```@example MAIN
try
  prob = ODEProblem(model)
catch e
  return e.msg
end
```

Interestingly, the error is wrong. ``x`` is defined and has an equation, at least on the basis of our scientific reasoning. However ``y`` that ``x`` introduced does not have an equation. Moreover, in our experience these errors messages become increasingly less useful when a model has many equations and/or variables, as many variables get cited as "missing" from the variable map even when only one should be.

**PBM** resolves these problems and always gives accurate error messages. This is because on top of the variable map that MTK constructs automatically, **PBM** requires the user to implicitly provide a map of variables to processes that govern said variables. **PBM** creates the map automatically, the only thing the user has to do is to define the equations in terms of what [`processes_to_mtkmodel`](@ref) wants (which are either [`Process`](@ref)es or `Equation`s as above).
Here is what the user defines to make the same system of equations:

```@example MAIN
processes = [
    ExpRelaxation(z, x^2),      # introduces x variable
    TimeDerivative(x, 0.1*y),   # introduces y variable
    y ~ z - x,                  # can be an equation because LHS is single variable
]
```

which is then given to
```@example MAIN
model = processes_to_mtkmodel(processes; name = :example)
equations(model)
```

Notice that the resulting **MTK** model is not `structural_simplify`-ed, to allow composing it with other models. By default `t` is taken as the independent variable.

Now, in contrast to before, if we "forgot" a process, **PBM** will react accordingly. For example, if we forgot the 2nd process, then the construction will error informatively, telling us exactly which variable is missing, and because of which processes it is missing:
```@example MAIN
try
  model = processes_to_mtkmodel(processes[[1, 3]])
catch e
  return e.msg
end
```

If instead we "forgot" the ``y`` process, **PBM** will not error, but instead warn, and make ``y`` equal to a named parameter:
```@example MAIN
model = processes_to_mtkmodel(processes[1:2])
equations(model)
```

```@example MAIN
parameters(model)
```

Lastly, [`processes_to_mtkmodel`](@ref) also allows the concept of "default" processes, that can be used for introduced "process-less" variables.
Default processes like `processes` given as a 2nd argument to [`process_to_mtkmodel`](@ref).
For example,

```@example MAIN
model = processes_to_mtkmodel(processes[1:2], processes[3:3])
equations(model)
```

does not throw any warnings as it obtained a process for ``y`` from the given default processes.

### Special handling of timescales

In dynamical systems modelling the timescale associated with a process is a special parameter. That is why, if a timescale is given for either the [`TimeDerivative`](@ref) or [`ExpRelaxation`](@ref) processes, it is converted to a named `@parameter` by default:

```@example MAIN
processes = [
    ExpRelaxation(z, x^2, 2.0),  # third argument is the timescale
    TimeDerivative(x, 0.1*y, 0.5),
    y ~ z-x,
]

model = processes_to_mtkmodel(processes)
equations(model)
```

```@example MAIN
parameters(model)
```

This special handling is also why each process explicitly declares a timescale via the [`timescale`](@ref) function that one can optionally extend.


## Main API function

```@docs
processes_to_mtkmodel
```

## [Predefined `Process` subtypes](@id predefined_processes)

```@docs
ParameterProcess
TimeDerivative
ExpRelaxation
```

## `Process` API

This API describes how you can implement your own `Process` subtype, if the [existing predefined subtypes](@ref predefined_processes) don't fit your bill!

```@docs
Process
ProcessBasedModelling.lhs_variable
ProcessBasedModelling.rhs
ProcessBasedModelling.NoTimeDerivative
ProcessBasedModelling.lhs
```

## Utility functions

```@docs
default_value
has_variable
new_derived_named_parameter
```
