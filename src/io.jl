# This file contains function reading instances

mutable struct Data
    N::Int64 # the number of vertices
    M::Int64 # the number of arcs
    Adjacent::BitArray{2} 
    LatencyMat::Array{Float64, 2} # matrix latency [u, v, latency]
    CapacityNode::Array{Int64,1} # capacity *functions* of each vertex
    CostNode::Array{Int64,1} # openning cost of each vertex

    K::Int64 # the number of Commodidties
    Commodidty::Array{Float64, 2} #[s, t, flux, latencyMax]

    F::Int64 # the number of functions
    CapacityFun::Array{Int64,1} # capacity *flux* of each function
    CostFun::Array{Int64, 2} # cost of fun on node u = CostFun[fun, u]

    Order::Array{Array{Int64,1},1} # Order[k] : the list of functions ordered for commodity k
    Layer::Array{Int64,1} # the number of layers of each commodity

    Affinity::Array{Array{Int64,1},1} # Affinity[k] : the list of functions exclusive for commodity k

    # Constructeur
    function Data(dir::String, small_test::Bool=false, name::String="", num::Int=1)
        if small_test
            instance = dir * name * "/" * name * "_"
        else
            instance = dir * name * "/" * name * "_$num" * "/"
        end
        
        println("reading ", instance)
        # ---------------------
        # reading "Graph.txt"
        # ---------------------
        datafile = open(instance * "Graph.txt")
        readline(datafile)
        N = parse(Int64, split(readline(datafile), " ")[2])
        CapacityNode = [0 for _ in 1:N]
        CostNode = [0 for _ in 1:N]
        Adjacent = falses(N, N)

        M = parse(Int64, split(readline(datafile), " ")[2])
        data = readlines(datafile)
        close(datafile)
        LatencyMat = Array{Float64, 2}(undef, 0, 3)

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

            if CostNode[u] == 0
                CostNode[u] = parse(Int64, line[6])
            end
        end


        # ---------------------
        # reading "Commodity.txt"
        # ---------------------
        Commodity = Array{Float64, 2}(undef, 0, 4) #TODO : category
        datafile = open(instance * "Commodity.txt")
        readline(datafile)
        K = parse(Int64, split(readline(datafile), " ")[2])
        data = readlines(datafile)
        close(datafile)

        for eachLine in data
            line = split(eachLine, " ")

            s = parse(Int64, line[1]) + 1
            t = parse(Int64, line[2]) + 1
            Commodidty = vcat(Commodidty, [s t round(Int, parse(Float64, line[3])) parse(Float64, line[4])])
            
        end


        # ------------------------
        # reading "Functions.txt"
        # ------------------------
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

            Order[k] = [parse(Int64, line[i])+1 for i in 1:l]
            Layer[k] = l
            k +=1
        end


        # ------------------------
        # reading "Affinity.txt"
        # ------------------------
        Affinity = [[] for _ in 1:K]
        datafile = open(instance * "Affinity.txt")
        data = readlines(datafile)
        close(datafile)

        k = 0
        for eachLine in data
            k +=1
            line = split(eachLine, " ")
            l = size(line, 1)
            for i in 1:l
                for s in 1:size(line, 1)
                    if line[s] == "" 
                        splice!(line, s)
                        break
                    end
                end
                if size(line, 1) <1
                    break
                end
            end

            l = size(line, 1)

            if l <= 1
                continue
            end
            
            Affinity[k] = [parse(Int64, line[i])+1 for i in 1:l]
        end


        new(N, M, Adjacent, LatencyMat, CapacityNode, CostNode, K, Commodidty, F, CapacityFun, CostFun, Order, Layer, Affinity)
    end

end