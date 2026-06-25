module TransformModule
    using ..Component.JulGame 
    import ..Component
    
    export Transform
    mutable struct Transform
        position::Math.Vector3f
        scale::Math.Vector3f
        rotation::Math.Vector3f
        screenPosition::Math.Vector2
        screenRotation::Math.Vector2
        parent

        function Transform(position::Math.Vector3f = Math.Vector3f(0.0, 0.0, 0.0), scale::Math.Vector3f = Math.Vector3f(1.0, 1.0, 1.0), rotation::Math.Vector3f = Math.Vector3f(0.0, 0.0, 0.0), parent = nothing)
            this = new()
            
            this.position = position
            this.scale = scale
            this.rotation = rotation
            this.screenPosition = Math.Vector2(0.0, 0.0)
            this.screenRotation = Math.Vector2(0.0, 0.0)
            this.parent = parent
            JulGame.EventsModule.ObserverModule.add_observer((event, data) -> on_notify(event, data))

            return this
        end   
    end     

    function Component.duplicate(this::Transform, parent::Any)
        newTransform = Transform(this.position, this.scale, this.rotation, this.parent)
        return newTransform
    end

    function Component.is_mouse_hovering(this::Transform)
        mousePosition = JulGame.InputModule.get_mouse_position_in_world_space()
        if mousePosition.x >= this.position.x && mousePosition.x <= this.position.x + this.scale.x && mousePosition.y >= this.position.y && mousePosition.y <= this.position.y + this.scale.y
            return true
        end
        
        return false
    end

    function Base.setproperty!(this::Transform, property::Symbol, value::Any)
        # only log if the property is already defined
        if JulGame.IS_EDITOR && !JulGame.IS_EDITOR_PLAY_MODE && isdefined(this, property) && JulGame.engine_states.current_state == :game_mode && isdefined(this, :parent) && this.parent !== nothing
            #@debug "setting transform property $(property) to: $(value)"
            JulGame.EventsModule.ObserverModule.notify_observer(:updated_transform, (id = this.parent.id, property = property, oldValue = getfield(this, property), newValue = value))
        end
        # Call the default setproperty! behavior
        invoke(setproperty!, Tuple{Any, Symbol, Any}, this, property, value)
    end

    function on_notify(event::Symbol, data::Any)
        if event == :updated_transform
          #  @debug "updated_transform oldValue: $(data.oldValue) newValue: $(data.newValue)"
        end
    end
end
