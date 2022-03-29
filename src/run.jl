#using CPLEX 
#using JuMP
# using DelimitedFiles
#include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("test", 1, true)

    bestsol = recuitSimule(data)
    println("recuit Simule :", bestsol )
    println("feasible : ", isFeasible(data, bestsol))
    println("Cost Solution : ", costHeuristic(data,bestsol))
    if !isFeasible(data, bestsol)
        Bestie = orderFunctions(data,bestsol)
        println("Cost Solution 2 : ", costHeuristic(data,Bestie))
    end
end



function test2()
    # small test
    # global data = Data("test1", 1, true)
    # cplexSolveMIP(data)


    sub_dirs = ["pdh", "di-yuan", "atlanta", "dfn-bwin", "dfn-gwin", "nobel-germany", "newyork", "abilene"]

    for num in 1:10
        global data = Data("di-yuan", num) 

        # cplexSolveMIP(data)
        @info "instance$num"
        recuitSimule(data)
    end

end

""" 
Solve all instances in the folder "data/" 
Write the results in the folder "res/method/"
"""
function solve_instances(method::String; maxTime::Float64=10.)
    resFolder = "../res/"
    dataFolder = "../data"
    for instanceName in readdir(dataFolder)
        for num in 1:10
            @info( "-- Resolution of " * instanceName * "_" * string(num) * " with " * method)
        
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
                if method == "recuit"
                    @info "Recuit : " @time sol = recuitSimule(data, max_time=maxTime) ######
                end
                open(outputFile, "w") do fout
                    println(fout, "path = ", sol.paths)
                    println(fout, "functions = ", sol.functions)
                    println(fout, "cost = ", sol.cost)
                    println(fout, "resolution_time = ", round(sol.resolution_time, digits=2))
                end
            end
        end
    end
    
end
solve_instances("recuit")