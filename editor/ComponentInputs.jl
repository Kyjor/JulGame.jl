using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using .julgame
# using .julgame.AnimationModule
# using .julgame.AnimatorModule
# using .julgame.ColliderModule
# using .julgame.EntityModule
# using .julgame.RigidbodyModule
# using .julgame.SpriteModule
# using .julgame.TransformModule

const julgameComponents = ["Transform", "Collider", "Rigidbody", "Animator", "Animation", "Entity", "SoundSource", "Sprite"]
"""
ShowComponentProperties(currentEntitySelected, component, componentType)
Creates inputs based on the component type and populates them.
"""
function ShowComponentProperties(currentEntitySelected, component, componentType)

    if componentType == "Transform"
        fieldsInComponent=fieldnames(julgame.TransformModule.Transform);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Collider"
        fieldsInComponent=fieldnames(julgame.ColliderModule.Collider);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Rigidbody"
        fieldsInComponent=fieldnames(julgame.RigidbodyModule.Rigidbody);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Animator"
        fieldsInComponent=fieldnames(julgame.AnimatorModule.Animator);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Animation"
        fieldsInComponent=fieldnames(julgame.AnimationModule.Animation);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    end

end

function ShowComponentPropertyInput(currentEntitySelected, component, componentType, componentField, name = C_NULL)
    if currentEntitySelected === nothing 
        return
    end
    itemToUpdateType = getType(currentEntitySelected)
    if itemToUpdateType == "Entity"
        itemToUpdate = currentEntitySelected.getComponent(componentType)
    else
        itemToUpdate = currentEntitySelected
    end

    componentFieldValue = getfield(component, componentField)
    componentFieldType = getType(componentFieldValue)

    if componentFieldType == "Vector2f"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue.x)
        y = Cfloat(componentFieldValue.y)
        @c CImGui.InputFloat("$(componentField) x", &x, 1)
        @c CImGui.InputFloat("$(componentField) y", &y, 1)
        itemToUpdate.setVector2fValue(componentField,convert(Float64, x),convert(Float64, y))

    elseif componentFieldType == "Bool" 
        @c CImGui.Checkbox("$(componentField)", &componentFieldValue)
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "String"
        buf = "$(componentFieldValue)"*"\0"^(64)
        CImGui.InputText("$(componentField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = 1:length(buf)
            if Int(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "Float64"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue)
        @c CImGui.InputFloat("$(componentField)", &x, 1)
        setfield!(itemToUpdate,componentField,componentFieldValue)
    
    elseif componentFieldType == "Int64"
        CImGui.Text(componentField)
        x = Cint(componentFieldValue)
        @c CImGui.InputInt("$(componentField)", &x, 1)
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "Vector4"
        vec4i = Cint[componentFieldValue.x, componentFieldValue.y, componentFieldValue.w, componentFieldValue.h]
        @c CImGui.InputInt4("input int4", vec4i)
        
    elseif componentFieldType == "Array" # Then we need to unpack the nested items
        for i = 1:length(componentFieldValue) 
            nestedType = "$(typeof(componentFieldValue[i]).name.wrapper)"
            nestedFieldType = String(split(nestedType, '.')[length(split(nestedType, '.'))])
            if CImGui.TreeNode("$(nestedFieldType) $(i)")
                CImGui.Button("Delete") && (deleteat!(componentFieldValue, i); break;)
                try
                    CImGui.Button("Add") && componentFieldValue[i].appendArray()
                catch e
                    println(e)
                end
                if nestedFieldType in julgameComponents
                    ShowComponentProperties(componentFieldValue[i], componentFieldValue[i], nestedFieldType)
                else
                    try
                        currentEntitySelected.updateArrayValue(ShowArrayPropertyInput(componentFieldValue, i), componentField, i)
                    catch e
                        println(e)
                    end
                end
                CImGui.TreePop()
            end
        end

    end

end

function ShowArrayPropertyInput(arr, index) 
    
    type = getType(arr[index])
    if type == "Vector4"
        vec = arr[index]
        vec4i = Cint[vec.x, vec.y, vec.w, vec.h]
        @c CImGui.InputInt4("input int4", vec4i)
        return julgame.Math.Vector4(vec4i[1], vec4i[2], vec4i[3], vec4i[4])
    end
end

function getType(item)
    componentFieldType = "$(typeof(item).name.wrapper)"
    return String(split(componentFieldType, '.')[length(split(componentFieldType, '.'))])
end