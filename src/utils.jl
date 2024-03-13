"""
    LiteralParameter(p)

A wrapper around a value `p` to indicate to
[`new_derived_named_parameter`](@ref) or [`@convert_to_parameters`](@ref)
to _not_ convert the given parameter `p` into a named `@parameters` instance,
but rather keep it as a numeric literal in the generated equations.
"""
struct LiteralParameter{P}
    p::P
end
# necessary for the macro
_literalvalue(x) = x
_literalvalue(p::LiteralParameter) = p.p

"""
    has_symbolic_var(eqs, var)

Return `true` if symbolic variable `var` exists in the equation(s) `eq`, `false` otherwise.
This works for either `@parameters` or `@variables`.
If `var` is a `Symbol` isntead of a `Num`, all variables are converted to their names
and equality is checked on the basis of the name only.

    has_symbolic_var(model, var)

When given a MTK model (such as `ODESystem`) search in _all_ the equations of the system,
including observed variables.
"""
function has_symbolic_var(eq::Equation, var)
    vars = get_variables(eq)
    return _has_thing(var, vars)
end
has_symbolic_var(eqs::Vector{Equation}, var) = any(eq -> has_symbolic_var(eq, var), eqs)
has_symbolic_var(mtk, var) = has_symbolic_var(all_equations(mtk), var)

function _has_thing(var::Num, vars)
    return any(isequal(var), vars)
end
function _has_thing(var::Symbol, vars)
    vars = ModelingToolkit.getname.(vars)
    var = ModelingToolkit.getname(var)
    return any(isequal(var), vars)
end

"""
    all_equations(model)

Equivalent with `vcat(equations(model), observed(model))`.
"""
all_equations(model) = vcat(equations(model), observed(model))

"""
    default_value(x)

Return the default value of a symbolic variable `x` or `nothing`
if it doesn't have any. Return `x` if `x` is not a symbolic variable.
The difference with `ModelingToolkit.getdefault` is that this function will
not error on the absence of a default value.
"""
default_value(x) = x
default_value(x::Num) = default_value(x.val)
function default_value(x::ModelingToolkit.SymbolicUtils.Symbolic)
    if haskey(x.metadata, ModelingToolkit.Symbolics.VariableDefaultValue)
        return x.metadata[ModelingToolkit.Symbolics.VariableDefaultValue]
    else
        @warn("No default value assigned to variable/parameter $(x).")
        return nothing
    end
end
# trick to get default values for state variables:
# Base.Fix1(getindex, ModelingToolkit.defaults(ssys)).(states(ssys))
# while `defaults` returns all default assignments.

is_variable(x::Num) = is_variable(x.val)
function is_variable(x)
    if x isa ModelingToolkit.SymbolicUtils.Symbolic
        if isnothing(x.metadata)
            return false
        end
        if haskey(x.metadata, ModelingToolkit.Symbolics.VariableSource)
            src = x.metadata[ModelingToolkit.Symbolics.VariableSource]
            return first(src) == :variables
        end
    end
    return false
end

"""
    new_derived_named_parameter(variable, value, extra::String; kw...)

If `value isa Num` return `value`.
If `value isa LiteralParameter`, replace it with its literal value.
Otherwise, create a new MTK `@parameter` whose name is created from `variable`
(which could also be just a `Symbol`) by adding the `extra` string.

**Keywords**:

- `prefix = true`: whether the `extra` is added at the start or the end, connecting
  with the with the `connector`.
- `connector = "_"`: what to use to connect `extra` with the name.


For example,

```
@variables x(t)
p = new_derived_named_parameter(x, 0.5, "τ")
```
Now `p` will be a parameter with name `:τ_x` and default value `0.5`.
"""
new_derived_named_parameter(v, value::Num, extra::String; kw...) = value
new_derived_named_parameter(v, value::LiteralParameter, extra::String; kw...) = value.p
function new_derived_named_parameter(v, value::Real, extra; connector = "_", prefix = true)
    n = string(ModelingToolkit.getname(v))
    newstring = if prefix
        extra*connector*n
    else
        n*connector*extra
    end
    new_derived_named_parameter(newstring, value)
end
function new_derived_named_parameter(newstring::String, value::Real)
    varsymbol = Symbol(newstring)
    dummy = (@parameters $(varsymbol) = value)
    return first(dummy)
end

# Macro thanks to Jonas Isensee,
# https://discourse.julialang.org/t/metaprogramming-macro-calling-another-macro-making-named-variables/109621/6
"""
    @convert_to_parameters vars...

Convert all variables `vars` into `@parameters` with name the same as `vars`
and default value the same as the value of `vars`. The macro leaves unaltered
inputs that are of type `Num`, assumming they are already parameters.
It also replaces [`LiteralParameter`](@ref) inputs with its literal values.
This macro is extremely useful to convert e.g., keyword arguments into named parameters,
while also allowing the user to give custom parameter names,
or to leave some keywords as numeric literals.

Example:

```
julia> A, B = 0.5, 0.5
(0.5, 0.5)

julia> C = first(@parameters X = 0.5)

julia> @convert_to_parameters A B C
3-element Vector{Num}:
 A
 B
 X

julia> typeof(A) # `A` is not a number anymore!
Num

julia> default_value(A)
0.5

julia> C # the binding `C` still corresponds to parameter named `:X`!
 X
```
"""
macro convert_to_parameters(vars...)
    expr = Expr(:block)
    for var in vars
        binding = esc(var)
        varname = QuoteNode(var)
        push!(expr.args,
            :($binding = ifelse(
                $binding isa LiteralParameter, _literalvalue($(binding)), ifelse(
                # don't do anyting if this is already a Num
                $binding isa Num, $binding,
                # Else, convert to modeling toolkit param.
                # This syntax was obtained by doing @macroexpand @parameters A = 0.5
                (ModelingToolkit.toparam)((Symbolics.wrap)((SymbolicUtils.setmetadata)((Symbolics.setdefaultval)((Sym){Real}($varname), $binding), Symbolics.VariableSource, (:parameters, $varname))))
                ))
            )
        )
    end
    push!(expr.args, Expr(:vect, esc.(vars)...))
    return expr
end
