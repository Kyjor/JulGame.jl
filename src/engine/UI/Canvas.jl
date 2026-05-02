module CanvasModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export Canvas
    export add_child, remove_child, get_children, set_active, is_child_active

    """
    Canvas - A container UI element that can hold other UI elements as children.
    Provides hierarchical organization, anchoring, and collective activation/deactivation.
    """
    mutable struct Canvas <: JulGame.ICanvas
        children::Vector{JulGame.IUIElement}
        clipChildren::Bool
        anchor::JulGame.Enum{Any}
        anchorOffset::Math.Vector2
        id::String
        isActive::Bool
        isHovered::Bool
        layer::Int
        name::String
        position::Math.Vector2
        size::Math.Vector2
        color::NTuple{4, Int}
        persistentBetweenScenes::Bool
        parent::Union{JulGame.IUIElement, Nothing, Any}
        rotation::Float64
        forceClickCheck::Bool
        clickEvents::Vector{Function}
        hoverEnterEvents::Vector{Function}
        hoverExitEvents::Vector{Function}
        isWorldEntity::Bool
        isVisible::Bool

        function Canvas(;
            id::String=JulGame.generate_uuid(),
            name::String="Canvas",
            anchor::Symbol=:none,
            anchorOffset::Math.Vector2=Math.Vector2(0, 0),
            layer::Int=0,
            position::Math.Vector2=Math.Vector2(0, 0),
            size::Math.Vector2=Math.Vector2(0, 0),
            clickEvents::Vector{Function}=Function[],
            hoverEnterEvents::Vector{Function}=Function[],
            hoverExitEvents::Vector{Function}=Function[],
            clickEvent::Union{Function, Nothing}=nothing,
            hoverEnterEvent::Union{Function, Nothing}=nothing,
            hoverExitEvent::Union{Function, Nothing}=nothing,
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(0, 0, 0, 0),
            clipChildren::Bool=false,
            parent::Union{JulGame.IUIElement, Nothing, Any}=nothing,
            rotation::Float64=0.0,
            forceClickCheck::Bool=false,
            isWorldEntity::Bool=false,
            isVisible::Bool=true,
        )
            this = new()
            this.children = JulGame.IUIElement[]
            this.clipChildren = clipChildren
            this.anchor = JulGame.Enum{Any}(JulGame.UI.ANCHOR_STATE_SYMBOLS...)
            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.id = id
            this.isActive = isActive
            this.isHovered = false
            this.layer = layer
            this.name = name
            this.position = position
            this.size = size
            this.color = color
            this.persistentBetweenScenes = persistentBetweenScenes
            this.parent = parent
            this.rotation = rotation
            this.forceClickCheck = forceClickCheck
            this.clickEvents = copy(clickEvents)
            this.hoverEnterEvents = copy(hoverEnterEvents)
            this.hoverExitEvents = copy(hoverExitEvents)
            if clickEvent !== nothing
                push!(this.clickEvents, clickEvent)
            end
            if hoverEnterEvent !== nothing
                push!(this.hoverEnterEvents, hoverEnterEvent)
            end
            if hoverExitEvent !== nothing
                push!(this.hoverExitEvents, hoverExitEvent)
            end
            this.isWorldEntity = isWorldEntity
            this.isVisible = isVisible
            return this
        end
    end

    function add_child(canvas::Canvas, child::JulGame.IUIElement)
        push!(canvas.children, child)
        child.parent = canvas
        nothing
    end

    function get_children(canvas::Canvas)
        return canvas.children
    end

    function set_active(canvas::Canvas, active::Bool)
        canvas.isActive = active
        nothing
    end

    function is_child_active(canvas::Canvas, child::JulGame.IUIElement)
        i = findfirst(x -> x === child, canvas.children)
        return i !== nothing && child.isActive
    end

    """
    remove_child(canvas::Canvas, child::JulGame.IUIElement)

    Removes a UI element from the canvas's children.
    """
    function remove_child(canvas::Canvas, child::JulGame.IUIElement)
        index = findfirst(x -> x === child, canvas.children)
        if index !== nothing
            deleteat!(canvas.children, index)
            child.parent = nothing
            @debug "Removed $(child.name) from canvas $(canvas.name)"
        else
            @warn "Child $(child.name) is not a child of canvas $(canvas.name)"
        end
    end

    """
    get_all_descendants(canvas::Canvas) -> Vector{UI.UIElement}

    Recursively gets all descendants of the canvas (children, grandchildren, etc.).
    """
    function get_all_descendants(canvas::Canvas)
        descendants = JulGame.IUIElement[]

        function collect_descendants(element::JulGame.IUIElement)
            if isa(element, Canvas)
                for child in element.children
                    push!(descendants, child)
                    collect_descendants(child)
                end
            end
        end

        collect_descendants(canvas)
        return descendants
    end

    function UI.render(canvas::Canvas)
    end

    """
    UI.destroy(canvas::Canvas)

    Destroys the canvas and all its children.
    """
    function UI.destroy(canvas::Canvas)
        @error "Destroy method not implemented for Canvas"
    end

    function UI.canvas_active_for_input(c::JulGame.ICanvas)::Bool
        return getfield(c::Canvas, :isActive)::Bool
    end

end # module CanvasModule
