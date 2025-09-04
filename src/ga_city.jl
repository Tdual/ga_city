#!/usr/bin/env julia
# ga_city.jl - メインプログラム

using Random
using Statistics
using Evolutionary

# モジュールを読み込み
include("modules.jl")

"""
メイン処理
"""
function main()
    println("=== Genetic City (道路接続性版, $(H)×$(W)グリッド) ===")
    
    # 設定メニュー
    menu()
    
    println("\n進化を開始します...")
    
    # 遺伝的アルゴリズムを実行
    best_x, best_f = run_ga()
    
    # 結果を表示
    println("\nBest fitness: ", round(best_f, digits=3))
    
    # 道路連結性の検証
    grid = reshape(Int.(round.(best_x)), H, W)
    n_components = count_road_components(grid, 1, 1, H, W)
    total_roads = sum(grid .== 1)
    println("道路連結状態: ", n_components == 1 ? "✅ 100%連結" : "❌ $(n_components)個の分離成分")
    println("道路総数: ", total_roads)
    
    # 最適な都市を表示
    println("\nBest city layout:")
    print_city_sample(best_x, 30)
end

# スクリプトとして実行された場合
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end