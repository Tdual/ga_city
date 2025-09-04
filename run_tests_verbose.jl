#!/usr/bin/env julia
# run_tests_verbose.jl - 詳細なテスト実行

using Test
using Random
using Statistics

include("src/modules.jl")

println("🧪 テスト開始...\n")

# 各テストを個別に実行
@testset verbose=true "GA City Tests (詳細)" begin
    
    @testset "1. 基本的な定数と構造体" begin
        @test H == 100
        @test W == 100
        @test length(SYMBOL) == 5
        println("  ✓ グリッドサイズ: $(H)×$(W)")
        println("  ✓ シンボル数: $(length(SYMBOL))")
        
        cfg = GameConfig()
        @test cfg.w_commute == -1.0
        @test cfg.penalty_disconnect == -1000.0
        println("  ✓ デフォルト設定確認済み")
    end
    
    @testset "2. Union-Find実装" begin
        test_grid = [
            1 1 0 0 0;
            1 0 0 2 2;
            0 0 1 1 1;
            0 0 1 0 0;
            3 3 1 1 1
        ]
        n_components = count_road_components(test_grid, 1, 1, 5, 5)
        @test n_components == 2
        println("  ✓ 道路連結成分数: $n_components (期待値: 2)")
    end
    
    @testset "3. 道路連結性の初期化" begin
        Random.seed!(42)
        x_init = create_connected_road_network()
        grid = reshape(Int.(round.(x_init)), H, W)
        n_components = count_road_components(grid, 1, 1, H, W)
        n_roads = sum(grid .== 1)
        
        @test n_components == 1
        @test n_roads > 0
        @test n_roads >= H + W - 1
        
        println("  ✓ 連結成分数: $n_components")
        println("  ✓ 道路数: $n_roads")
        println("  ✓ 最小スパニングツリー条件: OK")
    end
    
    @testset "4. 連結性修復関数" begin
        Random.seed!(123)
        x_broken = fill(0.0, H*W)
        x_broken[1:100] .= 1.0
        x_broken[9901:10000] .= 1.0
        
        grid_before = reshape(Int.(round.(x_broken)), H, W)
        n_before = count_road_components(grid_before, 1, 1, H, W)
        
        x_fixed = copy(x_broken)
        repair_connectivity!(x_fixed)
        
        grid_after = reshape(Int.(round.(x_fixed)), H, W)
        n_roads_after = sum(grid_after .== 1)
        n_roads_before = sum(grid_before .== 1)
        
        @test n_before == 2
        @test n_roads_after >= n_roads_before
        println("  ✓ 修復前成分数: $n_before")
        println("  ✓ 道路追加: $(n_roads_after - n_roads_before)本")
    end
    
    @testset "5. 適応度関数" begin
        Random.seed!(456)
        
        # ランダムな都市
        x_random = Float64.(rand(0:4, H*W))
        fitness_random = fitness_city(x_random)
        @test isa(fitness_random, Float64)
        println("  ✓ ランダム都市の適応度: $(round(fitness_random, digits=2))")
        
        # 連結道路網
        x_connected = create_connected_road_network()
        fitness_connected = fitness_city(x_connected)
        @test isa(fitness_connected, Float64)
        println("  ✓ 連結道路網の適応度: $(round(fitness_connected, digits=2))")
        
        # 道路なし
        x_no_roads = fill(2.0, H*W)
        fitness_no_roads = fitness_city(x_no_roads)
        @test fitness_no_roads < fitness_connected
        println("  ✓ 道路なし都市の適応度: $(round(fitness_no_roads, digits=2))")
        println("  ✓ ペナルティ確認: 道路なし < 連結道路")
    end
    
    @testset "6. 施設配置バランス" begin
        Random.seed!(789)
        x = create_connected_road_network()
        grid = reshape(Int.(round.(x)), H, W)
        
        counts = Dict(i => sum(grid .== i) for i in 0:4)
        
        @test all(counts[i] > 0 for i in 0:4)
        @test sum(values(counts)) == H * W
        
        println("  施設分布:")
        println("    🌳 公園: $(counts[0])")
        println("    🟫 道路: $(counts[1])")
        println("    🏠 住宅: $(counts[2])")
        println("    🏢 職場: $(counts[3])")
        println("    🏪 サービス: $(counts[4])")
        println("  ✓ 全施設タイプ存在")
        println("  ✓ 合計: $(sum(values(counts)))")
    end
    
    @testset "7. 進化アルゴリズム（小規模）" begin
        original_popsize = CFG.popsize
        original_generations = CFG.generations
        
        CFG.popsize = 10
        CFG.generations = 5
        
        Random.seed!(999)
        best_x, best_f = run_ga()
        
        @test length(best_x) == H * W
        @test isa(best_f, Float64)
        
        grid = reshape(Int.(round.(best_x)), H, W)
        n_components = count_road_components(grid, 1, 1, H, W)
        n_roads = sum(grid .== 1)
        
        if n_roads > 0
            @test n_components == 1
        end
        
        println("  ✓ 個体サイズ: $(length(best_x))")
        println("  ✓ 最終適応度: $(round(best_f, digits=2))")
        println("  ✓ 道路連結: $(n_components == 1 ? "完全連結" : "$(n_components)成分")")
        
        CFG.popsize = original_popsize
        CFG.generations = original_generations
    end
    
    @testset "8. エッジケース" begin
        empty_grid = zeros(Int, 5, 5)
        n_components = count_road_components(empty_grid, 1, 1, 5, 5)
        @test n_components == 0
        println("  ✓ 空グリッド: 成分数 = $n_components")
        
        all_roads = ones(Int, 5, 5)
        n_components = count_road_components(all_roads, 1, 1, 5, 5)
        @test n_components == 1
        println("  ✓ 全道路グリッド: 成分数 = $n_components")
        
        tiny_grid = ones(Int, 2, 2)
        n_components = count_road_components(tiny_grid, 1, 1, 2, 2)
        @test n_components == 1
        println("  ✓ 2×2グリッド: 成分数 = $n_components")
    end
end

println("\n" * "="^50)
println("🎉 全テスト完了！")
println("="^50)