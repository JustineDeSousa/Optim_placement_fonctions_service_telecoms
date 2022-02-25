# This file contains functions solving the multi-commodities problem using CPLEX solver
include("io.jl")
using CPLEX
using JuMP

TOL = 0.00001


# function tryconf()
#     model = Model(CPLEX.Optimizer)  # You must use a solver that supports conflict refining/IIS
#     # computation, like CPLEX or Gurobi
#     # for example, using Gurobi; model = Model(Gurobi.Optimizer)
#     @variable(model, x >= 0)
#     @constraint(model, c1, x >= 2)
#     @constraint(model, c2, x <= 1)
#     optimize!(model)

#     # termination_status(model) will likely be INFEASIBLE,
#     # depending on the solver

#     compute_conflict!(model)

#     conflict_constraint_list = ConstraintRef[]
#     for (F, S) in list_of_constraint_types(model)
#         for con in all_constraints(model, F, S)
#             if MOI.get(model, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
#                 push!(conflict_constraint_list, con)
#                 println(con)
#             end
#         end
#     end

# end


function cplexSolveMIP(data::Data)
    # modelization
    M = Model(CPLEX.Optimizer) 

    # variable
    @variable(M, x[i=1:data.N, j=1:data.N, k=1:data.K, c=1:data.Layer[k]], Bin)
    @variable(M, y[1:data.F, 1:data.N] >= 0, Int)
    @variable(M, u[1:data.N], Bin)

    # objective function
    @objective(M, Min, sum(data.CostNode[i] * u[i] for i in 1:data.N) +
        sum(data.CostFun[f, i] * y[f, i] for f in 1:data.F, i in 1:data.N))

    
    # ------------------
    # flux constraints
    # ------------------
    for k in 1:data.K
        s = round(Int, data.Commodity[k, 1])
        t = round(Int, data.Commodity[k, 2])

        # conversation flux at s
        @constraint(M, sum(sum(x[s, j, k, c] for j in 1:data.N if data.Adjacent[s, j]) - 
            sum(x[j, s, k, c] for j in 1:data.N if data.Adjacent[j, s]) for c in 1:data.Layer[k]) == 1)

        # conversation flux at t
        @constraint(M, sum(sum(x[t, j, k, c] for j in 1:data.N if data.Adjacent[t, j]) - 
            sum(x[j, t, k, c] for j in 1:data.N if data.Adjacent[j, t]) for c in 1:data.Layer[k]) == -1)

        # conversation flux at each node
        for i in 1:data.N
            if i == s || i == t
                continue
            end
            @constraint(M, sum(sum(x[i, j, k, c] for j in 1:data.N if data.Adjacent[i, j]) - 
                sum(x[j, i, k, c] for j in 1:data.N if data.Adjacent[j, i]) for c in 1:data.Layer[k]) == 0)
        end

        # -----------------------------------------
        # flux conservation at each layer
        # -----------------------------------------

        for i in 1:data.N
            @constraint(M, [c in 1:data.Layer[k]-1], sum(x[i, j, k, c+1] for j in 1:data.N if data.Adjacent[i, j]) - 
                sum(x[j, i, k, c+1] for j in 1:data.N if data.Adjacent[j, i]) + x[i, i, k, c+1] == x[i, i, k, c])
        end

        # for i in 1:data.N
        #     if i == t
        #         @constraint(M, sum(x[i, j, k, data.Layer[k]] for j in 1:data.N if data.Adjacent[i, j]) - 
        #         sum(x[j, i, k, data.Layer[k]] for j in 1:data.N if data.Adjacent[j, i]) == -1 + x[i, i, k, data.Layer[k]])
        #     else
        #         @constraint(M, sum(x[i, j, k, data.Layer[k]] for j in 1:data.N if data.Adjacent[i, j]) - 
        #         sum(x[j, i, k, data.Layer[k]] for j in 1:data.N if data.Adjacent[j, i]) == x[i, i, k, data.Layer[k]])
        #     end
        # end


        for i in 1:data.N
            @constraint(M, [c in 2:data.Layer[k]], sum(x[j, i, k, c] for j in 1:data.N if data.Adjacent[j, i]) - 
                sum(x[i, j, k, c] for j in 1:data.N if data.Adjacent[i, j]) + x[i, i, k, c-1] == x[i, i, k, c])
        end

        for i in 1:data.N
            if i == s
                @constraint(M, sum(x[j, i, k, 1] for j in 1:data.N if data.Adjacent[j, i]) - 
                    sum(x[i, j, k, 1] for j in 1:data.N if data.Adjacent[i, j]) == -1 + x[i, i, k, 1])
            else
                @constraint(M, sum(x[j, i, k, 1] for j in 1:data.N if data.Adjacent[j, i]) == 
                    sum(x[i, j, k, 1] for j in 1:data.N if data.Adjacent[i, j]) + x[i, i, k, 1] )
            end
            
        end


    end


    # constraint maximal latency 
    @constraint(M, [k in 1:data.K], sum( sum(data.LatencyMat[a, 3] * x[round(Int, data.LatencyMat[a, 1]), round(Int, data.LatencyMat[a, 2]), k, c]
    for a in 1:data.M) for c in 1:data.Layer[k] ) <= data.Commodity[k, 4])
    


    #TODO : for each layer, jump at most one vertex
    function lay(k::Int64,f::Int64, data::Data)
        for i in 1:data.Layer[k]
            # println(data.Order[k][i])
            # println("f",f)
            if f==data.Order[k][i]
                # println("---------")
                return i
            end
        end

        return data.Layer[k]+1
    end


    # constraint function capacitiy
    @constraint(M, [i in 1:data.N, f in 1:data.F], sum( sum(x[i, i, k, c] for c in 1:data.Layer[k] if c==lay(k,f,data))
        * round(Int, data.Commodity[k, 3]) for k in 1:data.K) <= data.CapacityFun[f] * y[f, i])
    
    # constraint machine capacity
    # @constraint(M, [i in 1:data.N], sum(y[f, i] for f in 1:data.F) <= data.CapacityNode[i])


    # constraint of variable u
    @constraint(M, [i in 1:data.N], u[i] <= sum(y[f, i] for f in 1:data.F))
    @constraint(M, [i in 1:data.N], u[i] * data.CapacityNode[i] >= sum(y[f, i] for f in 1:data.F)) # 


    # exclusive constraint
    for k in 1:data.K
        if size(data.Affinity[k], 1) < 1
            continue
        end
        layer = 1
        c = 0
        c_ = 0
        for f in data.Order[k]
            if f == data.Affinity[k][1]
                c = layer
            end
            if f == data.Affinity[k][2]
                c_ = layer
            end
            layer += 1
        end
        if c==0 || c_ ==0
            error("No correpondent function found ! ")
        end
        @constraint(M, [i in 1:data.N], x[i, i, k, c_] <= 1 - x[i, i, k, c])
    end
    
    # for each layer, at least one function is installed
    @constraint(M, [k in 1:data.K, c in 1:data.Layer[k]], sum(x[i, i, k, c] for i in 1:data.N) == 1)


    # solve the problem
    optimize!(M)
    # TODO : I'm not sure if this summary works for you
    println(solution_summary(M))

    #exploredNodes = MOI.get(backend(M), MOI.NodeCount())
    
    solveTime = MOI.get(M, MOI.SolveTime())

    # status of model
    status = termination_status(M)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)
    println("solveTime = ", solveTime)

    compute_conflict!(M)

    if has_values(M)
        GAP = MOI.get(M, MOI.RelativeGap())
        obj_val = objective_value(M)
        # best_bound = objective_bound(M)

        println("obj_val = ", obj_val)
        # println("best_bound = ", best_bound)
        # println("GAP = ", GAP)

        commodities_path = [[] for _ in 1:data.K] # Array{Array{Tuple{Int64,Int64},1},1}()
        fun_placement = zeros(Int64, data.F, data.N)

        for k in 1:data.K
            println("Client ", k, " : ")
            for c in 1:data.Layer[k]
                print("\tCouche ", c, " -> ")
                solution = [(i,j) for i in 1:data.N, j in 1:data.N if value(x[i,j,k,c]) > TOL ]
                println(solution)
            end

            commodities_path[k] = [(i, j) for c in 1:data.Layer[k], i in 1:data.N, j in 1:data.N if i != j && value(x[i,j,k,c]) > TOL]
        end
        for i in 1:data.F, j in 1:data.N
            if JuMP.value(y[i, j]) > TOL
                fun_placement[i, j] = round(Int, JuMP.value(y[i, j]))
            end
        end
        println("y = ", value.(y))
        
        # check feasibility
        verificationMIP(data, commodities_path, fun_placement)

    elseif MOI.get(M, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        conflict_constraint_list = ConstraintRef[]
        for (F, S) in list_of_constraint_types(M)
            for con in all_constraints(M, F, S)
                if MOI.get(M, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                    push!(conflict_constraint_list, con)
                    println(con)
                end
            end
        end

        error("No conflict could be found for an infeasible model.")
    end

end



function verificationMIP(data::Data, commodities_path::Array{Array{Any,1},1}, fun_placement::Array{Int64,2})
    # for each commodity, a valid path from s to t
    println("commodities_path : ", commodities_path)
    println("fun_placement : ", fun_placement)

    if isConnectedComponent(commodities_path, data) == false
        return false
    end

    # for i in 1:data.N
        
    # end

end


function isConnectedComponent(commodities_path::Array{Array{Any,1},1}, data::Data)
    # for each Commodity
    for k in 1:data.K
        v = Set{Int64}()
        sort!(commodities_path[k])
        for (i, j) in commodities_path[k]
            push!(v, i)
            push!(v, j)
        end
        vertices = collect(v)
        println("vertices : ", vertices)


        isVisited = Dict(i=>false for i in vertices)
        todo = []
    
        # pick up a source
        s = round(Int, data.Commodity[k, 1])
        append!(todo, s)

        while size(todo, 1) >0
            v = pop!(todo)
            if ! isVisited[v] 
                isVisited[v] = true
                for u in vertices
                    if data.Adjacent[v, u] && ! isVisited[u]
                        append!(todo, u)
                    end
                end
            end
        end

        for v in vertices
            if ! isVisited[v]
                return false
            end
        end

    end
    return true
end