abstract type Script end

# Behind these two functions so that a script type that overrides `getproperty` / `setproperty!` can still reach them.
Base.@constprop :aggressive Base.getproperty(script::Script, property::Symbol) = script_getproperty(script, property)
Base.@constprop :aggressive Base.setproperty!(script::Script, property::Symbol, value) = script_setproperty!(script, property, value)

Base.@constprop :aggressive function script_getproperty(script::Script, property::Symbol)
    # Every script's `parent` is the entity it is attached to; asserting that keeps `this.parent.x` inferable
    if property === :parent
        return getfield(script, :parent)::Union{IEntity, Ptr{Nothing}}
    end

    if isa(getfield(script, property), EditorExport)
        return getfield(script, property).value
    end

    return getfield(script, property)
end

Base.@constprop :aggressive function script_setproperty!(script::Script, property::Symbol, value)
    field_type = fieldtype(typeof(script), property)

    if field_type <: EditorExport
        setfield!(script, property, EditorExport(value))
    elseif field_type <: Math._Vector2 && value isa Math._Vector3
        # Handle Vector3 to Vector2 conversion
        T = typeof(value.x)
        if T <: Int32
            converted = Math._Vector2{T}(Math.TypeConversions.safe_int32_convert(value.x),
                                       Math.TypeConversions.safe_int32_convert(value.y))
        else
            converted = Math._Vector2{T}(convert(T, value.x), convert(T, value.y))
        end
        setfield!(script, property, converted)
    else
        setfield!(script, property, value)
    end
end

# TODO: Add a way to add custom fields to scripts