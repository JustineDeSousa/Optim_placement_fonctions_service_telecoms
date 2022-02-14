using CPLEX
using JuMP

m = Model(CPLEX.Optimizer)
inst = Instance(true) #true si inst test

#Paramètres#########################################
K = size(inst.commod, 1) #Nombre de clients
n = size(inst.functions, 2)-1 #Nombre de sommets
nb_arcs = size(inst.graph, 1) #Nombre d'arcs
F = size(inst.functions, 1) #Nombre de fonctions
C = [length(inst.orders[k,:]) for k in 1:K] #C[k] = nombre de couches client k
s = [ inst.commod[k,1] for k in 1:K ] #s[k] = noeud de départ client k
t = [ inst.commod[k,2] for k in 1:K ] #t[k] = noeud arrivée client k
####################################################

@variable(m, x[i=1:n, j=1:n, k=1:K, c=1:C[k]], Bin) # =1 si le client k emprunte l'arc (i,j) dans la couche k
@variable(m, y[f=1:F, i=1:n] >= 0) # nombre de fonctions installées au sommet i
@variable(m, v[f=1:F, i=1:n], Bin) # =1 si f installée au sommet i
@variable(m, u[i=1:n], Bin) # =1 si au moins une fonction est installée au sommet i

#Flux de données
function succ(node::Int)
	return [inst.graph[arc,2] for arc in 1:nb_arcs if inst.graph[arc,1] == node]
end
function prec(node::Int)
	return [inst.graph[arc,1] for arc in 1:nb_arcs if inst.graph[arc,2] == node]
end
@constraint(m, [k in 1:K], base_name="Conserv_s",
	sum( sum( x[s[k],j,k,c] for j in succ(s[k])) - sum( x[j, s[k],k,c] for j in prec(s[k]) ) for c in 1:C[k]) == 1)
@constraint(m, [k in 1:K], base_name="Conserv_t",
	sum( sum( x[t[k],j,k,c] for j in succ(s[k])) - sum( x[j, t[k],k,c] for j in prec(s[k]) ) for c in 1:C[k]) == -1)
@constraint(m, [k in 1:K, i=1:n; i!=s[k] && i!=t[k]], base_name="Conserv_k_i",
	sum( sum( x[i,j,k,c] for j in succ(i)) - sum( x[j, i,k,c] for j in prec(i) ) for c in 1:C[k]) == 0)

#Contraintes du pb : capacité, latence
@constraint(m, [k in 1:K], base_name="latence_max",
	sum( sum( inst.graph[arc,5]*x[inst.graph[arc,1],inst.graph[arc,2],k,c] for arc in 1:nb_arcs) for c in 1:C[k]) <= inst.commod[k,4] )
@constraint(m, [i in 1:n, f in 1:F], base_name="capa_funct_i_f",
	sum( sum( x[i,i,k,c] for c in 1:C[k])*inst.commod[k,3] for k in 1:K) <= inst.functions[f]*y[f,i])

function capa_N(node::Int)
	index = findfirst(x->x==node, inst.graph[:,1:2])
	return inst.graph[index[1], index[2]+2]
end
@constraint(m, [i in 1:n], base_name="capa_noeud", sum(  y[f,i] for f in 1:F ) <= capa_N(i) )

#Variables d'installation des fonctions
@constraint(m, [i in 1:n], base_name="instal_function_0", u[i] <= sum( y[f,i] for f in 1:F ) )
@constraint(m, [i in 1:n], base_name="instal_function_1", sum( y[f,i] for f in 1:F) <= typemax(Int)*u[i] )

#Ordre d'utilisation des fonctions
@constraint(m, [i in 1:n, k in 1:K], base_name="couches_diff_i_k_", x[i,i,k,inst.affinity[k,1]] <= 1 - x[i,i,k,inst.affinity[k,2]] )
@constraint(m, [k in 1:K, c in 1:C[k]], base_name="fonc_par_couche_k_c", sum(x[i,i,k,c] for i in 1:n) >= 1 )

#@objective(m, Min, sum( c[i]*u[i] for i in 1:n ) + sum( sum( c[f,i]*y[f,i] for f in 1:F) for i in 1:n) )