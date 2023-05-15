module platformer
include("../../../src/julgame.jl")
include("../scenes/level_0.jl")
#include("../scenes/level_1.jl")

    function run()
        level = level_0()
        return level.init(false)
    end

    function runEditor()
        level = level_0()

        return level.init(true)
    end

    julia_main() = run()
end