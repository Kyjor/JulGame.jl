mutable struct Script
    name::String
    serializedVariables::Array

    #default constructor
    Script() = new("", [])
    
    Script(name::String, serializedVariables::Array) = new(name, serializedVariables)
end   
