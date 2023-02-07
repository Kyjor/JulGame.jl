include("Animator.jl")
include("Collider.jl")
include("Rigidbody.jl")
include("Sprite.jl")
include("Transform.jl")
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Entity
    name::String
    components::Array{Any}
    
    function Entity(name::String)
        this = new()
        
        this.name = name
        this.components = []
        this.addComponent(Transform())

        return this
    end

    function Entity(name::String, transform::Transform)
        this = new()
        println("trying to add entity")
        this.name = name
        this.components = []
        this.addComponent(transform)

        return this
    end

    function Entity(name::String, transform::Transform, components::Array)
        this = new()
        println("trying to add entity")
        this.name = name
        this.components = []
        this.addComponent(transform)
        for component in components
            this.addComponent(component)
        end

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
    elseif s == :getAnimator
        function()
            return this.getComponent(Animator)
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
            if typeof(component) <: Animator && this.getSprite() != C_NULL 
                component.setSprite(this.getSprite())
            elseif typeof(component) <: Sprite && this.getAnimator() != C_NULL
                this.getAnimator().setSprite(component)
            end
        end
    elseif s == :update
        function()
            for component in this.components
                # if typeof(component) <: Sprite
                #    component.update()
                # end
           end
        end
    else
        getfield(this, s)
    end
end