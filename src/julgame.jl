module engine
    include("Math/Math.jl")
    using .Math: Math
    export Math

    include("Input/InputInstance.jl")
    using .InputInstance: Input
    export Input

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(2.0)
    #export MainLoop
    export MAIN

    export component
    include("Component/Component.jl")
    using .Component: Collider
    export Collider

end

global julgame = engine