 # HEADER

using DelimitedFiles

 
function read_Graph(instance::String)
	file = instance * "\\Graph.txt"
	data = readdlm(file, ' ')
	nb_nodes = data[2,2]
	nb_arcs = data[3,2]
	Node_1 = data[4:end,1]
	Node_2 = data[4:end,2]
	Capacity_node1 = data[4:end,3]
	Capacity_node2 = data[4:end,4]
	Latency_arc = data[4:end,5]
    
	return nb_nodes, nb_arcs, Node_1, Node_2, Capacity_node1, Capacity_node2, Latency_arc
end

function read_Commodity(instance::String)
	file = instance * "\\Commodity.txt"
	data = readdlm(file, ' ')
	nb_commodities = data[2,2]
	Source = data[3:end,1]
	Destination = data[3:end,2]
	Bandwidth = data[3:end,3]
	Latency = data[3:end,4]
	
    return nb_commodities, Source, Destination, Bandwidth, Latency
end

function read_Functions(instance::String)
	file = instance * "\\Functions.txt"
	data = readdlm(file, ' ')
	nb_functions = data[2,2]
	capacities = data[3:end, 1]
	cost_by_node = data[3:end, 2:end] #cost_by_node[i,j] = cout poser f_i au noeud j

	return nb_functions, capacities, cost_by_node
end

function read_Fct_Commod()
	file = instance * "\\Functions.txt"
	return readdlm(file, ' ')
	
end

function read_Affinity()
	file = instance * "\\Affinity.txt"
	return readdlm(file, ' ')
end

function read_instance(name::String, num::Int)
	instance = "instances\\" * instance * "\\" instance * "_" * num
	nb_nodes, nb_arcs, Node_1, Node_2, Capacity_node1, Capacity_node2, Latency_arc = read_Graph(instance)
	nb_commodities, Source, Destination, Bandwidth, Latency = read_Commodity(instance)
	nb_functions, capacities, cost_by_node = read_Functions(instance)
	orders = read_Fct_Commod(instance)
	affinity = read_Affinity(instance)
	
end
