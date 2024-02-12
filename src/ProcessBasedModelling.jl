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


# TODO: In MAKE, make it so that if a variable does not have a process
# a constant process is created for it if it has a default value.
# Add a keyword `use_default` which would warn if no process but there is default
# and otherwise would error.
# TODO: Make an "addition process" that adds to processes
# It checks whether they target the same variable
# TODO: Package should compose with ODESystem
# so that component-based modelling can be utilized as well.


# TODO: Perhaps not don't export `t, rhs`?
export t
export Process, ParameterProcess, TimeDerivative, ExpRelaxation
export processes_to_mtkmodel
export new_derived_named_parameter

end
