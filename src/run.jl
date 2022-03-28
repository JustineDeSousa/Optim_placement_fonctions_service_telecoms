#using CPLEX 
#using JuMP
using DelimitedFiles
#include("mip.jl")
include("heuristic.jl")


function test()
    global data = Data("test", 1, true)

    solution = init_solution(data,1.0)
    #println("neighborhood :", neighborhood(data,solution))
    bestsol=recuitSimule(data)
    println("recuit Simule :", bestsol )
    println("feasible : ", isFeasible(data, bestsol))
    println("Cost Solution : ", costHeuristic(data,bestsol))
    #global layers = functionsOrder(data,solution)
    if !isFeasible(data, bestsol)
        Bestie=orderFunctions(data,bestsol)
        println("Cost Solution 2 : ", costHeuristic(data,Bestie))
    end
    #global data = Data("pdh", 1)
    # cplexSolveMIP(data)
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

test2()