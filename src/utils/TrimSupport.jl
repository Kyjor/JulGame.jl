"""
    TRIM_BUILD::Bool

Whether this is a `juliac --trim` build, set by the `trim` preference of JulGame (in the `LocalPreferences.toml` of the
app's project). It is a preference, and not `Base.JLOptions().trim`, because the package images are precompiled by a
process that does not trim, and whatever that process compiled (generated functions included) is reused by the
trimming one. A preference change precompiles again, so the answer is the same everywhere.
"""
const TRIM_BUILD = let uuid = Base.UUID("4850f9bb-d191-4a1e-9f97-ee64062927c3")
    Base.generating_output() && Base.record_compiletime_preference(uuid, "trim")
    get(Base.get_preferences(uuid), "trim", false) === true
end

"""
    direct_subtypes(T::Type)

Every type declared directly under `T` in any loaded module. (`InteractiveUtils.subtypes` does the same, but would
make InteractiveUtils a dependency.)
"""
function direct_subtypes(T::Type)
    # The generated functions that call this run in the world of the code being compiled, which can be older than the
    # types being looked for (a `precompile` statement that runs while a package loads). Always look in the newest.
    return Base.invoke_in_world(typemax(UInt), find_direct_subtypes, T)
end

function find_direct_subtypes(T::Type)
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
    # A package that is still loading is not in `loaded_modules`, yet its own types must be found: code that runs while
    # it loads (`precompile` statements) compiles these switches, and an empty one would be reused afterwards.
    visit(root_module(T))
    # The app module (Battler) is a child of Main and is not in `loaded_modules` until it finishes loading.
    visit(Main)
    return found
end

"""The outermost module that holds `T`, below `Main`."""
function root_module(T::Type)
    mod = parentmodule(T)
    while parentmodule(mod) !== mod && parentmodule(mod) !== Main
        mod = parentmodule(mod)
    end
    return mod
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
@inline dispatch(f, target::Script, args...) = dispatch_over_subtypes(f, Val{Script}(), ErasedTarget(target), args...)
@inline dispatch(f, target::IUIElement, args...) = dispatch_over_subtypes(f, Val{IUIElement}(), ErasedTarget(target), args...)

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
    !TRIM_BUILD && return :(getfield(erased.value, $field))

    body = :(error("no UI element has a field " * $(string(property))))
    for subtype in reverse(concrete_subtypes(IUIElement))
        hasfield(subtype, property) || continue
        body = Expr(:if, :(erased.value isa $subtype), :(getfield(erased.value::$subtype, $field)), body)
    end
    return body
end

@generated function dispatch_over_subtypes(f::F, ::Val{T}, erased::ErasedTarget, args::Vararg{Any, N}) where {F, T, N}
    if !TRIM_BUILD
        return :(Base.invokelatest(f, erased.value, args...))
    end

    isconcretetype(T) && return Expr(:block, Expr(:meta, :noinline), :(f(erased.value::$T, args...)))

    body = :(error("dispatch: no concrete subtype of " * $(string(T)) * " matched"))
    for subtype in reverse(concrete_subtypes(T))
        body = Expr(:if, :(erased.value isa $subtype), :(f(erased.value::$subtype, args...)), body)
    end
    # Outlined so the caller (often a one-line `@inline` wrapper) stays small enough to inline. The wrapper's
    # arguments are concrete (`Val{T}`, `ErasedTarget`), so the call of this method is a resolved invoke.
    return Expr(:block, Expr(:meta, :noinline), body)
end

"""
    is_trimmed()::Bool

`true` in a `juliac --trim` build. The answer is a compile-time constant, so code after `is_trimmed() && return` is
never compiled there. Use it to leave out what cannot be trimmed (HTTP, JSON3, ...).
"""
is_trimmed() = TRIM_BUILD

"""
    print_line(message::String)

`println` for a single string. `println(stdout, ...)` writes through the abstractly typed `Base.stdout`, which a
`juliac --trim` build cannot resolve, so there it writes to `Core.stdout`.
"""
@generated function print_line(message::String)
    !TRIM_BUILD && return :(println(message))
    return :(println(Core.stdout, message))
end

"""
    log_exception(context::String, e)

Log `e` as an error. Call it inside a `catch` block. Outside `juliac --trim` the full exception and backtrace are
logged; a trimmed build cannot print arbitrary exceptions, so only the message of an `ErrorException` is printed.
"""
@generated function log_exception(context::String, e)
    if !TRIM_BUILD
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
    !TRIM_BUILD && return :(f(args...); return nothing)
    return :(return nothing)
end

"""
    print_backtrace(fromException::Bool, stream::Symbol = :stdout)

Prints the backtrace of the exception being handled (`fromException`) or of the current call, to `:stdout` or `:stderr`.
Does nothing in a `juliac --trim` build, which cannot print backtraces.
"""
@generated function print_backtrace(fromException::Bool, stream::Symbol)
    !TRIM_BUILD || return :(nothing)
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
        assign = if TRIM_BUILD && !(value <: fieldType) && (fieldType <: AbstractArray || fieldType <: AbstractDict)
            :(error("cannot assign a " * $(string(value)) * " to field " * $(string(fieldName)) * " of " * $(string(T))))
        else
            :(setfield!(object, $field, convert($fieldType, value)))
        end
        body = Expr(:if, :(property === $field), :(return $assign), body)
    end
    return body
end

# `getproperty(::Script)` calls these. The switch is over the concrete scripts that actually have the field.
# `:meta :noinline` keeps that switch out of `getproperty`: a trimmed build can inline `getproperty` only while it
# stays a single call, and then invokes this method (its arguments are concrete).
@generated function _script_getproperty(erased::ErasedTarget, ::Val{property}) where {property}
    field = QuoteNode(property)
    !TRIM_BUILD && return :(script_getproperty(erased.value, $field))

    body = :(error("no script has a field " * $(string(property))))
    for subtype in reverse(concrete_subtypes(Script))
        hasfield(subtype, property) || continue
        read = if property === :parent
            :(getfield(erased.value::$subtype, :parent)::Union{IEntity, Ptr{Nothing}})
        elseif fieldtype(subtype, property) <: EditorExport
            :(getfield(getfield(erased.value::$subtype, $field), :value))
        else
            :(getfield(erased.value::$subtype, $field))
        end
        body = Expr(:if, :(erased.value isa $subtype), read, body)
    end
    return Expr(:block, Expr(:meta, :noinline), body)
end

@generated function _script_setproperty!(erased::ErasedTarget, ::Val{property}, boxed::ErasedTarget) where {property}
    field = QuoteNode(property)
    !TRIM_BUILD && return :(script_setproperty!(erased.value, $field, boxed.value))

    body = :(error("no script has a field " * $(string(property))))
    for subtype in reverse(concrete_subtypes(Script))
        hasfield(subtype, property) || continue
        ft = fieldtype(subtype, property)
        # `EditorExport` and `Vector2` fields accept a value of a different type and convert it.
        # Every other field is asserted to its declared type so `setfield!` of an abstract value
        # (a `Script` stored into an interface field) is not inferred as a throw.
        assign = if ft <: EditorExport || ft <: Math._Vector2
            :(script_setproperty!(erased.value::$subtype, $field, boxed.value))
        else
            :(setfield!(erased.value::$subtype, $field, boxed.value::$ft))
        end
        body = Expr(:if, :(erased.value isa $subtype), assign, body)
    end
    return Expr(:block, Expr(:meta, :noinline), body)
end
