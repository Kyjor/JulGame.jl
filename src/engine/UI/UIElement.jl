abstract type UIElement end

mutable struct UIElementInstance
    # identifiers
    id::String
    name::String

    # positioning
    anchor::Union{JulGame.Enum, Nothing} # JulGame.EntityModule.Entity, Nothing}
    anchorOffset::Vector2
    isWorldEntity::Bool
    layer::Int
    parent::Union{UIElement, Nothing}
    position::Vector2
    size::Vector2

    # events
    clickEvents::Vector{Function}
    hoverEnterEvents::Vector{Function}
    hoverExitEvents::Vector{Function}

    # state
    isActive::Bool
    isHovered::Bool
    persistentBetweenScenes::Bool
    
    # rendering
    color::NTuple{4, Int}
    
    
    function UIElementInstance()
        this = new()


        return this
    end
end

relationships = Dict{UIElement, UIElementInstance}()

function Base.getproperty(script::UIElement, property::Symbol)
    # Check if the relationship exists
    add_relationship_if_not_exists(script)

    if hasfield(typeof(relationships[script]), property)
        #println("getproperty from parent: $(property) ")
        return getfield(relationships[script], property)
    end

    #println("getproperty from child: $(property) ")
    return getfield(script, property)
end

function Base.setproperty!(script::UIElement, property::Symbol, value)
    add_relationship_if_not_exists(script)

    #println("relationships[script]: $(relationships[script])")
    # check if the FightingEntity has the property
    if hasfield(typeof(relationships[script]), property)
        #println("setproperty! from parent: $(property) ")
        setfield!(relationships[script], property, value)
    else
        #println("setproperty! from child: $(property) ")
        setfield!(script, property, value)
    end
end

function add_relationship_if_not_exists(script::UIElement)
    if !haskey(relationships, script)
        #println("Adding relationship for $(script)")
        relationships[script] = UIElementInstance()
        return
    end
    #println("Relationship already exists for $(script)")
end

function delete_relationship(script::UIElement)
    if haskey(relationships, script)
        delete!(relationships, script)
    end
end