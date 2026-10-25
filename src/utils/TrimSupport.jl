"""
    direct_subtypes(T::Type)

Every type declared directly under `T` in any loaded module. (`InteractiveUtils.subtypes` does the same, but would
make InteractiveUtils a dependency.)
"""
function direct_subtypes(T::Type)
    found = Type[]
    visited = Set{Module}()
    function visit(mod::Module)
        mod in visited && return
        push!(visited, mod)
        for name in names(mod; all = true)
            (isdefined(mod, name) && !Base.isdeprecated(mod, name)) || continue
            value = getglobal(mod, name)
            if value isa Module
                visit(value)
            elseif value isa DataType && value !== T && supertype(value) === T && !(value in found)
                push!(found, value)
            end
        end
    end
    foreach(visit, values(Base.loaded_modules))
    return found
end

"""
    concrete_subtypes(T::Type)

All concrete subtypes of `T`, recursively.
"""
function concrete_subtypes(T::Type)
    found = Type[]
    for subtype in direct_subtypes(T)
        if isconcretetype(subtype)
            push!(found, subtype)
        else
            append!(found, concrete_subtypes(subtype))
        end
    end
    return found
end

"""
    dispatch(f, target, args...)

Call `f(target, args...)` and return its result, where `target` is only known by an abstract type (e.g. `Script`,
`IUIElement`). Methods for other abstract types are added where those types are defined.

With `juliac --trim` the call is expanded into an `isa` chain over every concrete subtype that exists when the
method is compiled, so the compiler can see every callee. Otherwise it uses `invokelatest`, which also picks up
types and methods defined after the engine started (scripts included at runtime).
"""
# One method per abstract type: inside a method on `target::T`, `T` is only known as `<:Script`, not as `Script`.
dispatch(f, target::Script, args...) = dispatch_over_subtypes(f, Val{Script}(), ErasedTarget(target), args...)
dispatch(f, target::IUIElement, args...) = dispatch_over_subtypes(f, Val{IUIElement}(), ErasedTarget(target), args...)

# A generated function that is not inlined can only be called directly when all its argument types are concrete, and
# `Type{T}` or an abstract `T` do not count. `Val{T}` and this wrapper (instead of the abstractly typed target) do.
struct ErasedTarget
    value::Any
end

# Scripts read the UI elements they look up (`get_ui_element_by_id`) as plain `IUIElement`s, which have no fields.
# For one of those, reading a field expands into a switch over the concrete element types that have it.
# Code that knows the element type reads the field directly.
Base.@constprop :aggressive @inline function ui_field(element::T, property::Symbol) where {T <: IUIElement}
    isconcretetype(T) && return getfield(element, property)
    return ui_getproperty(ErasedTarget(element), Val(property))
end

@generated function ui_getproperty(erased::ErasedTarget, ::Val{property}) where {property}
    field = QuoteNode(property)
    Base.JLOptions().trim == 0 && return :(getfield(erased.value, $field))

    body = :(error("no UI element has a field " * $(string(property))))
    for subtype in reverse(concrete_subtypes(IUIElement))
        hasfield(subtype, property) || continue
        body = Expr(:if, :(erased.value isa $subtype), :(getfield(erased.value::$subtype, $field)), body)
    end
    return body
end

@generated function dispatch_over_subtypes(f::F, ::Val{T}, erased::ErasedTarget, args::Vararg{Any, N}) where {F, T, N}
    if Base.JLOptions().trim == 0
        return :(Base.invokelatest(f, erased.value, args...))
    end

    isconcretetype(T) && return :(f(erased.value::$T, args...))

    body = :(error("dispatch: no concrete subtype of " * $(string(T)) * " matched"))
    for subtype in reverse(concrete_subtypes(T))
        body = Expr(:if, :(erased.value isa $subtype), :(f(erased.value::$subtype, args...)), body)
    end
    return body
end

"""
    is_trimmed()::Bool

`true` in a `juliac --trim` build. The answer is a compile-time constant, so code after `is_trimmed() && return` is
never compiled there. Use it to leave out what cannot be trimmed (HTTP, JSON3, ...).
"""
@generated function is_trimmed()
    return Base.JLOptions().trim != 0
end

"""
    print_line(message::String)

`println` for a single string. `println(stdout, ...)` writes through the abstractly typed `Base.stdout`, which a
`juliac --trim` build cannot resolve, so there it writes to `Core.stdout`.
"""
@generated function print_line(message::String)
    Base.JLOptions().trim == 0 && return :(println(message))
    return :(println(Core.stdout, message))
end

"""
    log_exception(context::String, e)

Log `e` as an error. Call it inside a `catch` block. Outside `juliac --trim` the full exception and backtrace are
logged; a trimmed build cannot print arbitrary exceptions, so only the message of an `ErrorException` is printed.
"""
@generated function log_exception(context::String, e)
    if Base.JLOptions().trim == 0
        return :(@error context exception = (e, catch_backtrace()))
    end
    return :(print_exception_message(context, e))
end

# Kept out of `log_exception` so that generated function stays small enough to be inlined into its callers.
function print_exception_message(context::String, @nospecialize(e))
    message = e isa ErrorException ? e.msg : "exception of unknown type"
    print_line("Error: " * context * ": " * (message isa String ? message : "exception message of unknown type"))
end

"""
    unless_trimmed(f, args...)

Calls `f(args...)`, except in a `juliac --trim` build, where `f` (dynamic code loading and the like) is left out
so the compiler never has to see it.
"""
@generated function unless_trimmed(f::F, args::Vararg{Any, N}) where {F, N}
    Base.JLOptions().trim == 0 && return :(f(args...); return nothing)
    return :(return nothing)
end

"""
    print_backtrace(fromException::Bool, stream::Symbol = :stdout)

Prints the backtrace of the exception being handled (`fromException`) or of the current call, to `:stdout` or `:stderr`.
Does nothing in a `juliac --trim` build, which cannot print backtraces.
"""
@generated function print_backtrace(fromException::Bool, stream::Symbol)
    Base.JLOptions().trim == 0 || return :(nothing)
    return :(Base.show_backtrace(stream === :stderr ? stderr : stdout, fromException ? catch_backtrace() : stacktrace()))
end

print_backtrace(fromException::Bool) = print_backtrace(fromException, :stdout)

"""
    set_field_converted!(object, property::Symbol, value)

`setfield!` that converts `value` to the field's type, like `object.property = value` does.

Written as a switch over the fields, so it needs no constant `property` to be inferable.
"""
@generated function set_field_converted!(object::T, property::Symbol, value) where {T}
    body = :(error("type " * $(string(T)) * " has no field " * string(property)))
    for fieldName in reverse(fieldnames(T))
        field = QuoteNode(fieldName)
        fieldType = fieldtype(T, fieldName)
        # Containers cannot be converted without dynamic calls, so under trim only an already matching value is stored.
        assign = if Base.JLOptions().trim != 0 && !(value <: fieldType) && (fieldType <: AbstractArray || fieldType <: AbstractDict)
            :(error("cannot assign a " * $(string(value)) * " to field " * $(string(fieldName)) * " of " * $(string(T))))
        else
            :(setfield!(object, $field, convert($fieldType, value)))
        end
        body = Expr(:if, :(property === $field), :(return $assign), body)
    end
    return body
end
