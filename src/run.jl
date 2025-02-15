include("mip.jl")
include("col_gen1.jl")
include("col_gen2.jl")
include("heuristic.jl")



""" 
Solve all instances in the folder "data/" 
Write the results in the folder "res/method/"
"""
function solve_instances(method::String; maxTime::Float64=10.0)
    resFolder = "../res/"
    dataFolder = "../data"
    for instanceName in readdir(dataFolder)
        for num in 1:10
            # @info( "-- Resolution of " * instanceName * "_" * string(num))

            folder = resFolder * method * "/" * instanceName
            if !isdir(folder)
                if !isdir(resFolder * method)
                    mkdir(resFolder * method)
                end
                mkdir(folder)
            end
            outputFile = folder * "/" * instanceName * "_" * string(num) * ".txt"

            if !isfile(outputFile) #if the instance hasn't been solved already
                data = Data(instanceName, num)
                if method == "MIP"
                    @info "MIP : " * instanceName * "_" * string(num)
                    @time (paths, cost, resolution_time) = cplexSolveMIP(data)
                    ite = 0
                    paths = []
                    functions = []
                elseif method == "LP"
                    @info "LP : " * instanceName * "_" * string(num)
                    @time (paths, cost, resolution_time) = cplexSolveMIP(data, LP=true)
                    ite = 0
                    functions = []
                elseif method == "DW1"
                    @info "DW1 : " * instanceName * "_" * string(num)
                    @time (cost, ite, resolution_time) = column_genaration1(data::Data)
                    paths = []
                    functions = []
                elseif method == "DW2"
                    @info "DW2 : " * instanceName * "_" * string(num)
                    @time (cost, ite, resolution_time) = column_genaration2(data::Data)
                    paths = []
                    functions = []
                elseif method == "Recuit"
                    @info "Recuit : " * instanceName * "_" * string(num)
                    @time sol = recuitSimule(data, max_time=maxTime)
                    paths = sol.paths
                    functions = sol.functions
                    cost = sol.cost
                    ite = 0
                    resolution_time = round(sol.resolution_time, digit=2)
                else
                    @error "The " * method * " is not supported. Please try one the following : LP, DW1, DW2, MIP or Recuit"
                end
                open(outputFile, "w") do fout
                    println(fout, "paths = ", paths)
                    println(fout, "functions = ", functions)
                    println(fout, "cost = ", cost)
                    println(fout, "nb_it = ", ite)
                    println(fout, "resolution_time = ", resolution_time)
                end
            end
        end
    end

end


function write_table()
    resFolder = "../res/"
    dataFolder = "../data/"
    titles = ["Instances", "PLNE", "LP", "DW1", "DW2", "Recuit Simulé"]
    subtitles = ["", "Temps(s)", "Valeur", "Temps(s)", "Valeur","GAP", "Temps(s)", "Valeur","GAP", "Temps(s)", "Valeur","GAP", "Temps(s)", "Valeur", "GAP"]
    rows = Vector{String}[]
    for instanceName in readdir(dataFolder)
        for num in 1:10
            value_MIP = 0
            line = String[instanceName * "\\_" * string(num)]
            for method in ["MIP/", "LP/", "DW1/", "DW2/", "Recuit/"]
                instance = resFolder * method * instanceName * "/" * instanceName * "_" * string(num) * ".txt"
                println(instance)
                if isfile(instance)
                    include(instance)
                    results = [ string(resolution_time), string(cost) ]
                    if method == "MIP/"
                        value_MIP = cost
                    elseif 0 < value_MIP < Inf
                        GAP = round(abs(cost - value_MIP)/value_MIP * 100, digits = 2)
                        push!(results, string(GAP) * "\\%")
                    else
                        push!(results, "-")
                    end
                elseif method == "MIP/"
                    results = ["-", "-"]
                else
                    results = ["-", "-", "-"]
                end
                append!( line, results )
                
            end
            push!(rows,line)
        end
    end
    write_table_tex("../res/mip_bounds", "Comparaison entre les bornes obtenues et la valeur optimale", 
    titles, rows, num_col_titles = [1,2,3,3,3,3], subtitles = subtitles, alignments = "c|cc|ccc|ccc|ccc|ccc", maxRawsPerPage=40)
end


# solve_instances("MIP")
# solve_instances("LP")
# solve_instances("DW1")
# solve_instances("DW2")
# solve_instances("Recuit")
# write_table()
# performanceDiagram("../res/diagram")
