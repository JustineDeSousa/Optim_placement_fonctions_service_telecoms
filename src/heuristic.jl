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

