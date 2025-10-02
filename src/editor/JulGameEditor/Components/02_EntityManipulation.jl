"""
EntityManipulation.jl

Integration layer for using ManipulationArrows with entities in the scene viewer.
Provides high-level functions for manipulating entity positions and sizes.
"""

# Entity manipulation mode enum
@enum EntityManipulationMode begin
    Position
    Scale
    Both
end

"""
    handle_entity_manipulation(entity, mode::EntityManipulationMode = Both, grid_snap::Int = 0) -> Bool

Handles manipulation arrows for an entity. Returns true if the entity was modified.

# Arguments
- `entity`: The entity to manipulate (must have transform component)
- `mode`: What to manipulate (Position, Scale, Both)
- `grid_snap`: Grid snapping value (0 = no snapping)

# Returns
- `Bool`: true if the entity was modified during this frame
"""
function handle_entity_manipulation(entity, mode::EntityManipulationMode = Both, grid_snap::Int = 0)::Bool
    if !haskey(entity.components, "Transform")
        @warn "Entity $(entity.name) has no Transform component for manipulation"
        return false
    end
    
    transform = entity.components["Transform"]
    modified = false
    
    # Handle position manipulation
    if mode == Position || mode == Both
        pos_ref = Ref(Math.Vector2(transform.position.x, transform.position.y))
        if draw_position_arrows(pos_ref, grid_snap)
            transform.position = Math.Vector2(pos_ref[].x, pos_ref[].y)
            modified = true
        end
    end
    
    # Handle scale manipulation (if entity has scale)
    if (mode == Scale || mode == Both) && hasfield(typeof(transform), :scale)
        scale_ref = Ref(Math.Vector2(transform.scale.x, transform.scale.y))
        widget_pos = Math.Vector2(transform.position.x, transform.position.y)
        draw_resize_handles(widget_pos, scale_ref, grid_snap, Default)
        if scale_ref[] != Math.Vector2(transform.scale.x, transform.scale.y)
            transform.scale = scale_ref[]
            modified = true
        end
    end
    
    return modified
end

"""
    handle_sprite_manipulation(entity, grid_snap::Int = 0) -> Bool

Specialized manipulation for sprite entities (position + size).
"""
function handle_sprite_manipulation(entity, grid_snap::Int = 0)::Bool
    if !haskey(entity.components, "Transform")
        return false
    end
    
    transform = entity.components["Transform"]
    modified = false
    
    # Position manipulation
    pos_ref = Ref(Math.Vector2(transform.position.x, transform.position.y))
    if draw_position_arrows(pos_ref, grid_snap)
        transform.position = Math.Vector2(pos_ref[].x, pos_ref[].y)
        modified = true
    end
    
    # Size manipulation for sprites
    if haskey(entity.components, "Sprite")
        sprite = entity.components["Sprite"]
        if hasfield(typeof(sprite), :size)
            size_ref = Ref(Math.Vector2(sprite.size.x, sprite.size.y))
            widget_pos = Math.Vector2(transform.position.x, transform.position.y)
            draw_resize_handles(widget_pos, size_ref, grid_snap, Default)
            if size_ref[] != Math.Vector2(sprite.size.x, sprite.size.y)
                sprite.size = size_ref[]
                modified = true
            end
        end
    end
    
    return modified
end

"""
    handle_ui_element_manipulation(ui_element, grid_snap::Int = 0) -> Bool

Specialized manipulation for UI elements.
"""
function handle_ui_element_manipulation(ui_element, grid_snap::Int = 0)::Bool
    modified = false
    
    # Position manipulation
    if hasfield(typeof(ui_element), :position)
        pos_ref = Ref(Math.Vector2(ui_element.position.x, ui_element.position.y))
        if draw_position_arrows(pos_ref, grid_snap)
            ui_element.position = pos_ref[]
            modified = true
        end
    end
    
    # Size manipulation
    if hasfield(typeof(ui_element), :size)
        size_ref = Ref(Math.Vector2(ui_element.size.x, ui_element.size.y))
        widget_pos = hasfield(typeof(ui_element), :position) ? 
                    Math.Vector2(ui_element.position.x, ui_element.position.y) : 
                    Math.Vector2(0, 0)
        draw_resize_handles(widget_pos, size_ref, grid_snap, Default)
        if size_ref[] != Math.Vector2(ui_element.size.x, ui_element.size.y)
            ui_element.size = size_ref[]
            modified = true
        end
    end
    
    return modified
end