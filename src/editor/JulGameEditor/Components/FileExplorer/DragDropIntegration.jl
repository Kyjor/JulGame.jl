"""
    DragDropIntegration

Advanced drag-and-drop integration for the file explorer system.
Extends the existing ImportFile scene integration patterns to support
direct drag-and-drop from the file explorer to scene elements,
hierarchy, and other editor components.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using JulGame: SDL2

include("FileExplorer.jl")

"""
    Drag-and-drop payload types
"""

const DRAG_DROP_FILE_PATH = "FILE_PATH"
const DRAG_DROP_MULTIPLE_FILES = "MULTIPLE_FILES"
const DRAG_DROP_ASSET_REFERENCE = "ASSET_REFERENCE"

"""
    Enhanced drag source handling for file explorer items
"""

function begin_file_drag_source(filepath::String, is_multi_select::Bool = false)
    if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
        @debug "Begin file drag source: $filepath"
        explorer = JulGame.EditorState["file_explorer"]
        
        if is_multi_select && length(explorer.selected_items) > 1
            # Multi-file drag
            selected_files = collect(explorer.selected_items)
            files_data = join(selected_files, "\n")
            payload_bytes = Vector{UInt8}(files_data)
            
            CImGui.SetDragDropPayload(DRAG_DROP_MULTIPLE_FILES, pointer(payload_bytes), length(payload_bytes))
            
            # Visual feedback for multiple files
            CImGui.Text("Moving $(length(selected_files)) items:")
            for (i, file) in enumerate(selected_files)
                if i > 5  # Show max 5 files
                    CImGui.Text("... and $(length(selected_files) - 5) more")
                    break
                end
                CImGui.Text("• $(basename(file))")
            end
        else
            # Single file drag (following existing pattern)
            payload_bytes = Vector{UInt8}(filepath)
            CImGui.SetDragDropPayload(DRAG_DROP_FILE_PATH, pointer(payload_bytes), length(payload_bytes))
            
            # Visual feedback
            filename = basename(filepath)
            file_type = get_file_type(filepath)
            icon = get_file_type_icon(file_type)
            
            CImGui.Text("$icon $filename")
            
            # Show what can be created from this file type
            if file_type == :image
                CImGui.TextColored((0.7, 0.9, 1.0, 1.0), "Sprite Entity or UI Button")
            elseif file_type == :audio
                CImGui.TextColored((0.7, 0.9, 1.0, 1.0), "Sound Entity")
            elseif file_type == :script
                CImGui.TextColored((0.7, 0.9, 1.0, 1.0), "Script Component")
            elseif file_type == :scene
                CImGui.TextColored((0.7, 0.9, 1.0, 1.0), "Load Scene")
            end
        end
        
        CImGui.EndDragDropSource()
    end
end

"""
    Scene viewer drop target integration
"""

function handle_scene_viewer_drop_target()::Bool
    @debug "Scene viewer drop target activated"
    current_scene_main = get(JulGame.EditorState, "current_scene_main", nothing)
    if current_scene_main === nothing
        @debug "No current scene available for drop"
        return false
    end

    if CImGui.BeginDragDropTarget()
        # Handle single file drops
        single_file_payload = CImGui.AcceptDragDropPayload(DRAG_DROP_FILE_PATH)
        if single_file_payload != C_NULL
            @debug "Received drag-drop payload for single file"
            filepath = extract_file_path_from_payload(single_file_payload)
            @debug "Extracted filepath: $filepath"
            if filepath != ""
            create_scene_entity_from_file(filepath, current_scene_main, JulGame.InputModule.get_mouse_position_in_world_space())
                CImGui.EndDragDropTarget()
                return true
            end
        end
        
        # Handle multiple file drops
        multi_file_payload = CImGui.AcceptDragDropPayload(DRAG_DROP_MULTIPLE_FILES)
        if multi_file_payload != C_NULL
            filepaths = extract_multiple_file_paths_from_payload(multi_file_payload)
            if !isempty(filepaths)
                create_multiple_scene_entities(filepaths, current_scene_main, JulGame.InputModule.get_mouse_position_in_world_space())
                CImGui.EndDragDropTarget()
                return true
            end
        end
    
        CImGui.EndDragDropTarget()
    end
    return false
end

"""
    Hierarchy window drop target integration
"""

function handle_hierarchy_drop_target(target_entity = nothing)::Bool
    if !CImGui.BeginDragDropTarget()
        return false
    end
    
    current_scene_main = get(JulGame.EditorState, "current_scene_main", nothing)
    if current_scene_main === nothing
        CImGui.EndDragDropTarget()
        return false
    end
    
    # Handle file drops onto hierarchy
    single_file_payload = CImGui.AcceptDragDropPayload(DRAG_DROP_FILE_PATH)
    if single_file_payload != C_NULL
        filepath = extract_file_path_from_payload(single_file_payload)
        if filepath != ""
            entity = create_scene_entity_from_file(filepath, current_scene_main, JulGame.InputModule.get_mouse_position_in_world_space())
            
            # If dropped onto another entity, make it a child
            if target_entity !== nothing && entity !== nothing
                # TODO: Implement parent-child relationships
                @debug "Would make $(entity.name) a child of $(target_entity.name)"
            end
            
            CImGui.EndDragDropTarget()
            return true
        end
    end
    
    CImGui.EndDragDropTarget()
    return false
end

"""
    Inspector window drop target for component assignment
"""

function handle_inspector_drop_target(selected_entity)::Bool
    if selected_entity === nothing || !CImGui.BeginDragDropTarget()
        return false
    end
    
    # Handle file drops for component creation
    single_file_payload = CImGui.AcceptDragDropPayload(DRAG_DROP_FILE_PATH)
    if single_file_payload != C_NULL
        filepath = extract_file_path_from_payload(single_file_payload)
        if filepath != ""
            add_component_from_file(selected_entity, filepath)
            CImGui.EndDragDropTarget()
            return true
        end
    end
    
    CImGui.EndDragDropTarget()
    return false
end

"""
    Entity creation from dropped files (extends ImportFile patterns)
"""

function create_scene_entity_from_file(filepath::String, current_scene_main, position = Math.Vector2f(0.0, 0.0))
    file_type = get_file_type(filepath)
    relative_path = get_asset_relative_path(filepath)
    entity_name = generate_entity_name_from_file(filepath)
    @info "Creating scene entity from file: $filepath"
    @info "file_type: $file_type"
    @info "relative_path: $relative_path"
    @info "entity_name: $entity_name"
    @info "position: $position"
    try
        entity = nothing
        
        if file_type == :image
            # Use existing ImportFile function
            entity = create_entity_with_sprite(relative_path, entity_name)
            push!(current_scene_main.scene.entities, entity)
            @debug "Created sprite entity: $(entity_name)"
        elseif file_type == :audio
            # Use existing ImportFile function
            entity = create_entity_with_sound(relative_path, entity_name)
            push!(current_scene_main.scene.entities, entity)
            @debug "Created sound entity: $(entity_name)"
        elseif file_type == :script
            # Create entity with script component
            entity = JulGame.Entity(entity_name)
            # TODO: Add script component when available
            push!(current_scene_main.scene.entities, entity)
            @debug "Created script entity: $(entity_name)"
        elseif file_type == :scene
            # TODO: Implement scene loading/merging
            @debug "Scene file dropped: $filepath"
        else
            @warn "Unsupported file type for entity creation: $file_type"
            return nothing
        end

        entity.transform.position = Math.Vector3f(position.x, position.y, 0.0)
        return entity
        
    catch e
        @error "Failed to create entity from file $(filepath): $e"
        return nothing
    end
end

function create_multiple_scene_entities(filepaths::Vector{String}, current_scene_main, position::Math.Vector2 = Math.Vector2(0.0, 0.0))
    created_entities = []
    
    for filepath in filepaths
        entity = create_scene_entity_from_file(filepath, current_scene_main, position)
        if entity !== nothing
            push!(created_entities, entity)
        end
    end
    
    if !isempty(created_entities)
        # Arrange entities in a grid pattern
        arrange_entities_in_grid(created_entities)
        @debug "Created $(length(created_entities)) entities from dropped files"
    end
    
    return created_entities
end

"""
    UI element creation for specific drop targets
"""

function create_ui_element_from_file(filepath::String, current_scene_main, ui_type::Symbol = :button)
    file_type = get_file_type(filepath)
    
    if file_type != :image
        @warn "Only image files can be used for UI elements"
        return nothing
    end
    
    relative_path = get_asset_relative_path(filepath)
    element_name = generate_entity_name_from_file(filepath)
    
    try
        if ui_type == :button
            # Use existing ImportFile function
            screen_button = create_ui_screenbutton(relative_path, element_name)
            push!(current_scene_main.scene.uiElements, screen_button)
            @debug "Created UI button: $(element_name)"
            return screen_button
        end
        # TODO: Add other UI element types
        
    catch e
        @error "Failed to create UI element from file $(filepath): $e"
        return nothing
    end
end

"""
    Component addition from dropped files
"""

function add_component_from_file(entity, filepath::String)
    file_type = get_file_type(filepath)
    relative_path = get_asset_relative_path(filepath)
    
    try
        if file_type == :image && !JulGame.has_sprite(entity)
            # Add sprite component
            JulGame.add_sprite(entity, true)
            entity.sprite.imagePath = relative_path
            entity.sprite.pixelsPerUnit = 0
            JulGame.Component.load_image(entity.sprite, relative_path)
            @debug "Added sprite component to $(entity.name)"
            
        elseif file_type == :audio && !JulGame.has_sound_source(entity)
            # Add sound source component
            JulGame.add_sound_source(entity)
            entity.soundSource.path = relative_path
            JulGame.Component.load_sound(entity.soundSource, relative_path, false)
            @debug "Added sound source component to $(entity.name)"
            
        elseif file_type == :script
            # TODO: Add script component
            @debug "Would add script component to $(entity.name): $relative_path"
            
        else
            @warn "Cannot add component of type $file_type to entity"
        end
        
    catch e
        @error "Failed to add component from file $(filepath): $e"
    end
end

"""
    Drop target visual feedback
"""

function show_drop_target_highlight(target_name::String, accepted_types::Vector{Symbol} = Symbol[])
    if CImGui.IsItemHovered() && CImGui.GetDragDropPayload() != C_NULL
        # Highlight the drop target
        draw_list = CImGui.GetWindowDrawList()
        item_min = CImGui.GetItemRectMin()
        item_max = CImGui.GetItemRectMax()
        
        # Draw highlight border
        highlight_color = IM_COL32(100, 200, 255, 100)
        CImGui.AddRect(draw_list, item_min, item_max, highlight_color, 4.0, 0, 2.0)
        
        # Show tooltip with accepted file types
        if !isempty(accepted_types)
            CImGui.BeginTooltip()
            CImGui.Text("Drop files here to create:")
            for file_type in accepted_types
                icon = get_file_type_icon(file_type)
                CImGui.Text("$icon $(string(file_type)) files")
            end
            CImGui.EndTooltip()
        end
    end
end

"""
    Utility functions for drag-and-drop
"""

function extract_file_path_from_payload(payload_ptr)::String
    try
        payload = unsafe_load(payload_ptr)
        path_bytes = unsafe_wrap(Array{UInt8}, convert(Ptr{UInt8}, payload.Data), payload.DataSize)
        return String(path_bytes)
    catch e
        @error "Failed to extract file path from drag payload: $e"
        return ""
    end
end

function extract_multiple_file_paths_from_payload(payload_ptr)::Vector{String}
    try
        payload = unsafe_load(payload_ptr)
        data_bytes = unsafe_wrap(Array{UInt8}, convert(Ptr{UInt8}, payload.Data), payload.DataSize)
        data_string = String(data_bytes)
        return split(data_string, "\n")
    catch e
        @error "Failed to extract multiple file paths from drag payload: $e"
        return String[]
    end
end

function get_asset_relative_path(filepath::String)::String
    # Convert to relative path following ImportFile patterns
    relative_path = relpath(filepath, JulGame.BasePath)
    
    # Clean up path following ImportFile patterns
    if startswith(relative_path, "assets/")
        relative_path = replace(relative_path, "assets/" => "")
    end
    if startswith(relative_path, "assets\\")
        relative_path = replace(relative_path, "assets\\" => "")
    end
    if startswith(relative_path, "images/")
        relative_path = replace(relative_path, "images/" => "")
    end
    if startswith(relative_path, "images\\")
        relative_path = replace(relative_path, "images\\" => "")
    end
    if startswith(relative_path, "audio/")
        relative_path = replace(relative_path, "audio/" => "")
    end
    if startswith(relative_path, "audio\\")
        relative_path = replace(relative_path, "audio\\" => "")
    end
    if startswith(relative_path, "scripts/")
        relative_path = replace(relative_path, "scripts/" => "")
    end
    if startswith(relative_path, "scripts\\")
        relative_path = replace(relative_path, "scripts\\" => "")
    end
    if startswith(relative_path, "scenes/")
        relative_path = replace(relative_path, "scenes/" => "")
    end
    if startswith(relative_path, "scenes\\")
        relative_path = replace(relative_path, "scenes\\" => "")
    end
    return relative_path
end

function generate_entity_name_from_file(filepath::String)::String
    # Generate entity name following ImportFile patterns
    base_name = splitext(basename(filepath))[1]
    return replace(base_name, " " => "_")
end

function arrange_entities_in_grid(entities::Vector, grid_spacing::Float32 = 100.0f0)
    # Arrange entities in a grid pattern
    grid_size = Int(ceil(sqrt(length(entities))))
    
    for (i, entity) in enumerate(entities)
        if JulGame.has_transform(entity)
            row = div(i - 1, grid_size)
            col = (i - 1) % grid_size
            
            entity.transform.position.x = col * grid_spacing
            entity.transform.position.y = row * grid_spacing
        end
    end
end

"""
    Integration with existing file explorer UI
"""

function setup_file_explorer_drag_sources()
    # This function should be called from FileExplorerUI.jl
    # to set up drag sources for file items
end

function setup_editor_drop_targets()
    # This function should be called from Editor.jl
    # to set up drop targets in various editor windows
end

"""
    Smart drop behavior based on target context
"""

function determine_drop_behavior(filepath::String, target_context::Symbol)::Symbol
    file_type = get_file_type(filepath)
    
    if target_context == :scene_viewer
        if file_type in [:image, :audio, :script]
            return :create_entity
        elseif file_type == :scene
            return :load_scene
        end
    elseif target_context == :hierarchy
        return :create_entity
    elseif target_context == :inspector
        return :add_component
    elseif target_context == :ui_canvas
        if file_type == :image
            return :create_ui_element
        end
    end
    
    return :none
end

# Export functions for integration
export begin_file_drag_source, handle_scene_viewer_drop_target, handle_hierarchy_drop_target
export handle_inspector_drop_target, show_drop_target_highlight
export create_scene_entity_from_file, create_ui_element_from_file, add_component_from_file
