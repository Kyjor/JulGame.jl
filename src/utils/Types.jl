abstract type Script end

function Base.getproperty(script::Script, property::Symbol)
    if isa(getfield(script, property), EditorExport)
        return getfield(script, property).value
    end

    return getfield(script, property)
end

function Base.setproperty!(script::Script, property::Symbol, value)
    field = findfirst(f->f==property, fieldnames(typeof(script)))
    field_type = fieldtype(typeof(script), field)

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