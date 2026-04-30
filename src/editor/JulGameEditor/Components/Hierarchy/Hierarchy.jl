function show_hierarchy(currentSceneMain::Union{MainLoop, Nothing})
    #region Hierarchy
    CImGui.Begin("Hierarchy") 
                        
    currentSceneMain === nothing && CImGui.Text("No scene loaded. Load a scene to see the hierarchy.")
    if currentSceneMain !== nothing && CImGui.CollapsingHeader("Entities")
        filteredEntities = currentSceneMain.scene.entities

        # Track visible item index for alternating colors
        visible_index = 0
        
        for n = eachindex(filteredEntities)
            if filteredEntities[n].parent !== nothing
                continue
            end
            
            visible_index += 1
            
            # Apply alternating background colors
            if visible_index % 2 == 0
                # Even rows - darker background colors
                CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, (0.2, 0.2, 0.25, 0.4))  # Normal background
                CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.3, 0.3, 0.35, 0.8))  # Hover
                CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.25, 0.25, 0.3, 0.6))  # Selected
            else
                # Odd rows - lighter background colors  
                CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, (0.15, 0.15, 0.2, 0.2))  # Normal background
                CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.26, 0.59, 0.98, 0.8))  # Hover
                CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.26, 0.59, 0.98, 0.31))  # Selected
            end

            children = [] # filter(entity -> entity.parent == filteredEntities[n], entitiesWithParents)
            if length(children) == 0
                display_selectable_element(filteredEntities[n])
            else
                #handle_parent_entity_selection(filteredEntities[n], children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal, visible_index)
            end
            #handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections, visible_index)
            
            # Pop the style colors after processing the entity (now 3 colors instead of 2)
            CImGui.PopStyleColor(3)
        end
    end
    if currentSceneMain !== nothing
         # Context menu for the entire hierarchy window
         if CImGui.BeginPopupContextWindow("hierarchy_context_menu")
            if CImGui.MenuItem("Add Entity")
                JulGame.MainLoopModule.create_new_entity(currentSceneMain)
                @debug "Adding entity"
            end
            if CImGui.MenuItem("Add TextBox")
                JulGame.MainLoopModule.create_new_text_box(currentSceneMain)
                @debug "Adding textbox"
            end
            if CImGui.MenuItem("Add Image")
                JulGame.MainLoopModule.create_new_image(currentSceneMain)
                @debug "Adding image"
            end
            if CImGui.MenuItem("Add Button")
                JulGame.MainLoopModule.create_new_screen_button(currentSceneMain)
                @debug "Adding button"
            end
            if CImGui.MenuItem("Add Rectangle")
                JulGame.MainLoopModule.create_new_rectangle(currentSceneMain)
                @debug "Adding rectangle"
            end
            CImGui.EndPopup()
        end
    end

    CImGui.NewLine()
     
    #region UI Elements
    if currentSceneMain !== nothing && CImGui.CollapsingHeader("UI Elements")
        filteredUIElements = currentSceneMain.scene.uiElements
        for n = eachindex(filteredUIElements)
            display_selectable_element(filteredUIElements[n])
        end
    end

    CImGui.NewLine()

    if currentSceneMain !== nothing && CImGui.CollapsingHeader("Cameras")
        display_selectable_element(currentSceneMain.scene.camera)
    end

CImGui.End()
end


function hasDropConflict(filteredEntities, origin, destination)
    # If the entity we are dragging's target is it's own child, we can't move it
    if filteredEntities[destination].parent == filteredEntities[origin]
        @warn "Cannot move entity $(filteredEntities[origin].name) because it the parent of $(filteredEntities[destination].name)"
        return true
    end
    # if it is a grandchild, great grandchild, etc, we need to move all the way up the chain to check if we can move it 
    parent = filteredEntities[destination].parent
    while parent !== nothing
        if parent == filteredEntities[origin]
            @warn "Cannot move entity $(filteredEntities[origin].name) because it is a forefather of $(filteredEntities[destination].name)"
            return true
        end
        parent = parent.parent
    end

    return false
end

function display_selectable_element(element)
    CImGui.PushID(element.id)

    selected = JulGame.MAIN.selectedEntities !== nothing && length(JulGame.MAIN.selectedEntities) > 0 && element in JulGame.MAIN.selectedEntities
    if CImGui.Selectable(element.name, selected)
        # clear selection when CTRL is not held or current selection type is not the same as the entity type
        if length(JulGame.MAIN.selectedEntities) > 0 && typeof(JulGame.MAIN.selectedEntities[1]) != typeof(element)
            JulGame.MAIN.selectedEntities = []
        end
        if !unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)
            JulGame.MAIN.selectedEntities = []
        end
        push!(JulGame.MAIN.selectedEntities, element)
        #unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(JulGame.MAIN.selectedEntities, entityIndex)
    end

    if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
        element_type = split("$(typeof(element))", ".")[end]
        id_data = Vector{UInt8}("$(element.id)::$(element_type == "Entity" ? "Entity" : "UIElement")")
        CImGui.SetDragDropPayload("SCENE_ELEMENT", pointer(id_data), length(id_data)) # set payload to carry the index of our item (could be anything)
        CImGui.Text("Move $(element.name)")
        CImGui.EndDragDropSource()
    end
    
    CImGui.PopID()
end

function select_all_elements_in_between(lastSelectedIndex)
    start = 0
    for i in 1:lastSelectedIndex
        if hierarchyEntitySelections[i][2] == true && i != lastSelectedIndex
            start = i
            break
        end
    end
    if start != 0
        for i in start:lastSelectedIndex
            hierarchyEntitySelections[i] = (hierarchyEntitySelections[i][1], true)
            if i == lastSelectedIndex
                return
            end
        end
    end

    for i in length(hierarchyEntitySelections):-1:lastSelectedIndex
        if hierarchyEntitySelections[i][2] == true && i != lastSelectedIndex
            start = i
            break
        end
    end

    if start != 0
        for i in start:-1:lastSelectedIndex
            hierarchyEntitySelections[i] = (hierarchyEntitySelections[i][1], true)
        end
    end
end