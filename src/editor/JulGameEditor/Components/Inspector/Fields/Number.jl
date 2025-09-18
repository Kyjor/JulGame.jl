function show_field(structure::EditableStructure, field::Symbol, value::Union{Int32, Int64})
    show_field_label(field)
    ftype = typeof(value)
    val = convert(Int32, value)
    @c CImGui.InputInt("##$(string(field))_$(string(typeof(structure)))", &val, 1)

    if val != convert(Int32, value)
        finalValue = convert(ftype, val)
        setfield!(structure, field, finalValue)
    end
    
    return val != convert(Int32, value)
end