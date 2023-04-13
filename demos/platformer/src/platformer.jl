module platformer
include("../scenes/level_0.jl")

    function run()
        return level_0()
    end

    function runEditor()
        return level_0(true)
    end

    julia_main() = run()
end