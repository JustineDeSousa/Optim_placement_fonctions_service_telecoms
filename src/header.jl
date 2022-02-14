 # HEADER
using DelimitedFiles


mutable struct Instance
	#ATTRIBUTS	
	graph::Matrix{Int} # Une ligne par arc: (noeud départ, noeud arrivée, capaN départ, capaN arrivée, latence)
	commod::Matrix{Int} # Une ligne par commodité: (noeud départ, noeud arrivée, qté données, latence max)
	functions::Matrix{Int} # Une ligne par fonction: (capacité, coûts de placement en chaque noeud)
	orders::Matrix{Int} # Une ligne par comomodité:fonctions dans l'odre dans lequel elles doivent être executées
	affinity::Matrix{Int} # Une ligne par comomodité: un couple de fonctions qui ne peuvent pas être installées sur un même noeud 
	# Constructeur
	function Instance(test::Bool=false, name::String="", num::Int=1)
		if test
			instance = "../instances_test/test_"
		else
			instance = "../instances/" * name * "/" * name * "_" * num * "/"
		end
		#Graph
		graph = readdlm(instance * "Graph.txt", ' ', Int, '\n', skipstart=3)
		graph[:,1:2] = graph[:,1:2] .+1
		#Commod
		commod = readdlm(instance * "Commodity.txt", ' ', Int, '\n'; skipstart = 2)
		commod[:,1:2] = commod[:,1:2].+1
		#Functions
		functions =  readdlm(instance * "Functions.txt", ' ', Int, '\n'; skipstart=2)
		#Orders
		orders = readdlm(instance * "Fct_commod.txt", ' ', Int, '\n') .+1
		#Affinity
		affinity = readdlm(instance * "Affinity.txt", ' ', Int, '\n') .+1
		#Instance
		new(graph, commod, functions, orders, affinity)
	end

end
instance = "../instances_test/test_";
inst = Instance(true)