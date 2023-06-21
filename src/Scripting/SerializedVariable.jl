include("SerializedVariable.jl")

mutable struct Script
    name::String
    serializedVariables::Array{SerializedVariable}

    #default constructor
    Script() = new("", [])
    
    Script(name::String, serializedVariables::Array) = new(name, serializedVariables)
end   
