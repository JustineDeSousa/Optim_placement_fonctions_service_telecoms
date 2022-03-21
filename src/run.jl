using CPLEX 
using JuMP
using DelimitedFiles
include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("test", 1, true)

    solution = init_solution(data,1.0)
    println(solution)

    println("feasible but not ordered : ", isPartiallyFeasible(data, solution) )
    println("feasible : ", isFeasible(data, solution))
    println("nb contrante violee : ",nbConstraintsViolated(data, solution))
    println("maxLatency : ", maxLatency(data,solution))
    println("Cost Solution : ", costHeuristic(data,solution))
    #println("neighborhood :", neighborhood(data,solution))
    bestsol=recuitSimule(data)
    println("recuit Simule :", bestsol )
    println("feasible but not ordered : ", isPartiallyFeasible(data, bestsol) )
    println("feasible : ", isFeasible(data, bestsol))
    println("nb contrante violee : ",nbConstraintsViolated(data,bestsol))
    println("maxLatency : ", maxLatency(data,bestsol))
    println("Cost Solution : ", costHeuristic(data,bestsol))
    #global layers = functionsOrder(data,solution)
    if !isFeasible(data, bestsol)
        Bestie=orderFunctions(data,bestsol)
        println("feasible2 : ", isFeasible(data, Bestie))
        println("feasible but not ordered2 : ", isPartiallyFeasible(data, Bestie) )
        println("feasible2 : ", isFeasible(data, Bestie))
        println("nb contrante violee2 : ",nbConstraintsViolated(data,Bestie))
        println("maxLatency2 : ", maxLatency(data,Bestie))
        println("Cost Solution 2 : ", costHeuristic(data,Bestie))
    end
    #global data = Data("pdh", 1)
    # cplexSolveMIP(data)
end

# test()