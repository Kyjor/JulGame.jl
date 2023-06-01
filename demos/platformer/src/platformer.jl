module platformer
    include("../scenes/level_0.jl")
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(isEditor = false)
        SDL2.init()
        level = level_0()
        return level.init(isEditor)
    end

    julia_main() = run()
end