export register_default_process!, default_processes, default_processes_eqs

const _DEFAULT_PROCESSES = Dict{Module, Dict}()

"""
    register_default_process!(process, m::Module; warn = true)

Register a `process` (`Equation` or `Process`) as a default process for its LHS variable
in the list of default processes tracked by the given module.
If `warn`, throw a warning if a default process with same LHS variable already
exists and will be overwritten.

You can use [`default_processes`](@ref) to obtain the list of tracked default processes.

!!! note "For developers"
    If you are developing a new module/package that is based on ProcessBasedModelling.jl,
    and within it you also register default processes, then enclose your
    `register_default_process!` calls within the module's `__init__()` function.
    For example:
    ```julia
    module MyProcesses
    # ...

    function __init__()
        register_default_process!.(
            [
                process1,
                process2,
                # ...
            ],
            Ref(MyProcesses)
        )
    end

    end # module
    ```
"""
function register_default_process!(process::Union{Process, Equation}, m::Module; warn = true)
    mdict = default_processes(m)
    lhsvar = lhs_variable(process)
    # overwritting here should never happen but oh well.
    if haskey(mdict, lhsvar) && warn
        @warn("Overwritting default process for variable $(lhsvar)")
    end
    mdict[lhsvar] = process
    return nothing
end

"""
    default_processes(m::Module)

Return the dictionary of default processes tracked by the given module.
See also [`default_processes_eqs`](@ref).
"""
function default_processes(m::Module)
    if !haskey(_DEFAULT_PROCESSES, m)
        _DEFAULT_PROCESSES[m] = Dict{Num}{Any}()
    end
    return _DEFAULT_PROCESSES[m]
end

"""
    default_processes_eqs(m::Module)

Same as [`default_processes`](@ref), but return the equations
of all processes in a vector format, which is rendered as LaTeX
in Markdown to HTML processing by e.g., Documenter.jl.
"""
function default_processes_eqs(m::Module)
    d = default_processes(m)
    eqs = [lhs(proc) ~ rhs(proc) for proc in values(d)]
    return eqs
end