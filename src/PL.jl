include("header.jl")
using CPLEX
using JuMP

m = Model(CPLEX.Optimizer)
inst = Instance(true) #true si inst test

#Paramètres####################################################################
K = size(inst.commod, 1) #Nombre de clients
n = size(inst.functions, 2)-1 #Nombre de sommets
nb_arcs = size(inst.graph, 1) #Nombre d'arcs
F = size(inst.functions, 1) #Nombre de fonctions
C = [length(inst.orders[k,:]) for k in 1:K] #C[k] = nombre de couches client k
s = [ inst.commod[k,1] for k in 1:K ] #s[k] = noeud de départ client k
t = [ inst.commod[k,2] for k in 1:K ] #t[k] = noeud arrivée client k
###############################################################################

@variable(m, x[i=1:n, j=1:n, k=1:K, c=1:C[k]], Bin) # =1 si le client k emprunte l'arc (i,j) dans la couche c
@variable(m, y[f=1:F, i=1:n] >= 0, Int) # nombre de fonctions installées au sommet i
@variable(m, v[f=1:F, i=1:n], Bin) # =1 si f installée au sommet i
@variable(m, u[i=1:n], Bin) # =1 si au moins une fonction est installée au sommet i

#Flux de données
function succ(node::Int)
	return [inst.graph[arc,2] for arc in 1:nb_arcs if inst.graph[arc,1] == node]
end


function prec(node::Int)
	return [inst.graph[arc,1] for arc in 1:nb_arcs if inst.graph[arc,2] == node]
end
conserv_s = @constraint(m, [k in 1:K], base_name="conserv_s",
	sum( sum( x[s[k],j,k,c] for j in succ(s[k])) - sum( x[j, s[k],k,c] for j in prec(s[k]) ) - x[s[k],s[k],k,c] for c in 1:C[k]) == 1)
conserv_t = @constraint(m, [k in 1:K], base_name="conserv_t",
	sum( sum( x[t[k],j,k,c] for j in succ(s[k])) - sum( x[j, t[k],k,c] for j in prec(s[k]) ) - x[t[k],t[k],k,c] for c in 1:C[k]) == -1)
conserv = @constraint(m, [k in 1:K, i=1:n; i!=s[k] && i!=t[k]], base_name="Conserv_k_i",
	sum( sum( x[i,j,k,c] for j in succ(i)) - sum( x[j, i,k,c] for j in prec(i) ) for c in 1:C[k]) == 0)

#Contraintes du pb : capacité, latence
latence = @constraint(m, [k in 1:K], base_name="latence_max",
	sum( sum( inst.graph[arc,5]*x[inst.graph[arc,1],inst.graph[arc,2],k,c] for arc in 1:nb_arcs) for c in 1:C[k]) <= inst.commod[k,4] )
capa_function = @constraint(m, [f in 1:F, i in 1:n], base_name="capa_funct_f_i",
	sum( sum( x[i,i,k,c] for c in 1:C[k])*inst.commod[k,3] for k in 1:K) <= inst.functions[f,1]*y[f,i])



function capa_N(node::Int)
	index = findfirst(x->x==node, inst.graph[:,1:2])
	return inst.graph[index[1], index[2]+2]
end
# capa_node = @constraint(m, [i in 1:n], base_name="capa_noeud", sum(  y[f,i] for f in 1:F ) <= capa_N(i) )

#Variables d'installation des fonctions
@constraint(m, [i in 1:n], base_name="instal_function_0", u[i] <= sum( y[f,i] for f in 1:F ) )
@constraint(m, [i in 1:n], base_name="instal_function_1", sum( y[f,i] for f in 1:F) <= typemax(Int)*u[i] )

#Ordre d'utilisation des fonctions
exclusion = @constraint(m, [i in 1:n, k in 1:K], base_name="exclusion_i_k_", x[i,i,k,inst.affinity[k,1]] <= 1 - x[i,i,k,inst.affinity[k,2]] )
couche = @constraint(m, [k in 1:K, c in 1:C[k]], base_name="couche_k_c", sum(x[i,i,k,c] for i in 1:n) == 1 )

#Objectif
function node_cost(node::Int)
	index = findfirst(x->x==node, inst.graph[:,1])
	return inst.graph[index[1], 6]
end
@objective(m, Min, sum( node_cost(i)*u[i] for i in 1:n ) + sum( sum( inst.functions[f,i+1]*y[f,i] for f in 1:F) for i in 1:n) )

optimize!(m)
if termination_status(m) == OPTIMAL
    println("Solution is optimal")
elseif termination_status(m) == TIME_LIMIT && has_values(m)
    println("Solution is suboptimal due to a time limit, but a primal solution is available")
else
    error("The model was not solved correctly.")
end
println("  objective value = ", objective_value(m))
for k in 1:K
	println("Client ", k, " : ")
	for c in 1:C[k]
		print("\tCouche ", c, " -> ")
		solution = [(i,j) for i in 1:n, j in 1:n if value(x[i,j,k,c]) > 0 ]
		println(solution)
	end
end

