include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("test", 1, true)

    solution = init_solution(data,1.0)
    println(solution)

    println("feasible but not ordered : ", isPartiallyFeasible(data, solution) )
    println("feasible : ", isFeasible(data, solution))
    global layers = functionsOrder(data,solution)
    
    #global data = Data("pdh", 1)
    # cplexSolveMIP(data)
end

test()