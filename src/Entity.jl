__precompile__()
include("Math/Vector2f.jl")
include("Collider.jl")
include("Rigidbody.jl")
include("Sprite.jl")
include("Transform.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Entity
    name::String
    components::Array
    
    function Entity(name)
        this = new()

        this.name = name
        this.components = []
        this.addComponent(Transform())

        return this
    end

    function Entity(name, transform::Transform)
        this = new()

        this.name = name
        this.components = []
        this.addComponent(transform)

        return this
    end
end

function Base.getproperty(this::Entity, s::Symbol)
    if s == :getComponent #Retrieves the first component of specified type from the list of components attached to the entity
        function(componentType)
            for component in this.components
               if typeof(component) <: componentType
                   return component
               end
            end
            return C_NULL
        end
    elseif s == :getName
        function()
            return this.name
        end
    elseif s == :getTransform
        function()
            return this.getComponent(Transform)
        end
    elseif s == :getSprite
        function()
            return this.getComponent(Sprite)
        end
    elseif s == :getCollider
        function()
            return this.getComponent(Collider)
        end
    elseif s == :getRigidbody
        function()
           return this.getComponent(Rigidbody)
        end
    elseif s == :addComponent
        function(component)
            println(string("Adding component of type: ", typeof(component), " to entity named " ,this.name))
            push!(this.components, component)
            if typeof(component) <: Transform
                return
            end
            component.setParent(this)
        end
    elseif s == :update
        function()
            for component in this.components
               if typeof(component) <: Sprite
                   component.update()
               end
           end
        end
    else
        getfield(this, s)
    end
end