
include("mip.jl")
include("col_gen1.jl")
include("col_gen2.jl")


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

function solve_instances(method::String; maxTime::Float64=10.0)
    resFolder = "../res/"
    dataFolder = "../data"

    # for instanceName in readdir(dataFolder)


        for num in 1:10
            @info( "-- Resolution of " * instanceName * "_" * string(num))

            folder = resFolder * method * "/" * instanceName
            if !isdir(folder)
                if !isdir(resFolder * method)
                    mkdir(resFolder * method)
                end
                mkdir(folder)
            end
            outputFile = folder * "/" * instanceName * "_" * string(num) * ".txt"

            if !isfile(outputFile) #if the instance hasn't been solved already
                data = Data(instanceName, num)
                if method == "MIP"
                    @info "MIP : " * instanceName * "_" * string(num)
                    @time (paths, cost, resolution_time) = cplexSolveMIP(data)
                    ite = 0
                    functions = []
                elseif method == "LP"
                    @info "LP : " * instanceName * "_" * string(num)
                    @time (paths, cost, resolution_time) = cplexSolveMIP(data, LP=true)
                    ite = 0
                    functions = []
                elseif method == "DW1"
                    @info "DW1 : " * instanceName * "_" * string(num)
                    @time (cost, ite, resolution_time) = column_genaration1(data::Data)
                    paths = []
                    functions = []
                elseif method == "DW2"
                    @info "DW2 : " * instanceName * "_" * string(num)
                    @time (cost, ite, resolution_time) = column_genaration2(data::Data)
                    paths = []
                    functions = []
                # elseif method == "Recuit"
                #     @info "Recuit : " * instanceName * "_" * string(num)
                #     @time sol = recuitSimule(data, max_time=maxTime)
                #     paths = sol.paths
                #     functions = sol.functions
                #     cost = sol.cost
                #     ite = 0
                #     resolution_time = round(sol.resolution_time, digit=2)
                else
                    @error "The " * method * " is not supported. Please try one the following : LP, DW1, DW2, MIP or Recuit"
                end
                open(outputFile, "w") do fout
                    println(fout, "path = ", paths)
                    println(fout, "functions = ", functions)
                    println(fout, "cost = ", cost)
                    println(fout, "nb_it = ", ite)
                    println(fout, "resolution_time = ", resolution_time)
                end
            end
        end
    # end

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
        global data = Data("dfn-bwin", num) 

        # @info "instance$num"
        # println("\n\nMIP ")
        # (solP, obj_v) = cplexSolveMIP(data)
        # @info "obj_v = ", obj_v

        @info "instance$num"
        println("\n\nDW1 ")
        (DW_bound, ite, solved_time) = column_genaration1(data)
        @info "DW_bound = ", DW_bound
    end

end


"""
test the first column generation model
"""
function test_col_gen1()
    # small test
    global data = Data("test1", 1, true)

    (DW_bound, ite, solved_time) = column_genaration1(data)
    @info "DW_bound = ", DW_bound

    # println("\nLP bound")
    # (solP, LP_Bound) = cplexSolveMIP(data, true, true)
    # @info "LP_Bound = ", LP_Bound

    # println("\nMIP ")
    # (solP, obj_v) = cplexSolveMIP(data)
    # @info "obj_v = ", obj_v


    # big data
    # global data = Data("atlanta", 5) 

    # (DW_bound, ite, solved_time) = column_genaration1(data)
    # @info "DW_bound = ", DW_bound

    # println("\n\nLP bound ")
    # (solP, LP_Bound) = cplexSolveMIP(data, LP=true)
    # @info "LP_Bound = ", LP_Bound

    # println("\n\nMIP ")
    # (solP, obj_v) = cplexSolveMIP(data)
    # @info "obj_v = ", obj_v

end

"""
test the second column generation model
"""
function test_col_gen2()

    # # small test
    # global data = Data("test1", 1, true)

    # (DW2_bound, ite, solved_time) = column_genaration2(data)
    # @info "DW2_bound = ", DW2_bound

    # println("\nLP bound")
    # (solP, LP_Bound) = cplexSolveMIP(data, true, true)
    # @info "LP_Bound = ", LP_Bound

    # println("\nMIP ")
    # (solP, obj_v) = cplexSolveMIP(data)
    # @info "obj_v = ", obj_v


    # big data
    global data = Data("pdh", 2) 

    (DW2_bound, ite, solved_time) = column_genaration2(data)
    @info "DW2_bound = ", DW2_bound

    println("\n\nLP bound ")
    (solP, LP_Bound) = cplexSolveMIP(data, LP=true)
    @info "LP_Bound = ", LP_Bound

    println("\n\nMIP ")
    (solP, obj_v) = cplexSolveMIP(data)
    @info "obj_v = ", obj_v
end



