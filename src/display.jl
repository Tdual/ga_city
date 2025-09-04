# display.jl - 表示関連の関数

# Dependencies are loaded via modules.jl

"""
都市のサンプル領域を絵文字で表示
"""
function print_city_sample(x::AbstractVector{<:Real}, sample_size::Int=30)
    grid = reshape(Int.(round.(x)), H, W)
    
    # 表示する範囲を決定（中央付近）
    start_h = max(1, H ÷ 2 - sample_size ÷ 2)
    start_w = max(1, W ÷ 2 - sample_size ÷ 2)
    end_h = min(H, start_h + sample_size - 1)
    end_w = min(W, start_w + sample_size - 1)
    
    println("都市の一部を表示 ($(end_h-start_h+1)×$(end_w-start_w+1), 位置: [$start_h:$end_h, $start_w:$end_w])")
    println("🌳=公園 🟫=道路 🏠=住宅 🏢=職場 🏪=サービス")
    println("─" ^ 40)
    
    for i in start_h:end_h
        for j in start_w:end_w
            print(SYMBOL[grid[i, j]])
        end
        println()
    end
end

"""
設定内容を表示
"""
function print_config()
    println("設定OK：")
    println("  w_commute=$(CFG.w_commute)  w_service=$(CFG.w_service)")
    println("  w_park=$(CFG.w_park)  w_road_connect=$(CFG.w_road_connect)")
    println("  w_road_network=$(CFG.w_road_network)  penalty_disconnect=$(CFG.penalty_disconnect)")
    println("  popsize=$(CFG.popsize)  generations=$(CFG.generations)")
    println("  selection=$(CFG.selection_method)  crossover=$(CFG.crossover_method)  mutation=$(CFG.mutation_method)")
    println("=" ^ 41)
end