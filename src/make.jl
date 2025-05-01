"""
    processes_to_mtkmodel(processes::Vector [, default]; kw...)

Construct a ModelingToolkit.jl model/system using the provided `processes` and `default` processes.
The model/system is _not_ structurally simplified. Use the function
[`processes_to_mtkeqs`](@ref) to obtain the raw `Vector{Equation}` before it is
passed to the MTK model/system like `ODESystem`.

During construction, the following automations improve user experience:

- Variable(s) introduced in `processes` that does not itself have a process obtain
  a default process from `default`.
- If no default exists, but the variable(s) itself has a default numerical value,
  a [`ParameterProcess`](@ref) is created for said variable and a warning is thrown.
- Else, an informative error is thrown.
- An error is also thrown if any variable has two or more processes assigned to it.

`processes` is a `Vector` whose elements can be:

1. Any instance of a subtype of [`Process`](@ref). `Process` is a
   wrapper around `Equation` that provides some conveniences, e.g., handling of timescales
   or not having limitations on the left-hand-side (LHS) form.
1. An `Equation`. The LHS format of the equation is limited.
   Let `x` be a `@variable` and `p` be a `@parameter`. Then, the LHS can only be one of:
   `x`, `Differential(t)(x)`, `Differential(t)(x)*p`, `p*Differential(t)(x)`,
   however, the versions with `p` may fail unexpectedly. Anything else will error.
2. A `Vector` of the above two, which is then expanded. This allows the convenience of
   functions representing a physical process that may require many equations to be defined
   (because e.g., they may introduce more variables).
3. A ModelingToolkit.jl `XDESystem`, in which case the `equations` of the system are expanded
   as if they were given as a vector of equations like above. This allows the convenience
   of straightforwardly coupling with already existing `XDESystem`s.

## Default processes

`processes_to_mtkmodel` allows for specifying default processes by giving `default`.
These default processes are assigned to variables introduced in the main input `processes`,
but themselves do not have an assigned process in the main input.

`default` can be a `Vector` of individual processes (`Equation` or `Process`).
Alternatively, `default` can be a `Module`. The recommended way to build field-specific
modelling libraries based on ProcessBasedModelling.jl is to define modules/submodules
that offer a pool of pre-defined variables and processes.
Modules may register their own default processes via the function
[`register_default_process!`](@ref).
These registered processes are used when `default` is a `Module`.

## Keyword arguments

- `type = ODESystem`: the model type to make.
- `name = nameof(type)`: the name of the model.
- `independent = t`: the independent variable (default: `@variables t`).
  `t` is also exported by ProcessBasedModelling.jl for convenience.
- `warn_default::Bool = true`: if `true`, throw a warning when a variable does not
  have an assigned process but it has a default value so that it becomes a parameter instead.
- `check_rhs::Bool = true`: if `true`, check that the RHS of all processes is NOT an
  `Equation` type. Throw an informative error if there is one. This
  helps scenarios where the RHS is wrongly an `Equation` assigning the LHS itself
  (has happened to me many times!).
"""
function processes_to_mtkmodel(args...;
        type = ODESystem, name = nameof(type), independent = t, kw...,
    )
    eqs = processes_to_mtkeqs(args...; kw...)
    sys = type(eqs, independent; name)
    return sys
end

"""
    processes_to_mtkeqs(args...) → eqs

Same as in [`processes_to_mtkmodel`](@ref), but return the created vector of `Equation`s
before the are passed to an MTK system.
"""
processes_to_mtkeqs(procs::Vector; kw...) =
processes_to_mtkeqs(procs, Dict{Num, Any}(); kw...)
processes_to_mtkeqs(procs::Vector, m::Module; kw...) =
processes_to_mtkeqs(procs, default_processes(m); kw...)
processes_to_mtkeqs(procs::Vector, v::Vector; kw...) =
processes_to_mtkeqs(procs, default_dict(v); kw...)

# The main implementation has the defaults to be a map from variable to process
# because this simplifies a bit the code
function processes_to_mtkeqs(_processes::Vector, default::Dict{Num, Any};
        type = ODESystem, name = nameof(type), independent = t, warn_default::Bool = true,
        check_rhs = true,
    )
    processes = expand_multi_processes(_processes)
    check_rhs && check_rhs_validity(processes)
    # Setup: obtain lhs-variables so we can track new variables that are not
    # in this vector. The vector has to be of type `Num`
    lhs_vars = Num[lhs_variable(p) for p in processes]
    ensure_unique_vars(lhs_vars, processes)
    # First pass: generate equations from given processes
    # and collect variables without equations
    incomplete = Num[]
    introduced = Dict{Num, Num}()
    eqs = Equation[]
    for proc in processes
        append_incomplete_variables!(incomplete, introduced, lhs_vars, proc)
        # add the generated equation in the pool of equations
        push!(eqs, equation(proc))
    end
    # Second pass: attempt to add default processes to incomplete variables
    # throw an error if default does not exist
    while !isempty(incomplete) # using a `while` allows us check variables added by the defaults
        added_var = popfirst!(incomplete)
        if haskey(default, added_var)
            # Then obtain default process
            def_proc = default[added_var]
            # add the equation to the equation pool
            push!(eqs, lhs(def_proc) ~ rhs(def_proc))
            # Also ensure that potentially new processes introduced by the default process
            # are taken care of and have a default value
            push!(lhs_vars, lhs_variable(def_proc))
            append_incomplete_variables!(incomplete, introduced, lhs_vars, def_proc)
        else
            def_val = default_value(added_var) # utilize default value (if possible)
            if !isnothing(def_val)
                if warn_default == true
                    @warn("""
                    Variable $(added_var) was introduced in process of variable $(introduced[added_var]).
                    However, a process for $(added_var) was not provided,
                    and there is no default process for it either.
                    Since it has a default value, we make it a parameter by adding a process:
                    `ParameterProcess($(ModelingToolkit.getname(added_var)))`.
                    """)
                end
                parproc = ParameterProcess(added_var)
                push!(eqs, lhs(parproc) ~ rhs(parproc))
                push!(lhs_vars, added_var)
            else
                throw(ArgumentError("""
                Variable $(added_var) was introduced in process of variable $(introduced[added_var]).
                However, a process for $(added_var) was not provided,
                there is no default process for $(added_var), and $(added_var) doesn't have a default value.
                Please provide a process for variable $(added_var).
                """))
            end
        end
    end
    return eqs
end

function expand_multi_processes(procs::Vector)
    etypes = Union{Vector, ODESystem, SDESystem, PDESystem}
    !any(p -> p isa etypes, procs) && return procs
    # Expand vectors of processes or ODESystems
    expanded = Any[procs...]
    idxs = findall(p -> p isa etypes, procs)
    multiprocs = expanded[idxs]
    deleteat!(expanded, idxs)
    for mp in multiprocs
        if mp isa Vector
            append!(expanded, mp)
        else # then it is XDE system
            append!(expanded, equations(mp))
        end
    end
    return expanded
end

function check_rhs_validity(processes)
    for p in processes
        if rhs(p) isa Equation
            lvar = lhs_variable(p)
            throw(ArgumentError("Process assigned to variable $(lvar) is ill defined. "*
                "The RHS is an `<: Equation` type but it shouldn't be."
            ))
        end
    end
    return
end

function default_dict(processes)
    default = Dict{Num, Any}()
    for proc in processes
        key = lhs_variable(proc)
        if haskey(default, key)
            throw(ArgumentError("More than 1 processes for variable $(key) in default processes."))
        end
        default[key] = proc
    end
    return default
end

# Add variables to `incomplete` from expression `r`, provided they are not in `lhs_vars`
# already. Also record which variables added them
function append_incomplete_variables!(incomplete, introduced, lhs_vars, process)
    proc_vars = filter(is_variable, get_variables(rhs(process)))
    newvars = setdiff(proc_vars, lhs_vars)
    # Store newly introduced variables without a lhs
    for nv in newvars
        # Note we can't use `(nv ∈ incomplete)`, that creates a symbolic expression
        any(isequal(nv), incomplete) && continue # skip if is already recorded
        numnv = (nv isa Num) ? nv : Num(nv)
        Symbol(nv) == :t && continue # Time-dependence is not a new variable!
        push!(incomplete, numnv)
        # Also record which variable introduced it
        introduced[numnv] = lhs_variable(process)
    end
    return
end

function ensure_unique_vars(lhs_vars, processes)
    nonun = nonunique(lhs_vars)
    isempty(nonun) && return # all good!
    dupprocs = []
    for var in nonun
        idxs = findall(p -> Symbol(lhs_variable(p)) == Symbol(var), processes)
        append!(dupprocs, processes[idxs])
    end
    errormsg = """
    The following variables have more than one processes assigned to them: $(nonun).
    The duplicate processes are:
    """
    for p in dupprocs
        errormsg *= "\n"*sprint(show, p)
    end
    throw(ArgumentError(errormsg))
    return
end

function nonunique(x::AbstractArray{T}) where T
    uniqueset = Set{T}()
    duplicatedset = Set{T}()
    duplicatedvector = Vector{T}()
    for i in x
        if i ∈ uniqueset
            if !(i ∈ duplicatedset)
                push!(duplicatedset, i)
                push!(duplicatedvector, i)
            end
        else
            push!(uniqueset, i)
        end
    end
    duplicatedvector
end