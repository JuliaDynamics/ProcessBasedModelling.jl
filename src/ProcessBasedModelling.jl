module ProcessBasedModelling

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ProcessBasedModelling

using Reexport
@reexport using ModelingToolkit

@variables t # independent variable (time)

include("API.jl")
include("utils.jl")
include("make.jl")
include("processes_basic.jl")

# TODO: Make an "addition process" that adds to processes
# It checks whether they target the same variable

# TODO: Perhaps not don't export `t`?
export t
export Process, ParameterProcess, TimeDerivative, ExpRelaxation
export processes_to_mtkmodel
export new_derived_named_parameter
export has_variable, default_value
export @convert_to_parameters, LiteralParameter
export lhs_variable, rhs, lhs

end
