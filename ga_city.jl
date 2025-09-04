# ==========================================
# ga_city.jl — Genetic City (with road connectivity)
# ==========================================
using Random, Statistics
using Evolutionary

# ----- 固定乱数（毎回変えたいならコメントアウト） -----
Random.seed!(42)

# ===== 都市の設定 =====
const H = 100
const W = 100
const N = H * W               # 遺伝子長（セル数）
const TYPES = 0:4             # 0=公園,1=道路,2=住宅,3=職場,4=サービス
SYMBOL = Dict(0=>"🌳", 1=>"🛣️", 2=>"🏠", 3=>"🏢", 4=>"🏪")  # 絵文字表示（文字列として）

# ===== コンフィグ =====
Base.@kwdef mutable struct GameConfig
    w_commute::Float64   = -1.0   # 住宅→職場 平均距離（短いほど良い→負）
    w_service::Float64   = -0.6   # 住宅→サービス 平均距離
    w_park::Float64      =  0.8   # 公園比率（高いほど良い→正）
    w_road_connect::Float64 = -2.0  # 道路非接続ペナルティ（施設1つあたり）
    w_road_network::Float64 = 5.0   # 道路ネットワーク連結ボーナス（正値）
    penalty_hw::Float64  = -50.0  # 職場が無い/住宅が無い時のペナルティ
    penalty_hs::Float64  = -20.0  # サービスが無い/住宅が無い時のペナルティ
    penalty_disconnect::Float64 = -10.0  # 道路の非連結ペナルティ（孤立道路グループ1つあたり）
    popsize::Int         = 80
    generations::Int     = 100
    show_trace::Bool     = false
    # 演算子指定（名前で選択、後で実体に解決）
    sel_name::String     = "susinv"       # susinv | tournament
    cx_name::String      = "DC"           # DC | uniformbin
    mut_name::String     = "PLM"          # PLM | gaussian
    # サンプリングサイズ（1000x1000は大きすぎるので一部を評価）
    sample_size::Int     = 100    # 評価時にサンプリングするセル数
end

const CFG = GameConfig()  # グローバル設定（メニューで上書き）

# ===== ユーティリティ =====
to_grid(chrom::Vector{Int}) = reshape(chrom, H, W)
to_grid_from_vec(x::AbstractVector{<:Real}) = reshape(round.(Int, clamp.(x, 0, 4)), H, W)

# 次元N対応マンハッタン距離
manhattan(a::CartesianIndex{N}, b::CartesianIndex{N}) where {N} = sum(abs, Tuple(a) .- Tuple(b))

# 最短距離
function mindist(p::CartesianIndex{N}, arr::Vector{CartesianIndex{N}}) where {N}
    isempty(arr) && return typemax(Int)
    dmin = typemax(Int)
    @inbounds for q in arr
        d = manhattan(p, q)
        if d < dmin; dmin = d; end
    end
    return dmin
end

# 道路に接続しているかチェック（上下左右に道路があるか）
function is_road_connected(grid::Matrix{Int}, i::Int, j::Int)
    # 境界チェック
    connected = false
    # 上
    if i > 1 && grid[i-1, j] == 1
        connected = true
    end
    # 下
    if i < H && grid[i+1, j] == 1
        connected = true
    end
    # 左
    if j > 1 && grid[i, j-1] == 1
        connected = true
    end
    # 右
    if j < W && grid[i, j+1] == 1
        connected = true
    end
    return connected
end

# 道路ネットワークの連結成分数を計算（Union-Find）
function count_road_components(grid::Matrix{Int}, start_h::Int, start_w::Int, sample_h::Int, sample_w::Int)
    # Union-Find構造の初期化
    parent = Dict{Tuple{Int,Int}, Tuple{Int,Int}}()
    
    # Find操作（経路圧縮付き）
    function find_root(node::Tuple{Int,Int})
        if !haskey(parent, node)
            parent[node] = node
            return node
        end
        if parent[node] != node
            parent[node] = find_root(parent[node])
        end
        return parent[node]
    end
    
    # Union操作
    function union(a::Tuple{Int,Int}, b::Tuple{Int,Int})
        root_a = find_root(a)
        root_b = find_root(b)
        if root_a != root_b
            parent[root_a] = root_b
        end
    end
    
    # サンプル領域内の道路を収集
    roads = Tuple{Int,Int}[]
    for i in start_h:(start_h + sample_h - 1)
        for j in start_w:(start_w + sample_w - 1)
            if grid[i, j] == 1  # 道路
                push!(roads, (i, j))
            end
        end
    end
    
    # 隣接する道路をUnion
    for road in roads
        i, j = road
        # 上
        if i > start_h && grid[i-1, j] == 1
            union(road, (i-1, j))
        end
        # 下
        if i < start_h + sample_h - 1 && grid[i+1, j] == 1
            union(road, (i+1, j))
        end
        # 左
        if j > start_w && grid[i, j-1] == 1
            union(road, (i, j-1))
        end
        # 右
        if j < start_w + sample_w - 1 && grid[i, j+1] == 1
            union(road, (i, j+1))
        end
    end
    
    # 連結成分数を数える
    if isempty(roads)
        return 0  # 道路がない場合
    end
    
    components = Set{Tuple{Int,Int}}()
    for road in roads
        push!(components, find_root(road))
    end
    
    return length(components)
end

# ===== 適応度（大きいほど良い） - サンプリング版 =====
function fitness_city(x::AbstractVector{<:Real})
    g = CFG
    grid = to_grid_from_vec(x)
    
    # 全領域を評価（100x100なのでサンプリング不要）
    sample_h = H
    sample_w = W
    start_h = 1
    start_w = 1
    
    # サンプル領域内で評価
    homes = CartesianIndex{2}[]
    works = CartesianIndex{2}[]
    servs = CartesianIndex{2}[]
    parks = CartesianIndex{2}[]
    
    unconnected_facilities = 0
    total_cells = sample_h * sample_w
    
    for i in start_h:(start_h + sample_h - 1)
        for j in start_w:(start_w + sample_w - 1)
            cell = grid[i, j]
            idx = CartesianIndex(i, j)
            
            if cell == 0
                push!(parks, idx)
            elseif cell == 2
                push!(homes, idx)
                # 住宅が道路に接続していないとペナルティ
                if !is_road_connected(grid, i, j)
                    unconnected_facilities += 1
                end
            elseif cell == 3
                push!(works, idx)
                # 職場が道路に接続していないとペナルティ
                if !is_road_connected(grid, i, j)
                    unconnected_facilities += 1
                end
            elseif cell == 4
                push!(servs, idx)
                # サービスが道路に接続していないとペナルティ
                if !is_road_connected(grid, i, j)
                    unconnected_facilities += 1
                end
            end
        end
    end
    
    score = 0.0
    
    # 通勤距離評価
    if !isempty(homes) && !isempty(works)
        d = [mindist(h, works) for h in homes]
        score += g.w_commute * mean(d)
    else
        score += g.penalty_hw
    end
    
    # サービス距離評価
    if !isempty(homes) && !isempty(servs)
        d = [mindist(h, servs) for h in homes]
        score += g.w_service * mean(d)
    else
        score += g.penalty_hs
    end
    
    # 公園比率ボーナス
    score += g.w_park * (length(parks)/total_cells) * 100.0
    
    # 道路接続性ペナルティ
    score += g.w_road_connect * unconnected_facilities
    
    # 道路ネットワーク連結性の評価
    road_components = count_road_components(grid, start_h, start_w, sample_h, sample_w)
    if road_components > 0
        # 理想は1つの連結成分（すべての道路が繋がっている）
        # 連結成分が増えるほどペナルティ
        score += g.penalty_disconnect * (road_components - 1)
        # 連結している場合はボーナス
        if road_components == 1
            score += g.w_road_network
        end
    end
    
    return score
end

# Evolutionary.optimize は最小化なので、-fitness を最小化
obj(x) = -fitness_city(x)

# ===== オペレータ解決（バージョン差を吸収） =====
function resolve_selection(name::String)
    if name == "susinv" && isdefined(Evolutionary, :susinv)
        return Evolutionary.susinv
    elseif name == "tournament"
        return Evolutionary.tournament(3)
    elseif isdefined(Evolutionary, :susinv)
        return Evolutionary.susinv
    else
        return Evolutionary.tournament(3)
    end
end

function resolve_crossover(name::String)
    if name == "DC" && isdefined(Evolutionary, :DC)
        return Evolutionary.DC
    elseif name == "uniformbin" && isdefined(Evolutionary, :uniformbin)
        return Evolutionary.uniformbin()
    elseif isdefined(Evolutionary, :DC)
        return Evolutionary.DC
    else
        return Evolutionary.uniformbin()
    end
end

function resolve_mutation(name::String)
    if name == "PLM" && isdefined(Evolutionary, :PLM)
        return Evolutionary.PLM()
    elseif name == "gaussian" && isdefined(Evolutionary, :gaussian)
        return Evolutionary.gaussian()
    elseif isdefined(Evolutionary, :PLM)
        return Evolutionary.PLM()
    else
        return Evolutionary.gaussian()
    end
end

# ===== 進化の実行 =====
function run_ga()
    g = CFG
    # 連続値で 0..4 に制約
    lower = fill(0.0, N); upper = fill(4.0, N)
    cnst  = Evolutionary.BoxConstraints(lower, upper)

    x0 = rand(N) .* 4.0

    alg = Evolutionary.GA(
        populationSize = g.popsize,
        selection = resolve_selection(g.sel_name),
        crossover = resolve_crossover(g.cx_name),
        mutation  = resolve_mutation(g.mut_name)
    )

    opts = Evolutionary.Options(
        iterations = g.generations,
        show_trace = g.show_trace,
        store_trace = false
    )

    result = Evolutionary.optimize(obj, cnst, x0, alg, opts)
    best_x = result.minimizer
    best_f = -result.minimum
    return best_x, best_f
end

# ===== 表示（サンプル領域のみ） =====
function print_city_sample(x::AbstractVector{<:Real}, size::Int=20)
    grid = to_grid_from_vec(x)
    
    # 中央付近から表示（100x100の場合）
    if size >= H || size >= W
        # グリッドより大きいサイズを指定された場合は全体を表示
        start_h = 1
        start_w = 1
        size = min(H, W)
        println("都市全体を表示 ($(size)×$(size))")
    else
        start_h = div(H - size, 2)
        start_w = div(W - size, 2)
        println("都市の一部を表示 ($(size)×$(size), 位置: [$(start_h):$(start_h+size-1), $(start_w):$(start_w+size-1)])")
    end
    println("🌳=公園 🛣️=道路 🏠=住宅 🏢=職場 🏪=サービス")
    println("─" ^ 40)
    for i in start_h:(start_h + size - 1)
        @inbounds println(join((SYMBOL[grid[i,j]] for j in start_w:(start_w + size - 1))))
    end
end

# ===== 簡易メニュー =====
function readnum(prompt::String, default)
    print(prompt, " [", default, "]: ")
    s = readline(stdin; keep=true)
    s = strip(s)
    isempty(s) ? default : parse(typeof(default), s)
end

function menu()
    println("=== Genetic City 設定 ($(H)×$(W)グリッド) ===")
    println("プリセットを選択:")
    println(" 1) バランス型      (通勤-1.0, サービス-0.6, 公園+0.8, 道路接続-2.0, 連結+5.0)")
    println(" 2) 職住近接重視    (通勤-1.6, サービス-0.4, 公園+0.4, 道路接続-2.0, 連結+5.0)")
    println(" 3) 緑化重視        (通勤-0.6, サービス-0.4, 公園+1.4, 道路接続-1.5, 連結+3.0)")
    println(" 4) サービス重視    (通勤-0.8, サービス-1.4, 公園+0.4, 道路接続-2.0, 連結+5.0)")
    println(" 5) カスタム設定")
    print("選択 [1–5] (Enter=1): ")
    choice = strip(readline(stdin; keep=true))
    choice = isempty(choice) ? "1" : choice

    if choice == "1"
        CFG.w_commute = -1.0; CFG.w_service = -0.6; CFG.w_park = 0.8
        CFG.w_road_connect = -2.0; CFG.w_road_network = 5.0; CFG.penalty_disconnect = -10.0
    elseif choice == "2"
        CFG.w_commute = -1.6; CFG.w_service = -0.4; CFG.w_park = 0.4
        CFG.w_road_connect = -2.0; CFG.w_road_network = 5.0; CFG.penalty_disconnect = -10.0
    elseif choice == "3"
        CFG.w_commute = -0.6; CFG.w_service = -0.4; CFG.w_park = 1.4
        CFG.w_road_connect = -1.5; CFG.w_road_network = 3.0; CFG.penalty_disconnect = -8.0
    elseif choice == "4"
        CFG.w_commute = -0.8; CFG.w_service = -1.4; CFG.w_park = 0.4
        CFG.w_road_connect = -2.0; CFG.w_road_network = 5.0; CFG.penalty_disconnect = -10.0
    else
        println("\n--- カスタム重み ---（負=ペナルティ, 正=ボーナス）")
        CFG.w_commute = readnum("通勤距離の重み (負値)", CFG.w_commute)
        CFG.w_service = readnum("サービス距離の重み (負値)", CFG.w_service)
        CFG.w_park    = readnum("公園比率の重み (正値)", CFG.w_park)
        CFG.w_road_connect = readnum("道路非接続ペナルティ (負値)", CFG.w_road_connect)
        CFG.w_road_network = readnum("道路連結ボーナス (正値)", CFG.w_road_network)
        CFG.penalty_disconnect = readnum("道路非連結ペナルティ (負値)", CFG.penalty_disconnect)
    end

    println("\n--- 進化パラメータ ---")
    CFG.popsize     = readnum("個体数", CFG.popsize)
    CFG.generations = readnum("世代数", CFG.generations)
    showt           = readnum("進行ログ表示 0/1", CFG.show_trace ? 1 : 0)
    CFG.show_trace  = (showt == 1)

    println("\n--- オペレータ選択（環境に無ければ自動で代替） ---")
    print("Selection [susinv | tournament] (Enter=", CFG.sel_name, "): ")
    s = strip(readline(stdin; keep=true)); CFG.sel_name = isempty(s) ? CFG.sel_name : s
    print("Crossover [DC | uniformbin]     (Enter=", CFG.cx_name, "): ")
    s = strip(readline(stdin; keep=true)); CFG.cx_name = isempty(s) ? CFG.cx_name : s
    print("Mutation  [PLM | gaussian]      (Enter=", CFG.mut_name, "): ")
    s = strip(readline(stdin; keep=true)); CFG.mut_name = isempty(s) ? CFG.mut_name : s

    println("\n設定OK：")
    println("  w_commute=", CFG.w_commute, "  w_service=", CFG.w_service)
    println("  w_park=", CFG.w_park, "  w_road_connect=", CFG.w_road_connect)
    println("  w_road_network=", CFG.w_road_network, "  penalty_disconnect=", CFG.penalty_disconnect)
    println("  popsize=", CFG.popsize, "  generations=", CFG.generations)
    println("  selection=", CFG.sel_name, "  crossover=", CFG.cx_name, "  mutation=", CFG.mut_name)
    println("=========================================\n")
end

function main()
    println("=== Genetic City (道路接続性版, $(H)×$(W)グリッド) ===")
    menu()
    
    println("\n進化を開始します...")
    
    best_x, best_f = run_ga()
    println("\nBest fitness: ", round(best_f, digits=3))
    println("\nBest city layout:")
    print_city_sample(best_x, 30)  # 100x100なので30x30を表示
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end