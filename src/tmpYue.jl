
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
                global data = Data(name, num) # reading function works
            end
        end
    end

end


function test()
    # global data = Data("test1", 1, true)
    # cplexSolveMIP(data)

    for num in 1:10
        global data = Data("pdh", num)

        cplexSolveMIP(data)
    end

end
