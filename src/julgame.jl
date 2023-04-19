module engine
    include("Math/Math.jl")
    using .Math: Math
    export Math

    include("Input/InputInstance.jl")
    using .InputInstance: Input
    export Input

    export component
    include("Component/Component.jl")
    using .Component: Collider
    export Collider

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(2.0)
    export MainLoop
    export MAIN
end

global const julgame = engine