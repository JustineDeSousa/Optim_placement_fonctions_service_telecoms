include("mip.jl")


function test()
    # dir = "../data/"
    # global data = Data(dir, false, "abilene",1)
    dir = "../small_data/"
    global data = Data(dir, true, "test")

    cplexSolveMIP(data)
end

