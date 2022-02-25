include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("test", 1, true)
    for k in 1:data.K
        println("path commodity ", k, "  : ", find_path(data, k))
    end
    
    #global data = Data("pdh", 1)

    # cplexSolveMIP(data)
end

