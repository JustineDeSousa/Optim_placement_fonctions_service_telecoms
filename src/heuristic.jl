include("io.jl")
TOL=0.00001
using DataStructures #Pour la PriorityQueue
using Random
Random.seed!(1) #initialized the fix random

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

function neighbours(data::Data, nd1::Int64,nd2::Int64)
	voisins = []
	for i in 1:data.N
	   if data.Adjacent[nd1,i] && data.Adjacent[i,nd2]
		   push!(voisins, i)
	   end
   end
   return voisins
end
function neighbours(data::Data, nd::Int64)
	voisins = []
	for i in 1:data.N
	   if data.Adjacent[nd,i]
		   push!(voisins, i)
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
	return any([ AreExcluded(data, f, fct) for fct in functions_node ])
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
	functionsOrder = [ 0 for _ in 1:data.K]
	functions=deepcopy(solution.functions)
	isOrder=Bool[]
	for k in 1:data.K
		order=[]
		path=deepcopy(solution.paths[k])
		for f in data.Order[k]
			needs=Int(ceil(data.Commodity[k,3] / data.CapacityFun[f]))
			for i in 1:needs
				push!(order,f)
			end
		end
		while 1<=length(path)
			if order[1] in functions[path[1]] 
				popfirst!(order)
				if length(order)==0
					break
				end
				
			else
				popfirst!(path)
				
			end
		end
		functionsOrder[k]=length(order)
		#println("debug   ",functionsOrder[k])
		if functionsOrder[k]>0
			push!(isOrder, false)
		end
	end
	ordered=all(isOrder)
	return ordered, functionsOrder

		# for node in solution.paths[k]
		# 	# println("solution.functions[",node,"] : ", solution.functions[node])
		# 	append!(functionsOrder[k], solution.functions[node] )
		# end

		#layers[k] = [f1,f1,f2,f3,...]
	# 	keepTrack = Int[]
	# 	for fct in data.Order[k]
	# 		#println("functionsOrder[",k,"] = ", functionsOrder[k])
	# 		f = popfirst!(functionsOrder[k])
	# 		while true 
	# 			f = popfirst!(functionsOrder[k])
	# 			if fct == f || isempty(functionsOrder[k])
	# 				#println("fct = ", fct, " - f = ", f, " - functionsOrder[",k,"] = ", functionsOrder[k])
	# 				break
	# 			end
	# 		end
	# 		if fct == f
	# 			push!(keepTrack, f)
	# 			#println("keepTrack : ", keepTrack)
	# 			continue
	# 		else #isempty(layers[k])
	# 			return false
	# 		end
	# 	end
	# end
	# return true
end

""" Renvoie true si la solution est réalisable """
function isFeasible(data::Data, solution::Solution)
	areOrdered, orders = areFunctionsOrdered(data,solution)
	return areOrdered && AllFunctionsPlaced(data,solution) && ExclCstRespected(data,solution)
end
"""compute the extra latency of solution"""
function maxLatency(data::Data,solution::Solution)
	maxLatency=0
	for k in 1:data.K
		lat=0
		lat+=sum(data.Latency[solution.paths[k][i],solution.paths[k][i+1]] for i in 1:(length(solution.paths[k])-1))
		if lat>data.Commodity[k,4]+TOL
			maxLatency+=lat-data.Commodity[k,4]
		end
	end
	return maxLatency
end
"""compute the number of constraint violated"""
function nbConstraintsViolated(data::Data, solution::Solution)
	numberConstraints=0
	for node in 1:data.N
		for f in solution.functions[node]
			if isExcluded(data, solution.functions[node], f)
				numberConstraints+=1
			end
		end
	end
	return numberConstraints
end


function neighborhood(data::Data, solution::Solution)
"""Function to generate a neighborhood"""
"""returns a list of new paths neighbor[k] = list of paths for the client k"""
	neighbors=[]
	for k in 1:data.K
		path=deepcopy(solution.paths[k])
		changes=ceil(Int,0.3*length(path))
		nodesToChange=rand(path,changes)
		nodesToChange=filter(x -> x != path[1] && x!=path[length(path)], nodesToChange)
		#println("nodes2change",nodesToChange)
		road=Array{Array{Int,1},1}(undef,0)
		for nodeToChange in nodesToChange
			#nodeToChange=rand(path)
			pos=findfirst(x->x==nodeToChange,path)
			#println("vecinos nodo",ng)
			#println("path ",path)
				#road=deepcopy(paths)
				changePath=deepcopy(solution.paths[k])
				if pos==1
					for node in neighbours(data,path[pos+1])
						changePath[pos]=node
						push!(road,changePath)	
					end
				elseif pos == length(path)
					for node in neighbours(data,path[pos-1])
						changePath[pos]=node
						push!(road,changePath)
					end
				else
					for node in neighbours(data,path[pos-1], path[pos+1])
						changePath[pos]=node
						push!(road,changePath)
					end
				end
		end
		push!(neighbors, road)
	end
	selectedNeighbors=Vector{Vector{Int64}}(undef,0)
	for k in 1:data.K
		latency=100000000
		if length(neighbors[k])==0
			selectRoad=solution.paths[k]
		else
			# for road in neighbors[k]
			# 	lat2=sum(data.Latency[solution.paths[k][i],solution.paths[k][i+1]] for i in 1:(length(solution.paths[k])-1))
			# 	#println("lat2: ",lat2)
			# 	if lat2<latency
			# 		lat2=length(road)
			# 		selectRoad=road
			# 	end
			# end
			selectRoad=rand(neighbors[k])
			#println("aaaaaaaaaaaaaaaaaaaaaaa")
		end
		push!(selectedNeighbors,selectRoad)
	end	
	return selectedNeighbors
end
"""Function to calculate the cost of the heuristic solution"""
function costHeuristic(data::Data, solution::Solution,alpha::Int64=100,beta::Int64=100,gamma::Int64=100)
	costOpenNode=0
	costFunctions=0
	for i in 1:data.N
		if length(solution.functions[i])!=0
			costOpenNode+=data.CostNode[i]
			for f in solution.functions[i]
				costFunctions+=data.CostFun[f,i]
			end
		end
	end	
	costConstV=nbConstraintsViolated(data,solution)
	costExtraLatency=maxLatency(data,solution)
	ord, orderFunc=areFunctionsOrdered(data,solution)
	ordCost=sum(orderFunc)
	finalCost=costOpenNode+costFunctions+alpha*costConstV+beta*costExtraLatency+gamma*ordCost

end

function recuitSimule(data::Data,tInit::Int64=500,nbIt::Int64=50,phi::Float64=0.9,tFloor::Float64=0.1)
	bestSol=init_solution(data,10.0)
	actualSol=deepcopy(bestSol)
	T=tInit
	while  T>=tFloor
		for k in 1:nbIt
			newSol=place_functions(data, neighborhood(data,actualSol), 10.0)
			deltaE=costHeuristic(data,newSol)-costHeuristic(data,actualSol)
			if deltaE<=0
				actualSol=deepcopy(newSol)
				#println("delta: ",deltaE)
				if costHeuristic(data,actualSol)<=costHeuristic(data,bestSol)
					bestSol=deepcopy(actualSol)
				end
			else
				q=rand()
				if q<= exp(-deltaE/T)
					actualSol=deepcopy(newSol)
				end
			end
		end
		T=phi*T
		
	end
	#println("feasible ", isFeasible(data,bestSol))
	if isFeasible(data,bestSol)
		return bestSol
	else
		return orderFunctions(data,bestSol)
	end
end
""" Function to order the placement of functions over a feasible path"""
function orderFunctions(data::Data,solution::Solution)
	functions_ordered=[Int[] for i in 1:data.N]
	nonOrder=[]
	functions=deepcopy(solution.functions)
	for k in 1:data.K
		path=deepcopy(solution.paths[k])
		ordK=Array{Tuple{Int64,Int64}}(undef,0)
		order=[]
		for f in data.Order[k]
			needs=Int(ceil(data.Commodity[k,3] / data.CapacityFun[f]))
			for i in 1:needs
				push!(order,f)
			end
		end
		#println("order : ",order)
		while length(order)!=0
			assign=false
			for i in path
				if order[1] in functions[i] && !isExcluded(data, functions_ordered[i], order[1])  && length(functions_ordered[i])<data.CapacityNode[i]
					assign=true
					push!(ordK,(i,order[1]))
					push!(functions_ordered[i],order[1])
					deleteat!(functions[i],findfirst(x-> x==order[1],functions[i]))
					if (findfirst(x-> x==i,path)-1)>0
						deleteat!(path,1:(findfirst(x-> x==i,path)-1))
					end
					deleteat!(order,1)
					break
				end
			end
			if !assign
				for i in path
					if length(functions[i])!=0 && !isExcluded(data, functions_ordered[i], order[1]) && length(functions_ordered[i])<data.CapacityNode[i]
						push!(ordK,(i,order[1]))
						push!(functions_ordered[i],order[1])
						if (findfirst(x-> x==i,path)-1)>0
							deleteat!(path,1:(findfirst(x-> x==i,path)-1))
						end
						assign=true
						deleteat!(order,1)
						break
					end
				end				
			end
			if !assign
				for i in path
					if !isExcluded(data,functions_ordered[i],order[1])
						push!(ordK,(i,order[1]))
						push!(functions_ordered[i],order[1])
						if (findfirst(x-> x==i,path)-1)>0
							deleteat!(path,1:(findfirst(x-> x==i,path)-1))
						end
						deleteat!(order,1)
						assign=true
						break
					end
				end
			end
			if !assign
				for tup in ordK
					deleteat!(functions_ordered[tup[1]],findfirst(x-> x==tup[2],functions_ordered[tup[1]]))
				end
				push!(nonOrder,k)
				break
			end
		end
	end
	for k in nonOrder
		path=deepcopy( solution.paths[k])
		order=[]
		for f in data.Order[k]
			needs=Int(ceil(data.Commodity[k,3] / data.CapacityFun[f]))
			for i in 1:needs
				push!(order,f)
			end
		end
		for f in order
			for i in path
				if !isExcluded(data, functions_ordered[i], f) && length(functions_ordered[i])<data.CapacityNode[i]
					push!(functions_ordered[i],f)
					if (findfirst(x-> x==i,path)-1)>0
						deleteat!(path,1:(findfirst(x-> x==i,path)-1))
					end
					#deleteat!(order,1)
					break
				end
			end
		end
	end
	solFinal=Solution(solution.paths,functions_ordered)
	println("finSol: ",solFinal)
	return solFinal
end
