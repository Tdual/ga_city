# ==========================================
# ga_city.jl  — Genetic City with Evolutionary.optimize
# ==========================================

using Random, Statistics
using Evolutionary

# ----- 固定乱数（毎回違う進化を見たければコメントアウト） -----
Random.seed!(42)

# ===== 都市の設定 =====
const H = 10
const W = 10
const N = H * W               # 遺伝子長（セル数）
const TYPES = 0:4             # 0=公園,1=道路,2=住宅,3=職場,4=サービス
SYMBOL = Dict(0=>'.', 1=>'=', 2=>'H', 3=>'W', 4=>'S')

# ===== ユーティリティ =====
to_grid(chrom::Vector{Int}) = reshape(chrom, H, W)
to_grid_from_vec(x::AbstractVector{<:Real}) = reshape(round.(Int, clamp.(x, 0, 4)), H, W)

# 次元Nに対応するマンハッタン距離（2次元でも3次元でも動く）
manhattan(a::CartesianIndex{N}, b::CartesianIndex{N}) where {N} = sum(abs, Tuple(a) .- Tuple(b))

# 最短距離（aと同じ次元のインデックス配列に対応）
function mindist(p::CartesianIndex{N}, arr::Vector{CartesianIndex{N}}) where {N}
    dmin = typemax(Int)
    @inbounds for q in arr
        d = manhattan(p, q)
        if d < dmin
            dmin = d
        end
    end
    return dmin
end

# ===== 適応度（大きいほど良い） =====
function fitness_city(x::AbstractVector{<:Real})
    grid = to_grid_from_vec(x)
    homes = findall(==(2), grid)
    works = findall(==(3), grid)
    servs = findall(==(4), grid)
    parks = findall(==(0), grid)

    score = 0.0
    if !isempty(homes) && !isempty(works)
        d = [mindist(h, works) for h in homes]
        score -= mean(d)                # 住宅→職場 近いほど良い
    else
        score -= 50.0
    end

    if !isempty(homes) && !isempty(servs)
        d = [mindist(h, servs) for h in homes]
        score -= 0.5 * mean(d)          # 住宅→サービス 近いほど良い
    else
        score -= 20.0
    end

    score += 0.3 * (length(parks)/N) * 100.0  # 公園比率ボーナス
    return score
end

# Evolutionary.optimize は「最小化」なので、-fitness を最小化 = fitness を最大化
obj(x) = -fitness_city(x)

# ===== 進化の実行 =====
function run_ga(; population_size::Int=80, generations::Int=80, log_every::Int=10)
    # 連続値ベクトル（後で 0..4 に丸めて評価）
    x0 = rand(N) .* 4.0

    # 0..4 のボックス制約を作成（★ここが BoxConstraints）
    lower = fill(0.0, N)
    upper = fill(4.0, N)
    cnst  = Evolutionary.BoxConstraints(lower, upper)

    # GAアルゴリズム設定（iterations はここでは指定しない）
    alg = Evolutionary.GA(
        populationSize = population_size,
        selection = Evolutionary.susinv,
        crossover = Evolutionary.DC,
        mutation  = Evolutionary.PLM()
    )

    # 反復回数などは Options で渡す
    opts = Evolutionary.Options(
        iterations = generations,
        show_trace = false,
        store_trace = false
    )

    # 最小化実行：obj = -fitness_city
    result = Evolutionary.optimize(obj, cnst, x0, alg, opts)

    best_x = result.minimizer
    best_f = -result.minimum
    return best_x, best_f
end


# ===== 表示 =====
function print_city(x::AbstractVector{<:Real})
    grid = to_grid_from_vec(x)
    for i in 1:H
        @inbounds println(join((SYMBOL[grid[i,j]] for j in 1:W)))
    end
end

function main()
    println("=== Genetic City (Evolutionary.jl optimize + GA) ===")
    best_x, best_f = run_ga(population_size=80, generations=100)
    println("Best fitness: ", round(best_f, digits=3))
    println("\nBest city layout:")
    print_city(best_x)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
