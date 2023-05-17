module platformer
include("../../../src/julgame.jl")
#include("../scenes/level_0.jl")
include("../scenes/level_1.jl")
using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 


    function run()
        level = level_1()
        initSDL()
        return level.init(false)
    end

    function runEditor()
        SDL2.init()
        level = level_1()

        return level.init(true)
    end

    function initSDL()
        SDL2.init()
    end

    julia_main() = run()
end