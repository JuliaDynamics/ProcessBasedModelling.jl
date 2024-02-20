"""
    ParameterProcess(variable, value = default_value(variable)) <: Process

The simplest process which equates a given `variable` to a constant value
that is encapsulated in a parameter. If `value isa Real`, then
a named parameter with the name of `variable` and `_0` appended is created.
Else, if `valua isa Num` then it is taken as the paremeter directly.

Example:
```julia
@variables T(t) = 0.5
proc = ParameterProcess(T)
```
will create the equation `T ~ T_0`, where `T_0` is a `@parameter` with default value `0.5`.
"""
struct ParameterProcess <: Process
    variable
    value
    function ParameterProcess(variable, value)
        var = new_derived_named_parameter(variable, value, "0")
        return new(variable, var)
    end
end
ParameterProcess(var) = ParameterProcess(var, default_value(var))
lhs_variable(c::ParameterProcess) = c.variable
rhs(cv::ParameterProcess) = cv.value

"""
    TimeDerivative(variable, expression [, τ])

The second simplest process that equates the time derivative of
the `variable` to the given `expression`
while providing some conveniences over manually constructing an `Equation`.

It creates the equation `τ_\$(variable) Differential(t)(variable) ~ expression`
by constructing a new `@parameter` with default value `τ`
(if `τ` is already a `@parameter`, it is used as-is).
If `τ` is not given, then 1 is used at its place and no parameter is created.

Note that if `iszero(τ)`, then the process `variable ~ expression` is created.
"""
struct TimeDerivative <: Process
    variable
    expression
    timescale
end
TimeDerivative(a, b) = TimeDerivative(a, b, nothing)
timescale(e::TimeDerivative) = e.timescale
rhs(e::TimeDerivative) = e.expression


"""
    ExpRelaxation(variable, expression [, τ]) <: Process

A common process for creating an exponential relaxation of `variable` towards the
given `expression`, with timescale `τ`. It creates the equation:
```
τn*Differential(t)(variable) ~ expression - variable
```
Where `τn` is a new named `@parameter` with the value of `τ`
and name `τ_(\$(variable))`. If instead `τ` is `nothing`, then 1 is used in its place
(this is the default behavior).
If `iszero(τ)`, then the equation `variable ~ expression` is created instead.

The convenience function
```julia
ExpRelaxation(process, τ)
```
allows converting an existing process (or equation) into an exponential relaxation
by using the `rhs(process)` as the `expression` in the equation above.
"""
struct ExpRelaxation <: Process
    variable
    expression
    timescale
end
ExpRelaxation(v, e) = ExpRelaxation(v, e, nothing)
ExpRelaxation(proc::Union{Process,Equation}, τ) = ExpRelaxation(lhs_variable(proc), rhs(proc), τ)

timescale(e::ExpRelaxation) = e.timescale
function rhs(e::ExpRelaxation)
    dt = isnothing(e.timescale) || iszero(e.timescale)
    dt ? e.expression : e.expression - e.variable
end