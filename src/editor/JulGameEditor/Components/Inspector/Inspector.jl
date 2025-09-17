EditableStructure = Union{Entity, UI.UIElement, TransformModule.Transform}
include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Fields"); join=true)))

function show_inspector(currentSceneMain::Union{MainLoop, Nothing})
    CImGui.Begin("Inspector") 
    if currentSceneMain !== nothing && currentSceneMain.selectedEntity !== nothing
        display_fields(currentSceneMain.selectedEntity)
    end
    CImGui.End()
end


function display_fields(structure::EditableStructure)
    for field in fieldnames(typeof(structure))
        structureType = string(split(typeof(structure), ".")[end])
        if get(FieldExclusions, structureType, []) != [] && field in get(FieldExclusions, structureType, [])
            continue
        end
        show_field(structure, field, getfield(structure, field))
    end
end

function show_field(structure::EditableStructure, field::Symbol, value::Any)
    #unmapped fields
end

function show_field(structure::EditableStructure, field::Symbol, value::TransformModule.Transform)
    display_fields(value)
    #unmapped fields
end

function show_field_label(field::Symbol)
    # capitalize the first letter
    toolTip = get(ToolTips, field, "")
    label = string(field)
    label = uppercase(label[1]) * label[2:end]
    # Space between each word (capital letter)
    label = replace(label, r"(?<=[a-z])(?=[A-Z])" => " ")#replace(label, r"(?=[A-Z])" => " ")
    label = strip(label)

    CImGui.Text("$(label)")
    if toolTip != ""
        CImGui.SameLine()
        show_help_marker("$(toolTip)")
    end
end