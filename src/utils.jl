"""
    has_variable(eq, var)

Return `true` if variable `var` exists in the equation(s) `eq`, `false` otherwise.
Function works irrespectively if `var` is an `@variable` or `@parameter`.
"""
function has_variable(eq::Equation, var)
    vars = get_variables(eq)
    return any(isequal(var), vars)
end
has_variable(eqs, var) = any(eq -> has_variable(eq, var), eqs)

"""
    default_value(x)

Return the default value of a symbolic variable `x` or `nothing`
if it doesn't have any. Return `x` if `x` is not a symbolic variable.
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
    new_derived_named_parameter(variable, value, extra::String, suffix = true)

If `value isa Num`, return `value`. Otherwise, create a new MTK `@parameter`
whose name is created from `variable` by adding the `extra` string.
If `suffix = true` the extra is added at the end after a `_`. Otherwise
it is added at the start, then a `_` and then the variable name.
"""
new_derived_named_parameter(v, value::Num, extra, suffix = true) = value
function new_derived_named_parameter(v, value::Real, extra, suffix = true)
    n = string(ModelingToolkit.getname(v))
    newstring = if suffix
        n*"_"*extra
    else
        extra*"_"*n
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
and default value the same as the value of `vars`. Example:

```
julia> A, B = 0.5, 0.5
(0.5, 0.5)

julia> @convert_to_parameters A B
2-element Vector{Num}:
 A
 B

julia> typeof(A) # `A` is not a number anymore!
Num

julia> default_value(A)
0.5
"""
macro convert_to_parameters(vars...)
    expr = Expr(:block)
    for var in vars
        binding = esc(var)
        varname = QuoteNode(var)
        push!(expr.args,
            :($binding = (ModelingToolkit.toparam)((Symbolics.wrap)((SymbolicUtils.setmetadata)((Symbolics.setdefaultval)((Sym){Real}($varname), $binding), Symbolics.VariableSource, (:parameters, $varname)))))
            )
    end
    push!(expr.args, Expr(:vect, esc.(vars)...))
    return expr
end

export @convert_to_parameters
