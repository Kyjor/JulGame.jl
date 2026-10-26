Base.@constprop :aggressive @inline function get_element_size(element::JulGame.IEntity)::Math.Vector2
    sprite = element.sprite
    if !(sprite isa JulGame.Component.SpriteModule.InternalSprite)
        return Math.Vector2(0, 0)
    end
    lastSize = sprite.lastRenderedScreenSize
    lastSize === nothing && return Math.Vector2(0, 0)
    # Apply interaction scale to shrink/grow hitbox independently of visual size
    interactionScale = sprite.interactionScale
    return Math.Vector2(lastSize.x * interactionScale, lastSize.y * interactionScale)
end

function clicked_down_on_this_element(this::Input, element::Union{JulGame.IUIElement, JulGame.IEntity})
    return is_element_in(this.elementsBeingClickedDownOn, element)
end

Base.@constprop :aggressive @inline function get_element_position(element::JulGame.IUIElement)::Math.Vector2
    return element.position
end

Base.@constprop :aggressive @inline function get_element_position(element::JulGame.IEntity)::Math.Vector2
    sprite = element.sprite
    if !(sprite isa JulGame.Component.SpriteModule.InternalSprite)
        return Math.Vector2(0, 0)
    end
    lastPosition = sprite.lastRenderedScreenPosition
    lastSize = sprite.lastRenderedScreenSize
    lastPosition === nothing && return Math.Vector2(0, 0)
    lastSize === nothing && return Math.Vector2(0, 0)
    # Center the scaled hitbox over the original sprite position
    interactionScale = sprite.interactionScale
    if interactionScale < 1.0
        sizeDiff = Math.Vector2(lastSize.x * (1.0 - interactionScale), lastSize.y * (1.0 - interactionScale))
        return Math.Vector2(lastPosition.x + sizeDiff.x / 2, lastPosition.y + sizeDiff.y / 2)
    end
    return Math.Vector2(lastPosition.x, lastPosition.y)
end

Base.@constprop :aggressive @inline function get_element_size(element::JulGame.IUIElement)::Math.Vector2
    return element.size
end

# The hit-test loop holds an entity or a UI element. One inlined method keeps that union callable under trim.
Base.@constprop :aggressive @inline function get_element_position(element::Union{JulGame.IEntity, JulGame.IUIElement})::Math.Vector2
    if element isa JulGame.IUIElement
        return get_element_position(element::JulGame.IUIElement)
    end
    return get_element_position(element::JulGame.IEntity)
end

Base.@constprop :aggressive @inline function get_element_size(element::Union{JulGame.IEntity, JulGame.IUIElement})::Math.Vector2
    if element isa JulGame.IUIElement
        return get_element_size(element::JulGame.IUIElement)
    end
    return get_element_size(element::JulGame.IEntity)
end
