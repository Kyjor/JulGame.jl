abstract type IEntity end
export IEntity
abstract type IUIElement end
export IUIElement
abstract type ITransform end
export ITransform
abstract type IShape end
export IShape
abstract type ISoundSource end
export ISoundSource
abstract type ISprite end
export ISprite
abstract type IAnimator end
export IAnimator
abstract type ICollider end
export ICollider
abstract type IObserver end
export IObserver
abstract type IHistory end
export IHistory
abstract type ICanvas <: IUIElement end
export ICanvas

# Each interface has exactly one implementation. Components and UI elements hold their parent through the
# interface (the implementations are defined later), so property access forwards to the concrete type via
# `as_entity` / `as_sprite` (methods added next to the structs) to keep field types inferable.
function as_entity end
function as_sprite end
function as_collider end

Base.@constprop :aggressive function Base.getproperty(entity::IEntity, property::Symbol)
    return getfield(as_entity(entity), property)
end

Base.@constprop :aggressive function Base.setproperty!(entity::IEntity, property::Symbol, value)
    concrete = as_entity(entity)
    return JulGame.set_field_converted!(concrete, property, value)
end

Base.@constprop :aggressive function Base.getproperty(sprite::ISprite, property::Symbol)
    return getfield(as_sprite(sprite), property)
end

Base.@constprop :aggressive function Base.setproperty!(sprite::ISprite, property::Symbol, value)
    return setproperty!(as_sprite(sprite), property, value)
end

Base.@constprop :aggressive function Base.getproperty(collider::ICollider, property::Symbol)
    return getfield(as_collider(collider), property)
end

Base.@constprop :aggressive function Base.setproperty!(collider::ICollider, property::Symbol, value)
    concrete = as_collider(collider)
    return JulGame.set_field_converted!(concrete, property, value)
end
