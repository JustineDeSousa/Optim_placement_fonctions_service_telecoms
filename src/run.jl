include("mip.jl")


function test()
    dir = "../small_data/"
    global data = Data(dir, true, "test")

    cplexSolveMIP(data)
end

