
include("mip.jl")
include("col_gen1.jl")


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
- normal : atlanta, dfn-bwin
- utra slow : dfn-gwin, nobel-germany, newyork, abilene ( Killed! )
"""
function test()
    # small test
    # global data = Data("test1", 1, true)
    # cplexSolveMIP(data)


    sub_dirs = ["pdh", "di-yuan", "atlanta", "dfn-bwin", "dfn-gwin", "nobel-germany", "newyork", "abilene"]

    for num in 1:10
        global data = Data("nobel-us", num) 

        cplexSolveMIP(data)
    end

end



function test_col_gen()
    # small test

    global data = Data("test1", 1, true)

    # --------------------
    # test sub problems
    # --------------------
    println("\n test feasible sol \n")

    for k in 1:data.K
        println("\n commodity k : ", k)
        α = 0.0
        β = zeros(data.N, size(data.Order[k], 1))
        sub_problem(data, k, α, β, false)

    end

end
