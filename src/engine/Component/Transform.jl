module TransformModule
    using ..Component.JulGame 
    using ..Component.JulGame.Math: _Vector2, _Vector3
    import ..Component
    
    export Transform
    mutable struct Transform
        position::_Vector3{Float64}
        scale::_Vector3{Float64}
        rotation::_Vector3{Float64}
        screenPosition::_Vector2{Float64}
        screenRotation::_Vector2{Float64}
        parent

        function Transform(
            position::Union{_Vector3{Float64}, _Vector2{Float64}} = _Vector3{Float64}(0.0, 0.0, 0.0),
            scale::Union{_Vector3{Float64}, _Vector2{Float64}} = _Vector3{Float64}(1.0, 1.0, 1.0),
            rotation::Union{_Vector3{Float64}, _Vector2{Float64}} = _Vector3{Float64}(0.0, 0.0, 0.0),
            parent = nothing,
        )
            pos3::_Vector3{Float64} = position isa _Vector3{Float64} ? position :
                _Vector3{Float64}(position.x, position.y, 0.0)
            scl3::_Vector3{Float64} = scale isa _Vector3{Float64} ? scale :
                _Vector3{Float64}(scale.x, scale.y, 0.0)
            rot3::_Vector3{Float64} = rotation isa _Vector3{Float64} ? rotation :
                _Vector3{Float64}(rotation.x, rotation.y, 0.0)
            this = new(pos3, scl3, rot3, _Vector2{Float64}(0.0, 0.0), _Vector2{Float64}(0.0, 0.0), parent)
            JulGame.EventsModule.ObserverModule.add_observer((event, data) -> on_notify(event, data))
            return this
        end   
    end     

    function Component.duplicate(this::Transform, parent::Any)
        newTransform = Transform(this.position, this.scale, this.rotation, this.parent)
        return newTransform
    end

    function Component.set_position(this::Transform, position::Union{_Vector3{Float64}, _Vector2{Float64}})
        this.position = position isa _Vector3{Float64} ? position :
            _Vector3{Float64}(position.x, position.y, 0.0)
    end

    function Component.is_mouse_hovering(this::Transform)
        mousePosition = JulGame.InputModule.get_mouse_position_in_world_space()
        if mousePosition.x >= this.position.x && mousePosition.x <= this.position.x + this.scale.x && mousePosition.y >= this.position.y && mousePosition.y <= this.position.y + this.scale.y
            return true
        end
        
        return false
    end

    function Base.setproperty!(this::Transform, property::Symbol, value::Any)
        if property == :parent
            setfield!(this, :parent, value)
            return
        end

        # only log if the property is already defined
        if JulGame.IS_EDITOR && !JulGame.IS_EDITOR_PLAY_MODE && !JulGame.juliac_trim_active() && isdefined(this, property) && JulGame.engine_states.current_state == :game_mode && isdefined(this, :parent) && this.parent !== nothing
            #@debug "setting transform property $(property) to: $(value)"
            JulGame.EventsModule.ObserverModule.notify_observer(:updated_transform, (id = JulGame.scene_entity_id((this.parent)::JulGame.Entity), property = property, oldValue = getfield(this, property), newValue = value))
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
