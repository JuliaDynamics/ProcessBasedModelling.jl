"""
A process subtype `p::Process` extends the `ProcessBasedModelling` unexported functions:
- `lhs_variable(p)` which returns the variable the process describes
  (left-hand-side variable). There is a default implementation
  `lhs_variable(p) = p.variable` if the field exists.
- `rhs(p)` which is the right-hand-side expression, i.e., the "actual" process.
- (optional) `timescale`, which defaults to [`NoTimeDerivative`](@ref).
- (optional) `lhs(p)` which returns the left-hand-side. Let `τ = timescale(p)`.
  Then default `lhs(p)` behavior depends on `τ` as follows:
  - Just `lhs_variable(p)` if `τ == NoTimeDerivative()`.
  - `Differential(t)(p)` if `τ == nothing`.
  - `τ_var*Differential(t)(p)` if `τ isa Union{Real, Num}`. If real,
    a new named parameter `τ_var` is created that has the prefix `:τ_` and then the
    lhs-variable name and has default value `τ`. Else if `Num`, `τ_var = τ` as given.
  - Explicitly extend `lhs_variable` if the above do not suit you.
"""
abstract type Process end

"""
    NoTimeDerivative()

Singleton value that is the default output of the `timescale` function
for variables that do not vary in time autonomously, i.e., they have no d/dt derivative
and hence the concept of a "timescale" does not apply to them.
"""
struct NoTimeDerivative end

function lhs_variable(p::Process)
    if !hasfield(typeof(p), :variable)
        error("`lhs_variable` not defined for process $(nameof(typeof(p))).")
    else
        return p.variable
    end
end

timescale(::Process) = NoTimeDerivative()

function lhs(p::Process)
    τ = timescale(p)
    v = lhs_variable(p)
    if isnothing(τ) # time variability exists but timescale is nonexistent (unity)
        return Differential(t)(v)
    elseif τ isa NoTimeDerivative || iszero(τ) # no time variability
        return v
    else # τ is either Num or Real
        τvar = new_derived_named_parameter(v, τ, "τ", false)
        return τvar*Differential(t)(v)
    end
end
function rhs(p::Process)
    error("Right-hand side (`rhs`) is not defined for process $(nameof(typeof(p))).")
end

rhs(e::Equation) = e.rhs
lhs(e::Equation) = lhs_variable(e)
function lhs_variable(e::Equation)
    x = e.lhs
    # we first check whether `x` is a variable
    if !is_variable(x)
        throw(ArgumentError("In given equation $(e), the left-hand-side does "*
        "not represent a variable."))
    end
    return x
end
