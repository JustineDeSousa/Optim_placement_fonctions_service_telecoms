include("io.jl")

using DataStructures

mutable struct Noeud
	id::Int
	score::Float64 #duree from start to this node
	#h::Int #estimated distance from this node to the node t
	Noeud(id::Int) = new(id, typemax(Float64))
end


function neighbours(nd::Int, data::Data)
	voisins = []
	for i in 1:data.N
	   if data.Adjacent[nd,i]
		   push!(voisins, i)
	   end
   end
   return voisins
end

#For one client
function find_path(data::Data, k::Int)
	
	s = data.Commodity[k,1]
	t = data.Commodity[k,2]
	s.score = 0
	open_list = PriorityQueue{Int, Float64}() #nodes visited who's neighbours haven't been inspected
	enqueue!(open_list, s, s.score)
	closed_list = [] #nodes visited who's neighbours have been inspected
	
	parents = zeros(Int, data.N)
	parents[s] = s
	start = time()
	
	while length(open_list) > 0 && time() - start < max_time
		
		current_nd = dequeue!(open_list) #noeud de plus petit score
		
		if current_nd == t #we've reached the end
			path = []
			inst.solved = true
			while parents[current_nd] != current_nd #reconstructing the path_
				push!(path, current_nd)
				current_nd = parents[current_nd]
			end
			
			return reverse(push!(path, s))
		end
		
		for node in neighbours(current_nd, data)
			# distance of the path_ from start to node by current_nd (minimal and robust)
			score = current_nd.score + data.LatencyMat[current_nd, node]*(1+inst.D[current_nd, node])
			score_poids = inst.nodes[current_nd].score_poids + inst.p[node] 
			score_poids_ph = score_poids + 2*inst.ph[node]			
			score = score_poids_ph + score_duree
			
			if (inst.nodes[node].score_duree +  inst.nodes[node].score_poids <= score)#On a déjà trouvé un meilleur chemin par current_nd to node
				continue
			elseif score_poids > inst.S			
				continue			
			else # On a trouvé chemin depuis current_nd vers node qui ne dépasse pas S et de meilleur score
				inst.nodes[node].score_duree = score_duree
				inst.nodes[node].score_poids = score_poids
				parents[node] = current_nd
				if !(node in keys(open_list))
					enqueue!(open_list, node, score)
				end
				if node in closed_list
					deleteat!(closed_list, findall(x->x==node, closed_list))
				end
			end
		end #for neighbours
		
		if !(current_nd in closed_list)
			push!(closed_list, current_nd)
		end
	end #while
	
	inst.solved = false
	if time() - start >= max_time
		inst.diagnostic = "OUT_OF_TIME"
	else
		inst.diagnostic = "EMPTY_OPEN_LIST"
	end
	return inst
end

function repare_poids!(inst::Instance)
	"""
	Calcul le pire des cas pour l'augmentation des poids des sommets sur le trajet solution
	"""
	model = Model(CPLEX.Optimizer)
	set_silent(model)
	@variable(model, poids[1:length(inst.path_)] >= 0)
	@constraint(model, sum(poids) <= inst.d2)
	@constraint(model, [k=1:length(inst.path_)], poids[k] <= 2 )
	@objective(model, Max, sum(poids))
	optimize!(model)
	inst.poids = value.(poids)
	if primal_status(model) == NO_SOLUTION
		inst.diagnostic = "ROBUST_WEIGHTS_PB"
		return false
	else
		return true
	end
end
function repare_delta!(inst::Instance)
	"""
	Calcul le pire des cas pour l'augmentation de la durée des arcs sur le trajet solution
	"""
	arcs = [i for i in 1:length(inst.path_)-1]
	sommets = [(inst.path_[i], inst.path_[i+1]) for i in 1:length(arcs)]
	
	model = Model(CPLEX.Optimizer)
	set_silent(model)
	@variable(model, delta[1:length(arcs)] >= 0)
	@constraint(model, sum(delta) <= inst.d1)
	@constraint(model, [k=1:length(arcs)], delta[k] <= inst.D[sommets[k][1], sommets[k][2]] )
	@objective(model, Max, sum(delta))
	optimize!(model)
	inst.delta = value.(delta)
	if primal_status(model) == NO_SOLUTION
		inst.diagnostic = "ROBUST_DURATION_PB"
		return false
	else
		return true
	end
end


function heuristic(instance::String, max_time::Float64)
	inst = Instance("../instances/$instance")
	start = time()
	inst = a_star_algorithm(inst, max_time)
	inst.res_time = time() - start
	obj = 0
	if length(inst.path_) == 0
		obj = -1
	else
		obj = obj_value(inst)
	end
	GAP = 0.0
	if inst.res_time > max_time
		GAP = 100.0
	end
	return inst.path_, obj, inst.res_time, inst.solved, " \"" * inst.diagnostic * "\"", GAP
end

