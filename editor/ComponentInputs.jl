using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using .julgame
using .julgame.AnimationModule
using .julgame.AnimatorModule
using .julgame.ColliderModule
using .julgame.EntityModule
using .julgame.RigidbodyModule
using .julgame.SpriteModule
using .julgame.TransformModule

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
    end

end

function ShowComponentPropertyInput(currentEntitySelected, component, componentType, componentField)
    componentFieldValue = getfield(component, componentField)
    componentFieldType = "$(typeof(componentFieldValue).name.wrapper)"
    componentFieldType = String(split(componentFieldType, '.')[length(split(componentFieldType, '.'))])

    if componentFieldType == "Vector2f"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue.x)
        y = Cfloat(componentFieldValue.y)
        @c CImGui.InputFloat("$(componentField) x", &x, 1)
        @c CImGui.InputFloat("$(componentField) y", &y, 1)
        currentEntitySelected.getComponent(componentType).setVector2fValue(componentField,convert(Float64, x),convert(Float64, y))

    elseif componentFieldType == "Bool" 
        @c CImGui.Checkbox("$(componentField)", &componentFieldValue)
        setfield!(currentEntitySelected.getComponent(componentType),componentField,componentFieldValue)

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
        setfield!(currentEntitySelected.getComponent(componentType),componentField,componentFieldValue)
    elseif componentFieldType == "Float64"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue)
        @c CImGui.InputFloat("$(componentField)", &x, 1)
        setfield!(currentEntitySelected.getComponent(componentType),componentField,componentFieldValue)
    
    elseif componentFieldType == "Int64"
        CImGui.Text(componentField)
        x = Cint(componentFieldValue)
        @c CImGui.InputInt("$(componentField)", &x, 1)
        setfield!(currentEntitySelected.getComponent(componentType),componentField,componentFieldValue)

    end

end

