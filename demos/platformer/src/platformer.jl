module platformer
include("../scenes/level_0.jl")

    function run()
        level_0()
    end

    julia_main() = run()
end