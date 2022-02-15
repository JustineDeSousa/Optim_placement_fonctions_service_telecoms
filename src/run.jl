include("mip.jl")


function test()
    dir = "../small_data/"
    global data = Data(dir, true, "grille2x3")
    dir = "../data/"
    #global data = Data(dir, false, "pdh", 1)

    cplexSolveMIP(data)
end

