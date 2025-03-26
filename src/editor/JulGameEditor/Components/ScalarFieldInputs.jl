using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame

"""
    show_boolean_input(component, componentField, fieldValue, label)

Shows input field for Boolean values.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)

# Returns
- `Bool`: whether the field was modified
"""
function show_boolean_input(component, componentField, fieldValue, label=nothing)
    displayLabel = label === nothing ? string(componentField) : label
    
    value = fieldValue
    @c CImGui.Checkbox("$(componentField)", &value)

    if value != fieldValue
        setfield!(component, componentField, value)
    end
    
    return value != fieldValue
end

"""
    show_string_input(component, componentField, fieldValue, label, maxLength=64)

Shows input field for String values.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)
- `maxLength`: Maximum length of the string input buffer

# Returns
- `Bool`: whether the field was modified
"""
function show_string_input(component, componentField, fieldValue, label=nothing, maxLength=64)
    displayLabel = label === nothing ? string(componentField) : label
    
    buf = "$(fieldValue)"*"\0"^(maxLength)
    @c CImGui.InputText(displayLabel, buf, length(buf))
    
    if buf != fieldValue
        # Extract the string up to the first null character
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        
        setfield!(component, componentField, currentTextInTextBox)
    end
    
    return buf != fieldValue
end

"""
    show_numeric_input(component, componentField, fieldValue, label, step=1)

Shows input field for numeric values (Int32, Float64, etc).

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)
- `step`: Step value for the input

# Returns
- `Bool`: whether the field was modified
"""
function show_numeric_input(component, componentField, fieldValue, label=nothing, step=1)
    displayLabel = label === nothing ? string(componentField) : label
    isFloat = isa(fieldValue, AbstractFloat)
    
    value = isFloat ? Cfloat(fieldValue) : Cint(fieldValue)

    if isFloat
        # Use appropriate step and faster step for float
        stepF = Cfloat(step)
        fasterStep = stepF * 10
        @c CImGui.InputFloat(displayLabel, &value, stepF, fasterStep)
        # Convert back to the original type
        value = convert(typeof(fieldValue), value)
    else
        @c CImGui.InputInt(displayLabel, &value, step)
        # Convert back to the original type
        value = convert(typeof(fieldValue), value)
    end
    
    if value != fieldValue
        setfield!(component, componentField, value)
    end
    
    return value != fieldValue
end 