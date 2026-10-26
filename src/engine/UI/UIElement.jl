abstract type UIElement <: JulGame.IUIElement end

mutable struct UIElementInstance
    # identifiers
    id::String
    name::String

    # positioning
    anchor::Union{JulGame.Enum{Any}, Nothing}
    anchorOffset::Vector2
    isWorldEntity::Bool
    layer::Int
    parent::Union{JulGame.IUIElement, Nothing, JulGame.IEntity, JulGame.ISprite}
    position::Vector2
    rotation::Float64
    size::Vector2
    originalSize::Vector2

    # events
    clickEvents::Vector{ClickCallback}
    hoverEnterEvents::Vector{HoverCallback}
    hoverExitEvents::Vector{HoverCallback}
    forceClickCheck::Bool
    ignoreInputEvents::Bool

    # state
    isActive::Bool
    isHovered::Bool
    persistentBetweenScenes::Bool
    
    # rendering
    color::NTuple{4, Int}
    
    
    function UIElementInstance()
        this = new()

        this.clickEvents = ClickCallback[]
        this.hoverEnterEvents = HoverCallback[]
        this.hoverExitEvents = HoverCallback[]
        this.forceClickCheck = false
        this.ignoreInputEvents = false  
        
        return this
    end
end

"""Shared state of a UI element. Every concrete element embeds one as its `base` field."""
@inline ui_instance(element::JulGame.IUIElement) = getfield(element, :base)::UIElementInstance

"""Hook run after a property is set. Concrete elements extend it (e.g. TextBox re-renders its text)."""
on_property_set(::JulGame.IUIElement, ::Symbol) = nothing

"""Stores a value in a field of the concrete element. Concrete elements extend it for fields that need more than a plain store (e.g. UIImage reloads its image when `path` is set)."""
set_element_field!(element::JulGame.IUIElement, property::Symbol, value) = JulGame.set_field_converted!(element, property, value)

# The hooks above have a method per element type. For an element only known as `IUIElement`, dispatch has to go through
# `JulGame.dispatch`, which `juliac --trim` can see through; for a concrete element a direct call is enough.
@inline function notify_property_set(element::T, property::Symbol) where {T <: JulGame.IUIElement}
    isconcretetype(T) && return on_property_set(element, property)
    return JulGame.dispatch(on_property_set, element, property)
end

@inline function assign_element_field!(element::T, property::Symbol, value) where {T <: JulGame.IUIElement}
    isconcretetype(T) && return set_element_field!(element, property, value)
    return JulGame.dispatch(set_element_field!, element, property, value)
end

# Fields of `UIElementInstance` are forwarded to `base`; all others live on the concrete element.
# A concrete element reads the field directly. An element known only as `IUIElement` (or `Union{Nothing, IUIElement}`)
# goes through a switch, which is what `juliac --trim` can resolve.
@generated function _ui_getproperty(erased::JulGame.ErasedTarget, ::Val{property}) where {property}
    field = QuoteNode(property)
    body = :(error("no UI element has a field " * $(string(property))))
    subtypes = reverse(JulGame.concrete_subtypes(JulGame.IUIElement))
    if property === :isHovered
        for subtype in subtypes
            body = Expr(:if, :(erased.value isa $subtype),
                :(let inst = getfield(erased.value::$subtype, :base)::UIElementInstance
                    getfield(inst, :isActive) ? getfield(inst, :isHovered) : false
                  end),
                body)
        end
    elseif hasfield(UIElementInstance, property)
        for subtype in subtypes
            body = Expr(:if, :(erased.value isa $subtype),
                :(getfield(getfield(erased.value::$subtype, :base)::UIElementInstance, $field)),
                body)
        end
    else
        for subtype in subtypes
            hasfield(subtype, property) || continue
            body = Expr(:if, :(erased.value isa $subtype), :(getfield(erased.value::$subtype, $field)), body)
        end
    end
    return body
end

Base.@constprop :aggressive @inline function Base.getproperty(element::JulGame.IUIElement, property::Symbol)
    if isconcretetype(typeof(element))
        if hasfield(UIElementInstance, property)
            inst = getfield(element, :base)::UIElementInstance
            if property === :isHovered && !getfield(inst, :isActive)
                return false
            end
            return getfield(inst, property)
        end
        return getfield(element, property)
    end
    return _ui_getproperty(JulGame.ErasedTarget(element), Val(property))
end

Base.@constprop :aggressive @inline function Base.getproperty(element::Union{Nothing, JulGame.IUIElement}, property::Symbol)
    return getproperty(element::JulGame.IUIElement, property)
end

Base.@constprop :aggressive @inline function Base.setproperty!(element::Union{Nothing, JulGame.IUIElement}, property::Symbol, value)
    setproperty!(element::JulGame.IUIElement, property, value)
    return value
end

# The setter is too big to inline, and a call that is not inlined is only resolved by `juliac --trim` when the element's type
# is concrete. So `setproperty!` stays small and goes through `JulGame.dispatch`, which reaches the worker for each concrete type.
Base.@constprop :aggressive @inline function Base.setproperty!(element::JulGame.IUIElement, property::Symbol, value)
    JulGame.dispatch_over_subtypes(set_ui_property!, Val{JulGame.IUIElement}(), JulGame.ErasedTarget(element), property, value)
    return value
end

function set_ui_property!(element::JulGame.IUIElement, property::Symbol, value)
    if hasfield(UIElementInstance, property)
        inst = ui_instance(element)
        if property === :isHovered
            prev = getfield(inst, :isHovered)
            setfield!(inst, property, convert(Bool, value))
            if prev != value
                UI.handle_hover_event(element, value)
            end
        else
            JulGame.set_field_converted!(inst, property, value)
        end
    else
        assign_element_field!(element, property, value)
    end
    notify_property_set(element, property)
    return value
end

function UI.set_color(this::JulGame.IUIElement; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
    this.color = (r%256, g%256, b%256, a%256)
end

function UI.align_to_anchor(this::JulGame.IUIElement)
    if JulGame.main_loop().scene.camera === nothing
        @debug "No camera found in scene"
        return
    end

    size = JulGame.main_loop().scene.camera.size
    parent_pos = Math.Vector2(0, 0)
    parent = this.parent # local copy so the type checks below narrow it
    if parent !== nothing 
        if isa(parent, JulGame.IUIElement)
            size = parent.size
            parent_pos = parent.position
        elseif isa(parent, JulGame.ISprite)
            lastSize = parent.lastRenderedScreenSize
            lastPosition = parent.lastRenderedScreenPosition
            if lastSize === nothing || lastPosition === nothing
                @debug "No last rendered screen size or position found for parent of $(this.name)"
                return
            end
            size = lastSize
            parent_pos = lastPosition
        end
    end

    if this.anchor.current_state == :center
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )  
    elseif this.anchor.current_state == :top
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottom
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :left
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :right
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
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
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerTop
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerBottom
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :none
        #@debug "No anchor set for textbox $(this.name)"
    else
        @error "Invalid anchor state: $(this.anchor.current_state)"
    end
end

# Inlined so that a call on an element only known as `IUIElement` is resolved by `juliac --trim`.
# Build the callback directly. `push!` into `Vector{ClickCallback}` would `convert`, which trim misses.
@inline function UI.add_click_event(this::JulGame.IUIElement, event::C) where {C}
    push!(this.clickEvents, event isa JulGame.ClickCallback ? event : JulGame.ClickCallback(event))
end

@inline function UI.add_hover_enter_event(this::JulGame.IUIElement, event::C) where {C}
    push!(this.hoverEnterEvents, event isa JulGame.HoverCallback ? event : JulGame.HoverCallback(event))
end

@inline function UI.add_hover_exit_event(this::JulGame.IUIElement, event::C) where {C}
    push!(this.hoverExitEvents, event isa JulGame.HoverCallback ? event : JulGame.HoverCallback(event))
end

function UI.handle_event(@nospecialize(this::Union{JulGame.IUIElement, JulGame.IEntity}), evt, x, y)
    if evt.type == evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        if this isa ScreenButtonModule.ScreenButton
            this.currentTexture = this.buttonDownTexture
        end
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
        if this isa ScreenButtonModule.ScreenButton
            this.currentTexture = this.buttonUpTexture
        end
        event = ClickEvent(evt, Int32(round(x)), Int32(round(y)))
        for eventToCall in this.clickEvents
            eventToCall(event)
        end
    elseif evt.type == SDL2.SDL_MOUSEMOTION
        if this.isHovered == false
            this.isHovered = true
        end
    end
end

function UI.handle_hover_event(this::JulGame.IUIElement, isEntering::Bool)
    events = isEntering ? this.hoverEnterEvents : this.hoverExitEvents
    for event in events
        event()
    end
    key = isEntering ? :hover_dispatch_enter_invocations : :hover_dispatch_exit_invocations
end