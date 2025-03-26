using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame
using JulGame.Math

"""
    show_vector2_input(component, componentField, fieldValue, label)

Shows input fields for Vector2 values, handling both float and integer types.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)

# Returns
- `Bool`: whether the field was modified
"""
function show_vector2_input(component, componentField, fieldValue, label=nothing)
    isFloat = isa(fieldValue, Math._Vector2{Float64})
    displayLabel = label === nothing ? string(componentField) : label
    
    x = isFloat ? Cfloat(fieldValue.x) : Cint(fieldValue.x)
    y = isFloat ? Cfloat(fieldValue.y) : Cint(fieldValue.y)
    original_x = x
    original_y = y

    if CImGui.TreeNode(displayLabel)
        if isFloat 
            @c CImGui.InputFloat("$(componentField) x", &x, 1)
            @c CImGui.InputFloat("$(componentField) y", &y, 1)
        else
            @c CImGui.InputInt("$(componentField) x", &x, 1)
            @c CImGui.InputInt("$(componentField) y", &y, 1)
        end
        
        if x != original_x || y != original_y
            setfield!(component, componentField, (isFloat ? Vector2f(x, y) : Vector2(x, y)))
        end
        
        CImGui.TreePop()
    end
    
    return x != original_x || y != original_y
end

"""
    show_vector3_input(component, componentField, fieldValue, label)

Shows input fields for Vector3 values, handling both float and integer types.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)

# Returns
- `Bool`: whether the field was modified
"""
function show_vector3_input(component, componentField, fieldValue, label=nothing)
    isFloat = isa(fieldValue, Math._Vector3{Float64})
    displayLabel = label === nothing ? string(componentField) : label
    
    vec3 = isFloat ? Cfloat[fieldValue.x, fieldValue.y, fieldValue.z] : 
                     Cint[fieldValue.x, fieldValue.y, fieldValue.z]
    
    original_x = vec3[1]
    original_y = vec3[2]
    original_z = vec3[3]

    if CImGui.TreeNode(displayLabel)
        if isFloat 
            @c CImGui.InputFloat3("input float3", vec3)
        else
            @c CImGui.InputInt3("input int3", vec3)
        end
        
        if vec3[1] != original_x || vec3[2] != original_y || vec3[3] != original_z
            setfield!(component, componentField, (isFloat ? 
                Vector3f(vec3[1], vec3[2], vec3[3]) : 
                Vector3(vec3[1], vec3[2], vec3[3])))
        end
        
        CImGui.TreePop()
    end
    
    return vec3[1] != original_x || vec3[2] != original_y || vec3[3] != original_z
end

"""
    show_vector4_input(component, componentField, fieldValue, label)

Shows input fields for Vector4 values, handling both float and integer types.

# Arguments
- `component`: The component containing the field
- `componentField`: The field symbol
- `fieldValue`: The current value of the field
- `label`: Label to display (defaults to componentField string)

# Returns
- `Bool`: whether the field was modified
"""
function show_vector4_input(component, componentField, fieldValue, label=nothing)
    isFloat = isa(fieldValue, Math._Vector4{Float64})
    displayLabel = label === nothing ? string(componentField) : label
    
    vec4 = isFloat ? Cfloat[fieldValue.x, fieldValue.y, fieldValue.z, fieldValue.t] : 
                     Cint[fieldValue.x, fieldValue.y, fieldValue.z, fieldValue.t]
    
    original_x = vec4[1]
    original_y = vec4[2]
    original_z = vec4[3]
    original_t = vec4[4]

    if CImGui.TreeNode(displayLabel)
        if isFloat 
            @c CImGui.InputFloat4("input float4", vec4)
        else
            @c CImGui.InputInt4("input int4", vec4)
        end
        
        if vec4[1] != original_x || vec4[2] != original_y || vec4[3] != original_z || vec4[4] != original_t
            setfield!(component, componentField, (isFloat ? 
                Vector4f(vec4[1], vec4[2], vec4[3], vec4[4]) : 
                Vector4(vec4[1], vec4[2], vec4[3], vec4[4])))
        end
        
        CImGui.TreePop()
    end
    
    return vec4[1] != original_x || vec4[2] != original_y || vec4[3] != original_z || vec4[4] != original_t
end 