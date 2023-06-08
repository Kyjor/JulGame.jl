module EntityModule
    using ..julGame.AnimationModule
    using ..julGame.AnimatorModule
    using ..julGame.ColliderModule
    using ..julGame.Math
    using ..julGame.RigidbodyModule
    using ..julGame.SoundSourceModule
    using ..julGame.SpriteModule
    using ..julGame.TransformModule

    export Entity
    mutable struct Entity
        id::Integer
        components::Array{Any}
        isActive::Bool
        name::String
        scripts::Array{Any}
        
        function Entity()
            this = new()

            return this
        end

        function Entity(name::String)
            this = new()
            
            this.id = 1
            this.components = []
            this.isActive = true
            this.name = name
            this.scripts = []

            return this
        end

        function Entity(name::String, transform)
            this = new()

            this.id = 1
            this.components = []
            this.isActive = true
            this.name = name
            this.addComponent(transform == C_NULL ? Transform() : transform)
            this.scripts = []

            return this
        end

        function Entity(name::String, transform::Transform, components::Array)
            this = new()

            this.id = 1
            this.components = []
            this.isActive = true
            this.name = name
            this.addComponent(transform)
            for component in components
                this.addComponent(component)
            end
            this.scripts = []

            return this
        end
        
        function Entity(name::String, transform::Transform, components::Array, scripts::Array)
            this = new()

            this.id = 1
            this.name = name
            this.components = []
            this.isActive = true
            this.addComponent(transform)
            for component in components
                this.addComponent(component)
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
                println(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
                push!(this.scripts, script)
                script.setParent(this)
            end
        elseif s == :getScripts
            function()
                return this.scripts
            end
        elseif s == :update
            function(deltaTime)
                for script in this.scripts
    #                script.update(deltaTime)
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
                if this.getComponent(Collider) != C_NULL
                    return
                end
                this.addComponent(Collider(Vector2f(this.getTransform().scale.x, this.getTransform().scale.y), "Test"))
            end
        elseif s == :addRigidbody
            function()
                if this.getComponent(Rigidbody) != C_NULL
                    return
                end
                this.addComponent(Rigidbody(1.0))
            end
        elseif s == :addSoundSource
            function(basePath)
                if this.getComponent(SoundSource) != C_NULL
                    return
                end
                this.addComponent(SoundSource(basePath))
            end
        elseif s == :addSprite
            function(basePath, game)
                if this.getComponent(Sprite) != C_NULL
                    return
                end
                this.addComponent(Sprite(basePath, "", true))
                this.getComponent("Sprite").injectRenderer(game.renderer)
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