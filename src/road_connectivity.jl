# road_connectivity.jl - 道路連結性関連の関数

using Random

"""
Union-Find構造で道路の連結成分数をカウント
"""
function count_road_components(grid::Matrix{Int}, start_h::Int, start_w::Int, sample_h::Int, sample_w::Int)
    end_h = min(start_h + sample_h - 1, size(grid, 1))
    end_w = min(start_w + sample_w - 1, size(grid, 2))
    
    # 道路セルの座標を収集
    road_cells = []
    for i in start_h:end_h
        for j in start_w:end_w
            if grid[i, j] == 1  # 道路
                push!(road_cells, (i, j))
            end
        end
    end
    
    n_roads = length(road_cells)
    if n_roads == 0
        return 0
    end
    
    # Union-Find構造
    parent = collect(1:n_roads)
    
    function find(x)
        if parent[x] != x
            parent[x] = find(parent[x])
        end
        return parent[x]
    end
    
    function union!(x, y)
        px, py = find(x), find(y)
        if px != py
            parent[px] = py
        end
    end
    
    # 座標からインデックスへのマッピング
    coord_to_idx = Dict((road_cells[i][1], road_cells[i][2]) => i for i in 1:n_roads)
    
    # 隣接する道路をUnion
    for idx in 1:n_roads
        i, j = road_cells[idx]
        # 4方向の隣接をチェック
        for (di, dj) in [(0, 1), (1, 0), (0, -1), (-1, 0)]
            ni, nj = i + di, j + dj
            if haskey(coord_to_idx, (ni, nj))
                union!(idx, coord_to_idx[(ni, nj)])
            end
        end
    end
    
    # 連結成分数をカウント
    components = length(unique(find(i) for i in 1:n_roads))
    return components
end

"""
BFSを使って連結した道路網を生成
"""
function create_connected_road_network()
    x = rand(0:4, H*W)
    
    # スパニングツリーで最小限の道路を配置
    visited = falses(H, W)
    queue = [(rand(1:H), rand(1:W))]
    visited[queue[1][1], queue[1][2]] = true
    
    while !isempty(queue)
        i, j = popfirst!(queue)
        x[(i-1)*W + j] = 1.0  # 道路にする
        
        # 4方向の隣接
        for (di, dj) in [(0,1), (1,0), (0,-1), (-1,0)]
            ni, nj = i + di, j + dj
            if 1 <= ni <= H && 1 <= nj <= W && !visited[ni, nj]
                if rand() < 0.7  # 70%の確率で道路を伸ばす
                    visited[ni, nj] = true
                    push!(queue, (ni, nj))
                end
            end
        end
    end
    
    # 追加の道路をランダムに配置
    n_additional = rand(H*W÷10:H*W÷5)
    for _ in 1:n_additional
        idx = rand(1:H*W)
        if x[idx] != 1.0
            x[idx] = 1.0
        end
    end
    
    # 住宅、職場、サービス施設、公園を適度に配置
    for idx in 1:H*W
        if x[idx] != 1.0
            x[idx] = rand([0, 2, 3, 4])
        end
    end
    
    return Float64.(x)
end

"""
分断された道路を修復
"""
function repair_connectivity!(x::AbstractVector{<:Real})
    grid = reshape(Int.(round.(x)), H, W)
    
    # 道路セルを収集
    road_cells = [(i, j) for i in 1:H for j in 1:W if grid[i, j] == 1]
    
    if length(road_cells) < 2
        return  # 道路が少なすぎる場合は何もしない
    end
    
    # 連結成分を見つける
    visited = falses(H, W)
    components = []
    
    for (i, j) in road_cells
        if !visited[i, j] && grid[i, j] == 1
            component = []
            queue = [(i, j)]
            visited[i, j] = true
            
            while !isempty(queue)
                ci, cj = popfirst!(queue)
                push!(component, (ci, cj))
                
                for (di, dj) in [(0,1), (1,0), (0,-1), (-1,0)]
                    ni, nj = ci + di, cj + dj
                    if 1 <= ni <= H && 1 <= nj <= W && !visited[ni, nj] && grid[ni, nj] == 1
                        visited[ni, nj] = true
                        push!(queue, (ni, nj))
                    end
                end
            end
            
            push!(components, component)
        end
    end
    
    # 最大の成分を基準にして他を接続
    if length(components) > 1
        max_comp = components[argmax(length.(components))]
        
        for comp in components
            if comp !== max_comp && !isempty(comp)
                # 最も近い点を見つけて道路で接続
                min_dist = Inf
                best_pair = nothing
                
                for (i1, j1) in comp[1:min(5, length(comp))]
                    for (i2, j2) in max_comp[1:min(10, length(max_comp))]
                        dist = abs(i2 - i1) + abs(j2 - j1)
                        if dist < min_dist
                            min_dist = dist
                            best_pair = ((i1, j1), (i2, j2))
                        end
                    end
                end
                
                if best_pair !== nothing && min_dist < 20
                    (i1, j1), (i2, j2) = best_pair
                    # 簡単な経路で接続
                    if rand() < 0.5  # 50%の確率で接続を試みる
                        # 水平→垂直
                        for j in min(j1, j2):max(j1, j2)
                            x[(i1-1)*W + j] = 1.0
                        end
                        for i in min(i1, i2):max(i1, i2)
                            x[(i-1)*W + j2] = 1.0
                        end
                    end
                end
            end
        end
    end
end