module Editor
    include("../../../src/julGame.jl")

    function run()
       julGame.Editor.run()
    end

    julia_main() = run()
end