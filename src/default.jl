export register_default_process!, default_processes

const _DEFAULT_PROCESSES = Dict{Module, Dict}()

"""
    register_default_process!(process, m::Module; warn = true)

Register a `process` (`Equation` or `Process`) as a default process for its LHS variable
in the list of default processes tracked by the given module.
If `warn`, throw a warning if a default process with same LHS variable already
exists and will be overwritten.
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
"""
function default_processes(m::Module)
    if !haskey(_DEFAULT_PROCESSES, m)
        _DEFAULT_PROCESSES[m] = Dict{Num}{Any}()
    end
    return _DEFAULT_PROCESSES[m]
end
