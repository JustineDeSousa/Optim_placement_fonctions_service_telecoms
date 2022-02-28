
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
                global data = Data(name, num)
                # cplexSolveMIP(data)
            end
        end
    end

end

"""
- utra fast : pdh, di-yuan
- fast : 
- normal : atlanta
- slow : 
- utra slow : abilene
"""
function test()
    # small test
    # global data = Data("test1", 1, true)
    # cplexSolveMIP(data)


    names = ["pdh", "di-yuan", "atlanta", "polska", "abilene"]

    for num in 1:10
        global data = Data("atlanta", num) 

        cplexSolveMIP(data)
    end

end
