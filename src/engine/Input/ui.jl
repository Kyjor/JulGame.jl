function get_element_size(element::JulGame.IEntity)
    if element.sprite === nothing
        return Math.Vector2(0, 0)
    end
    baseSize = element.sprite.lastRenderedScreenSize === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenSize
    # Apply interaction scale to shrink/grow hitbox independently of visual size
    interactionScale = try element.sprite.interactionScale catch; 1.0 end
    return Math.Vector2(baseSize.x * interactionScale, baseSize.y * interactionScale)
end

function clicked_down_on_this_element(this::Input, element::Union{JulGame.IUIElement, JulGame.IEntity})
    return element in this.elementsBeingClickedDownOn
end

function get_element_position(element::JulGame.IUIElement)
    return element.position
end

function get_element_position(element::JulGame.IEntity)
    if element.sprite === nothing
        return Math.Vector2(0, 0)
    end
    basePosition = element.sprite.lastRenderedScreenPosition === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenPosition
    baseSize = element.sprite.lastRenderedScreenSize === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenSize
    # Center the scaled hitbox over the original sprite position
    interactionScale = try element.sprite.interactionScale catch; 1.0 end
    if interactionScale < 1.0
        sizeDiff = Math.Vector2(baseSize.x * (1.0 - interactionScale), baseSize.y * (1.0 - interactionScale))
        return Math.Vector2(basePosition.x + sizeDiff.x / 2, basePosition.y + sizeDiff.y / 2)
    end
    return basePosition
end

function get_element_size(element::JulGame.IUIElement)
    return element.size
end
