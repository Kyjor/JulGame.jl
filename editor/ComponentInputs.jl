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
            ShowComponentPropertyInput(currentEntitySelected, component, fieldsInComponent[i])
        end
    elseif componentType == "Collider"
        fieldsInComponent=fieldnames(julgame.ColliderModule.Collider);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, fieldsInComponent[i])
        end
    end

end

function ShowComponentPropertyInput(currentEntitySelected, component, componentField)
    componentFieldValue = getfield(component, componentField)
    componentFieldType = "$(typeof(componentFieldValue).name.wrapper)"
    componentFieldType = String(split(componentFieldType, '.')[length(split(componentFieldType, '.'))])
    componentType = "$(typeof(component))"
    componentTypeString = String(split(componentType, '.')[length(split(componentType, '.'))])

    if componentFieldType == "Vector2f"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue.x)
        y = Cfloat(componentFieldValue.y)
        @c CImGui.InputFloat("$(componentField)x", &x, 1)
        @c CImGui.InputFloat("$(componentField)y", &y, 1)
        currentEntitySelected.getComponent(componentTypeString).setVector2fValue(componentField,convert(Float64, x),convert(Float64, y))
    end

end

