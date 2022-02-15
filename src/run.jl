include("mip.jl")


function test()
    dir = "../small_data/"
    global data = Data(dir, true, "grille2x3")

    cplexSolveMIP(data)
end

