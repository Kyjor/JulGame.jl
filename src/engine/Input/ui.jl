function get_element_size(element::JulGame.IEntity)
    sprite = element.sprite
    if !(sprite isa JulGame.Component.SpriteModule.InternalSprite)
        return Math.Vector2(0, 0)
    end
    lastSize = sprite.lastRenderedScreenSize
    baseSize = lastSize === nothing ? Math.Vector2(0, 0) : lastSize
    # Apply interaction scale to shrink/grow hitbox independently of visual size
    interactionScale = sprite.interactionScale
    return Math.Vector2(baseSize.x * interactionScale, baseSize.y * interactionScale)
end

function clicked_down_on_this_element(this::Input, element::Union{JulGame.IUIElement, JulGame.IEntity})
    return is_element_in(this.elementsBeingClickedDownOn, element)
end

function get_element_position(element::JulGame.IUIElement)
    return element.position
end

function get_element_position(element::JulGame.IEntity)
    sprite = element.sprite
    if !(sprite isa JulGame.Component.SpriteModule.InternalSprite)
        return Math.Vector2(0, 0)
    end
    lastPosition = sprite.lastRenderedScreenPosition
    lastSize = sprite.lastRenderedScreenSize
    basePosition = lastPosition === nothing ? Math.Vector2(0, 0) : lastPosition
    baseSize = lastSize === nothing ? Math.Vector2(0, 0) : lastSize
    # Center the scaled hitbox over the original sprite position
    interactionScale = sprite.interactionScale
    if interactionScale < 1.0
        sizeDiff = Math.Vector2(baseSize.x * (1.0 - interactionScale), baseSize.y * (1.0 - interactionScale))
        return Math.Vector2(basePosition.x + sizeDiff.x / 2, basePosition.y + sizeDiff.y / 2)
    end
    return basePosition
end

function get_element_size(element::JulGame.IUIElement)
    return element.size
end
