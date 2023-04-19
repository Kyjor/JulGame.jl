module Component
    using ..engine: Math
    abstract type EntityComponent end
    include("Collider.jl")
    
    export Collider
end