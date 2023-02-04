__precompile__()
include("Math/Vector2f.jl")
include("Collider.jl")
include("Rigidbody.jl")
include("Sprite.jl")
include("Transform.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Entity
    transform::Transform
    name::String
    sprite
    collider
    rigidbody
    components::Array
    
    function Entity(name)
        this = new()

        this.name = name
        this.transform = Transform()
        this.components = []
        return this
    end

    function Entity(name, transform::Transform)
        this = new()

        this.name = name
        this.transform = transform
        this.components = []
        this.sprite = C_NULL
        this.collider = C_NULL
        this.rigidbody = C_NULL
        return this
    end

    function Entity(name, transform::Transform, sprite)
        this = new()

        this.name = name
        this.transform = transform
        this.sprite = sprite
        this.components = []
        if this.sprite != C_NULL
            this.sprite.setParent(this)
        end
        this.collider = C_NULL
        this.rigidbody = C_NULL

        return this
    end

    function Entity(name, transform::Transform, sprite, collider)
        this = new()

        this.name = name
        this.transform = transform
        this.sprite = sprite
        this.collider = collider
        if this.collider != C_NULL
            this.collider.setParent(this)
        end
        this.components = []
        if this.sprite != C_NULL
            this.sprite.setParent(this)
        end
        this.rigidbody = C_NULL
        return this
    end
    
     function Entity(name, transform::Transform, collider)
        this = new()

        this.name = name
        this.transform = transform
        this.collider = collider
        if this.collider != C_NULL
            this.collider.setParent(this)
        end
        this.components = []
        this.sprite = C_NULL
        this.rigidbody = C_NULL
        return this
    end

    function Entity(name, transform::Transform, sprite, collider, rigidbody)
        this = new()

        this.name = name
        this.transform = transform
        this.sprite = sprite
        this.components = []
        if this.sprite != C_NULL
            this.sprite.setParent(this)
        end
            
        this.collider = collider
        if this.collider != C_NULL
            this.collider.setParent(this)
        end
        this.rigidbody = rigidbody
        if this.rigidbody != C_NULL
            this.rigidbody.setParent(this)
        end
        

        return this
    end
end

function Base.getproperty(this::Entity, s::Symbol)
    if s == :getName
        function()
            return this.name
        end
    elseif s == :getTransform
        function()
            return this.transform
        end
    elseif s == :getSprite
        function()
            return this.sprite
        end
    elseif s == :getCollider
        function()
            return this.collider
        end
    elseif s == :getRigidbody
        function()
           return this.rigidbody
        end
    elseif s == :addComponent
        function(component)
            println(string("Adding component of type: ", typeof(component), " to entity named " ,this.name))
           if typeof(component) <: Transform
            this.transform = component
            this.transform.setParent(this)
           elseif typeof(component) <: Sprite
            this.sprite = component
            this.sprite.setParent(this)
           elseif typeof(component) <: Collider
            this.collider = component
            this.collider.setParent(this)
           elseif typeof(component) <: Rigidbody
            this.rigidbody = component
            this.rigidbody.setParent(this)
           else
            println("Invalid type") 
           end 
           component.setParent(this)
           push!(this.components, component)
        end
    elseif s == :update
        function()
            for component in this.components
               if typeof(component) <: Sprite
                   component.update()
               end
           end
           if this.transform != C_NULL
               this.transform.update()
           end
           if this.sprite != C_NULL || isdefined(Base, this.sprite) == false
               # this.sprite.update()
           end
           if this.collider != C_NULL
               this.collider.update()
           end
           if this.rigidbody != C_NULL
               this.rigidbody.update()
           end
        end
    else
        getfield(this, s)
    end
end