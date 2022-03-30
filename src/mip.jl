# This file contains functions solving the multi-commodities problem using CPLEX solver
include("io.jl")


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


function cplexSolveMIP(data::Data, opt = true, LP = false)
    solP = [[] for _ in 1:data.K]

    # modelization
    M = Model(CPLEX.Optimizer) 

    # variable
    @variable(M, x[i=1:data.N, j=1:data.N, k=1:data.K, c=1:data.Layer[k]], Bin)
    @variable(M, y[1:data.F, 1:data.N] >= 0, Int)
    @variable(M, u[1:data.N], Bin)

    if LP
        relax_integrality(M)
    end

    # objective function
    if opt
        println("--------------------optimization--------------------")

        @objective(M, Min, sum(data.CostNode[i] * u[i] for i in 1:data.N) +
            sum(data.CostFun[f, i] * y[f, i] for f in 1:data.F, i in 1:data.N)
        )
    else
        # constant objective for feasible sol only
        println("--------------------feasible--------------------")
        @objective(M, Min, 1)
    end
    
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

        # first layer
        for i in 1:data.N
            if i == s
                @constraint(M, sum(x[j, i, k, 1] for j in 1:data.N if data.Adjacent[j, i]) - 
                    sum(x[i, j, k, 1] for j in 1:data.N if data.Adjacent[i, j]) == -1 + x[i, i, k, 1])
            else
                @constraint(M, sum(x[j, i, k, 1] for j in 1:data.N if data.Adjacent[j, i]) == 
                    sum(x[i, j, k, 1] for j in 1:data.N if data.Adjacent[i, j]) + x[i, i, k, 1] )
            end
            
        end


        # intermediate from 2 to n layers
        for i in 1:data.N
            @constraint(M, [c in 1:data.Layer[k]-1], sum(x[i, j, k, c+1] for j in 1:data.N if data.Adjacent[i, j]) - 
                sum(x[j, i, k, c+1] for j in 1:data.N if data.Adjacent[j, i]) + x[i, i, k, c+1] == x[i, i, k, c])
        end
        # TODO : it seems that these two constr are identical !
        # for i in 1:data.N
        #     @constraint(M, [c in 2:data.Layer[k]], sum(x[j, i, k, c] for j in 1:data.N if data.Adjacent[j, i]) - 
        #         sum(x[i, j, k, c] for j in 1:data.N if data.Adjacent[i, j]) + x[i, i, k, c-1] == x[i, i, k, c])
        # end

    end

    #TODO : 1) each layer exactly one vertex jump; 2) each arc is passed at most once by all commodities
    # @constraint(M, 
    #     [k in 1:data.K, c in 1:data.Layer[k]],
    #     sum(x[i, i, k, c] for i in 1:data.N) == 1
    # )

    # @constraint(M,
    #     [k in 1:data.K, l in size(data.LatencyMat, 1)],
    #     sum(x[round(Int, data.LatencyMat[l, 1]), round(Int, data.LatencyMat[l, 2]), k, c] for c in 1:data.Layer[k]) <= 1
    # )


    # constraint maximal latency 
    @constraint(M, [k in 1:data.K], sum( sum(data.LatencyMat[a, 3] * x[round(Int, data.LatencyMat[a, 1]), round(Int, data.LatencyMat[a, 2]), k, c]
    for a in 1:data.M) for c in 1:data.Layer[k] ) <= data.Commodity[k, 4])
    

    function lay(k::Int64,f::Int64, data::Data)
        """ return a list of layers where f appears for commodity k"""
        return [l for l in 1:data.Layer[k] if data.Order[k][l] == f]
    end

    # constraint function capacitiy
    @constraint(M, [i in 1:data.N, f in 1:data.F], sum(x[i, i, k, c] * round(Int, data.Commodity[k, 3])
        for k in 1:data.K, c in lay(k, f, data)) <= data.CapacityFun[f] * y[f, i])
    
    
    # constraint of variable u
    @constraint(M, [i in 1:data.N], u[i] <= sum(y[f, i] for f in 1:data.F))

    # constraint machine capacity
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
    set_silent(M)
    optimize!(M)
    # println(solution_summary(M))

    #exploredNodes = MOI.get(backend(M), MOI.NodeCount())
    
    solveTime = MOI.get(M, MOI.SolveTime())

    # status of model
    status = termination_status(M)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)
    println("solveTime = ", solveTime)

    compute_conflict!(M)
    obj_val = 0.0
    solveTime = 0.0

    if has_values(M)
        # GAP = MOI.get(M, MOI.RelativeGap())
        obj_val = round(objective_value(M), digits = 2)
        # best_bound = objective_bound(M)
        solveTime = round(MOI.get(M, MOI.SolveTime()), digits = 2)

        println("obj_val = ", obj_val)
        # println("best_bound = ", best_bound)
        # println("GAP = ", GAP)
        if LP
            return (solP, obj_val)
        end

        commodities_path = [[] for _ in 1:data.K] # Array{Array{Tuple{Int64,Int64},1},1}()
        fun_placement = zeros(Int64, data.F, data.N)
        commodities_jump = [[] for _ in 1:data.K]

        for k in 1:data.K
            # println("Client ", k, " : ")
            # for c in 1:data.Layer[k]
            #     print("\tCouche ", c, " -> ")
            #     solution = [(i,j) for i in 1:data.N, j in 1:data.N if value(x[i,j,k,c]) > TOL ]
            #     println(solution)
            # end

            commodities_jump[k] = [i for i in 1:data.N, c in 1:data.Layer[k] if value(x[i, i, k, c]) > TOL]

            commodities_path[k] = [(i, j) for c in 1:data.Layer[k], i in 1:data.N, j in 1:data.N if i != j && value(x[i,j,k,c]) > TOL]
        end


        for i in 1:data.F, j in 1:data.N
            if JuMP.value(y[i, j]) > TOL
                fun_placement[i, j] = round(Int, JuMP.value(y[i, j]))
            end
        end
        # println("y = ", value.(y))
        
        # check feasibility
        isFeasible = verificationMIP(data, commodities_path, fun_placement, commodities_jump)
        println("isFeasible ? ", isFeasible)


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

    if opt
        return (solP, obj_val)
    else
        for k in 1:data.K
            χ = zeros(Int, data.N, data.N, data.Layer[k])
            for i in 1:data.N, j in 1:data.N, c in 1:1:data.Layer[k]
                if value(x[i,j,k,c]) > TOL
                    χ[i, j, c] = 1
                end
            end
            append!(solP[k], [χ])
        end

        return (solP, obj_val)
    end
end


"""
Return true if the solution MIP solved by CPLEX is feasible.
"""
function verificationMIP(data::Data, commodities_path::Array{Array{Any,1},1}, fun_placement::Array{Int64,2}, commodities_jump::Array{Array{Any,1},1})

    # for each commodity, if there is a valid path from s to t
    # println("commodities_path : ", commodities_path)
    # println("fun_placement : ", fun_placement)
    # println("commodities_jump : ", commodities_jump)

    if isConnectedComponent(commodities_path, data) == false
        @error "Commodity path not valid !"
        return false
    end

    # maximal latency satisfied ?
    for k in 1:data.K
        acc_lat = 0.0
        for (u, v) in commodities_path[k]
            acc_lat += data.Latency[u, v]
        end
        if round(acc_lat, digits = 3) - round(data.Commodity[k, 4], digits = 3) >= TOL
            println("k : ", k, "  acc_lat = ", acc_lat, "; data.Commodity[k, 4] = ", data.Commodity[k, 4])
            @error "maximal latency violated !"
        end
    end

    # node capacity satisfied ?
    for i in 1:data.N
        if sum(fun_placement[:, i]) > data.CapacityNode[i]
            @error "node capacity violated !"
            return false
        end
    end

    # function capacity satisfied ?
    residual_capa = [sum(fun_placement[:, i] .* data.CapacityFun) for i in 1:data.N]
    # println("residual_capa : ", residual_capa)
    for k in 1:data.K
        if size(commodities_jump[k], 1) < size(data.Order[k], 1)
            @error "functions ordering violated ! "
            false
        end
        for v in commodities_jump[k]
            residual_capa[v] -= data.Commodity[k, 3]
            if residual_capa[v] < 0
                # println("commodities_jump[$k", "] : ", commodities_jump[k])
                # println("v : ", v, "residual_capa[v] = ", residual_capa[v])
                @error "functions capacity not sufficient for demand !"
                return false
            end
        end
    end

    # Affinity verified ?
    for k in 1:data.K
        if size(data.Affinity[k], 1) < 2
            continue
        end
        f = data.Affinity[k][1]
        g = data.Affinity[k][2]
        if commodities_jump[k][f] == commodities_jump[k][g]
            @error "Affinity violated by commodity $k"
            return false
        end
    end
    
    return true
end


"""
Return true, if each path P_k is vaild from s_k to t_k.
"""
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
        # println("vertices : ", vertices)


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