
include("io.jl")

MAXITE = 100


TOL = 0.000001


"""
Restricted master relaxed problem

A new proposed model
"""
function master_problem2(data::Data)
    global P′

    # the number of feasible paths for each commodity k
    sizeP = [size(P′[k], 1) for k in 1:data.K]
    # @show sizeP

    MP = Model(CPLEX.Optimizer)

    # -------------------------------------------
    # relaxed vars y_fi, u_i, b^k_fi, a^k_fi
    # -------------------------------------------
    @variable(MP, y[1:data.F, 1:data.N] ≥ 0)

    @variable(MP, u[1:data.N] ≥ 0)
    @constraint(MP, [i in 1:data.N], u[i] ≤ 1)

    @variable(MP, b[1:data.K, 1:data.F, 1:data.N] ≥ 0)
    @constraint(MP, [k in 1:data.K, f in 1:data.F, i in 1:data.N], b[k, f, i] ≤ 1)

    @variable(MP, a[1:data.K, 1:data.F, 1:data.N] ≥ 0)
    @constraint(MP, [k in 1:data.K, f in 1:data.F, i in 1:data.N], a[k, f, i] ≤ 1)

    @variable(MP, ρ[k=1:data.K, 1:sizeP[k]] ≥ 0) # <=1 redundent as to the convexity constr

    # -------------
    # objective
    # -------------
    @objective(MP, Min, sum(data.CostNode[i] * u[i] for i in 1:data.N) +
                        sum(data.CostFun[f, i] * y[f, i] for f in 1:data.F, i in 1:data.N)
    )

    # ------------
    # convexity
    # ------------
    con_α = @constraint(MP, [k in 1:data.K], sum(ρ[k, p] for p in 1:sizeP[k]) == 1)

    # ----------------------------------------
    # ∀ f, is installed at least at one node
    # ----------------------------------------
    @constraint(MP, [k in 1:data.K, f in Set(data.Order[k])], sum(a[k, f, i] for i in 1:data.N) ≥ 1)

    # -------------------
    # capacity machine
    # -------------------
    @constraint(MP, [i in 1:data.N], sum(y[f, i] for f in 1:data.F) ≤ u[i] * data.CapacityNode[i])

    # --------------------
    # capacity function
    # --------------------
    @constraint(MP, [f in 1:data.F, i in 1:data.N],
        sum(round(Int, data.Commodity[k, 3]) * a[k, f, i] for k in 1:data.K) ≤ data.CapacityFun[f] * y[f, i]
    )

    # --------------------
    # exclusive function
    # --------------------
    for k in 1:data.K
        if size(data.Affinity[k], 1) < 1
            continue
        end
        f1 = 0
        f2 = 0
        for f in data.Order[k]
            if f == data.Affinity[k][1]
                f1 = f
            end
            if f == data.Affinity[k][2]
                f2 = f
            end
        end

        if f1 == 0 || f2 == 0
            error("No correpondent function found ! ")
        end
        @constraint(MP, [i in 1:data.N], a[k, f1, i] + a[k, f2, i] ≤ 1)
    end

    # ---------------------------
    # no f installed before s_k
    # ---------------------------
    @constraint(MP, [k in 1:data.K, f in Set(data.Order[k])], b[k, f, round(Int, data.Commodity[k, 1])] == 0)

    # ---------------------------
    # ∀ f installed before t_k
    # ---------------------------
    @constraint(MP, [k in 1:data.K, f in Set(data.Order[k])], b[k, f, round(Int, data.Commodity[k, 2])] == 1)

    # ----------------------------------------
    # if f is installed after i => f not on i
    # ----------------------------------------
    @constraint(MP, [k in 1:data.K, f in Set(data.Order[k]), i in 1:data.N], a[k, f, i] ≤ b[k, f, i])

    # -------------------
    # ordered placement
    # -------------------
    for k in 1:data.K
        length_f = size(data.Order[k], 1)
        if length_f <= 1
            continue
        end

        for i in 1:length_f-1, j in i+1:length_f
            f1 = data.Order[k][i]
            f2 = data.Order[k][j]
            @constraint(MP, [i in 1:data.N], b[k, f2, i] ≤ b[k, f1, i])
        end

    end

    # ----------------------------------------------------------------------------------
    # ∀ (i,j), f installed on j <=> f not installed before i but exactly installed on j
    # ----------------------------------------------------------------------------------
    #TODO : check if it's correct
    con_μ = @constraint(MP,
        [k in 1:data.K, f in Set(data.Order[k]), arc in 1:data.M],
        sum(ρ[k, p] * P′[k][p][round(Int, data.LatencyMat[arc, 1]), round(Int, data.LatencyMat[arc, 2])]
            for p in 1:sizeP[k]) - 1 +
        b[k, f, round(Int, data.LatencyMat[arc, 2])] - b[k, f, round(Int, data.LatencyMat[arc, 1])] ≤
        a[k, f, round(Int, data.LatencyMat[arc, 2])]
    )

    # -----------------------------------------------
    # f cannot be installed on i if i is not opened
    # -----------------------------------------------
    @constraint(MP, [k in 1:data.K, f in Set(data.Order[k]), i in 1:data.N], a[k, f, i] ≤ u[i])

    # --------------------------------------------
    # f cannot installed on i if no arc passes i
    # --------------------------------------------
    con_ω = @constraint(MP, [k in 1:data.K, f in Set(data.Order[k]), i in 1:data.N], a[k, f, i] ≤
                                                                                     sum(ρ[k, p] * sum(P′[k][p][i, j] + P′[k][p][j, i] for j in 1:data.N if data.Adjacent[i, j]) for p in 1:sizeP[k])
    )


    # solve the problem
    set_silent(MP) # turn off cplex output
    optimize!(MP)

    # status of model
    status = termination_status(MP)
    isOptimal = status == MOI.OPTIMAL

    # display solution
    # println("isOptimal ? ", isOptimal)
    # @info "MP status ", status

    compute_conflict!(MP)

    LB = 0.0

    if has_values(MP) && isOptimal
        LB = objective_value(MP)
        # @info "LB = ", LB
        # println("LB objective ", LB)

        # @show sum(value.(ρ))
        # @show value.(u)
        # @show value.(y)

        for k in 1:data.K, p in 1:sizeP[k]
            if value(ρ[k, p]) > TOL
                # @info "k, p, ρ[k, p]", k, p, ρ[k, p]
            end
        end

    elseif MOI.get(MP, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        conflict_constraint_list = ConstraintRef[]
        for (F, S) in list_of_constraint_types(MP)
            for con in all_constraints(MP, F, S)
                if MOI.get(MP, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                    push!(conflict_constraint_list, con)
                    # println(con)
                end
            end
        end

        error("No conflict could be found for an infeasible model.")
    else
        error("Master problem doesn't have optimal solution !")
    end


    # --------------------
    # get dual variables
    # --------------------
    α = zeros((data.K))
    μ = zeros(data.K, data.F, data.M)
    ω = zeros(data.K, data.F, data.N)

    # @show dual.(con_α)
    # @show dual.(con_μ)
    # @show dual.(con_ω)

    if has_duals(MP)
        for k in 1:data.K

            tmp = collect(Set(data.Order[k]))

            # @show k, tmp

            for fi in 1:size(tmp, 1)
                for arc in 1:data.M
                    μ[k, tmp[fi], arc] = -dual(con_μ[k, tmp[fi], arc])
                end

                for i in 1:data.N
                    ω[k, tmp[fi], i] = dual(con_ω[k, tmp[fi], i])
                end
            end
        end

        return (dual.(con_α), μ, ω, LB)
    else
        # @info has_duals(MP)
        error("col_gen2.jl MP has no dual vars ! ")
        return (α, μ, ω, LB)
    end

end




"""
∀ k, - verify if reduced cost ≤ 0?
    - if yes, return the verctor of arcs (i.e. path for commodity k) 
    - otherwise, nothing 

Returns : 
    - new_col : Bool
    - χ : [i, j] = {0, 1} ∀ ij ∈ A,

Args : 
    - opt : if false, then we generate feasible route only
"""
function sub_problem2(data::Data, k::Int64, α::Float64, μ::Array{Float64,3}, ω::Array{Float64,3}, opt=true, feasib=0)
    new_col = false

    χ = zeros(Int, data.N, data.N)

    SM = Model(CPLEX.Optimizer)

    @variable(SM, x[1:data.N, 1:data.N], Bin)

    if opt
        # println("--------------------optimization--------------------")
        @objective(SM, Min,
            sum(μ[k, f, arc] * x[round(Int, data.LatencyMat[arc, 1]), round(Int, data.LatencyMat[arc, 1])]
                for f in Set(data.Order[k]), arc in 1:data.M
            ) +
            sum(ω[k, f, i] * sum(x[round(Int, data.LatencyMat[arc, 1]), round(Int, data.LatencyMat[arc, 2])]
                                 for arc in 1:data.M if round(Int, data.LatencyMat[arc, 1]) == i || round(Int, data.LatencyMat[arc, 2]) == i
            )
                for f in Set(data.Order[k]), i in 1:data.N
            )
        )

    elseif feasib == 0
        # constant
        # println("--------------------feasible--------------------")
        @objective(SM, Max, -1)

    elseif feasib == 1
        # the shortest path length
        # println("--------------------feasible--------------------")
        @objective(SM, Max, -sum(x))

    elseif feasib == 2
        # the longest path length
        # println("--------------------feasible--------------------")
        @objective(SM, Min, -sum(x))
    end


    # ------------------
    # flux constraints
    # ------------------
    s = round(Int, data.Commodity[k, 1])
    t = round(Int, data.Commodity[k, 2])

    # conversation flux at s
    @constraint(SM, sum(x[s, j] for j in 1:data.N if data.Adjacent[s, j]) -
                    sum(x[j, s] for j in 1:data.N if data.Adjacent[j, s]) == 1
    )

    # conversation flux at t
    @constraint(SM, sum(x[t, j] for j in 1:data.N if data.Adjacent[t, j]) -
                    sum(x[j, t] for j in 1:data.N if data.Adjacent[j, t]) == -1
    )

    # conversation flux at each node
    for i in 1:data.N
        if i == s || i == t
            continue
        end
        @constraint(SM, sum(x[i, j] for j in 1:data.N if data.Adjacent[i, j]) -
                        sum(x[j, i] for j in 1:data.N if data.Adjacent[j, i]) == 0
        )
    end


    # ----------------------------------
    # constraint maximal latency 
    # ----------------------------------
    @constraint(SM,
        sum(data.LatencyMat[arc, 3] * x[round(Int, data.LatencyMat[arc, 1]), round(Int, data.LatencyMat[arc, 2])]
            for arc in 1:data.M) ≤ data.Commodity[k, 4]
    )


    # solve the problem
    set_silent(SM) # turn off cplex output
    optimize!(SM)
    # println(solution_summary(SM))

    # status of model
    status = termination_status(SM)
    isOptimal = status == MOI.OPTIMAL

    # display solution
    # println("isOptimal ? ", isOptimal)

    if has_values(SM)
        GAP = MOI.get(SM, MOI.RelativeGap())
        # println("GAP : ", GAP)
        # println("SM obj_v : ", objective_value(SM))
        reduced_cost = objective_value(SM) - α
        # println("reduced_cost : ", reduced_cost)


        sol = [(i, j) for i in 1:data.N, j in 1:data.N if value(x[i, j]) > TOL]
        # println(sol)


        # println()
        # @info "(k, reduced_cost) = ", k, reduced_cost

        # the minimum reduced_cost is negative
        if reduced_cost <= -TOL
            new_col = true
            for i in 1:data.N, j in 1:data.N
                if value(x[i, j]) > TOL
                    χ[i, j] = 1
                end
            end
        end
    else
        return (new_col, χ)
        @error "col_gen2.jl : sub-problem has no optimal solution !"
    end

    # println("χ : ", χ)
    return (new_col, χ)

end




"""
Algorithm column generation
"""
function column_genaration2(data::Data)

    # ---------------------
    # step 1 : sol initial
    # ---------------------
    ite = 0
    # @info "ite = ", ite
    global P′ = [[] for _ in 1:data.K]
    # P′[k] : [χ1, χ2...] set of paths of commodity k

    for feasib in [0, 1, 2]
        for k in 1:data.K
            # println("\n commodity k : ", k, " feasib : ", feasib)
            α = zeros((data.K))
            μ = zeros(data.K, data.F, data.M)
            ω = zeros(data.K, data.F, data.N)

            (new_col, χ) = sub_problem2(data, k, α[k], μ, ω, false, feasib)
            # @show new_col, χ
            if new_col
                append!(P′[k], [χ])
                # @show P′[k]
            end
        
        end
    end


    start = time()
    convergence = []
    DW2 = Inf

    # println("\n\n\n")

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
        # println("\n\n ---------------")
        # @info "ite = $ite"
        # println("---------------\n")

        # println("\n resolve MP")
        (α, μ, ω, LB) = master_problem2(data)

        if LB < DW2
            DW2 = LB
        end

        append!(convergence, LB)

        # -------------------------
        # step 3 : resolve SP ∀ k
        # -------------------------

        for k in 1:data.K
            # println()
            # @info "(ite, k) = ", ite, k

            if !stop[k]
                (new_col, χ) = sub_problem2(data, k, α[k], μ, ω)
                # @show (new_col, χ)

                if new_col
                    append!(P′[k], [χ])
                    # @show size(P′[k], 1)
                else
                    stop[k] = true
                    # @info "commodity ", k, "terminates ! \n"
                end
            end
        end
    end

    # println()
    # @info "Ending with DW = ", DW2, " and with ite : ", ite
    # println()

    solved_time = round(time() - start, digits=2)
    # @show convergence

    return @show (round(DW2, digits=2), ite, solved_time)


end