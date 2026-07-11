
module InteractionComponentsModule
    export ClickEvents, HoverEnterEvents, HoverExitEvents, IsHovered, ForceClickCheck, IgnoreInputEvents

    mutable struct ClickEvents;        value::Vector{Function}; end
    mutable struct HoverEnterEvents;   value::Vector{Function}; end
    mutable struct HoverExitEvents;    value::Vector{Function}; end
    mutable struct IsHovered;          value::Bool;             end
    mutable struct ForceClickCheck;    value::Bool;             end
    mutable struct IgnoreInputEvents;  value::Bool;             end
end
