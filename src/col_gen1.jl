# This file contains functions solving the multi-commodities problem using CPLEX solver
# by approach column generation
#TODO : 1) master_problem; 2) dual vars; 3) initial sols; 4) sub_problem

include("mip.jl")


TOL = 0.00001


function master_problem()
    
end




"""
∀ k, - verify if reduced cost ≤ 0?
    - if yes, return the verctor of arcs (i.e. path for commodity k) 
    - otherwise, nothing 

Returns : 
    - new_col : Bool
    - path : [x[i, j] ∀ ij ∈ A]
"""
#TODO : dual vars
function sub_problem(data::Data, k::Int64, α::Float64, β::Array{Float64,2}, opt = true)
    new_col = false
    path = zeros(Int, (data.M)) # not sure

    SM = Model(CPLEX.Optimizer) 

    @variable(SM, x[i=1:data.N, j=1:data.N, c=1:data.Layer[k]], Bin)


    function lay(k::Int64,f::Int64, data::Data)
        """ return a list of layers where f appears for commodity k"""
        return [l for l in 1:data.Layer[k] if data.Order[k][l] == f]
    end

    if opt
        #TODO : objective reduced cost
        println("--------------------optimization--------------------")
        @objective(SM, 
            Min, 
            -(α + sum(β[i, f] * x[i, i, c] for i in 1:data.N, f in 1:data.Order[k], c in lay(k, f, data) ))
        )
    else
        # constant objective for feasible sol only
        println("--------------------feasible--------------------")
        @objective(SM, Min, 1)
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
    optimize!(SM)
    println(solution_summary(SM))
    
    # status of model
    status = termination_status(SM)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)

    if has_values(SM) && isOptimal
        GAP = MOI.get(SM, MOI.RelativeGap())
        println("GAP : ", GAP)
        reduced_cost = objective_value(SM)
        println("reduced_cost : ", reduced_cost)

        for c in 1:data.Layer[k]
            print("\tCouche ", c, " -> ")
            sol = [(i,j) for i in 1:data.N, j in 1:data.N if value(x[i, j, c]) > TOL ]
            println(sol)
        end

        if reduced_cost <= TOL
            # TODO : generate path and return
            new_col = true
        end

    end

    return (new_col, path)
end



#TODO : verification feasibility of sub_problem
