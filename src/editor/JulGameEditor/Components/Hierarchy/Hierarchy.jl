function show_hierarchy(currentSceneMain::Union{MainLoop, Nothing}, hierarchyEntitySelections)
    #region Hierarchy
    CImGui.Begin("Hierarchy") 
                        
    currentSceneMain === nothing && CImGui.Text("No scene loaded. Load a scene to see the hierarchy.")
    if currentSceneMain !== nothing && CImGui.CollapsingHeader("Entities")
        # remove other entities from hierarchyEntitySelections if currentSceneMain.selectedEntity is not in hierarchyEntitySelections
        # this happens if we select an entity in the scene view
        if currentSceneMain.selectedEntity !== nothing && any(entity -> (entity[1] == currentSceneMain.selectedEntity && entity[2] == false), hierarchyEntitySelections)
            for index in eachindex(hierarchyEntitySelections)
                hierarchyEntitySelections[index] = (hierarchyEntitySelections[index][1], currentSceneMain.selectedEntity == hierarchyEntitySelections[index][1])
            end
        end 
         
        filteredEntities = currentSceneMain.scene.entities

        if length(hierarchyEntitySelections) == 0 || length(hierarchyEntitySelections) != length(filteredEntities) || updateSelectionsBasedOnFilter
            hierarchyEntitySelections= []
            for entity in filteredEntities
                push!(hierarchyEntitySelections, (entity, false))
            end
        end

        # Add bulk delete button
        # selected_count = count(es -> es[2], hierarchyEntitySelections)
        # if selected_count > 0 && CImGui.Button("Delete Selected ($(selected_count))")
        #     delete_confirmation_modal.open = true
        # end
        # CImGui.NewLine()

        # Track visible item index for alternating colors
        visible_index = 0
        
        for n = eachindex(filteredEntities)
            if filteredEntities[n].parent != C_NULL
                continue
            end
            
            visible_index += 1
            
            # Apply alternating background colors
            if visible_index % 2 == 0
                # Even rows - slightly darker background
                CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.3, 0.3, 0.35, 0.8))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.25, 0.25, 0.3, 0.6))
            else
                # Odd rows - default/lighter background  
                CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.26, 0.59, 0.98, 0.8))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.26, 0.59, 0.98, 0.31))
            end

            delete_confirmation_modal = nothing
            ui_delete_confirmation_modal = nothing
            children = [] # filter(entity -> entity.parent == filteredEntities[n], entitiesWithParents)
            if length(children) == 0
                handle_childless_entity_selection(filteredEntities[n], hierarchyEntitySelections, n, currentSceneMain, delete_confirmation_modal, visible_index)
            else
                handle_parent_entity_selection(filteredEntities[n], children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal, visible_index)
            end
            handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections, visible_index)
            
            # Pop the style colors after processing the entity
            CImGui.PopStyleColor(2)
        end

        #CImGui.PopStyleVar()
    end

    CImGui.NewLine()
     
    #region UI Elements
    if currentSceneMain !== nothing && CImGui.CollapsingHeader("UI Elements")
       # show_ui_elements_hierarchy(currentSceneMain)
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
    while parent != C_NULL
        if parent == filteredEntities[origin]
            @warn "Cannot move entity $(filteredEntities[origin].name) because it is a forefather of $(filteredEntities[destination].name)"
            return true
        end
        parent = parent.parent
    end

    return false
end

function handle_childless_entity_selection(entity, hierarchyEntitySelections, entityIndex, currentSceneMain, delete_confirmation_modal, filteredEntities = nothing, hasParent = false, visible_index = 0)
    CImGui.PushID(entity.id)
    
    # Apply alternating colors for child entities if not a parent entity
    if hasParent && visible_index > 0
        if visible_index % 2 == 0
            # Even rows - slightly darker background
            CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.3, 0.3, 0.35, 0.8))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.25, 0.25, 0.3, 0.6))
        else
            # Odd rows - default/lighter background  
            CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.26, 0.59, 0.98, 0.8))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.26, 0.59, 0.98, 0.31))
        end
    end
    
    if CImGui.Selectable(entity.name, hierarchyEntitySelections[entityIndex][2])
        # clear selection when CTRL is not held
        (!unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)) && deselect_all_entities(hierarchyEntitySelections)
        hierarchyEntitySelections[entityIndex] = (hierarchyEntitySelections[entityIndex][1], true)
        unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(hierarchyEntitySelections, entityIndex)
        currentSceneMain.selectedEntity = entity
    end
    
    # Pop style colors if they were applied
    if hasParent && visible_index > 0
        CImGui.PopStyleColor(2)
    end
    
    # Handle right-click context menu
    if hierarchyEntitySelections[entityIndex][2]
        show_entity_context_menu(currentSceneMain, hierarchyEntitySelections, delete_confirmation_modal, visible_index)
    end
    
    if filteredEntities !== nothing 
        # Use the provided entityIndex directly since we now calculate it correctly
        handle_drag_and_drop(filteredEntities, entityIndex, currentSceneMain, hierarchyEntitySelections, hasParent, visible_index)
    end 

    CImGui.PopID()
end

function handle_parent_entity_selection(entity, children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal, visible_index = 0)
    # Apply alternating colors for parent entities
    if visible_index > 0
        if visible_index % 2 == 0
            # Even rows - slightly darker background
            CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.3, 0.3, 0.35, 0.8))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.25, 0.25, 0.3, 0.6))
        else
            # Odd rows - default/lighter background  
            CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.26, 0.59, 0.98, 0.8))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.26, 0.59, 0.98, 0.31))
        end
    end
    
    # First create the tree node
    treeNodeOpen = CImGui.TreeNodeEx(entity.name, CImGui.ImGuiTreeNodeFlags_None)
    
    # Pop style colors after creating the tree node
    if visible_index > 0
        CImGui.PopStyleColor(2)
    end
    
    # Handle selection similar to childless entities
    if CImGui.IsItemClicked() && !CImGui.IsItemToggledOpen()
        # clear selection when CTRL is not held
        (!unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)) && deselect_all_entities(hierarchyEntitySelections)
        hierarchyEntitySelections[n] = (hierarchyEntitySelections[n][1], true)
        unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(hierarchyEntitySelections, n)
        currentSceneMain.selectedEntity = entity
    end
    
    # Handle right-click context menu
    if hierarchyEntitySelections[n][2]
        show_entity_context_menu(currentSceneMain, hierarchyEntitySelections, delete_confirmation_modal, visible_index)
    end
    
    # Make it a drag source
    if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
        @c CImGui.SetDragDropPayload("Entity", &n, sizeof(Cint))
        CImGui.Text("Move $(entity.name)")
        CImGui.EndDragDropSource()
    end
    
    # Make it a drop target
    
    if CImGui.BeginDragDropTarget()
        payload = CImGui.AcceptDragDropPayload("Entity")
        if payload != C_NULL
            payload = unsafe_load(payload)
            @assert payload.DataSize == sizeof(Cint)
            
            origin = unsafe_load(Ptr{Cint}(payload.Data))
            if !hasDropConflict(filteredEntities, origin, n) && filteredEntities[origin].parent != entity && filteredEntities[origin] != entity
                @debug "Moving entity $(filteredEntities[origin].name) to $(entity.name)"
                # Set the parent of the dragged entity to this entity
                filteredEntities[origin].parent = entity
            end
            CImGui.EndDragDropTarget()
        end
    end
    delete_confirmation_modal = nothing
    ui_delete_confirmation_modal = nothing
    
    # If the tree node is open, show its children
    if treeNodeOpen
        child_visible_index = 0
        for child in children
            child_visible_index += 1
            # Find the correct index for this child in the filteredEntities list
            childIndex = findfirst(e -> e === child, filteredEntities)
            if childIndex !== nothing
                # Check if this child has its own children
                childChildren = filter(e -> e.parent === child, filteredEntities)
                
                if isempty(childChildren)
                    # Regular child with no children of its own
                    handle_childless_entity_selection(child, hierarchyEntitySelections, childIndex, currentSceneMain, delete_confirmation_modal, filteredEntities, true, child_visible_index)
                else
                    # Child has its own children - recursively handle it as a parent
                    #handle_parent_entity_selection(child, childChildren, hierarchyEntitySelections, childIndex, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal, child_visible_index)
                end
            end
        end
        CImGui.TreePop()
    end
end

function deselect_all_entities(hierarchyEntitySelections)
    for index in eachindex(hierarchyEntitySelections)
        hierarchyEntitySelections[index] = (hierarchyEntitySelections[index][1], false)
    end
end

function select_all_elements_in_between(hierarchyEntitySelections, lastSelectedIndex)
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