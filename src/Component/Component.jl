module Component
    using ..engine
    abstract type EntityComponent end
    include("Collider.jl")
    
    export Collider
end