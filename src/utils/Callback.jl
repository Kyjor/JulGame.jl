"""
    Callback{E}

A type-erased closure that can be stored in a concretely typed container and called without
dynamic dispatch, so it works under `juliac --trim`. `E` is the event type passed to the closure
(`Nothing` for none; a `Tuple` is splatted into the closure's arguments). Closures that do not accept
the event are called with no arguments.

Any `Function` converts to a `Callback`, so `push!(callbacks, () -> ...)` keeps working.
"""
struct Callback{E}
    box::Any # the `CallbackBox` that keeps the closure alive
    thunk::Ptr{Cvoid}
end

mutable struct CallbackBox{F, E}
    f::F
end

# `applicable` is resolved at compile time for concrete closures, so this costs nothing under `--trim`.
_invoke_closure(f::F, event::E) where {F, E <: Tuple} = applicable(f, event...) ? f(event...) : f()
_invoke_closure(f::F, event::E) where {F, E} = applicable(f, event) ? f(event) : f()

function _run_callback(boxPtr::Ptr{CallbackBox{F, E}}, eventPtr::Ptr{Base.RefValue{E}}) where {F, E}
    box = unsafe_pointer_to_objref(boxPtr)::CallbackBox{F, E}
    if E === Nothing
        box.f()
    else
        _invoke_closure(box.f, (unsafe_pointer_to_objref(eventPtr)::Base.RefValue{E})[])
    end
    return nothing
end

@generated function Callback{E}(f::F) where {F, E}
    return quote
        Callback{$E}(
            CallbackBox{$F, $E}(f),
            @cfunction(_run_callback, Cvoid, (Ptr{CallbackBox{$F, $E}}, Ptr{Base.RefValue{$E}})),
        )
    end
end

Callback{E}(callback::Callback{E}) where {E} = callback
Callback(f) = Callback{Nothing}(f)
Callback(callback::Callback) = callback

Base.convert(::Type{Callback{E}}, f::Function) where {E} = Callback{E}(f)
Base.convert(::Type{Callback{E}}, callback::Callback{E}) where {E} = callback

function (callback::Callback{Nothing})()
    ccall(callback.thunk, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), pointer_from_objref(callback.box), C_NULL)
    return nothing
end

# Must be heap allocated: its address crosses the `ccall`, which the compiler does not see as an escape.
@noinline _event_ref(::Type{E}, event) where {E} = Ref{E}(event)

function (callback::Callback{E})(event::E) where {E}
    ref = _event_ref(E, event)
    GC.@preserve ref ccall(callback.thunk, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), pointer_from_objref(callback.box), pointer_from_objref(ref))
    return nothing
end

"""Argument handed to click callbacks (callbacks that take no argument are called without it)."""
struct ClickEvent
    evt::SDL2.SDL_Event
    x::Int32
    y::Int32
end

const ClickCallback = Callback{ClickEvent}
const HoverCallback = Callback{Nothing}

"""Argument handed to observer callbacks: `(event, data)`."""
const ObserverEvent = Tuple{Symbol, Any}
const ObserverCallback = Callback{ObserverEvent}

"""A render function queued for the main loop, drawn at `layer`."""
struct RenderFunction
    function_to_call::HoverCallback
    isWorldEntity::Bool
    layer::Int
end
