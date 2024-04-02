module ProcessBasedModelling

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ProcessBasedModelling

using Reexport
using ModelingToolkit: t_nounits as t, D_nounits as D
@reexport using ModelingToolkit

include("API.jl")
include("utils.jl")
include("default.jl")
include("make.jl")
include("processes_basic.jl")

export t
export Process, ParameterProcess, TimeDerivative, ExpRelaxation, AdditionProcess
export processes_to_mtkmodel
export new_derived_named_parameter
export has_symbolic_var, default_value
export @convert_to_parameters, LiteralParameter
# export lhs_variable, rhs, lhs # I am not sure whether these should be exported.
export all_equations

end
