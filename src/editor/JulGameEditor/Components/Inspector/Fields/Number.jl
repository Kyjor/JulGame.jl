function show_field(structure::EditableStructure, field::Symbol, value::Union{Int32, Int64})
    show_field_label(field)
    ftype = typeof(value)
    val = convert(Int32, value)
    @c CImGui.InputInt("##$(string(field))_$(string(typeof(structure)))", &val, 1)

    if val != convert(Int32, value)
        finalValue = convert(ftype, val)
        setproperty!(structure, field, finalValue)
    end
    
    return val != convert(Int32, value)
end

function show_field(structure::EditableStructure, field::Symbol, value::Union{Float32, Float64})
    show_field_label(field)
    ftype = typeof(value)
    val = convert(Float32, value)
    @c CImGui.InputFloat("##$(string(field))_$(string(typeof(structure)))", &val, 0.1f0, 1.0f0, "%.3f")

    if val != convert(Float32, value)
        finalValue = convert(ftype, val)
        setproperty!(structure, field, finalValue)
    end
    
    return val != convert(Float32, value)
end