# This file contains functions solving the multi-commodities problem using CPLEX solver
# by approach column generation

include("mip.jl")

MAXITE = 100


TOL = 0.000001

"""
Restricted master relaxed problem

The classical model adapted to the MIP
""" 
function master_problem1(data::Data)
    global P
    # println(P)

    # the number of feasible paths for each commodity k
    sizeP = [size(P[k], 1) for k in 1:data.K]
    @show sizeP

    MP = Model(CPLEX.Optimizer) 

    # relaxed vars
    @variable(MP, y[1:data.F, 1:data.N] >= 0)
    @variable(MP, u[1:data.N] >= 0)
    @constraint(MP, [i in 1:data.N], u[i] <= 1)
    @variable(MP, ρ[k=1:data.K, 1:sizeP[k]] >= 0) # <=1 redundent as to the convexity constr

    # convexity
    con_α = @constraint(MP, [k in 1:data.K], sum(ρ[k, p] for p in 1:sizeP[k]) == 1)


    # objective function
    @objective(MP, Min, sum(data.CostNode[i] * u[i] for i in 1:data.N) +
                sum(data.CostFun[f, i] * y[f, i] for f in 1:data.F, i in 1:data.N)
    )
    

    # constraint of variable u
    @constraint(MP, [i in 1:data.N], u[i] <= sum(y[f, i] for f in 1:data.F))


    # constraint machine capacity
    @constraint(MP, [i in 1:data.N], u[i] * data.CapacityNode[i] >= sum(y[f, i] for f in 1:data.F))


    function lay(k::Int64,f::Int64, data::Data)
        """ return a list of layers where f appears for commodity k"""
        return [l for l in 1:data.Layer[k] if data.Order[k][l] == f]
    end

    # constraint function capacitiy # x[i, i, k, c]
    con_β = @constraint(MP, [i in 1:data.N, f in 1:data.F], 
                sum(sum(ρ[k,p] * P[k][p][i, i, c] for p in 1:sizeP[k]) * round(Int, data.Commodity[k, 3])
                    for k in 1:data.K, c in lay(k, f, data))  <= data.CapacityFun[f] * y[f, i]
    )
    
    # solve the problem
    set_silent(MP) # turn off cplex output
    optimize!(MP)
    
    # status of model
    status = termination_status(MP)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)
    @info "MP status ", status

    compute_conflict!(MP)

    LB = 0.0

    if has_values(MP) && isOptimal
        LB = objective_value(MP)
        @info "LB = ", LB
        println("LB objective ", LB)

        # @show sum(value.(ρ))
        @show value.(u)
        @show value.(y)

        for k in 1:data.K, p in 1:sizeP[k]
            if value(ρ[k, p]) >TOL
                @info "k, p, ρ[k, p]", k, p, ρ[k, p]
            end
        end

    elseif MOI.get(MP, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        conflict_constraint_list = ConstraintRef[]
        for (F, S) in list_of_constraint_types(MP)
            for con in all_constraints(MP, F, S)
                if MOI.get(MP, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                    push!(conflict_constraint_list, con)
                    println(con)
                end
            end
        end

        error("No conflict could be found for an infeasible model.")
    else
        error("Master problem doesn't have optimal solution !")
    end

    α = zeros((data.K))
    β = zeros(data.N, data.F)
    if has_duals(MP)
        @show dual.(con_α)
        @show dual.(con_β)
        return (dual.(con_α), -dual.(con_β), LB)
    else
        @info has_duals(MP)
        return (α, β, LB)
    end
    
end




"""
∀ k, - verify if reduced cost ≤ 0?
    - if yes, return the verctor of arcs (i.e. path for commodity k) 
    - otherwise, nothing 

Returns : 
    - new_col : Bool
    - χ : [i, j, c] = {0, 1} ∀ ij ∈ A, ∀ c ∈ data.Layer[k]

Args : 
    - opt : if false, then we generate feasible route avoiding to put many functions on the same node(
"""
function sub_problem1(data::Data, k::Int64, α::Float64, β::Array{Float64,2}, opt = true, feasib = 0)
    new_col = false
    # c_max = maximum(data.Layer) # "couches" maximum
    χ = zeros(Int, data.N, data.N, data.Layer[k])

    SM = Model(CPLEX.Optimizer) 

    @variable(SM, x[i=1:data.N, j=1:data.N, c=1:data.Layer[k]], Bin)


    function lay(k::Int64,f::Int64, data::Data)
        """ return a list of layers where f appears for commodity k"""
        return [l for l in 1:data.Layer[k] if data.Order[k][l] == f]
    end

    if opt
        println("--------------------optimization--------------------")
        @objective(SM, Min, 
            sum(β[i, f] * x[i, i, c] * round(Int, data.Commodity[k, 3])
                    for i in 1:data.N, f in data.Order[k], c in lay(k, f, data) 
                )
        )

    elseif feasib == 0
        # constant
        println("--------------------feasible--------------------")
        @objective(SM, Max, -1)

    elseif feasib == 1
        # avoid to install too many functions on one node
        println("--------------------feasible--------------------")
        @variable(SM, extra >= 0, Int)

        @objective(SM, Max, -extra-1)

        @variable(SM, cc[i=1:data.N]>=0, Int)
        @constraint(SM, [i in 1:data.N], sum(x[i, i, c] for c in 1:data.Layer[k]) <= cc[i])
        @constraint(SM, [i in 1:data.N], extra >= cc[i])

    elseif feasib == 2
        # the shortest path length
        println("--------------------feasible--------------------")
        @objective(SM, Max, -sum(x))

    elseif feasib == 3
        # the longest path
        println("--------------------feasible--------------------")
        @objective(SM, Min, -sum(x))
    end


    # ------------------
    # flux constraints
    # ------------------
    s = round(Int, data.Commodity[k, 1])
    t = round(Int, data.Commodity[k, 2])

    # conversation flux at s
    @constraint(SM, sum(sum(x[s, j, c] for j in 1:data.N if data.Adjacent[s, j]) - 
        sum(x[j, s, c] for j in 1:data.N if data.Adjacent[j, s]) for c in 1:data.Layer[k]) == 1)

    # conversation flux at t
    @constraint(SM, sum(sum(x[t, j, c] for j in 1:data.N if data.Adjacent[t, j]) - 
        sum(x[j, t, c] for j in 1:data.N if data.Adjacent[j, t]) for c in 1:data.Layer[k]) == -1)

    # conversation flux at each node
    for i in 1:data.N
        if i == s || i == t
            continue
        end
        @constraint(SM, sum(sum(x[i, j, c] for j in 1:data.N if data.Adjacent[i, j]) - 
            sum(x[j, i, c] for j in 1:data.N if data.Adjacent[j, i]) for c in 1:data.Layer[k]) == 0)
    end


    # -----------------------------------------
    # flux conservation at each layer
    # -----------------------------------------

    # first layer
    for i in 1:data.N
        if i == s
            @constraint(SM, sum(x[j, i, 1] for j in 1:data.N if data.Adjacent[j, i]) - 
                sum(x[i, j, 1] for j in 1:data.N if data.Adjacent[i, j]) == -1 + x[i, i, 1])
        else
            @constraint(SM, sum(x[j, i, 1] for j in 1:data.N if data.Adjacent[j, i]) == 
                sum(x[i, j, 1] for j in 1:data.N if data.Adjacent[i, j]) + x[i, i, 1] )
        end
        
    end

    # intermediate from 2 to n layers
    for i in 1:data.N
        @constraint(SM, 
            [c in 1:data.Layer[k]-1],
            sum(x[i, j, c+1] for j in 1:data.N if data.Adjacent[i, j]) -
            sum(x[j, i, c+1] for j in 1:data.N if data.Adjacent[j, i]) + x[i, i, c+1] == x[i, i, c]
        )
    end


    # ----------------------------------
    # constraint maximal latency 
    # ----------------------------------
    @constraint(SM, 
        sum( sum(data.LatencyMat[a, 3] * x[round(Int, data.LatencyMat[a, 1]), round(Int, data.LatencyMat[a, 2]), c] 
                for a in 1:data.M) for c in 1:data.Layer[k] ) <= data.Commodity[k, 4]
    )


    # ----------------------------------
    # exclusive constraint
    # ----------------------------------
    if size(data.Affinity[k], 1) == 2
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
        @constraint(SM, [i in 1:data.N], x[i, i, c_] <= 1 - x[i, i, c])
    end


    # ---------------------------------------------------
    # for each layer, exactly one function is installed
    # ---------------------------------------------------
    @constraint(SM, [c in 1:data.Layer[k]], sum(x[i, i, c] for i in 1:data.N) == 1)


    # solve the problem
    set_silent(SM) # turn off cplex output
    optimize!(SM)
    # println(solution_summary(SM))
    
    # status of model
    status = termination_status(SM)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)

    if has_values(SM) #&& isOptimal
        GAP = MOI.get(SM, MOI.RelativeGap())
        println("GAP : ", GAP)
        reduced_cost = objective_value(SM) - α
        println("reduced_cost : ", reduced_cost)

        for c in 1:data.Layer[k]
            print("\tCouche ", c, " -> ")
            sol = [(i,j) for i in 1:data.N, j in 1:data.N if value(x[i, j, c]) > TOL ]
            println(sol)
        end

        println()
        @info "(k, reduced_cost) = ", k, reduced_cost
        
        # the minimum reduced_cost is negative
        if reduced_cost <= -TOL
            new_col = true
            for i in 1:data.N
                for j in 1:data.N
                    for c in 1:data.Layer[k]
                        if value(x[i, j, c]) > TOL
                            χ[i, j, c] = 1
                        end
                    end
                end
            end
        end
    else
        error("col_gen1.jl : sub-problem has no optimal solution !")
    end

    # println("χ : ", χ)
    return (new_col, χ)
end




"""
Algorithm column generation
"""
function column_genaration1(data::Data)
    start = time()
    convergence = []
    # ---------------------
    # step 1 : sol initial
    # ---------------------
    ite = 0
    @info "ite = ", ite
    (solP, obj_val) = cplexSolveMIP(data, false, false)

    global P = [solP[k] for k in 1:data.K]
    # P[k] : [χ1, χ2...] set of paths of commodity k

    for feasib in [0, 1, 2, 3]
        for k in 1:data.K
            println("\n commodity k : ", k, " feasib : ", feasib)
            α = zeros((data.K))
            β = zeros(data.N, data.F)
    
            (new_col, χ) = sub_problem1(data, k, α[k], β, false, feasib)
            # @show new_col, χ
    
            append!(P[k], [χ])
            # @show P[k]
        end
    end

    DW = Inf

    println("\n\n\n")

    # ---------------------
    # step 2 : resolve MP
    # ---------------------
    stop = [false for _ in 1:data.K]
    @show sum(stop)

    while sum(stop) < data.K
        if ite >= MAXITE
            break
        end
        ite += 1
        println("\n\n ---------------")
        @info "ite = $ite"
        println("---------------\n")
        # @show size(P, 1)

        println("\n resolve MP")
        (α, β, LB) = master_problem1(data)

        if LB < DW
            DW = LB
        end
        
        append!(convergence, LB)
    
        # -------------------------
        # step 3 : resolve SP ∀ k
        # -------------------------

        for k in 1:data.K
            println()
            @info "(ite, k) = ", ite, k 

            if !stop[k]
                (new_col, χ) = sub_problem1(data, k, α[k], β)
                # @show (new_col, χ)

                if new_col
                    append!(P[k], [χ])
                    # @show size(P[k], 1)
                else
                    stop[k] = true
                    @info "commodity ", k, "terminates ! \n"
                end
            end
        end
    end

    println()
    @info "Ending with DW = ", DW, " and with ite : ", ite
    println()

    solved_time = round(time() - start, digits = 2)
    @show convergence

    return(round(DW, digits = 2), ite, solved_time)
end