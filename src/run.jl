using CPLEX 
using JuMP

include("mip.jl")

function test1()
    dir = "../data/"

    for file in readdir(dir)
        path = dir * file

        if isdir(path)

            for subfile in readdir(path)
                path = dir * file * subfile
                println("path : ", path)

                
            end
        end
    end

end


function test()
    # dir = "../small_data/"
    # global data = Data(dir, true, "grille2x3")

    dir = "../data/"
    global data = Data(dir, false, "pdh", 1)

    cplexSolveMIP(data)
end

