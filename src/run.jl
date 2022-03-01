include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("grille2x3", 1, true)
    global solution = init_solution(data,1.0)
    println(solution)

    println("feasible but not ordered : ", isPartiallyFeasible(data, solution) )
    println("feasible : ", isFeasible(data, solution))
    println("dataTransportedInOrder : ", dataTransportedInOrder(data,solution))
    
    #global data = Data("pdh", 1)
    # cplexSolveMIP(data)
end

test()