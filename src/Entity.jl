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
        id::Integer
        components::Array{Any}
        isActive::Bool
        name::String
        scripts::Array{Any}
        #
        function Entity(name::String = "New entity", transform::Union{Ptr{Nothing}, Transform} = C_NULL, components::Array{Union{Animation, Animator, Collider, CircleCollider, Rigidbody, Shape, SoundSource, Sprite}} = Vector{Union{Animation, Animator, Collider, CircleCollider, Rigidbody, Shape, SoundSource, Sprite}}(), scripts::Array = [])
            this = new()

            this.id = 1
            this.name = name
            this.components = []
            this.isActive = true
            transform = transform == C_NULL ? Transform() : transform
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
                        if typeof(component) <: CircleCollider #typeof(component) <: Collider || 
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
        elseif s == :getShape
            function()
                return this.getComponent(Shape)
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
        elseif s == :getSoundSource
            function()
            return this.getComponent(SoundSource)
            end
        elseif s == :addComponent
            function(component)
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
            function()
                if this.getComponent(Animator) != C_NULL
                    return
                end
                this.addComponent(Animator([Animation([Vector4(0,0,0,0)], 60)]))
            end
        elseif s == :addCollider
            function()
                if this.getComponent(Collider) != C_NULL || this.getComponent(CircleCollider) == C_NULL
                    return
                end
                this.addComponent(Collider(Vector2f(this.getTransform().scale.x, this.getTransform().scale.y), "Test"))
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
                this.getComponent("Sprite").injectRenderer(game.renderer)
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
            end
        end
    end
end