module platformer
include("../scenes/level_0.jl")
include("../scenes/level_1.jl")

    function run()
        return level_0()
    end

    function runEditor()
        return level_1(true)
    end

    julia_main() = run()
end