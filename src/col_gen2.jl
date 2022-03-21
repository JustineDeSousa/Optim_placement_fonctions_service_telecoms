
MAXITE = 100


TOL = 0.000001

"""
Restricted master relaxed problem
"""
function master_problem2(data::Data)
    global P′
    # println(P′)

    # the number of feasible paths for each commodity k
    sizeP = [size(P′[k], 1) for k in 1:data.K]
    @show sizeP


    MP = Model(CPLEX.Optimizer) 

    # relaxed vars y_fi, u_i, b^k_fi, a^k_fi
    @variable(MP, y[1:data.F, 1:data.N] >= 0)

    @variable(MP, u[1:data.N] >= 0)
    @constraint(MP, [i in 1:data.N], u[i] <= 1)

    @variable(MP, b[1:data.K, 1:data.F, 1:data.N] >= 0)
    @constraint(MP, [k in 1:data.K, f in 1:data.F, i in 1:data.N], b[k, f, i] <= 1)

    @variable(MP, a[1:data.K, 1:data.F, 1:data.N] >= 0)
    @constraint(MP, [k in 1:data.K, f in 1:data.F, i in 1:data.N], a[k, f, i] <= 1)

    @variable(MP, ρ[k=1:data.K, 1:sizeP[k]] >= 0) # <=1 redundent as to the convexity constr

    # convexity
    con_α = @constraint(MP, [k in 1:data.K], sum(ρ[k, p] for p in 1:sizeP[k]) == 1)

    # f is installed at least at one node
    @constraint(MP, [k in 1:data.K, f in ])


end

