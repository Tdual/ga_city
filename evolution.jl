# evolution.jl - 進化アルゴリズム関連

using Evolutionary

# Dependencies are loaded via modules.jl

"""
遺伝的アルゴリズムで都市を進化させる
"""
function run_ga()
    # 初期個体生成
    init_func() = create_connected_road_network()
    
    # 最適化制約
    lbound = fill(0.0, H*W)
    ubound = fill(4.0, H*W)
    
    # 選択方法
    selection = if CFG.selection_method == "susinv"
        susinv
    elseif CFG.selection_method == "tournament"
        tournament(5)
    else
        roulette
    end
    
    # 交叉方法
    crossover = if CFG.crossover_method == "DC"
        DC
    elseif CFG.crossover_method == "uniformbin"
        uniformbin(0.5)
    else
        intermediate(0.5)
    end
    
    # 変異方法
    mutation = if CFG.mutation_method == "PLM"
        PLM()
    elseif CFG.mutation_method == "gaussian"
        gaussian(0.5)
    else
        uniform()
    end
    
    # 最適化実行
    result = Evolutionary.optimize(
        fitness_city,
        BoxConstraints(lbound, ubound),
        init_func,
        GA(
            selection=selection,
            crossover=crossover,
            mutation=mutation,
            mutationRate=0.1,
            crossoverRate=0.8,
            populationSize=CFG.popsize
        ),
        Evolutionary.Options(
            iterations=CFG.generations,
            show_trace=CFG.verbose,
            show_every=10
        )
    )
    
    # 連結性を修復
    best_x = result.minimizer
    repair_connectivity!(best_x)
    
    return best_x, fitness_city(best_x)
end