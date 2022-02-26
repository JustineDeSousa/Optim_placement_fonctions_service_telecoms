include("io.jl")

using DataStructures

mutable struct Noeud
	id::Int
	score::Float64 #duree from start to this node
	#h::Int #estimated distance from this node to the node t
	Noeud(id::Int) = new(id, typemax(Float64))
end


function neighbours(nd::Noeud, data::Data)
	voisins = []
	for i in 1:data.N
	   if data.Adjacent[nd.id,i]
		   push!(voisins, Noeud(i))
	   end
   end
   return voisins
end

#For one client
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
		
		for node in neighbours(current_nd, data)
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

function isConflict(data::Data, f1::Int, f2::Int)
	if f1 == f2
		return false
	end
	for k in 1:data.K
		if f1 in data.Affinity[k] && f2 in data.Affinity[k]
			return true
		end
	end
	return false
end

function isConflict(data::Data, functions_node::Vector{Int}, f::Int)
	for fct in functions_node
		if isConflict(data, f, fct)
			return true
		end
	end
	return false
end

function place_functions(data::Data, paths::Vector{Vector{Int}}, max_time::Float64=100.0)
	startingTime = time()

	# Liste des fonctions placées en chaque noeud, éventuellement plusieurs copies
	functions = [ Int[] for _ in 1:data.N]

	#Flux total à faire passer par la fonction f
	flux = [ sum( data.Commodity[k,3]*(sum(data.Order[k].==f) > 0) for k in 1:data.K) for f in 1:data.F ]

	#Number of functions that we need
	nb_functions = [ ceil(Int, flux[f]/data.CapacityFun[f]) for f in 1:data.F ]
	
	#Nombre de fois qu'on passe par ce noeud
	nb_path = [ sum(sum(paths[k].==node) for k in 1:data.K) for node in 1:data.N ]
	
	while sum(nb_functions) > 0 && time() - startingTime < max_time

		f = findmax(nb_functions)[2] #Function that we need the most
		node = findmax(nb_path)[2] #Sommet où on passe le plus

		
		while nb_functions[f] > 0 && time() - startingTime < max_time #While we still need the function
			# println("node = ", node)
			if data.CapacityNode[node] - length(functions[node]) > 0 #if not node_full
				if !isConflict(data,functions[node],f) #if no conflict
					push!(functions[node], f) #We place f at node
					# println("functions[", node, "] = ", functions[node])
					nb_functions[f] -= 1 #We need f one less time
					# println("nb_functions : ", nb_functions)
				else #conflict : next node
					# println("conflict")
					node = findmax(union(nb_path[1:node-1],nb_path[node+1:end]))
				end
			else #node_full
				# println("node full")
				nb_path[node] = 0 #We don't want to place function here anymore
				node = findmax(nb_path)[2] 
			end
		end
		
	end

	return functions
end

function init_solution(data::Data, max_time::Float64=100.0)
	paths = [ find_path(data,k) for k in 1:data.K ]
	return paths, place_functions(data, paths, max_time)
end

