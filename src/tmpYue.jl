
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
        global data = Data("di-yuan", num) 

        # cplexSolveMIP(data)
        @info "instance$num"
        column_genaration1(data)
    end

end



function test_col_gen()
    # small test
    # global data = Data("test1", 1, true)

    # column_genaration1(data)

    # println("\nLP bound")
    # sol, LP_Bound = cplexSolveMIP(data, true, true)
    # @info "LP_Bound = ", LP_Bound


    # big data
    global data = Data("pdh", 1) 

    column_genaration1(data)

    println("\nLP bound ")
    sol, LP_Bound = cplexSolveMIP(data, true, true)
    @info "LP_Bound = ", LP_Bound


end


