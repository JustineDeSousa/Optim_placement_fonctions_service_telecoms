include("io.jl")

using DataStructures #Pour la PriorityQueue

""" Renvoie l'ensemble des voisins de nd dans le graphe data.Adjacent"""
function neighbours(data::Data, nd::Noeud)
	voisins = []
	for i in 1:data.N
	   if data.Adjacent[nd.id,i]
		   push!(voisins, Noeud(i))
	   end
   end
   return voisins
end

""" Renvoie un chemin de s_k à t_k """
function find_path(data::Data, k::Int, max_time::Float64=100.0)
	#Initialisation
	s = Noeud(Int(data.Commodity[k,1]))
	t = Noeud(Int(data.Commodity[k,2]))
	s.score = 0
	path = Int[]

	#nodes visited who's neighbours haven't been inspected
	open_list = PriorityQueue{Noeud, Float64}() 
	enqueue!(open_list, s, s.score)

	#nodes visited who's neighbours have been inspected
	closed_list = [] 
	
	#reconstruction du chemin
	parents = Dict{Noeud,Noeud}()
	parents[s] = s

	solved = false
	start = time()
	
	while length(open_list) > 0 && time() - start < max_time
		
		current_nd = dequeue!(open_list) #noeud de plus petit score

		if !(current_nd in closed_list)
			push!(closed_list, current_nd)
		end

		if current_nd.id == t.id #we've reached the end
			solved = true
			while parents[current_nd] != current_nd #reconstructing the path_
				push!(path, current_nd.id)
				current_nd = parents[current_nd]
			end
			
			return reverse(push!(path, s.id))
		end
		
		for node in neighbours(data,current_nd)
			# distance from start to node by current_nd (minimal and robust)
			score = current_nd.score + data.Latency[current_nd.id, node.id]
			
			#On a déjà trouvé un meilleur chemin par current_nd to node
			if node.score <= score
				continue			
			else # On a trouvé chemin depuis current_nd vers node de meilleur score
				node.score = score
				parents[node] = current_nd
				
				#Add neighbours to open_list
				if !(node in keys(open_list))
					enqueue!(open_list, node, score)
				end
				#Remove neighbours from closed list
				if node in closed_list
					deleteat!(closed_list, findall(x->x==node, closed_list))
				end
			end
		end #for neighbours		
	end #while
	
	solved = false
	if time() - start >= max_time
		diagnostic = "OUT_OF_TIME"
	else
		diagnostic = "EMPTY_OPEN_LIST"
	end
	return path
end


""" Renvoie true si f1 et f2 sont dans les contraintes d'exclusion """
function AreExcluded(data::Data, f1::Int, f2::Int)
	return f1 != f2 && any( [f1 in data.Affinity[k] && f2 in data.Affinity[k] for k in 1:data.K ])
end

""" Renvoie true si f est en conflit avec l'une des fonctions déjà placée """
function isExcluded(data::Data, functions_node::Vector{Int}, f::Int)
	return any([ isConflict(data, f, fct) for fct in functions_node ])
end

"""
Place autant de fonctions que nécessaire sur le chemin des clients pour remplir leurs demandes
"""
function place_functions(data::Data, paths::Vector{Vector{Int}}, max_time::Float64=100.0)
	startingTime = time()

	# Liste des fonctions placées en chaque noeud, éventuellement plusieurs copies
	functions = [ Int[] for _ in 1:data.N]

	#Flux total à faire passer par la fonction f
	flux = [ sum( data.Commodity[k,3]*(sum(data.Order[k].==f) > 0) for k in 1:data.K) for f in 1:data.F ]

	#Number of functions that we need for each type of function
	nb_functions = [ ceil(Int, flux[f]/data.CapacityFun[f]) for f in 1:data.F ]
	
	#Nombre de fois qu'on passe par chaque noeud
	nb_path = [ sum(sum(paths[k].==node) for k in 1:data.K) for node in 1:data.N ]
	
	while sum(nb_functions) > 0 && time() - startingTime < max_time

		f = findmax(nb_functions)[2] #Function that we need the most
		node = findmax(nb_path)[2] #Sommet où on passe le plus
		
		while nb_functions[f] > 0 && time() - startingTime < max_time #While we still need the function
			# println("node ", node)
			if data.CapacityNode[node] - length(functions[node]) > 0 #if not node_full
				if !isExcluded(data,functions[node],f) #if no conflict
					push!(functions[node], f) #We place f at node
					# println("functions[", node, "] = ", functions[node])
					nb_functions[f] -= 1 #We need f one less time
					# println("nb_functions : ", nb_functions)
				else #conflict : next node
					# println("conflict")
					node = findmax(union(nb_path[1:node-1],nb_path[node+1:end]))[2]
				end
			else #node_full
				# println("node full")
				nb_path[node] = 0 #We don't want to place function here anymore
				node = findmax(nb_path)[2]
			end
		end
		
	end

	return Solution(paths, functions)
end

""" 
Renvoie une solution initiale admissible en ignorant les 
contraintes d'ordre sur les fonctions
"""
function init_solution(data::Data, max_time::Float64=100.0)
	paths = [ find_path(data,k) for k in 1:data.K ]
	return place_functions(data, paths, max_time)
end

""" 
Renvoie true si 
	∀ client k, toutes les fonctions f commandées par k sont 
	placées sur son chemin
"""
function AllFunctionsPlaced(data::Data, solution::Solution)
	return all([all([any([ f in solution.functions[node] 
						for node in solution.paths[k] ]) 
					for f in data.Order[k] ] ) 
				for k in 1:data.K ])
end

""" Renvoie true toutes les contraintes d'exclusion sont respectées """
function ExclCstRespected(data::Data, solution::Solution)
	return all(!,[any([ isExcluded(data, solution.functions[node], f) 
					for f in solution.functions[node]] ) 
				for node in 1:data.N ])
end

""" Return true if the solution is feasible (without regarding the order csts) """
function isPartiallyFeasible(data::Data, solution::Solution)
	return AllFunctionsPlaced(data,solution) && ExclCstRespected(data,solution)
end

""" Return true if the solution respect the cst of orders """                                           


function areFunctionsOrdered(data::Data, solution::Solution)
	functionsOrder = [ Int[] for _ in 1:data.K]
	
	for k in 1:data.K
		for node in solution.paths[k]
			# println("solution.functions[",node,"] : ", solution.functions[node])
			append!(functionsOrder[k], solution.functions[node] )
		end

		#layers[k] = [f1,f1,f2,f3,...]
		keepTrack = Int[]
		for fct in data.Order[k]
			println("functionsOrder[",k,"] = ", functionsOrder[k])
			f = popfirst!(functionsOrder[k])
			while true 
				f = popfirst!(functionsOrder[k])
				if fct == f || isempty(functionsOrder[k])
					println("fct = ", fct, " - f = ", f, " - functionsOrder[",k,"] = ", functionsOrder[k])
					break
				end
			end
			if fct == f
				push!(keepTrack, f)
				println("keepTrack : ", keepTrack)
				continue
			else #isempty(layers[k])
				return false
			end
		end
	end
	return true
end

""" Renvoie true si la solution est réalisable """
function isFeasible(data::Data, solution::Solution)
	return areFunctionsOrdered(data,solution) && AllFunctionsPlaced(data,solution) && ExclCstRespected(data,solution)
end

function neighborhood(data::Data, paths::Vector{Vector{Int}},functions::Vector{Vector{Int}})
##Function to generate a neighborhood##
##returns a list of new paths neighbor[k] = list of paths for the client k##
	neighbors=[]
	for k in 1:data.K
		path=deepcopy(paths[k])
		changes=ceil(Int,0.3*length(path))
		nodesToChange=rand(path,changes)
		println("nodes2change",nodesToChange)
		road=Array{Array{Int,1},1}(undef,0)
		for nodeToChange in nodesToChange
			#nodeToChange=rand(path)
			pos=findfirst(x->x==nodeToChange,path)
			ng=neighbours2(nodeToChange, data)
			println("vecinos nodo",ng)
			println("path ",path)
			for node in ng
				#road=deepcopy(paths)
				changePath=deepcopy(paths[k])
				if pos==1
					if path[pos+1] in neighbours2(node,data)
						changePath[pos]=node
						push!(road,changePath)	
					end
				elseif pos == length(path)
					if path[pos-1] in neighbours2(node,data)
						changePath[pos]=node
						push!(road,changePath)
					end
				elseif path[pos-1] in neighbours2(node,data) && path[pos+1] in neighbours2(node,data)
					changePath[pos]=node
					push!(road,changePath)
				end
				#road[k]=path
				#push!(neighbors, road)
			end
			
		end
		push!(neighbors, road)
	end
#	for k in 1:data.K
#		println("road ",neighbors[k])
#		end
	return neighbors
end
