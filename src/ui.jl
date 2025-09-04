# ui.jl - ユーザーインターフェース

# Dependencies are loaded via modules.jl

"""
メニューを表示して設定を取得
"""
function menu()
    println("=== Genetic City 設定 ($(H)×$(W)グリッド) ===")
    
    # プリセット選択
    println("プリセットを選択:")
    for (id, (name, preset)) in PRESETS
        println(" $id) $(rpad(name, 16))" *
                "(通勤$(preset.w_commute), サービス$(preset.w_service), " *
                "公園+$(preset.w_park), 道路接続$(preset.w_road_connect), " *
                "連結+$(preset.w_road_network))")
    end
    println(" 5) カスタム設定")
    
    print("選択 [1–5] (Enter=1): ")
    choice = readline()
    choice = isempty(choice) ? 1 : parse(Int, choice)
    
    if choice in 1:4
        apply_preset!(choice)
    elseif choice == 5
        # カスタム設定
        print("通勤距離の重み [-2.0 to 0] (Enter=-1.0): ")
        input = readline()
        CFG.w_commute = isempty(input) ? -1.0 : parse(Float64, input)
        
        print("サービス距離の重み [-2.0 to 0] (Enter=-0.6): ")
        input = readline()
        CFG.w_service = isempty(input) ? -0.6 : parse(Float64, input)
        
        print("公園比率の重み [0 to 2.0] (Enter=0.8): ")
        input = readline()
        CFG.w_park = isempty(input) ? 0.8 : parse(Float64, input)
        
        print("道路接続ペナルティ [-20.0 to 0] (Enter=-10.0): ")
        input = readline()
        CFG.w_road_connect = isempty(input) ? -10.0 : parse(Float64, input)
        
        print("道路連結ボーナス [0 to 200] (Enter=100.0): ")
        input = readline()
        CFG.w_road_network = isempty(input) ? 100.0 : parse(Float64, input)
    end
    
    # 進化パラメータ
    println("--- 進化パラメータ ---")
    
    print("個体数 [$(CFG.popsize)]: ")
    input = readline()
    if !isempty(input)
        CFG.popsize = parse(Int, input)
    end
    
    print("世代数 [$(CFG.generations)]: ")
    input = readline()
    if !isempty(input)
        CFG.generations = parse(Int, input)
    end
    
    print("進行ログ表示 0/1 [0]: ")
    input = readline()
    CFG.verbose = !isempty(input) && input == "1"
    
    # 遺伝的演算子の選択
    println("--- オペレータ選択（環境に無ければ自動で代替） ---")
    
    print("Selection [susinv | tournament] (Enter=susinv): ")
    input = readline()
    if !isempty(input) && input in ["susinv", "tournament"]
        CFG.selection_method = input
    end
    
    print("Crossover [DC | uniformbin]     (Enter=DC): ")
    input = readline()
    if !isempty(input) && input in ["DC", "uniformbin"]
        CFG.crossover_method = input
    end
    
    print("Mutation  [PLM | gaussian]      (Enter=PLM): ")
    input = readline()
    if !isempty(input) && input in ["PLM", "gaussian"]
        CFG.mutation_method = input
    end
    
    print_config()
end