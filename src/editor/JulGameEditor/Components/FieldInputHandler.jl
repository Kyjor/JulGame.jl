using CImGui
using JulGame
using JulGame.Math

# These files are already included in ComponentInputs.jl
# include("VectorFieldInputs.jl")
# include("ScalarFieldInputs.jl")

"""
    handle_component_field_input(component, componentField, newScriptText="")

Generic handler function that determines the type of a component field and calls
the appropriate input function.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `newScriptText`: Text for new script creation (if needed)

# Returns
- `Bool`: whether any field was modified
"""
function handle_component_field_input(component, componentField, newScriptText="")
    fieldValue = getfield(component, componentField)
    fieldName = string(componentField)
    modified = false
    
    # Handle ID field specially
    if isa(fieldValue, String) && fieldName == "id"
        CImGui.Text("$(fieldName): $(fieldValue)")
        CImGui.SameLine()
        CImGui.Button("Copy") && SDL2.SDL_SetClipboardText(fieldValue)
        return false
    end
    
    # Handle vector types
    if isa(fieldValue, Math._Vector2{Float64}) || isa(fieldValue, Math._Vector2{Int32})
        return show_vector2_input(component, componentField, fieldValue)
    elseif isa(fieldValue, Math._Vector3{Float64}) || isa(fieldValue, Math._Vector3{Int32})
        return show_vector3_input(component, componentField, fieldValue)
    elseif isa(fieldValue, Math._Vector4{Float64}) || isa(fieldValue, Math._Vector4{Int32})
        return show_vector4_input(component, componentField, fieldValue)
    
    # Handle scalar types 
    elseif isa(fieldValue, Bool)
        return show_boolean_input(component, componentField, fieldValue)
    elseif isa(fieldValue, String)
        return show_string_input(component, componentField, fieldValue)
    elseif isa(fieldValue, Number)
        return show_numeric_input(component, componentField, fieldValue)
    
    # Handle scripts specially
    elseif fieldName == "scripts"
        show_script_editor(component, newScriptText)
        return false
    
    # Handle arrays and other complex types
    elseif isa(fieldValue, Vector)
        # Complex vector handling would go here
        return false
    end
    
    # Default case for unhandled types
    CImGui.Text("$(fieldName): Unhandled type $(typeof(fieldValue))")
    return false
end 