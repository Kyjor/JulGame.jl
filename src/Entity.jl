module EntityModule
    using ..JulGame.AnimationModule
    using ..JulGame.AnimatorModule
    using ..JulGame.ColliderModule
    using ..JulGame.CircleColliderModule
    using ..JulGame.Math
    using ..JulGame.RigidbodyModule
    using ..JulGame.ShapeModule
    using ..JulGame.SoundSourceModule
    using ..JulGame.SpriteModule
    using ..JulGame.TransformModule

    export Entity
    mutable struct Entity
        id::Int
        animator::Union{InternalAnimator, Ptr{Nothing}}
        collider::Union{InternalCollider, Ptr{Nothing}}
        circleCollider::Union{CircleCollider, Ptr{Nothing}}
        rigidbody::Union{Rigidbody, Ptr{Nothing}}
        shape::Union{Shape, Ptr{Nothing}}
        soundSource::Union{Vector{SoundSource}, Ptr{Nothing}}
        Sprite::Union{Sprite, Ptr{Nothing}}
        transform::Transform

        components::Vector{Union{CircleCollider, Rigidbody, Shape, SoundSource, Sprite, Transform}}
        isActive::Bool
        name::String
        persistentBetweenScenes::Bool
        scripts::Vector{Any}
        
        function Entity(name::String = "New entity", transform::Transform = Transform(), components::Vector{Union{Animation, Animator, CircleCollider, Rigidbody, Shape, SoundSource, Sprite}} = Vector{Union{Animation, Animator, CircleCollider, Rigidbody, Shape, SoundSource, Sprite}}(), scripts::Array = [])
            this = new()

            this.id = 1
            this.name = name
            this.animator = C_NULL
            this.collider = C_NULL
            this.components = []
            this.isActive = true
            this.addComponent(transform)
            if components != C_NULL
                for component in components
                    this.addComponent(component)
                end
            end
            this.scripts = []
            for script in scripts
                this.addScript(script)
            end
            this.persistentBetweenScenes = false

            return this
        end
    end

    function Base.getproperty(this::Entity, s::Symbol)
        if s == :getComponent #Retrieves the first component of specified type from the list of components attached to the entity
            function(componentType)
                if typeof(componentType) == String
                    componentType = eval(Symbol(componentType))
                end

                for component in this.components
                    if componentType <: Collider
                        if typeof(component) <: CircleCollider
                            return component
                        end
                    end

                    if typeof(component) <: componentType
                        return component
                    end
                end
                return C_NULL
            end
        elseif s == :removeComponent #Retrieves the first component of specified type from the list of components attached to the entity
            function(componentType)
                for i = 1:length(this.components)
                    if typeof(this.components[i]) <: componentType
                        deleteat!(this.components, i)
                    end
                end
                return C_NULL
            end
        elseif s == :getTransform
            function()
                return this.getComponent(Transform)
            end
        elseif s == :getSprite
            function()
                return this.getComponent(Sprite)
            end
        elseif s == :getShape
            function()
                return this.getComponent(Shape)
            end
        elseif s == :getRigidbody
            function()
            return this.getComponent(Rigidbody)
            end
        elseif s == :getSoundSource
            function()
            return this.getComponent(SoundSource)
            end
        elseif s == :addComponent
            function(component::Union{Animator, CircleCollider, Rigidbody, Shape, SoundSource, Sprite, Transform})
                push!(this.components, component::Union{Animation, Animator, CircleCollider, Rigidbody, Shape, SoundSource, Sprite, Transform})
                if typeof(component) <: Transform
                    return
                end
                component.setParent(this)
                if typeof(component) <: Sprite && this.animator != C_NULL
                    this.animator.setSprite(component)
                end
            end
        elseif s == :addScript
            function(script)
                #println(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
                push!(this.scripts, script)
                script.setParent(this)
                try
                    script.initialize()
                catch e
                    println(e)
                    Base.show_backtrace(stdout, catch_backtrace())
                end
            end
        elseif s == :getScripts
            function()
                return this.scripts
            end
        elseif s == :update
            function(deltaTime)
                for script in this.scripts
                    try
                        script.update(deltaTime)
                    catch e
                        println(e)
                        Base.show_backtrace(stdout, catch_backtrace())
                    end
                end
            end
        elseif s == :addAnimator
            function(animator::Animator = Animator(Animation[Animation(Vector4[Vector4(0,0,0,0)], 60)]))
                if this.animator != C_NULL
                    return
                end

                this.animator = InternalAnimator(this::Entity, animator.animations)
                if this.getSprite() != C_NULL 
                    this.animator.setSprite(this.getSprite())
                end
            end
        elseif s == :addCollider
            function(collider::Collider = Collider(true, false, false, Vector2f(0,0), Vector2f(1,1), "Test"))
                if this.collider != C_NULL
                    return
                end
                    
                rigidbody::Union{Rigidbody, Ptr{Nothing}} = this.getComponent(Rigidbody)
                this.collider = InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.isPlatformerCollider::Bool, collider.enabled::Bool, rigidbody)
            end
        elseif s == :addCircleCollider
            function()
                if this.getComponent(Collider) != C_NULL || this.getComponent(CircleCollider) != C_NULL
                    return
                end
                this.addComponent(max(this.getTransform().scale.x, this.getTransform().scale.y), Vector2f(0,0), "Test")
            end
        elseif s == :addRigidbody
            function()
                if this.getComponent(Rigidbody) != C_NULL
                    return
                end
                this.addComponent(Rigidbody(1.0))
            end
        elseif s == :addSoundSource
            function()
                if this.getComponent(SoundSource) != C_NULL
                    return
                end
                this.addComponent(SoundSource())
            end
        elseif s == :addSprite
            function(game)
                if this.getComponent(Sprite) != C_NULL
                    return
                end
                this.addComponent(Sprite("", C_NULL, false, Math.Vector3(255, 255, 255), true))
                this.getComponent("Sprite").initialize()
            end
        elseif s == :addShape
            function()
                if this.getComponent(Shape) != C_NULL
                    return
                end
                this.addComponent(Shape())
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
                println("")
                println("")
                println("")
            end
        end
    end
end