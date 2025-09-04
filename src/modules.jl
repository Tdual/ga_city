# modules.jl - 全モジュールの読み込み（一度だけ実行）

if !@isdefined(MODULES_LOADED)
    const MODULES_LOADED = true
    
    include("config.jl")
    include("road_connectivity.jl")
    include("fitness.jl")
    include("evolution.jl")
    include("display.jl")
    include("ui.jl")
end