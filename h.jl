 # HEADER

using DelimitedFiles

 
function read_Graph(fichier::String)
	data = readdlm(fichier, ' ')
	nb_nodes = data[2,2]
	nb_arcs = data[3,2]
	client = []
	for k in 1:size(data,1)-3
		push!(client, data[k+3,:])
	end
    
    return nb_nodes, nb_arcs, client
end
