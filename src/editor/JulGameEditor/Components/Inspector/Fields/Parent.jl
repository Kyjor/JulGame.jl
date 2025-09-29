function show_parent_field(structure::EditableStructure, field::Symbol, value::Union{JulGame.UI.UIElement, JulGame.IEntity, Nothing})
    show_field_label(field)
    if value !== nothing
        CImGui.Text("$(value.name), $(value.id)")
        CImGui.SameLine()
        if CImGui.Button("Remove parent")
            structure.parent = nothing
            changed = true
        end
    else
        CImGui.Text("No parent")
    end

    if CImGui.BeginDragDropTarget()
        # Handle single file drops
        single_element_payload = CImGui.AcceptDragDropPayload("SCENE_ELEMENT")
        if single_element_payload != C_NULL
            @info "Received drag-drop payload for single element"
            payload = unsafe_load(single_element_payload)
            string_data = String(unsafe_wrap(Array{UInt8}, convert(Ptr{UInt8}, payload.Data), payload.DataSize))
            element_id = strip(split(string_data, "::")[1])
            element_type = strip(split(string_data, "::")[2])
            println("Element ID: $element_id, Element type: $element_type")
            element = if element_type == "Entity"
                JulGame.SceneModule.get_entity_by_id(string(element_id))
            elseif element_type == "UIElement"
                JulGame.SceneModule.get_ui_element_by_id(string(element_id))
            else
                nothing
            end
            @info "Element ID: $element_id"
            @info "Element: $element"
            if element !== nothing
                structure.parent = element
                changed = true
            end
        end

        CImGui.EndDragDropTarget()
    end
   
    changed = false


    return changed
end