using CPLEX 
using JuMP
include("mip.jl")


function test()
    dir = "../small_data/"
    global data = Data(dir, true, "test")
    # dir = "../data/"
    # global data = Data(dir, false, "pdh", 1)

    cplexSolveMIP(data)
end

