module platformer
include("../../../src/julgame.jl")
#include("../scenes/level_0.jl")
include("../scenes/level_1.jl")

    function run()
        return level_1()
    end

    function runEditor()
        level = level_1()

        return level.init(true)
    end

    julia_main() = run()
end