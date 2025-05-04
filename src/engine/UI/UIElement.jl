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

    if hasfield(typeof(relationships[script]), property)
        #println("setproperty! from parent: $(property) ")
        setfield!(relationships[script], property, value)
    else
        #println("setproperty! from child: $(property) ")
        setfield!(script, property, value)
    end

    if contains("$(typeof(script))", "TextBox")
        @debug "rerendering text for $(script)"
        if property == :text || property == :isActive || property == :textColor || property == :maxLineWidth || property == :wrapWords || property == :fontSize || property == :color
            #= if s == :text && length(x) == 0
                setfield!(this, s, " ")# prevents segfault when text is empty
            end =#
            if script.isConstructed
                @debug("rerendering text for $(script.name) because of $(property) = $(value)")
                UI.rerender_text(script) # this line MUST stay inside the if for specific fields as we can't call this on fields that are used in this function
            end
        end
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

function UI.set_color(this::UIElement; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
    this.color = (r%256, g%256, b%256, a%256)
end

function UI.align_to_anchor(this::UIElement)
    if MAIN.scene.camera === nothing
        @debug "No camera found in scene"
        return
    end

    #@info "centering text $(this.name) with anchor $(this.anchor.current_state)"
    size = MAIN.scene.camera.size
    parent_pos = Math.Vector2(0, 0)
    if this.parent !== nothing
        size = this.parent.size
        parent_pos = this.parent.position
    end

    if this.anchor.current_state == :center
        this.position = Math.Vector2(
            parent_pos.x + max(size.x/2 - this.size.x/2, 0) + this.anchorOffset.x, 
            parent_pos.y + max(size.y/2 - this.size.y/2, 0) + this.anchorOffset.y
        )  
    elseif this.anchor.current_state == :top
        this.position = Math.Vector2(
            parent_pos.x + max(size.x/2 - this.size.x/2, 0) + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottom
        this.position = Math.Vector2(
            parent_pos.x + max(size.x/2 - this.size.x/2, 0) + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :left
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + max(size.y/2 - this.size.y/2, 0) + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :right
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + max(size.y/2 - this.size.y/2, 0) + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :topLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :topRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottomLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottomRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + max(size.y/2 - this.size.y/2, 0) + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + max(size.y/2 - this.size.y/2, 0) + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerTop
        this.position = Math.Vector2(
            parent_pos.x + max(size.x/2 - this.size.x/2, 0) + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerBottom
        this.position = Math.Vector2(
            parent_pos.x + max(size.x/2 - this.size.x/2, 0) + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :none
        @debug "No anchor set for textbox $(this.name)"
    else
        @error "Invalid anchor state: $(this.anchor.current_state)"
    end
end