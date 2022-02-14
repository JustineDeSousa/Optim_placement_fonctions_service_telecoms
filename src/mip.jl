# This file contains functions solving the multi-commodities problem using CPLEX solver
include("io.jl")


TOL = 0.00001


function cplexSolveMIP(data::Data)
    # modelization
    M = Model(CPLEX.Optimizer) 

    # variable
    @variable(M, x[i=1:data.N, j=1:data.N, k=1:data.K, c=1:data.Layer[k]], Bin)
    @variable(M, y[1:data.F, 1:data.N] >= 0, Int)
    #@variable(M, v[1:data.F, 1:data.N], Bin)
    @variable(M, u[1:data.N], Bin)

    # objective function
    @objective(M, Min, sum(data.CostNode[i] * u[i] for i in 1:data.N) +
        sum(data.CostFun[f, i] * y[f, i] for f in 1:data.F, i in 1:data.N))

    
    # ------------------
    # flux constraints
    # ------------------
    for k in 1:data.K
        s = round(Int, data.Commodidty[k, 1])
        t = round(Int, data.Commodidty[k, 2])

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

    end


    # constraint maximal latency 
    @constraint(M, [k in 1:data.K], sum( sum(data.LatencyMat[a, 3] * x[round(Int, data.LatencyMat[a, 1]), round(Int, data.LatencyMat[a, 2]), k, c]
    for a in 1:data.M) for c in 1:data.Layer[k] ) <= data.Commodidty[k, 4])
    


    #TODO : for each layer, jump at most one vertex
    function lay(k::Int64,f::Int64, data::Data)
        for i in 1:data.Layer[k]
            println(data.Order[k][i])
            println("f",f)
            if f==data.Order[k][i]
                println("---------")
                return i
            end
        end
        return data.Layer[k]+1
    end

    # constraint function capacitiy
    @constraint(M, [i in 1:data.N, f in 1:data.F], sum( sum(x[i, i, k, c] for c in 1:data.Layer[k] if c==lay(k,f,data))
        * round(Int, data.Commodidty[k, 3]) for k in 1:data.K) <= data.CapacityFun[f] * y[f, i])
    
    # constraint machine capacity
    @constraint(M, [i in 1:data.N], sum(y[f, i] for f in 1:data.F) <= data.CapacityNode[i])


    # constraint of variable u
    @constraint(M, [i in 1:data.N], u[i] <= sum(y[f, i] for f in 1:data.F))
    @constraint(M, [i in 1:data.N], u[i] * 10000000 >= sum(y[f, i] for f in 1:data.F))


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
    @constraint(M, [k in 1:data.K, c in 1:data.Layer[k]], sum(x[i, i, k, c] for i in 1:data.N) >= 1)



    # solve the problem
    optimize!(M)

    #exploredNodes = MOI.get(backend(M), MOI.NodeCount())
    
    solveTime = MOI.get(M, MOI.SolveTime())

    # status of model
    status = termination_status(M)
    isOptimal = status==MOI.OPTIMAL

    # display solution
    println("isOptimal ? ", isOptimal)
    println("solveTime = ", solveTime)
    println("status = ", status)

    if has_values(M)
        GAP = MOI.get(M, MOI.RelativeGap())
        obj_val = objective_value(M)
        best_bound = objective_bound(M)

        println("obj_val = ", obj_val)
        println("best_bound = ", best_bound)
        println("GAP = ", GAP)
        for k in 1:data.K
            println("Client ", k, " : ")
            for c in 1:data.Layer[k]
                print("\tCouche ", c, " -> ")
                solution = [(i,j) for i in 1:n, j in 1:n if value(x[i,j,k,c]) > 0 ]
                println(solution)
            end
        end
        println("y = ", value.(y))

    end


end