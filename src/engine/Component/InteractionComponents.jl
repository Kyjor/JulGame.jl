"""
    InteractionComponentsModule

Per-field Ark components backing an `Entity`'s input/interaction state. Each
wraps a single value so it can be a distinct component type (three separate
`Bool` fields need three distinct types). They are always present on every
entity and surfaced through the usual `entity.clickEvents` / `entity.isHovered`
symbol accessors.
"""
module InteractionComponentsModule
    export ClickEvents, HoverEnterEvents, HoverExitEvents, IsHovered, ForceClickCheck, IgnoreInputEvents

    mutable struct ClickEvents;        value::Vector{Function}; end
    mutable struct HoverEnterEvents;   value::Vector{Function}; end
    mutable struct HoverExitEvents;    value::Vector{Function}; end
    mutable struct IsHovered;          value::Bool;             end
    mutable struct ForceClickCheck;    value::Bool;             end
    mutable struct IgnoreInputEvents;  value::Bool;             end
end
