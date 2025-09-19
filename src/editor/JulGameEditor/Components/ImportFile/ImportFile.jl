"""
    ImportFile

A module for handling file import dialogs when files are dropped onto the editor window.
Provides functionality to import files one at a time with destination folder selection,
file renaming, image preview, and audio preview capabilities.
Supports images and audio files only.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using JulGame: SDL2
using NativeFileDialog

"""
    FileImportDialog

Structure to manage the file import dialog state.
"""
mutable struct FileImportDialog
    is_open::Bool
    current_file::String
    destination_folder::String
    new_filename::Ref{String}
    preview_texture::Ptr{SDL2.LibSDL2.SDL_Texture}
    preview_size::ImVec2
    is_image::Bool
    is_audio::Bool
    audio_preview::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
    is_audio_playing::Bool
    conflict_error::String
    add_to_scene::Bool
    create_as_ui_element::Bool
    temp_files_to_cleanup::Vector{String}  # Track temporary files for cleanup
    
    function FileImportDialog()
        new(false, "", "assets", Ref(""), C_NULL, ImVec2(0, 0), false, false, C_NULL, false, "", false, false, String[])
    end
end

# Global dialog instance
const import_dialog = FileImportDialog()

"""
    initialize_import_dialog()

Initialize the import dialog state in EditorState.
"""
function initialize_import_dialog()
    if !haskey(JulGame.EditorState, "file_import_dialog")
        JulGame.EditorState["file_import_dialog"] = import_dialog
    end
    
    if !haskey(JulGame.EditorState, "import_queue_index")
        JulGame.EditorState["import_queue_index"] = 1
    end
end

"""
    is_supported_file(filepath::String) -> Bool

Check if the file is a supported format (images or audio).
"""
function is_supported_file(filepath::String)
    return is_image_file(filepath) || is_audio_file(filepath)
end

"""
    is_image_file(filepath::String) -> Bool

Check if the file is a supported image format.
"""
function is_image_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".png", ".jpg", ".jpeg", ".bmp", ".tga", ".gif"]
end

"""
    is_audio_file(filepath::String) -> Bool

Check if the file is a supported audio format.
"""
function is_audio_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".wav", ".mp3", ".ogg", ".flac", ".aiff"]
end

"""
    load_image_preview(filepath::String, renderer) -> (Ptr{SDL2.LibSDL2.SDL_Texture}, ImVec2)

Load an image for preview in the dialog. Returns texture pointer and size.
"""
function load_image_preview(filepath::String, renderer)
    try
        if !isfile(filepath) || !is_image_file(filepath)
            return C_NULL, ImVec2(0, 0)
        end
        
        # Load the image surface
        surface = SDL2.IMG_Load(filepath)
        if surface == C_NULL
            @warn "Failed to load image surface: $(filepath)"
            return C_NULL, ImVec2(0, 0)
        end
        
        # Create texture from surface
        texture = SDL2.SDL_CreateTextureFromSurface(renderer, surface)
        
        # Get surface dimensions
        surface_ref = unsafe_load(surface)
        width = surface_ref.w
        height = surface_ref.h
        
        # Free the surface
        SDL2.SDL_FreeSurface(surface)
        
        if texture == C_NULL
            @warn "Failed to create texture from surface: $(filepath)"
            return C_NULL, ImVec2(0, 0)
        end
        
        # Calculate preview size (max 200x200, maintaining aspect ratio)
        max_size = 200.0
        aspect_ratio = width / height
        
        if width > height
            preview_width = min(width, max_size)
            preview_height = preview_width / aspect_ratio
        else
            preview_height = min(height, max_size)
            preview_width = preview_height * aspect_ratio
        end
        
        return texture, ImVec2(preview_width, preview_height)
        
    catch e
        @error "Error loading image preview: $(e)"
        return C_NULL, ImVec2(0, 0)
    end
end

"""
    load_audio_preview(filepath::String) -> Ptr{SDL2.LibSDL2.Mix_Chunk}

Load an audio file for preview in the dialog. Returns audio chunk pointer.
"""
function load_audio_preview(filepath::String)
    try
        if !isfile(filepath) || !is_audio_file(filepath)
            return C_NULL
        end
        
        # Load the audio chunk for preview
        chunk = SDL2.Mix_LoadWAV(filepath)
        if chunk == C_NULL
            @warn "Failed to load audio preview: $(filepath) - $(unsafe_string(SDL2.SDL_GetError()))"
            return C_NULL
        end
        
        return chunk
        
    catch e
        @error "Error loading audio preview: $(e)"
        return C_NULL
    end
end

"""
    cleanup_preview_texture()

Clean up the current preview texture.
"""
function cleanup_preview_texture()
    dialog = JulGame.EditorState["file_import_dialog"]
    if dialog.preview_texture != C_NULL
        SDL2.SDL_DestroyTexture(dialog.preview_texture)
        dialog.preview_texture = C_NULL
        dialog.preview_size = ImVec2(0, 0)
    end
end

"""
    cleanup_audio_preview()

Clean up the current audio preview.
"""
function cleanup_audio_preview()
    dialog = JulGame.EditorState["file_import_dialog"]
    if dialog.audio_preview != C_NULL
        # Stop any playing audio
        SDL2.Mix_HaltChannel(-1)
        SDL2.Mix_FreeChunk(dialog.audio_preview)
        dialog.audio_preview = C_NULL
        dialog.is_audio_playing = false
    end
end

"""
    cleanup_all_previews()

Clean up both image and audio previews.
"""
function cleanup_all_previews()
    cleanup_preview_texture()
    cleanup_audio_preview()
end

"""
    is_temp_file(filepath::String) -> Bool

Check if a file is a temporary file (from clipboard paste).
"""
function is_temp_file(filepath::String)
    return occursin("clipboard_image_", basename(filepath)) || startswith(dirname(filepath), tempdir())
end

"""
    setup_next_file(renderer)

Set up the dialog for the next file in the queue.
"""
function setup_next_file(renderer)
    dropped_files = get(JulGame.EditorState, "dropped_files", nothing)
    if dropped_files === nothing || isempty(dropped_files)
        return false
    end
    
    # Filter to only supported files
    supported_files = filter(is_supported_file, dropped_files)
    if isempty(supported_files)
        # No supported files, cleanup and exit
        cleanup_import_queue()
        return false
    end
    
    # Update dropped_files to only include supported files
    JulGame.EditorState["dropped_files"] = supported_files
    dropped_files = supported_files
    
    queue_index = JulGame.EditorState["import_queue_index"]
    if queue_index > length(dropped_files)
        return false
    end
    
    dialog = JulGame.EditorState["file_import_dialog"]
    current_file = dropped_files[queue_index]
    
    # Clean up previous previews
    cleanup_all_previews()
    
    # Set up dialog state
    dialog.current_file = current_file
    dialog.new_filename[] = basename(current_file)
    dialog.is_image = is_image_file(current_file)
    dialog.is_audio = is_audio_file(current_file)
    dialog.conflict_error = ""
    
    # Track temporary files for cleanup
    if is_temp_file(current_file) && !(current_file in dialog.temp_files_to_cleanup)
        push!(dialog.temp_files_to_cleanup, current_file)
    end
    
    # Set default destination folder based on file type
    if dialog.is_image
        dialog.destination_folder = "assets/images"
    elseif dialog.is_audio
        dialog.destination_folder = "assets/audio"
    else
        dialog.destination_folder = "assets"
    end
    
    # Load preview if it's an image
    if dialog.is_image
        dialog.preview_texture, dialog.preview_size = load_image_preview(current_file, renderer)
    end
    
    # Load preview if it's audio
    if dialog.is_audio
        dialog.audio_preview = load_audio_preview(current_file)
    end
    
    dialog.is_open = true
    return true
end

"""
    get_project_folders() -> Vector{String}

Get a list of common project folders for the destination dropdown.
"""
function get_project_folders()
    base_folders = ["assets", "assets/images", "assets/audio", "assets/sounds", "assets/fonts", "scripts", "scenes"]
    
    # Add existing subdirectories from assets if they exist
    assets_path = joinpath(JulGame.BasePath, "assets")
    if isdir(assets_path)
        try
            for item in readdir(assets_path)
                item_path = joinpath(assets_path, item)
                if isdir(item_path)
                    folder_name = "assets/$(item)"
                    if !(folder_name in base_folders)
                        push!(base_folders, folder_name)
                    end
                end
            end
        catch e
            @debug "Error reading assets directory: $(e)"
        end
    end
    
    return base_folders
end

"""
    show_file_browser_dialog(title::String, initial_path::String="") -> String

Show a reusable file browser dialog. Returns selected path or empty string if cancelled.
"""
function show_file_browser_dialog(title::String, initial_path::String="")
    try
        # Use NativeFileDialog for a native file browser experience
        path = pick_folder(initial_path)
        return path !== nothing ? path : ""
    catch e
        @error "Error showing file browser dialog: $(e)"
        return ""
    end
end

"""
    check_filename_conflict() -> Bool

Check if the current filename would cause a conflict. Updates conflict_error if so.
"""
function check_filename_conflict()
    dialog = JulGame.EditorState["file_import_dialog"]
    
    # Clear previous error
    dialog.conflict_error = ""
    
    if strip(dialog.new_filename[]) == ""
        dialog.conflict_error = "Filename cannot be empty"
        return true
    end
    
    # Create destination directory path
    dest_dir = joinpath(JulGame.BasePath, dialog.destination_folder)
    dest_file = joinpath(dest_dir, dialog.new_filename[])
    
    if isfile(dest_file)
        dialog.conflict_error = "File already exists: $(dialog.new_filename[])"
        return true
    end
    
    return false
end

"""
    import_current_file() -> Bool

Import the current file to the selected destination. Returns true if successful.
"""
function import_current_file()
    dialog = JulGame.EditorState["file_import_dialog"]
    
    if dialog.current_file == "" || !isfile(dialog.current_file)
        dialog.conflict_error = "Invalid file path"
        return false
    end
    
    # Check for conflicts first
    if check_filename_conflict()
        return false
    end
    
    # Create destination directory if it doesn't exist
    dest_dir = joinpath(JulGame.BasePath, dialog.destination_folder)
    if !isdir(dest_dir)
        try
            mkpath(dest_dir)
        catch e
            dialog.conflict_error = "Failed to create destination directory: $(e)"
            return false
        end
    end
    
    # Copy the file
    dest_file = joinpath(dest_dir, dialog.new_filename[])
    try
        cp(dialog.current_file, dest_file)
        @info "File imported successfully: $(basename(dest_file)) to $(dialog.destination_folder)"
        
        # Add to scene if requested
        if dialog.add_to_scene
            # We need to get the current scene from the caller
            # For now, we'll store it in the dialog state
            current_scene_main = get(JulGame.EditorState, "current_scene_main", nothing)
            if current_scene_main !== nothing
                add_imported_file_to_scene(dest_file, current_scene_main)
            end
        end
        
        return true
    catch e
        dialog.conflict_error = "Failed to copy file: $(e)"
        return false
    end
end

"""
    add_imported_file_to_scene(file_path::String, current_scene_main)

Add the imported file to the current scene as an entity or UI element.
"""
function add_imported_file_to_scene(file_path::String, current_scene_main)
    dialog = JulGame.EditorState["file_import_dialog"]
    
    if current_scene_main === nothing
        @warn "No scene loaded - cannot add file to scene"
        return
    end
    
    # Get the relative path for the asset
    relative_path = relpath(file_path, JulGame.BasePath)
    entity_name = replace(splitext(basename(file_path))[1], " " => "_")
    
    try
        if dialog.is_image
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
            if dialog.create_as_ui_element
                # Create ScreenButton UI element
                screen_button = create_ui_screenbutton(relative_path, entity_name)
                push!(current_scene_main.scene.uiElements, screen_button)
                @info "Added ScreenButton UI element: $(entity_name)"
            else
                # Create entity with sprite
                entity = create_entity_with_sprite(relative_path, entity_name)
                push!(current_scene_main.scene.entities, entity)
                @info "Added entity with sprite: $(entity_name)"
            end
        elseif dialog.is_audio
            # Create entity with sound source
            if startswith(relative_path, "assets/")
                relative_path = replace(relative_path, "assets/" => "")
            end
            if startswith(relative_path, "assets\\")
                relative_path = replace(relative_path, "assets\\" => "")
            end
            if startswith(relative_path, "sounds/")
                relative_path = replace(relative_path, "sounds/" => "")
            end
            if startswith(relative_path, "sounds\\")
                relative_path = replace(relative_path, "sounds\\" => "")
            end
            entity = create_entity_with_sound(relative_path, entity_name)
            push!(current_scene_main.scene.entities, entity)
            @info "Added entity with sound source: $(entity_name)"
        end
    catch e
        @error "Failed to add file to scene: $(e)"
    end
end

"""
    advance_queue()

Move to the next file in the import queue.
"""
function advance_queue()
    JulGame.EditorState["import_queue_index"] += 1
end

"""
    cancel_current_import()

Cancel the current file import and move to the next file.
"""
function cancel_current_import()
    dialog = JulGame.EditorState["file_import_dialog"]
    
    # Clean up temporary file if it's from clipboard
    if is_temp_file(dialog.current_file)
        try
            if isfile(dialog.current_file)
                rm(dialog.current_file, force=true)
                @debug "Cleaned up cancelled clipboard file: $(dialog.current_file)"
            end
            # Remove from cleanup list
            filter!(f -> f != dialog.current_file, dialog.temp_files_to_cleanup)
        catch e
            @warn "Failed to clean up cancelled clipboard file: $(e)"
        end
    end
    
    cleanup_all_previews()
    advance_queue()
    dialog.is_open = false
end

"""
    create_entity_with_sprite(image_path::String, entity_name::String) -> Entity

Create a new entity with a sprite component using the imported image.
"""
function create_entity_with_sprite(image_path::String, entity_name::String)
    # Create new entity
    entity = JulGame.Entity(entity_name)
    
    # Add sprite component
    JulGame.add_sprite(entity, true)
    
    entity.sprite.imagePath = image_path
    entity.sprite.pixelsPerUnit = 0
    JulGame.Component.load_image(entity.sprite, image_path)
    
    return entity
end

"""
    create_ui_screenbutton(image_path::String, button_name::String) -> ScreenButton

Create a new ScreenButton UI element using the imported image.
"""
function create_ui_screenbutton(image_path::String, button_name::String)
    # Create ScreenButton with the imported image
    screenButton = JulGame.UI.ScreenButton(
        nothing; # No click event defined here by default
        name=button_name, 
        buttonUpSpritePath=image_path, 
        buttonDownSpritePath=image_path, # Use same image for both states
        size=JulGame.Math.Vector2(256, 64), 
        position=JulGame.Math.Vector2(0, 0), 
        fontPath=joinpath("FiraCode-Regular.ttf"),
    )
    
    if !screenButton.isInitialized
        JulGame.initialize(screenButton)
    end
    
    return screenButton
end

"""
    create_entity_with_sound(audio_path::String, entity_name::String) -> Entity

Create a new entity with a SoundSource component using the imported audio.
"""
function create_entity_with_sound(audio_path::String, entity_name::String)
    # Create new entity
    entity = JulGame.Entity(entity_name)
    
    # Add SoundSource component
    JulGame.add_sound_source(entity)
    
    entity.soundSource.path = audio_path
    JulGame.Component.load_sound(entity.soundSource, audio_path, false) # false = not music
    
    return entity
end

"""
    cleanup_temp_files()

Clean up temporary files created from clipboard paste.
"""
function cleanup_temp_files()
    dialog = JulGame.EditorState["file_import_dialog"]
    for temp_file in dialog.temp_files_to_cleanup
        try
            if isfile(temp_file)
                rm(temp_file, force=true)
                @debug "Cleaned up temporary file: $(temp_file)"
            end
            # Also try to remove the parent temp directory if it's empty
            temp_dir = dirname(temp_file)
            if isdir(temp_dir) && isempty(readdir(temp_dir))
                rm(temp_dir, force=true)
                @debug "Cleaned up temporary directory: $(temp_dir)"
            end
        catch e
            @warn "Failed to clean up temporary file $(temp_file): $(e)"
        end
    end
    empty!(dialog.temp_files_to_cleanup)
end

"""
    cleanup_import_queue()

Clean up the import queue when all files are processed.
"""
function cleanup_import_queue()
    # Clean up any remaining previews
    cleanup_all_previews()
    
    # Clean up temporary files
    cleanup_temp_files()
    
    # Clear the dropped files and reset queue
    JulGame.EditorState["dropped_files"] = nothing
    JulGame.EditorState["import_queue_index"] = 1
    
    dialog = JulGame.EditorState["file_import_dialog"]
    dialog.is_open = false
    dialog.current_file = ""
    dialog.new_filename[] = ""
    dialog.conflict_error = ""
    dialog.add_to_scene = false
    dialog.create_as_ui_element = false
end

"""
    show_file_import_dialog(renderer, current_scene_main=nothing) -> Bool

Show the file import dialog. Returns true if dialog is still active.
"""
function show_file_import_dialog(renderer, current_scene_main=nothing)
    # Initialize if needed
    initialize_import_dialog()
    dropped_files = get(JulGame.EditorState, "dropped_files", nothing)
    if dropped_files === nothing || isempty(dropped_files)
        @info "No dropped files found, returning false"
        return false
    end
    dialog = JulGame.EditorState["file_import_dialog"]
    # Set up the first/next file if dialog is not open
    if !dialog.is_open
        if !setup_next_file(renderer)
            cleanup_import_queue()
            return false
        end
    end
    # Show the modal dialog (blocking)
    CImGui.OpenPopup("Import File")
  
    if CImGui.BeginPopupModal("Import File", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        # File info section
        CImGui.Text("Importing file:")
        CImGui.SameLine()
        CImGui.TextColored((0.7, 0.9, 1.0, 1.0), basename(dialog.current_file))
        
        # Show special indicator for clipboard files
        if is_temp_file(dialog.current_file)
            CImGui.SameLine()
            CImGui.TextColored((0.3, 1.0, 0.3, 1.0), "(from clipboard)")
        end
        
        CImGui.Text("From:")
        CImGui.SameLine()
        if is_temp_file(dialog.current_file)
            CImGui.TextColored((0.8, 0.8, 0.8, 1.0), "Clipboard → Temporary file")
        else
            CImGui.TextColored((0.8, 0.8, 0.8, 1.0), dirname(dialog.current_file))
        end
        
        # File type indicator
        if dialog.is_image
            CImGui.Text("Type:")
            CImGui.SameLine()
            CImGui.TextColored((0.3, 0.8, 0.3, 1.0), "Image")
        elseif dialog.is_audio
            CImGui.Text("Type:")
            CImGui.SameLine()
            CImGui.TextColored((0.8, 0.3, 0.8, 1.0), "Audio")
        end
        
        CImGui.Separator()
        
        # Image preview section
        if dialog.is_image && dialog.preview_texture != C_NULL
            CImGui.Text("Preview:")
            
            # Center the image
            window_width = CImGui.GetWindowWidth()
            image_width = dialog.preview_size.x
            CImGui.SetCursorPosX((window_width - image_width) * 0.5)
            
            # Draw the image with a border
            cursor_pos = CImGui.GetCursorScreenPos()
            draw_list = CImGui.GetWindowDrawList()
            
            # Add border
            border_color = IM_COL32(100, 100, 100, 255)
            CImGui.AddRect(draw_list, 
                         ImVec2(cursor_pos.x - 2, cursor_pos.y - 2),
                         ImVec2(cursor_pos.x + dialog.preview_size.x + 2, cursor_pos.y + dialog.preview_size.y + 2),
                         border_color)
            
            # Add the image
            CImGui.Image(dialog.preview_texture, dialog.preview_size)
            CImGui.Separator()
        end
        
        # Audio preview section
        if dialog.is_audio && dialog.audio_preview != C_NULL
            CImGui.Text("Audio Preview:")
            
            # Center the audio controls
            window_width = CImGui.GetWindowWidth()
            button_width = 80.0
            CImGui.SetCursorPosX((window_width - button_width) * 0.5)
            
            if !dialog.is_audio_playing
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
                
                if CImGui.Button("Play", ImVec2(button_width, 0))
                    # Play the audio preview
                    channel = SDL2.Mix_PlayChannel(-1, dialog.audio_preview, 0)
                    if channel != -1
                        dialog.is_audio_playing = true
                    end
                end
                
                CImGui.PopStyleColor(3)
            else
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.7, 0.2, 0.2, 1.0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.8, 0.3, 0.3, 1.0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.9, 0.4, 0.4, 1.0))
                
                if CImGui.Button("⏸ Stop", ImVec2(button_width, 0))
                    # Stop the audio preview
                    SDL2.Mix_HaltChannel(-1)
                    dialog.is_audio_playing = false
                end
                
                CImGui.PopStyleColor(3)
            end
            
            # Check if audio finished playing
            if dialog.is_audio_playing && SDL2.Mix_Playing(-1) == 0
                dialog.is_audio_playing = false
            end
            
            CImGui.Separator()
        end
        
        # Destination folder selection
        CImGui.Text("Destination folder:")
        folders = get_project_folders()
        current_folder_index = findfirst(x -> x == dialog.destination_folder, folders)
        if current_folder_index === nothing
            current_folder_index = 1
            dialog.destination_folder = folders[1]
        end
        
        folder_names = [folder for folder in folders]
        selected_index = Ref(Int32(current_folder_index - 1))  # ImGui uses 0-based indexing and expects Int32
        
        CImGui.SetNextItemWidth(250)
        if CImGui.Combo("##destination", selected_index, folder_names, length(folder_names))
            dialog.destination_folder = folders[selected_index[] + 1]
            # Clear conflict error when destination changes
            dialog.conflict_error = ""
        end
        
        CImGui.SameLine()
        if CImGui.Button("Browse...")
            selected_path = show_file_browser_dialog("Select Destination Folder", JulGame.BasePath)
            if selected_path != ""
                # Convert to relative path if possible
                if startswith(selected_path, JulGame.BasePath)
                    dialog.destination_folder = relpath(selected_path, JulGame.BasePath)
                else
                    dialog.destination_folder = selected_path
                end
                # Clear conflict error when destination changes
                dialog.conflict_error = ""
            end
        end
        
        # File name input
        CImGui.Text("File name:")
        CImGui.SetNextItemWidth(300)
        
        # Create a proper buffer for InputText
        buf = "$(dialog.new_filename[])" * "\0"^256
        if CImGui.InputText("##filename", buf, length(buf))
            # Extract the string up to the first null character
            current_text = ""
            for character_index in eachindex(buf)
                if Int32(buf[character_index]) == 0 
                    if character_index != 1
                        current_text = String(SubString(buf, 1, character_index-1))
                    end
                    break
                end
            end
            dialog.new_filename[] = current_text
            # Clear conflict error when filename changes
            dialog.conflict_error = ""
        end
        
        # Show conflict error if any
        if dialog.conflict_error != ""
            CImGui.TextColored((1.0, 0.3, 0.3, 1.0), "Error: $(dialog.conflict_error)")
        end
        
        # Add to Scene options
        CImGui.Separator()
        CImGui.Text("Scene Options:")
        
        # Check if a scene is loaded
        if current_scene_main === nothing
            CImGui.TextColored((0.8, 0.6, 0.0, 1.0), "No scene loaded - cannot add to scene")
            CImGui.Checkbox("Add to Scene", Ref(false))  # Disabled checkbox
        else
            if CImGui.Checkbox("Add to Scene", Ref(dialog.add_to_scene))
                dialog.add_to_scene = !dialog.add_to_scene
            end
            
            if dialog.add_to_scene
                CImGui.Indent()
                
                if dialog.is_image
                    CImGui.Text("Create as:")
                    CImGui.SameLine()
                    if CImGui.RadioButton("Entity (Sprite)", !dialog.create_as_ui_element)
                        dialog.create_as_ui_element = false
                    end
                    CImGui.SameLine()
                    if CImGui.RadioButton("UI Element (Button)", dialog.create_as_ui_element)
                        dialog.create_as_ui_element = true
                    end
                elseif dialog.is_audio
                    CImGui.TextColored((0.7, 0.9, 1.0, 1.0), "Will create entity with SoundSource component")
                end
                
                CImGui.Unindent()
            end
        end
        
        # Queue info
        queue_index = JulGame.EditorState["import_queue_index"]
        total_files = length(dropped_files)
        CImGui.Text("File $(queue_index) of $(total_files)")
        
        CImGui.Separator()
        
        # Buttons
        # Check for conflicts before enabling import button
        has_conflict = check_filename_conflict()
        
        if has_conflict
            # Disabled button style for conflicts
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_Alpha, unsafe_load(CImGui.GetStyle().Alpha) * 0.5)
            CImGui.Button("Import", ImVec2(100, 0))  # Disabled button
            CImGui.PopStyleVar()
        else
            # Normal import button
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
            
            if CImGui.Button("Import", ImVec2(100, 0))
                if import_current_file()
                    # Remove current file from queue
                    deleteat!(dropped_files, queue_index)
                    
                    # Check if there are more files
                    if queue_index <= length(dropped_files)
                        # More files to process, set up next file
                        dialog.is_open = false  # This will trigger setup_next_file on next call
                    else
                        # No more files, cleanup
                        cleanup_import_queue()
                        CImGui.CloseCurrentPopup()
                        CImGui.PopStyleColor(3)
                        CImGui.EndPopup()
                        return false
                    end
                end
            end
            
            CImGui.PopStyleColor(3)
        end
        
        CImGui.SameLine()
        
        if CImGui.Button("Skip", ImVec2(100, 0))
            # Clean up temporary file if it's from clipboard
            if is_temp_file(dialog.current_file)
                try
                    if isfile(dialog.current_file)
                        rm(dialog.current_file, force=true)
                        @debug "Cleaned up skipped clipboard file: $(dialog.current_file)"
                    end
                    # Remove from cleanup list
                    filter!(f -> f != dialog.current_file, dialog.temp_files_to_cleanup)
                catch e
                    @warn "Failed to clean up skipped clipboard file: $(e)"
                end
            end
            
            # Remove current file from queue without importing
            deleteat!(dropped_files, queue_index)
            
            # Check if there are more files
            if queue_index <= length(dropped_files)
                # More files to process, set up next file
                dialog.is_open = false  # This will trigger setup_next_file on next call
            else
                # No more files, cleanup
                cleanup_import_queue()
                CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
                return false
            end
        end
        
        CImGui.SameLine()
        
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.7, 0.2, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.8, 0.3, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.9, 0.4, 0.4, 1.0))
        
        if CImGui.Button("Cancel All", ImVec2(100, 0))
            cleanup_import_queue()
            CImGui.CloseCurrentPopup()
            CImGui.PopStyleColor(3)
            CImGui.EndPopup()
            return false
        end
        
        CImGui.PopStyleColor(3)
        
        CImGui.EndPopup()
        return true
    end
    
    return false
end

"""
    handle_dropped_files(renderer, current_scene_main=nothing)

Main function to call from the editor loop to handle dropped files.
This should be called where the current file drop handling is done.
"""
function handle_dropped_files(renderer, current_scene_main=nothing)
    dropped_files = get(JulGame.EditorState, "dropped_files", nothing)
    if dropped_files !== nothing && !isempty(dropped_files)
        # Store current scene in EditorState for access during import
        if current_scene_main !== nothing
            JulGame.EditorState["current_scene_main"] = current_scene_main
        end
        return show_file_import_dialog(renderer, current_scene_main)
    end
    return false
end
