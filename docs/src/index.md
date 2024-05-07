```@docs
ProcessBasedModelling
```

!!! note "Basic familiarity with ModelingToolkit.jl"
    These docs assume that you have some basic familiarity with ModelingToolkit.jl. If you don't going through the introductory tutorial of [ModelingToolkit.jl](https://docs.sciml.ai/ModelingToolkit/stable/) should be enough to get you started!

!!! note "Default `t` is unitless"
    Like ModelingToolkit.jl, ProcessBasedModelling.jl also exports `t` as the independent variable representing time.
    However, instead of the default `t` of ModelingToolkit.jl, here `t` is unitless.
    Do `t = ModelingToolkit.t` to obtain the unitful version of `t`.

## Usage

In ProcessBasedModelling.jl, each variable is governed by a "process".
Conceptually this is just an equation that _defines_ the given variable.
To couple the variable with the process it is governed by, a user either defines simple equations of the form `variable ~ expression`, or creates an instance of [`Process`](@ref) if the left-hand-side of the equation needs to be anything more complex (or, simply if you want to utilize the conveniences of predefined processes).
In either case, the `variable` and the `expression` are both _symbolic expressions_ created via ModellingToolkit.jl.

Once all the processes about the physical system are collected, they are given as a `Vector` to the [`processes_to_mtkmodel`](@ref) central function, similarly to how one gives a `Vector` of `Equation`s to e.g., `ModelingToolkit.ODESystem`. `processes_to_mtkmodel` also defines what quantifies as a "process" in more specificity.
Then `processes_to_mtkmodel` ensures that all variables in the relational graph of your equations have a defining equation, or throws informative errors/warnings otherwise.
It also provides some useful automation, see the example below.

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

@variables t # independent variable _without_ units
@variables z(t) = 0.0
@variables x(t) # no default value
@variables y(t) = 0.0
```
ProcessBasedModelling.jl (**PBM**) strongly recommends that all defined variables have a default value at definition point. Here we didn't do this for ``x`` to illustrate what how such an "omission" will be treated by **PBM**.

!!! note "ModelingToolkit.jl is re-exported"
    ProcessBasedModelling.jl re-exports the whole `ModelingToolkit` package,
    so you don't need to be `using` both of them, just `using ProcessBasedModelling`.

To make the equations we want, we can use MTK directly, and call
```@example MAIN
eqs = [
  Differential(t)(z) ~ x^2 - z
  Differential(t)(x) ~ 0.1y
  y ~ z - x
]

model = ODESystem(eqs, t; name = :example)

equations(model)
```

All good. Now, if we missed the process for one variable (because of our own error/sloppyness/very-large-codebase), MTK will throw an error when we try to _structurally simplify_ the model (a step necessary before solving the ODE problem):

```@example MAIN
# no errors:
model = ODESystem(eqs[1:2], t; name = :example)
```

```julia
# here is the error
model = structural_simplify(model)
```
```
ERROR: ExtraVariablesSystemException: The system is unbalanced.
There are 3 highest order derivative variables and 2 equations.
More variables than equations, here are the potential extra variable(s):
 z(t)
 x(t)
 y(t)
```

The error message is unhelpful as all variables are reported as "potentially missing".
At least on the basis of our scientific reasoning however, both ``x, z`` have an equation.
It is ``y`` that ``x`` introduced that does not have an equation.
Moreover, in our experience these error messages become increasingly less accurate or helpful when a model has many equations and/or variables.
This makes it difficult to quickly find out where the "mistake" happened in the equations.

**PBM** resolves these problems and always gives accurate error messages when
it comes to the construction of the system of equations.
This is because on top of the variable map that MTK constructs automatically, **PBM** requires the user to implicitly provide a map of variables to processes that govern said variables. **PBM** creates the map automatically, the only thing the user has to do is to define the equations in terms of what [`processes_to_mtkmodel`](@ref) wants (which are either [`Process`](@ref)es or `Equation`s as above).

For the majority of cases, **PBM** can infer the LHS variable a process "defines" automatically, just by passing in a vector of `Equation`s, like in **MTK**.
For cases where this is not possible a dedicated `Process` type is provided, whose subtypes act as wrappers around equations providing some additional conveniences.

Here is what the user defines to make the same system of equations via **PBM**:

```@example MAIN
using ProcessBasedModelling

processes = [
    ExpRelaxation(z, x^2),      # defines z, introduces x; `Process` subtype
    Differential(t)(x) ~ 0.1*y, # defines x, introduces y; normal `Equation`
    y ~ z - x,                  # defines y; normal `Equation`
]
```

which is then given to

```@example MAIN
model = processes_to_mtkmodel(processes; name = :example)
equations(model)
```

Notice that the resulting **MTK** model is not `structural_simplify`-ed, to allow composing it with other models. By default `t` is taken as the independent variable.

Now, in contrast to before, if we "forgot" a process, **PBM** will react accordingly.
For example, if we forgot the process for ``x``, then the construction will error informatively,
telling us exactly which variable is missing, and because of which processes it is missing:
```julia
model = processes_to_mtkmodel(processes[[1, 3]])
```
```
ERROR: ArgumentError: Variable x(t) was introduced in process of variable z(t).
However, a process for x(t) was not provided,
there is no default process for x(t), and x(t) doesn't have a default value.
Please provide a process for variable x(t).
```

If instead we "forgot" the ``y`` process, **PBM** will not error, but warn, and make ``y`` equal to a named parameter, since ``y`` has a default value.
So, running:
```@example MAIN
model = processes_to_mtkmodel(processes[1:2])
equations(model)
```

Makes the named parameter:

```@example MAIN
parameters(model)
```

and throws the warning:
```julia
┌ Warning: Variable y(t) was introduced in process of variable x(t).
│ However, a process for y(t) was not provided,
│ and there is no default process for it either.
│ Since it has a default value, we make it a parameter by adding a process:
│ `ParameterProcess(y)`.
└ @ ProcessBasedModelling ...\ProcessBasedModelling\src\make.jl:65
```

Lastly, [`processes_to_mtkmodel`](@ref) also allows the concept of "default" processes, that can be used for introduced "process-less" variables.
Default processes are like `processes` and given as a 2nd argument to [`processes_to_mtkmodel`](@ref).
For example,

```@example MAIN
model = processes_to_mtkmodel(processes[1:2], processes[3:3])
equations(model)
```

does not throw any warnings as it obtained a process for ``y`` from the given default processes.

!!! note "Default processes example"
    The default process infrastructure of **PBM** is arguably its most powerful quality when it comes to building field-specific libraries. Its usefulness is illustrated in the derivative package [ConceptualClimateModels.jl](https://github.com/JuliaDynamics/ConceptualClimateModels.jl).


## Special handling of timescales

In dynamical systems modelling the timescale associated with a process is a special parameter. That is why, if a timescale is given for either the [`TimeDerivative`](@ref) or [`ExpRelaxation`](@ref) processes, it is converted to a named `@parameter` by default:

```@example MAIN
processes = [
    ExpRelaxation(z, x^2, 2.0),    # third argument is the timescale
    TimeDerivative(x, 0.1*y, 0.5), # third argument is the timescale
    y ~ z-x,
]

model = processes_to_mtkmodel(processes)
equations(model)
```

```@example MAIN
parameters(model)
```

Note the automatically created parameters ``\tau_x, \tau_z``.
This special handling is also why each process can declare a timescale via the [`ProcessBasedModelling.timescale`](@ref) function that one can optionally extend
(although in our experience the default behaviour covers almost all cases).

If you do not want this automation, you can opt out in two ways:

- Provide your own created parameter as the third argument in e.g., `ExpRelaxation`
- Wrap the numeric value into [`LiteralParameter`](@ref). This will insert the numeric literal into the equation.

See the section on [automatic parameters](@ref auto_params) for more related automation,
such as the macro [`@convert_to_parameters`](@ref) which can be particularly useful
when developing a field-specific library.

## Main API function

```@docs
processes_to_mtkmodel
```

## [Predefined `Process` subtypes](@id predefined_processes)

```@docs
ParameterProcess
TimeDerivative
ExpRelaxation
AdditionProcess
```

## `Process` API

This API describes how you can implement your own `Process` subtype, if the [existing predefined subtypes](@ref predefined_processes) don't fit your bill!

```@docs
Process
ProcessBasedModelling.lhs_variable
ProcessBasedModelling.rhs
ProcessBasedModelling.timescale
ProcessBasedModelling.NoTimeDerivative
ProcessBasedModelling.lhs
```

## [Automatic named parameters](@id auto_params)

```@docs
new_derived_named_parameter
@convert_to_parameters
LiteralParameter
```

## Utility functions

```@docs
default_value
has_symbolic_var
```
