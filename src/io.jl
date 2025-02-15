# using Plots
# This file contains function reading instances

mutable struct Data
    N::Int64 # the number of vertices
    M::Int64 # the number of arcs
    Adjacent::BitArray{2}
    LatencyMat::Array{Float64,2} # matrix latency [u, v, latency]
    Latency::Array{Float64,2} # Latency[u,v] = l_{uv}
    CapacityNode::Array{Int64,1} # capacity *functions* of each vertex
    CostNode::Array{Int64,1} # openning cost of each vertex

    K::Int64 # the number of Commodidties
    Commodity::Array{Float64,2} #[s, t, flux, latencyMax]

    F::Int64 # the number of functions
    CapacityFun::Array{Int64,1} # capacity *flux* of each function
    CostFun::Array{Int64,2} # cost of fun on node u = CostFun[fun, u]

    Order::Array{Array{Int64,1},1} # Order[k] : the list of functions ordered for commodity k
    Layer::Array{Int64,1} # the number of layers of each commodity

    Affinity::Array{Array{Int64,1},1} # Affinity[k] : the list of functions exclusive for commodity k

    # Constructeur
    function Data(name::String="", num::Int=1, small_test::Bool=false)
        if small_test
            instance = "../small_data/" * name * "/" * name * "_"
        else
            instance = "../data/" * name * "/" * name * "_$num" * "/"
        end


        # ---------------------
        # reading "Graph.txt"
        # ---------------------
        # println("reading ", instance * "Graph.txt")
        datafile = open(instance * "Graph.txt")
        readline(datafile)
        N = parse(Int64, split(readline(datafile), " ")[2])
        CapacityNode = [0 for _ in 1:N]
        CostNode = [0 for _ in 1:N]
        Adjacent = falses(N, N)

        M = parse(Int64, split(readline(datafile), " ")[2])
        data = readlines(datafile)
        close(datafile)
        LatencyMat = Array{Float64,2}(undef, 0, 3)
        Latency = zeros(N, N)

        for eachLine in data
            line = split(eachLine, " ")
            for i in 1:size(line, 1)
                if line[i] == ""
                    splice!(line, i)
                    break
                end
            end

            u = parse(Int64, line[1]) + 1
            v = parse(Int64, line[2]) + 1
            Adjacent[u, v] = true

            if CapacityNode[u] == 0
                CapacityNode[u] = parse(Int64, line[3])
            end

            if CapacityNode[v] == 0
                CapacityNode[v] = parse(Int64, line[4])
            end

            LatencyMat = vcat(LatencyMat, [u v parse(Float64, line[5])])
            Latency[u, v] = parse(Float64, line[5])

            if CostNode[u] == 0
                CostNode[u] = parse(Int64, line[6])
            end
        end


        # ---------------------
        # reading "Commodity.txt"
        # ---------------------
        # println("reading ", instance * "Commoodity.txt")
        Commodity = Array{Float64,2}(undef, 0, 4) #TODO : category
        datafile = open(instance * "Commodity.txt")
        readline(datafile)
        K = parse(Int64, split(readline(datafile), " ")[2])
        data = readlines(datafile)
        close(datafile)

        for eachLine in data
            line = split(eachLine, " ")

            s = parse(Int64, line[1]) + 1
            t = parse(Int64, line[2]) + 1
            Commodity = vcat(Commodity, [s t round(Int, parse(Float64, line[3])) parse(Float64, line[4])])

        end


        # ------------------------
        # reading "Functions.txt"
        # ------------------------
        # println("reading ", instance * "Functions.txt")
        datafile = open(instance * "Functions.txt")
        readline(datafile)
        F = parse(Int64, split(readline(datafile), " ")[2])
        data = readlines(datafile)
        close(datafile)
        CapacityFun = [0 for _ in 1:F]
        CostFun = zeros(Int64, F, N)
        f = 1

        for eachLine in data
            line = split(eachLine, " ")
            CapacityFun[f] = parse(Int64, line[1])
            for i in 1:N
                CostFun[f, i] = parse(Int64, line[i+1])
            end

            #CostFun = vcat(CostFun, [parse(Int64, line[i+1]) for i in 1:N])

            f += 1
        end


        # ------------------------
        # reading "Fct_commod.txt"
        # ------------------------
        # println("reading ", instance * "Fct_commod.txt")
        Order = [[] for _ in 1:K]
        Layer = [0 for _ in 1:K]
        datafile = open(instance * "Fct_commod.txt")
        data = readlines(datafile)
        close(datafile)

        k = 1
        for eachLine in data
            line = split(eachLine, " ")
            # println(line)
            l = size(line, 1)
            if line[l] == "" || line[l] == " "
                pop!(line)
                l -= 1
            end

            Order[k] = [parse(Int64, line[i]) + 1 for i in 1:l]
            Layer[k] = l
            k += 1
        end


        # ------------------------
        # reading "Affinity.txt"
        # ------------------------
        # println("reading ", instance * "Affinity.txt")
        Affinity = [[] for _ in 1:K]
        datafile = open(instance * "Affinity.txt")
        data = readlines(datafile)
        close(datafile)

        k = 0
        for eachLine in data
            k += 1
            line = split(eachLine, " ")
            l = size(line, 1)
            for i in 1:l
                for s in 1:size(line, 1)
                    if line[s] == ""
                        splice!(line, s)
                        break
                    end
                end
                if size(line, 1) < 1
                    break
                end
            end

            l = size(line, 1)

            if l <= 1
                continue
            end

            Affinity[k] = [parse(Int64, line[i]) + 1 for i in 1:l]
        end

        new(N, M, Adjacent, LatencyMat, Latency, CapacityNode, CostNode, K, Commodity, F, CapacityFun, CostFun, Order, Layer, Affinity)
    end

end

""" Noeud(id, score)
    permet de trouver un plus court chemin    
"""
mutable struct Noeud
    id::Int
    score::Float64 #duree from start to this node
    #h::Int #estimated distance from this node to the node t
    Noeud(id::Int) = new(id, typemax(Float64))
end

""" Solution(paths, functions)
    stocke une solution de notre problème
"""
mutable struct Solution
    paths::Vector{Vector{Int}}
    functions::Vector{Vector{Int}}
    cost::Float64
    nb_it::Int
    resolution_time::Float64
    function cost(data, functions)
        costOpenNodes = sum(data.CostNode[isempty.(functions).==false])
        costFunctions = sum(data.CostFun[f, i] for i in 1:data.N for f in functions[i])
        return costOpenNodes + costFunctions
    end
    function Solution(paths::Vector{Vector{Int}}, functions::Vector{Vector{Int}}, data::Data)
        new(paths, functions, cost(data, functions), 0, 0.0)
    end
    function Solution(paths::Vector{Vector{Int}}, functions::Vector{Vector{Int}}, data::Data, nb_it::Int, resolution_time::Float64)
        new(paths, functions, cost(data, functions), nb_it, resolution_time)
    end
    function Solution(solution::Solution, data::Data, nb_it, resolution_time)
        new(solution.paths, solution.functions, cost(data, solution.functions), nb_it, resolution_time)
    end
end


# mutable struct MIPsol
#     objVal::Float64
#     solveTime::Float64
#     isOptimal::Bool
# end

"""
Write a table in a .tex file
Input:
    - output = filename of the output file
    - caption = caption of the table
    - titles = header of the table
        - num_col_titles = number of cols for each title
    - subtitles = subheader of the table
        - num_col_sub = number of cols for each subtitle
"""
function write_table_tex(output::String, caption::String, titles::Array{String}, rows::Vector{Vector{String}};
    subtitles::Array{String}=String[], subsubtitles::Array{String}=String[],
    num_col_titles::Array{Int}=ones(Int, length(titles)), num_col_sub::Array{Int}=ones(Int, length(subtitles)),
    alignments::String="c"^sum(num_col_titles), lines::Array{String}=fill("", length(rows)), maxRawsPerPage::Int=50)

    fout = open(output * ".tex", "w")

    println(fout,
raw"""\documentclass[main.tex]{subfiles}
\margin{0.5cm}{0.5cm}
\begin{document}
\thispagestyle{empty}
"""
    )

    #HEADER OF TABLE
    header = raw"""
\begin{landscape}
\begin{table}[h]
    \centering
\resizebox{\columnwidth}{!}{%
    \begin{tabular}{"""

    header *= alignments * "}\n\t\\hline\t\n\t"

    for i in 1:length(titles)
        if num_col_titles[i] > 1
            header *= "\\multicolumn{" * string(num_col_titles[i]) * "}{c}{"
        end
        header *= "\\textbf{" * titles[i] * "}"
        if num_col_titles[i] > 1
            header *= "}"
        end
        if i < length(titles)
            header *= " &"
        end
    end
    header *= "\\\\"

    #SUBHEADERS
    subheader = ""
    if length(subtitles) > 0
        subheader *= "\t"
        for i in 1:length(subtitles)
            if num_col_sub[i] > 1
                subheader *= "\\multicolumn{" * string(num_col_sub[i]) * "}{c}{"
            end
            subheader *= subtitles[i]
            if num_col_sub[i] > 1
                subheader *= "}"
            end
            if i < length(subtitles)
                subheader *= " &"
            end
        end
        subheader *= "\\\\"
    end

    #SUBSUBHEADERS
    subsubheader = ""
    if length(subsubtitles) > 0
        subsubheader *= "\t"
        for i in 1:length(subsubtitles)
            subsubheader *= subsubtitles[i]

            if i < length(subsubtitles)
                subsubheader *= " &"
            end
        end
        subsubheader *= "\\\\\n\t\\hline"
    end

    #FOOTER OF TABLES
    footer1 = raw"""
    \end{tabular}
}"""
    footer2 = raw"""
\end{table}
\end{landscape}
"""
    caption = "\caption{" * caption * "}"
    println(fout, header)
    println(fout, subheader)
    println(fout, subsubheader)
    println(fout, "\t\\hline")
    id = 1

    #CONTENT
    for j in 1:length(rows)
        print(fout, "\t")
        for i in 1:length(rows[j])
            print(fout, rows[j][i])
            if i < length(rows[j])
                print(fout, " &")
            end
        end

        println(fout, "\\\\" * lines[j])


        #If we need to start a new page
        if rem(id, maxRawsPerPage) == 0
            println(fout, footer1, footer2, "\\newpage\n\\thispagestyle{empty}")
            println(fout, header)
            println(fout, subheader)
            println(fout, subsubheader)
            println(fout, "\t\\hline")
        end
        id += 1
    end

    println(fout, footer1, caption, footer2)
    println(fout, "\\end{document}")
    close(fout)
end

"""
Create a pdf file which contains a performance diagram associated to the results of the ../res folder
Display one curve for each subfolder of the ../res folder.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
"""
function performanceDiagram(outputFile::String)
    
    resultFolder = "../res/"
    maxSize = 0 # Maximal number of files in a subfolder
    subfolderCount = 0  # Number of subfolders
    folderName = Array{String, 1}()

    # For each file in the result folder
    for method in readdir(resultFolder)
        methodPath = resultFolder * method
        
        # If it is a subfolder
        if isdir(methodPath)
            folderName = vcat(folderName, method)
            subfolderCount += 1
            folderSize = 10*size(readdir(methodPath), 1)
            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    results = Array{Float64}(undef, subfolderCount, maxSize)    # Array that will contain the resolution times (one line for each subfolder)

    for i in 1:subfolderCount
        for j in 1:maxSize
            results[i, j] = Inf
        end
    end

    folderCount = 0
    maxSolveTime = 0

    # For each subfolder
    for method in readdir(resultFolder)
        methodPath = resultFolder * method
        if isdir(methodPath)
            folderCount += 1
            fileCount = 0

            for instanceName in readdir(methodPath)
                
                path = methodPath * "/" * instanceName
                # For each text file in the subfolders
                for resultFile in filter(x->occursin(".txt", x), readdir(path))

                    fileCount += 1
                    @show path * "/" * resultFile
                    include(path * "/" * resultFile)

                    if cost < Inf
                        @debug results[folderCount, fileCount] = resolution_time

                        if resolution_time > maxSolveTime
                            maxSolveTime = resolution_time
                        end 
                    end 
                end 
            end
        end
    end 

    # Sort each row increasingly
    @debug results
    @debug results = sort(results, dims=2)
    @debug size(results)

    println("Max solve time: ", maxSolveTime)

    # For each line to plot
    for dim in 1: size(results, 1)

        x = Array{Float64, 1}()
        y = Array{Float64, 1}()

        # x coordinate of the previous inflexion point
        previousX = 0
        previousY = 0

        append!(x, previousX)
        append!(y, previousY)
            
        # Current position in the line
        currentId = 1

        # While the end of the line is not reached 
        while currentId != size(results, 2) && results[dim, currentId] != Inf
            # Number of elements which have the value previousX
            identicalValues = 1

            # While the value is the same
            while currentId < size(results, 2) && results[dim, currentId] == previousX
                currentId += 1
                identicalValues += 1
            end

            # Add the proper points
            append!(x, previousX)
            append!(y, currentId - 1)

            if results[dim, currentId] != Inf
                append!(x, results[dim, currentId])
                append!(y, currentId - 1)
            end
            
            previousX = results[dim, currentId]
            previousY = currentId - 1
        end

        append!(x, maxSolveTime)
        append!(y, currentId - 1)

        # If it is the first subfolder
        if dim == 1

            # Draw a new plot
            plot(x, y, label = folderName[dim], legend = :bottomright, xaxis = "Time (s)", yaxis = "Solved instances",linewidth=3)

        # Otherwise 
        else
            # Add the new curve to the created plot
            savefig(plot!(x, y, label = folderName[dim], linewidth=3), outputFile)
        end 
    end
end 
