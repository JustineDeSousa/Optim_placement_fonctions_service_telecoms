using CPLEX
using JuMP

model = Model(CPLEX.Optimizer)

"""
n : nombre de sommets
m : nombre d'arcs
F : nombre de fonctions
Source[k in 1:K] : noeud source de chaque client
Destination[k in 1:K] : noeud de destination de chaque client
"""
@variable(model, x[k=1:n, i=1:n, j=1:n], Bin) # =1 si le client k emprunte l'arc (i,j)
@variable(model, y[f=1:F, i=1:n] >= 0) # nombre de fonctions installées au sommet i
@variable(model, v[f=1:F, i=1:n], Bin)
@variable(model, u[i=1:n], Bin) # =1 si au moins une fonction est installée au sommet i

@constraint(model, [k in 1:K], sum( x[k,Source[k],j] for j in succ(Source[k])) - sum( x[k,j,Source[k]] for j in prec(Source[k]) ) == 1 )
@constraint(model, [k in 1:K], sum( x[k,Destination[k],j] for j in succ(Destination[k])) - sum( x[k,j,Destination[k]] for j in prec(Destination[k]) ) == -1 )
@constraint(model, [k in 1:K, i in ], sum( x[k,Destination[k],j] for j in succ(Destination[k])) - sum( x[k,j,Destination[k]] for j in prec(Destination[k]) ) == -1 )