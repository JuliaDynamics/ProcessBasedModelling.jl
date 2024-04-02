using ProcessBasedModelling
using Test
using OrdinaryDiffEq

@testset "construction + evolution" begin
    # The model, as defined below, is bistable due to ice albedo feedback
    # so two initial conditions should go to two attractors
    # If that's the case, we are sure model construction was valid

    # First, make some default processes
    @variables T(t) = 300.0       # temperature, in Kelvin
    @variables α(t) = 0.3         # albedo of ice, unitless
    @variables ε(t) = 0.5         # effective emissivity, unitless
    solar_constant = 340.25 # W/m^2, already divided by 4
    σ_Stefan_Boltzman = 5.670374419e-8    # stefan boltzman constant

    Base.@kwdef struct HeatBalance <: Process
        c_T = 5e8
    end
    ProcessBasedModelling.lhs_variable(::HeatBalance) = T
    ProcessBasedModelling.timescale(proc::HeatBalance) = proc.c_T/solar_constant
    function ProcessBasedModelling.rhs(::HeatBalance)
        absorbed_shortwave = 1 - α
        emitted_longwave = ε*(σ_Stefan_Boltzman/solar_constant)*T^4
        return absorbed_shortwave - emitted_longwave
    end

    # make a new type of process
    struct TanhProcess <: Process
        variable
        driver_variable
        left
        right
        scale
        reference
    end
    function ProcessBasedModelling.rhs(p::TanhProcess)
        x = p.driver_variable
        (; left, right, scale, reference) = p
        return tanh_expression(x, left, right, scale, reference)
    end
    function tanh_expression(T, left, right, scale, reference)
        return left + (right - left)*(1 + tanh(2(T - reference)/(scale)))*0.5
    end

    processes = [
        TanhProcess(α, T, 0.7, 0.289, 10.0, 274.5),
        TanhProcess(ε, T, 0.5, 0.41, 2.0, 288.0),
        HeatBalance()
    ]

    sys = processes_to_mtkmodel(processes)
    @test sys isa ODESystem
    @test length(unknowns(sys)) == 3

    sys = structural_simplify(sys)
    @test length(unknowns(sys)) == 1
    @test has_symbolic_var(equations(sys), T)

    u0s = [[300.0], [100.0]]
    ufs = []
    for u0 in u0s
        p = ODEProblem(sys, u0, (0.0, 1000.0*365*24*60*60.0))
        sol = solve(p, Tsit5())
        push!(ufs, sol.u[end])
    end

    @test ufs[1] ≈ [319] atol = 1
    @test ufs[2] ≈ [245] atol = 1

    # vector of processes
    processes = [
        [TanhProcess(α, T, 0.7, 0.289, 10.0, 274.5),
        TanhProcess(ε, T, 0.5, 0.41, 2.0, 288.0),],
        HeatBalance()
    ]

    sys = processes_to_mtkmodel(processes)
    @test sys isa ODESystem
    @test length(unknowns(sys)) == 3

    sys = structural_simplify(sys)
    @test length(unknowns(sys)) == 1
    @test has_symbolic_var(equations(sys), T)

end

@testset "add missing processes" begin
    @variables z(t) = 0.0
    @variables x(t) # no default value
    @variables y(t) = 0.0

    procs = [
        ExpRelaxation(z, x^2, 1.0), # introduces x and y variables
        TimeDerivative(x, 0.1*y),   # introduces y variable!
        y ~ z-x,                    # is an equation, not a process!
    ]

    @testset "only one variable and no defaults" begin
        @test_throws ArgumentError processes_to_mtkmodel(procs[1:1])
    end

    @testset "first two, still missing y, but it has default" begin
        model = @test_logs (:warn, r"\W*((?i)Variable(?-i))\W*") processes_to_mtkmodel(procs[1:2])
        @test length(unknowns(model)) == 3
    end

    @testset "first with default the third; missing x" begin
        @test_throws ArgumentError processes_to_mtkmodel(procs[1:1], procs[3:3])
    end

    @testset "first with default the second; y gets contant value a different warning" begin
        model = @test_logs (:warn, r"\W*((?i)parameter(?-i))\W*") processes_to_mtkmodel(procs[1:1], procs[2:2])
        @test length(unknowns(model)) == 3
    end

    @testset "all three processes given" begin
        sys = processes_to_mtkmodel(procs[1:1], procs[2:3])
        @test length(unknowns(sys)) == 3
        sys = processes_to_mtkmodel(procs[1:2], procs[3:3])
        @test length(unknowns(sys)) == 3
        sys = processes_to_mtkmodel(procs[1:3])
        @test length(unknowns(sys)) == 3
        @test length(unknowns(structural_simplify(sys))) == 2
    end
end

@testset "utility functions" begin
    # Test an untested clause:
    @test default_value(0.5) == 0.5

    @testset "derived" begin
        @variables x(t) = 0.5
        p = new_derived_named_parameter(x, 0.2, "t")
        @test ModelingToolkit.getname(p) == :t_x
        @test default_value(p) == 0.2
        p = new_derived_named_parameter(x, 0.2, "t"; prefix = false, connector = "")
        @test ModelingToolkit.getname(p) == :xt
    end

    @testset "convert" begin
        A, B = 0.5, 0.5
        C = first(@parameters X = 0.5)
        @convert_to_parameters A B C
        @test A isa Num
        @test default_value(A) == 0.5
        @test ModelingToolkit.getname(C) == :X
    end

    @testset "literal in derived" begin
        @variables x(t) = 0.5
        p = LiteralParameter(0.5)
        p = new_derived_named_parameter(x, p, "t")
        @test p == 0.5
    end

    @testset "literal in covert" begin
        p = LiteralParameter(0.5)
        @convert_to_parameters p
        @test p == 0.5
    end

end

@testset "default processes, has_thing" begin
    @variables x(t) = 0.5
    @variables y(t) = 0.5
    @variables z(t) = 0.5
    @variables w(t) = 0.5
    @variables q(t) = 0.5
    processes = [
        TimeDerivative(x, x^2, 1.2),
        ParameterProcess(y),
        ExpRelaxation(z, x^2, 0.5),
        AdditionProcess(ParameterProcess(w), x^2),
        AdditionProcess(TimeDerivative(q, x^2, 1.2), ExpRelaxation(q, x^2), q ~ y*x)
    ]
    mtk = processes_to_mtkmodel(processes)
    mtk = structural_simplify(mtk)
    eqs = all_equations(mtk)
    @test has_symbolic_var(eqs, x)
    @test has_symbolic_var(eqs, y)
    @test has_symbolic_var(eqs, :z)
    @test has_symbolic_var(eqs, mtk.w)
    @test has_symbolic_var(eqs, q)
    @test has_symbolic_var(mtk, q)
    @test has_symbolic_var(eqs, mtk.τ_z)
    @test has_symbolic_var(eqs, :w_0)
end

@testset "addition process error" begin
    @variables x(t) y(t) z(t)
    @test_throws ArgumentError AdditionProcess(x ~ 0.1z, y ~ x^2)
end

@testset "ODESystem as process" begin
    @variables z(t) = 0.0
    @variables x(t) = 0.0
    @variables y(t) = 0.0
    @variables w(t) = 0.0
    procs = [
        ExpRelaxation(z, x^2, 1.0), # introduces x and y variables
        TimeDerivative(x, 0.1*y),   # introduces y variable!
        y ~ z-x,                    # is an equation, not a process!
    ]

    sys = processes_to_mtkmodel(procs)
    sys2 = processes_to_mtkmodel([sys, w ~ x*y])
    @test length(equations(sys2)) == 4
    @test sort(ModelingToolkit.getname.(unknowns(sys2))) == [:w, :x, :y, :z]
end

module TestDefault
    using ProcessBasedModelling
    @variables x(t) = 0.5 y(t) = 0.2
    register_default_process!.([
        Differential(t)(x) ~ 0.2y - x,
        y ~ x^2,
    ], Ref(TestDefault))
end

@testset "registering default" begin
    using .TestDefault
    @variables z(t) = 0.1
    eqs = [z ~ TestDefault.x - 1]
    mtk = processes_to_mtkmodel(eqs, TestDefault)
    @test length(unknowns(mtk)) == 3
    @test has_symbolic_var(mtk, z)
    @test has_symbolic_var(mtk, TestDefault.x)
end
