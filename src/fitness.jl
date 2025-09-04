# fitness.jl - 適応度関数

# Dependencies are loaded via modules.jl

"""
都市の適応度を計算
"""
function fitness_city(x::AbstractVector{<:Real})
    grid = reshape(Int.(round.(x)), H, W)
    fitness_val = 0.0
    
    # 施設の座標を収集
    houses = [(i, j) for i in 1:H for j in 1:W if grid[i, j] == 2]
    offices = [(i, j) for i in 1:H for j in 1:W if grid[i, j] == 3]
    services = [(i, j) for i in 1:H for j in 1:W if grid[i, j] == 4]
    roads = [(i, j) for i in 1:H for j in 1:W if grid[i, j] == 1]
    
    # 通勤距離（住宅→職場）
    if !isempty(houses) && !isempty(offices)
        commute_distances = []
        for (hi, hj) in houses
            min_dist = minimum(abs(oi - hi) + abs(oj - hj) for (oi, oj) in offices)
            push!(commute_distances, min_dist)
        end
        avg_commute = mean(commute_distances)
        fitness_val += CFG.w_commute * avg_commute
    else
        fitness_val += CFG.w_commute * 100  # ペナルティ
    end
    
    # サービスアクセス距離（住宅→サービス）
    if !isempty(houses) && !isempty(services)
        service_distances = []
        for (hi, hj) in houses
            min_dist = minimum(abs(si - hi) + abs(sj - hj) for (si, sj) in services)
            push!(service_distances, min_dist)
        end
        avg_service = mean(service_distances)
        fitness_val += CFG.w_service * avg_service
    else
        fitness_val += CFG.w_service * 100  # ペナルティ
    end
    
    # 公園比率
    park_ratio = sum(grid .== 0) / (H * W)
    fitness_val += CFG.w_park * park_ratio * 100
    
    # 道路接続性チェック
    if !isempty(roads)
        # 施設が道路に隣接しているかチェック
        unconnected_count = 0
        for i in 1:H
            for j in 1:W
                if grid[i, j] in [2, 3, 4]  # 住宅、職場、サービス
                    # 4方向に道路があるかチェック
                    has_road = false
                    for (di, dj) in [(0,1), (1,0), (0,-1), (-1,0)]
                        ni, nj = i + di, j + dj
                        if 1 <= ni <= H && 1 <= nj <= W && grid[ni, nj] == 1
                            has_road = true
                            break
                        end
                    end
                    if !has_road
                        unconnected_count += 1
                    end
                end
            end
        end
        fitness_val += CFG.w_road_connect * unconnected_count
        
        # 道路ネットワークの連結性
        n_components = count_road_components(grid, 1, 1, H, W)
        if n_components == 1
            fitness_val += CFG.w_road_network * 10  # 10倍ボーナス
        elseif n_components > 1
            fitness_val += CFG.penalty_disconnect * (n_components - 1) * 10  # 10倍ペナルティ
        end
    else
        fitness_val += CFG.penalty_disconnect * 10  # 道路なしは大ペナルティ
    end
    
    return fitness_val
end

"""
平均を計算するヘルパー関数
"""
function mean(x)
    isempty(x) ? 0.0 : sum(x) / length(x)
end