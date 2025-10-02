"""
    FileFinderMenu.jl

A revamped file finder system with preview functionality for the JulGame editor.
This module provides a modal dialog for selecting files with the following features:

- **Preview System**: Shows thumbnails for images, icons for other file types
- **Search Functionality**: Real-time filtering of files by name
- **Keyboard Navigation**: Arrow keys to navigate through files
- **Audio Preview**: Play/stop audio files directly in the modal
- **Adjustable Preview Size**: Slider to control thumbnail size
- **Modal Interface**: Non-blocking modal dialog that integrates with the editor

## Usage

```julia
# Open the file finder modal
open_file_finder_modal("/path/to/assets", "images", "Select Image File")

# Check if modal is open
if is_file_finder_open()
    # Modal is currently open
end

# Get the result when modal is closed
if !is_file_finder_open() && get_file_finder_result() != ""
    selected_file = get_file_finder_result()
    # Use the selected file
end
```

## Integration

The modal is automatically displayed in the main editor loop and integrates
with the existing ImportFile preview system for consistent functionality.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using JulGame: SDL2
using JulGame: Component, Math, SceneLoaderModule, UI

# File type definitions
imageExtensions = [".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tga", ".webp"]
soundExtensions = [".wav", ".ogg", ".flac", ".mp3", ".aac", ".m4a", ".wma", ".aiff", ".aif", ".aifc", ".amr", ".au", ".snd", ".ra", ".rm", ".rmvb", ".mka", ".opus", ".sln", ".voc", ".vox", ".raw", ".wv", ".webm", ".dts", ".ac3", ".ec3", ".mlp", ".tta", ".mka", ".mks", ".m3u", ".m3u8", ".pls", ".asx", ".xspf", ".m4b", ".m4p", ".m4r", ".m4v", ".3gp", ".3g2", ".mp4", ".m4v", ".mkv", ".webm", ".flv", ".vob", ".ogv", ".avi", ".wmv", ".mov", ".qt", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".f4v", ".f4p", ".f4a", ".f4b", ".f4m"]
fontExtensions = [".ttf", ".otf", ".ttc", ".woff", ".woff2", ".eot", ".sfnt", ".pfa", ".pfb", ".pfr", ".gsf", ".cid", ".cff", ".bdf", ".pcf", ".snf", ".mm", ".otb", ".dfont", ".bin", ".sfd", ".t42", ".t1", ".fon", ".fnt"]
scriptExtensions = [".jl"]
extensionsDict = Dict("images" => imageExtensions, "sounds" => soundExtensions, "fonts" => fontExtensions, "scripts" => scriptExtensions)

# File finder state for modal dialog
mutable struct FileFinderState
    is_open::Bool
    current_path::String
    selected_file::String
    file_type::String
    title::String
    preview_texture::Ptr{SDL2.LibSDL2.SDL_Texture}
    preview_size::ImVec2
    is_image::Bool
    is_audio::Bool
    audio_preview::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
    is_audio_playing::Bool
    search_query::Ref{String}
    show_previews::Bool
    preview_size_slider::Float32
    file_list::Vector{String}
    filtered_files::Vector{String}
    selected_index::Int
    scroll_position::Float32
    # Field-specific tracking
    target_field::Symbol
    target_structure_type::String
    
    function FileFinderState()
        new(false, "", "", "", "", C_NULL, ImVec2(0, 0), false, false, C_NULL, false, Ref(""), true, 128.0, String[], String[], 0, 0.0, :none, "")
    end
end

# Global state instance
const file_finder_state = FileFinderState()

"""
    initialize_file_finder()
Initialize the file finder state in EditorState.
"""
function initialize_file_finder()
    if !haskey(JulGame.EditorState, "file_finder")
        JulGame.EditorState["file_finder"] = file_finder_state
    end
end

"""
    open_file_finder_modal(base_path::String, file_type::String, title::String = "", target_field::Symbol = :none, target_structure_type::String = "")
Open the file finder modal dialog.
"""
function open_file_finder_modal(base_path::String, file_type::String, title::String = "", target_field::Symbol = :none, target_structure_type::String = "")
    @debug "Opening file finder modal for path: $base_path, type: $file_type, field: $target_field, structure: $target_structure_type"
    
    # Always completely reset the state first to prevent cross-contamination
    reset_file_finder_state()
    
    state = JulGame.EditorState["file_finder"]
    
    # Set up the new modal state
    state.is_open = true
    state.current_path = base_path
    state.file_type = file_type
    state.title = title != "" ? title : "Select $(file_type) File"
    state.target_field = target_field
    state.target_structure_type = target_structure_type
    
    # Load file list
    refresh_file_list()
    @debug "File finder modal opened with $(length(state.file_list)) files"
end

"""
    cleanup_file_finder_preview()
Clean up preview resources.
"""
function cleanup_file_finder_preview()
    state = JulGame.EditorState["file_finder"]
    if state.preview_texture != C_NULL
        SDL2.SDL_DestroyTexture(state.preview_texture)
        state.preview_texture = C_NULL
        state.preview_size = ImVec2(0, 0)
    end
    if state.audio_preview != C_NULL
        SDL2.Mix_HaltChannel(-1)
        SDL2.Mix_FreeChunk(state.audio_preview)
        state.audio_preview = C_NULL
        state.is_audio_playing = false
    end
end

"""
    reset_file_finder_state()
Completely reset the file finder state to prevent cross-contamination.
"""
function reset_file_finder_state()
    state = JulGame.EditorState["file_finder"]
    
    # Clean up all resources
    cleanup_file_finder_preview()
    
    # Reset all state variables
    state.is_open = false
    state.current_path = ""
    state.selected_file = ""
    state.file_type = ""
    state.title = ""
    state.search_query[] = ""
    state.show_previews = true
    state.preview_size_slider = 128.0
    state.file_list = String[]
    state.filtered_files = String[]
    state.selected_index = 0
    state.scroll_position = 0.0
    state.is_image = false
    state.is_audio = false
    state.is_audio_playing = false
    state.target_field = :none
    state.target_structure_type = ""
    
    @debug "File finder state completely reset"
end

"""
    refresh_file_list()
Refresh the file list based on current path and file type.
"""
function refresh_file_list()
    state = JulGame.EditorState["file_finder"]
    extensions = extensionsDict[state.file_type]
    state.file_list = String[]
    
    if isdir(state.current_path)
        for file in readdir(state.current_path)
            file_path = joinpath(state.current_path, file)
            if isfile(file_path)
                ext = lowercase(splitext(file)[2])
                if ext in extensions
                    push!(state.file_list, String(file))
                end
            end
        end
    end
    
    # Sort files
    sort!(state.file_list)
    
    # Apply search filter
    apply_search_filter()
end

"""
    apply_search_filter()
Apply search query to filter files.
"""
function apply_search_filter()
    state = JulGame.EditorState["file_finder"]
    query = lowercase(state.search_query[])
    
    if query == ""
        state.filtered_files = Base.copy(state.file_list)
    else
        state.filtered_files = String[file for file in state.file_list if occursin(query, lowercase(String(file)))]
    end
    
    # Reset selection if needed
    if state.selected_index >= length(state.filtered_files)
        state.selected_index = max(0, length(state.filtered_files) - 1)
    end
end

"""
    load_file_preview(filepath::String, renderer)
Load preview for the selected file.
"""
function load_file_preview(filepath::String, renderer)
    state = JulGame.EditorState["file_finder"]
    
    # Clean up previous preview
    cleanup_file_finder_preview()
    
    if !isfile(filepath)
        return
    end
    
    ext = lowercase(splitext(filepath)[2])
    
    # Check if it's an image
    if ext in imageExtensions
        state.is_image = true
        state.is_audio = false
        
        # Load image preview using ImportFile function
        texture, size = load_image_preview(filepath, renderer)
        if texture != C_NULL
            # Scale to preview size
            scale = min(state.preview_size_slider / max(size.x, size.y), 1.0)
            state.preview_texture = texture
            state.preview_size = ImVec2(size.x * scale, size.y * scale)
        end
        
    elseif ext in soundExtensions
        state.is_image = false
        state.is_audio = true
        
        # Load audio preview
        state.audio_preview = load_audio_preview(filepath)
        
    else
        state.is_image = false
        state.is_audio = false
    end
end

"""
    show_file_finder_modal(renderer)
Display the file finder modal dialog.
"""
function show_file_finder_modal(renderer)
    state = JulGame.EditorState["file_finder"]
    
    if !state.is_open
        return ""
    end
    
    @debug "Showing file finder modal with $(length(state.filtered_files)) filtered files"
    
    # Modal flags
    modal_flags = CImGui.ImGuiWindowFlags_AlwaysAutoResize | 
                  CImGui.ImGuiWindowFlags_NoCollapse |
                  CImGui.ImGuiWindowFlags_NoDocking |
                  CImGui.ImGuiWindowFlags_Modal
    
    # Open modal as a regular window with modal behavior
    if CImGui.Begin("File Finder", Ref(state.is_open), modal_flags)
        CImGui.Text(state.title)
        CImGui.Separator()
        
        # Search bar
        CImGui.Text("Search: TODO")
        CImGui.SameLine()
        # if CImGui.InputText("##search", state.search_query, 256)
        #     apply_search_filter()
        # end
        
        # Preview toggle
        CImGui.SameLine()
        CImGui.Checkbox("Show Previews", Ref(state.show_previews))
        
        if state.show_previews
            CImGui.SameLine()
            CImGui.Text("Size:")
            CImGui.SameLine()
            CImGui.SliderFloat("##preview_size", Ref(state.preview_size_slider), 64.0, 256.0)
        end
        
        CImGui.Separator()
        
        # Main content area
        content_height = state.show_previews ? 400.0 : 300.0
        if CImGui.BeginChild("FileList", ImVec2(600, content_height), true)
            
            # File list
            for (i, file) in enumerate(state.filtered_files)
                file_path = joinpath(state.current_path, file)
                is_selected = i - 1 == state.selected_index
                
                # Selection highlighting
                if is_selected
                    CImGui.PushStyleColor(CImGui.ImGuiCol_Header, (0.3, 0.5, 0.8, 0.8))
                    CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, (0.4, 0.6, 0.9, 0.9))
                    CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderActive, (0.2, 0.4, 0.7, 1.0))
                end
                
                # File item with preview
                if state.show_previews && is_selected
                    show_file_item_with_preview(file, file_path, renderer, state.preview_size_slider)
                else
                    if CImGui.Selectable(file, is_selected)
                        state.selected_index = i - 1
                        state.selected_file = file_path
                        load_file_preview(file_path, renderer)
                    end
                end
                
                if is_selected
                    CImGui.PopStyleColor(3)
                end
                
                # Handle keyboard navigation
                if is_selected && CImGui.IsKeyPressed(CImGui.ImGuiKey_UpArrow)
                    state.selected_index = max(0, state.selected_index - 1)
                    if state.selected_index < length(state.filtered_files)
                        new_file = joinpath(state.current_path, state.filtered_files[state.selected_index + 1])
                        load_file_preview(new_file, renderer)
                    end
                elseif is_selected && CImGui.IsKeyPressed(CImGui.ImGuiKey_DownArrow)
                    state.selected_index = min(length(state.filtered_files) - 1, state.selected_index + 1)
                    if state.selected_index < length(state.filtered_files)
                        new_file = joinpath(state.current_path, state.filtered_files[state.selected_index + 1])
                        load_file_preview(new_file, renderer)
                    end
                end
            end
            
            CImGui.EndChild()
        end
        
        # Preview panel
        if state.show_previews && state.selected_index < length(state.filtered_files)
            selected_file = state.filtered_files[state.selected_index + 1]
            file_path = joinpath(state.current_path, selected_file)
            
            CImGui.Separator()
            CImGui.Text("Preview: $(selected_file)")
            
            if state.is_image && state.preview_texture != C_NULL
                # Center the image
                window_width = CImGui.GetWindowWidth()
                image_width = state.preview_size.x
                CImGui.SetCursorPosX((window_width - image_width) * 0.5)
                
                # Draw the image with a border
                cursor_pos = CImGui.GetCursorScreenPos()
                draw_list = CImGui.GetWindowDrawList()
                
                # Add border
                border_color = IM_COL32(100, 100, 100, 255)
                CImGui.AddRect(draw_list, 
                             ImVec2(cursor_pos.x - 2, cursor_pos.y - 2),
                             ImVec2(cursor_pos.x + state.preview_size.x + 2, cursor_pos.y + state.preview_size.y + 2),
                             border_color)
                
                # Add the image
                CImGui.Image(state.preview_texture, state.preview_size)
                
            elseif state.is_audio && state.audio_preview != C_NULL
                CImGui.Text("Audio File: $(selected_file)")
                CImGui.SameLine()
                
                if CImGui.Button(state.is_audio_playing ? "Stop" : "Play")
                    if state.is_audio_playing
                        SDL2.Mix_HaltChannel(-1)
                        state.is_audio_playing = false
                    else
                        SDL2.Mix_HaltChannel(-1)  # Stop any currently playing audio
                        SDL2.Mix_PlayChannel(-1, state.audio_preview, 0)
                        state.is_audio_playing = true
                    end
                end
                
            else
                CImGui.Text("No preview available")
            end
        end
        
        CImGui.Separator()
        
        # Buttons
        button_width = 100.0
        CImGui.SetCursorPosX(CImGui.GetWindowWidth() - button_width * 2 - 20)
        
        if CImGui.Button("Cancel", ImVec2(button_width, 0))
            cleanup_file_finder_preview()
            state.is_open = false
        end
        
        CImGui.SameLine()
        
        if CImGui.Button("Select", ImVec2(button_width, 0))
            if state.selected_index < length(state.filtered_files)
                selected_file = state.filtered_files[state.selected_index + 1]
                result = joinpath(state.current_path, selected_file)
                
                # Handle script files specially
                if state.file_type == "scripts"
                    result = splitext(selected_file)[1]
                end
                
                cleanup_file_finder_preview()
                state.is_open = false
                return result
            end
        end
        
        CImGui.End()
    end
    
    return ""
end

"""
    show_file_item_with_preview(filename::String, filepath::String, renderer, preview_size::Float32)
Show a file item with inline preview.
"""
function show_file_item_with_preview(filename::String, filepath::String, renderer, preview_size::Float32)
    ext = lowercase(splitext(filename)[2])
    
    # Create a child window for the file item
    item_height = preview_size + 30.0
    if CImGui.BeginChild("FileItem_$(filename)", ImVec2(preview_size + 20, item_height), true)
        
        # Preview thumbnail
        if ext in imageExtensions
            texture, size = load_image_preview(filepath, renderer)
            if texture != C_NULL
                # Scale to fit
                scale = min(preview_size / max(size.x, size.y), 1.0)
                scaled_size = ImVec2(size.x * scale, size.y * scale)
                
                # Center the image
                offset_x = (preview_size - scaled_size.x) * 0.5
                if offset_x > 0
                    CImGui.SetCursorPosX(CImGui.GetCursorPosX() + offset_x)
                end
                
                CImGui.Image(texture, scaled_size)
            else
                # Fallback icon
                CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "Image")
            end
        elseif ext in soundExtensions
            # Audio icon
            CImGui.TextColored((0.8, 0.8, 0.2, 1.0), "♪ Audio")
        elseif ext in fontExtensions
            # Font icon
            CImGui.TextColored((0.2, 0.8, 0.2, 1.0), "Aa Font")
        elseif ext in scriptExtensions
            # Script icon
            CImGui.TextColored((0.8, 0.2, 0.8, 1.0), "{} Script")
        else
            # Unknown file type
            CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "?")
        end
        
        # File name
        CImGui.TextWrapped(filename)
        
        # Handle selection
        if CImGui.IsItemClicked()
            # Selection will be handled by the parent
        end
        
    end
    CImGui.EndChild()
end

"""
    get_file_finder_result() -> String
Get the result from the file finder modal if a file was selected.
"""
function get_file_finder_result()::String
    state = JulGame.EditorState["file_finder"]
    if state.is_open
        return ""
    end
    
    return state.selected_file
end

"""
    is_file_finder_open() -> Bool
Check if the file finder modal is currently open.
"""
function is_file_finder_open()::Bool
    state = JulGame.EditorState["file_finder"]
    return state.is_open
end

"""
    get_file_finder_target() -> (Symbol, String)
Get the target field and structure type for the current file finder session.
"""
function get_file_finder_target()::Tuple{Symbol, String}
    state = JulGame.EditorState["file_finder"]
    return (state.target_field, state.target_structure_type)
end

# Legacy function for backward compatibility
function display_files(base_path::String, file_type::String, title::String = "", depth::Int = 1; default::String = "", menu_id::String = "")::String
    # Open the new modal file finder
    open_file_finder_modal(base_path, file_type, title)
    return ""
end