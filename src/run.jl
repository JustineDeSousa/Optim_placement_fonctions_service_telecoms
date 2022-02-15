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
                ss = split(subfile, "_")
                name = String(ss[1])
                num = parse(Int64, ss[2])
                println("name : ", name, ", num : ", num)
                global data = Data(dir, false, name, num) # reading function works
            end
        end
    end

end


function test()
    dir = "../small_data/"
    global data = Data(dir, true, "test")

    # dir = "../data/"
    # global data = Data(dir, false, "pdh", 1)

    cplexSolveMIP(data)
end

