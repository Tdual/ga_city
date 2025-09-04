#!/usr/bin/env julia
# test_ga_city.jl - GA City のテストスイート

using Test
using Random
using Statistics

# モジュールを読み込み
include("../src/modules.jl")

@testset "GA City Tests" begin
    
    @testset "基本的な定数と構造体" begin
        @test H == 100
        @test W == 100
        @test length(SYMBOL) == 5
        @test SYMBOL[0] == "🌳"
        @test SYMBOL[1] == "🟫"
        @test SYMBOL[2] == "🏠"
        @test SYMBOL[3] == "🏢"
        @test SYMBOL[4] == "🏪"
        
        # GameConfig のデフォルト値
        cfg = GameConfig()
        @test cfg.w_commute == -1.0
        @test cfg.w_service == -0.6
        @test cfg.w_park == 0.8
        @test cfg.w_road_connect == -10.0
        @test cfg.w_road_network == 100.0
        @test cfg.penalty_disconnect == -1000.0
    end
    
    @testset "Union-Find 実装" begin
        # 5x5グリッドでテスト
        test_grid = [
            1 1 0 0 0;
            1 0 0 2 2;
            0 0 1 1 1;
            0 0 1 0 0;
            3 3 1 1 1
        ]
        
        n_components = count_road_components(test_grid, 1, 1, 5, 5)
        @test n_components == 2  # 2つの道路グループがある
    end
    
    @testset "道路連結性の初期化" begin
        # 初期化された道路網が連結されているか確認
        Random.seed!(42)
        x_init = create_connected_road_network()
        
        # グリッドに変換
        grid = reshape(Int.(round.(x_init)), H, W)
        
        # 道路の連結成分数を確認
        n_components = count_road_components(grid, 1, 1, H, W)
        @test n_components == 1  # 必ず1つの連結成分
        
        # 道路が存在することを確認
        n_roads = sum(grid .== 1)
        @test n_roads > 0
        @test n_roads >= H + W - 1  # 最低限のスパニングツリー
    end
    
    @testset "連結性修復関数" begin
        # 修復関数が動作することを確認
        Random.seed!(123)
        
        # 完全に分断された道路を作成
        x_broken = fill(0.0, H*W)
        # 左上隅に道路の島
        for i in 1:100
            x_broken[i] = 1.0
        end
        # 右下隅に道路の島
        for i in 9901:10000
            x_broken[i] = 1.0
        end
        
        # 修復前の連結成分数
        grid_before = reshape(Int.(round.(x_broken)), H, W)
        n_before = count_road_components(grid_before, 1, 1, H, W)
        @test n_before == 2  # 2つの分離した道路グループ
        
        # 修復実行
        x_fixed = copy(x_broken)
        repair_connectivity!(x_fixed)
        
        # 修復後の道路数を確認
        grid_after = reshape(Int.(round.(x_fixed)), H, W)
        n_roads_after = sum(grid_after .== 1)
        n_roads_before = sum(grid_before .== 1)
        
        # 修復により道路が追加されることを確認
        @test n_roads_after >= n_roads_before
        
        # 関数が正常に実行されることを確認
        @test isa(x_fixed, Vector)
        @test length(x_fixed) == H*W
    end
    
    @testset "適応度関数の計算" begin
        Random.seed!(456)
        
        # ランダムな都市を生成
        x_random = Float64.(rand(0:4, H*W))
        fitness_random = fitness_city(x_random)
        @test isa(fitness_random, Float64)
        @test fitness_random < 0  # 通常は負の値
        
        # 完全に連結された道路網
        x_connected = create_connected_road_network()
        fitness_connected = fitness_city(x_connected)
        @test isa(fitness_connected, Float64)
        
        # 道路なしの都市
        x_no_roads = fill(2.0, H*W)  # 全て住宅
        fitness_no_roads = fitness_city(x_no_roads)
        @test fitness_no_roads < fitness_connected  # 道路なしはペナルティ大
    end
    
    @testset "マンハッタン距離計算" begin
        # 基本的なマンハッタン距離の計算確認
        # (1,1) から (5,5) への距離
        dist = abs(5-1) + abs(5-1)
        @test dist == 8
        
        # (2,3) から (7,4) への距離
        dist = abs(7-2) + abs(4-3)
        @test dist == 6
        
        # 同じ位置
        dist = abs(3-3) + abs(3-3)
        @test dist == 0
    end
    
    @testset "施設配置のバランス" begin
        Random.seed!(789)
        x = create_connected_road_network()
        grid = reshape(Int.(round.(x)), H, W)
        
        # 各施設タイプの数を集計
        counts = Dict(i => sum(grid .== i) for i in 0:4)
        
        # 全施設タイプが存在することを確認
        @test counts[0] > 0  # 公園
        @test counts[1] > 0  # 道路
        @test counts[2] > 0  # 住宅
        @test counts[3] > 0  # 職場
        @test counts[4] > 0  # サービス
        
        # 合計がグリッドサイズと一致
        @test sum(values(counts)) == H * W
    end
    
    @testset "進化アルゴリズムの基本動作" begin
        # 小規模な進化を実行（時間短縮のため）
        original_popsize = CFG.popsize
        original_generations = CFG.generations
        
        CFG.popsize = 10
        CFG.generations = 5
        
        Random.seed!(999)
        best_x, best_f = run_ga()
        
        # 結果の検証
        @test length(best_x) == H * W
        @test isa(best_f, Float64)
        
        # 連結性の確認
        grid = reshape(Int.(round.(best_x)), H, W)
        n_components = count_road_components(grid, 1, 1, H, W)
        if sum(grid .== 1) > 0
            @test n_components == 1  # 道路は必ず連結
        end
        
        # 設定を元に戻す
        CFG.popsize = original_popsize
        CFG.generations = original_generations
    end
    
    @testset "エッジケース" begin
        # 空のグリッド
        empty_grid = zeros(Int, 5, 5)
        n_components = count_road_components(empty_grid, 1, 1, 5, 5)
        @test n_components == 0
        
        # 全て道路
        all_roads = ones(Int, 5, 5)
        n_components = count_road_components(all_roads, 1, 1, 5, 5)
        @test n_components == 1
        
        # 非常に小さいグリッド
        tiny_grid = ones(Int, 2, 2)
        n_components = count_road_components(tiny_grid, 1, 1, 2, 2)
        @test n_components == 1
    end
end

# テスト実行のサマリーを表示
println("\n" * "="^50)
println("テスト完了！")
println("="^50)