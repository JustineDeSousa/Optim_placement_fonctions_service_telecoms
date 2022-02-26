include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("grille2x3", 1, true)
    paths = [ find_path(data,k) for k in 1:data.K]
    println("paths = ", paths)

    init_solution(data,1.0)

    #global data = Data("pdh", 1)
    # cplexSolveMIP(data)
end

test()