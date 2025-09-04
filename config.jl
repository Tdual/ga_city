# config.jl - 設定とプリセット管理

# グリッドサイズ
const H = 100
const W = 100

# 施設タイプとシンボルの定義
const SYMBOL = Dict(
    0 => "🌳",  # 公園
    1 => "🟫",  # 道路
    2 => "🏠",  # 住宅
    3 => "🏢",  # 職場
    4 => "🏪"   # サービス施設
)

# ゲーム設定構造体
Base.@kwdef mutable struct GameConfig
    # 適応度関数の重み
    w_commute::Float64 = -1.0          # 通勤距離（負は短い方が良い）
    w_service::Float64 = -0.6          # サービス距離（負は短い方が良い）
    w_park::Float64 = 0.8              # 公園比率（正は多い方が良い）
    w_road_connect::Float64 = -10.0    # 道路非接続ペナルティ
    w_road_network::Float64 = 100.0    # 道路ネットワーク連結ボーナス
    penalty_disconnect::Float64 = -1000.0  # 道路非連結ペナルティ
    
    # 進化アルゴリズムパラメータ
    popsize::Int = 80
    generations::Int = 100
    verbose::Bool = false
    
    # 遺伝的演算子
    selection_method::String = "susinv"
    crossover_method::String = "DC"
    mutation_method::String = "PLM"
end

# グローバル設定インスタンス
const CFG = GameConfig()

# プリセット設定
const PRESETS = Dict(
    1 => ("バランス型", GameConfig(
        w_commute=-1.0, w_service=-0.6, w_park=0.8,
        w_road_connect=-10.0, w_road_network=100.0, penalty_disconnect=-1000.0
    )),
    2 => ("職住近接重視", GameConfig(
        w_commute=-1.6, w_service=-0.4, w_park=0.4,
        w_road_connect=-10.0, w_road_network=100.0, penalty_disconnect=-1000.0
    )),
    3 => ("緑化重視", GameConfig(
        w_commute=-0.6, w_service=-0.4, w_park=1.4,
        w_road_connect=-8.0, w_road_network=80.0, penalty_disconnect=-800.0
    )),
    4 => ("サービス重視", GameConfig(
        w_commute=-0.8, w_service=-1.4, w_park=0.4,
        w_road_connect=-10.0, w_road_network=100.0, penalty_disconnect=-1000.0
    ))
)

"""
プリセット設定を適用
"""
function apply_preset!(preset_id::Int)
    if haskey(PRESETS, preset_id)
        _, preset = PRESETS[preset_id]
        CFG.w_commute = preset.w_commute
        CFG.w_service = preset.w_service
        CFG.w_park = preset.w_park
        CFG.w_road_connect = preset.w_road_connect
        CFG.w_road_network = preset.w_road_network
        CFG.penalty_disconnect = preset.penalty_disconnect
    end
end