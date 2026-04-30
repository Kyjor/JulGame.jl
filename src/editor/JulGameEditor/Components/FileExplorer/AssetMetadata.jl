"""
    AssetMetadata

Asset metadata and tagging system for the file explorer.
Provides comprehensive metadata extraction, tagging, dependency tracking,
and asset management features while maintaining performance through caching.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using Dates
using JSON3

include("FileExplorer.jl")

"""
    Asset metadata structures
"""

mutable struct AssetMetadata
    # Basic file information
    file_path::String
    file_type::Symbol
    file_size::Int64
    created_time::DateTime
    modified_time::DateTime
    
    # Type-specific metadata
    image_metadata::Union{Nothing, Dict{String, Any}}
    audio_metadata::Union{Nothing, Dict{String, Any}}
    script_metadata::Union{Nothing, Dict{String, Any}}
    
    # User-defined data
    tags::Set{String}
    description::String
    custom_properties::Dict{String, Any}
    
    # Usage tracking
    used_in_scenes::Set{String}
    reference_count::Int
    last_accessed::DateTime
    
    # Cache control
    metadata_version::Int
    needs_refresh::Bool
    
    function AssetMetadata(file_path::String)
        new(
            file_path, get_file_type(file_path), 0, now(), now(),
            nothing, nothing, nothing,
            Set{String}(), "", Dict{String, Any}(),
            Set{String}(), 0, now(),
            1, true
        )
    end
end

"""
    Metadata extraction functions
"""

function extract_image_metadata(filepath::String)::Dict{String, Any}
    metadata = Dict{String, Any}()
    
    try
        if !isfile(filepath) || !is_image_file(filepath)
            return metadata
        end
        
        # Basic file info
        stat_info = stat(filepath)
        metadata["file_size"] = stat_info.size
        metadata["format"] = uppercase(splitext(filepath)[2][2:end])
        
        # Try to get image dimensions using SDL2 (following ImportFile patterns)
        try
            surface = SDL2.IMG_Load(filepath)
            if surface != C_NULL
                surface_ref = unsafe_load(surface)
                metadata["width"] = surface_ref.w
                metadata["height"] = surface_ref.h
                metadata["aspect_ratio"] = round(surface_ref.w / surface_ref.h, digits=3)
                
                # Calculate megapixels
                total_pixels = surface_ref.w * surface_ref.h
                metadata["megapixels"] = round(total_pixels / 1_000_000, digits=2)
                
                SDL2.SDL_FreeSurface(surface)
            end
        catch e
            @debug "Failed to extract image dimensions: $e"
        end
        
        # Estimated memory usage (uncompressed)
        if haskey(metadata, "width") && haskey(metadata, "height")
            # Assume 4 bytes per pixel (RGBA)
            memory_usage = metadata["width"] * metadata["height"] * 4
            metadata["memory_usage_mb"] = round(memory_usage / (1024 * 1024), digits=2)
        end
        
    catch e
        @error "Error extracting image metadata for $filepath: $e"
    end
    
    return metadata
end

function extract_audio_metadata(filepath::String)::Dict{String, Any}
    metadata = Dict{String, Any}()
    
    try
        if !isfile(filepath) || !is_audio_file(filepath)
            return metadata
        end
        
        # Basic file info
        stat_info = stat(filepath)
        metadata["file_size"] = stat_info.size
        metadata["format"] = uppercase(splitext(filepath)[2][2:end])
        
        # Try to get audio info using SDL2_mixer (simplified)
        try
            chunk = SDL2.Mix_LoadWAV(filepath)
            if chunk != C_NULL
                # Basic audio properties (SDL2_mixer provides limited info)
                metadata["loaded_successfully"] = true
                
                # Estimate duration based on file size and format (very rough)
                if metadata["format"] in ["WAV", "OGG"]
                    # Rough estimation - actual implementation would need audio library
                    estimated_duration = stat_info.size / (44100 * 2 * 2)  # 44.1kHz, stereo, 16-bit
                    metadata["estimated_duration_seconds"] = round(estimated_duration, digits=1)
                end
                
                SDL2.Mix_FreeChunk(chunk)
            end
        catch e
            @debug "Failed to extract audio metadata: $e"
        end
        
    catch e
        @error "Error extracting audio metadata for $filepath: $e"
    end
    
    return metadata
end

function extract_script_metadata(filepath::String)::Dict{String, Any}
    metadata = Dict{String, Any}()
    
    try
        if !isfile(filepath) || !is_script_file(filepath)
            return metadata
        end
        
        # Basic file info
        stat_info = stat(filepath)
        metadata["file_size"] = stat_info.size
        metadata["format"] = uppercase(splitext(filepath)[2][2:end])
        
        # Read and analyze script content
        content = read(filepath, String)
        lines = split(content, '\n')
        
        metadata["line_count"] = length(lines)
        metadata["character_count"] = length(content)
        metadata["non_empty_lines"] = count(line -> !isempty(strip(line)), lines)
        
        # Julia-specific analysis
        if metadata["format"] == "JL"
            function_count = count(line -> occursin(r"^\s*function\s+", line), lines)
            struct_count = count(line -> occursin(r"^\s*struct\s+", line), lines)
            module_count = count(line -> occursin(r"^\s*module\s+", line), lines)
            
            metadata["function_count"] = function_count
            metadata["struct_count"] = struct_count
            metadata["module_count"] = module_count
            
            # Extract function names
            function_names = String[]
            for line in lines
                match_result = match(r"^\s*function\s+([a-zA-Z_][a-zA-Z0-9_!]*)", line)
                if match_result !== nothing
                    push!(function_names, match_result.captures[1])
                end
            end
            metadata["function_names"] = function_names
        end
        
    catch e
        @error "Error extracting script metadata for $filepath: $e"
    end
    
    return metadata
end

"""
    Metadata management functions
"""

function get_or_create_metadata(filepath::String)::AssetMetadata
    explorer = JulGame.EditorState["file_explorer"]
    
    # Check if metadata exists and is current
    if haskey(explorer.asset_metadata, filepath)
        metadata = explorer.asset_metadata[filepath]
        
        # Check if file was modified since last metadata extraction
        if isfile(filepath)
            current_mtime = stat(filepath).mtime
            if current_mtime <= metadata.modified_time && !metadata.needs_refresh
                return metadata
            end
        end
    end
    
    # Create or refresh metadata
    metadata = AssetMetadata(filepath)
    refresh_metadata!(metadata)
    explorer.asset_metadata[filepath] = metadata
    
    return metadata
end

function refresh_metadata!(metadata::AssetMetadata)
    if !isfile(metadata.file_path)
        return
    end
    
    try
        # Update basic file information
        stat_info = stat(metadata.file_path)
        metadata.file_size = stat_info.size
        metadata.modified_time = unix2datetime(stat_info.mtime)
        metadata.file_type = get_file_type(metadata.file_path)
        
        # Extract type-specific metadata
        if metadata.file_type == :image
            metadata.image_metadata = extract_image_metadata(metadata.file_path)
        elseif metadata.file_type == :audio
            metadata.audio_metadata = extract_audio_metadata(metadata.file_path)
        elseif metadata.file_type == :script
            metadata.script_metadata = extract_script_metadata(metadata.file_path)
        end
        
        # Update cache control
        metadata.metadata_version += 1
        metadata.needs_refresh = false
        
    catch e
        @error "Error refreshing metadata for $(metadata.file_path): $e"
    end
end

"""
    Tagging system
"""

function add_tag_to_asset(filepath::String, tag::String)
    if isempty(strip(tag))
        return
    end
    
    explorer = JulGame.EditorState["file_explorer"]
    metadata = get_or_create_metadata(filepath)
    
    # Add tag to asset
    push!(metadata.tags, strip(lowercase(tag)))
    
    # Add to global tag suggestions
    push!(explorer.tag_suggestions, strip(lowercase(tag)))
    
    save_metadata_to_disk(metadata)
end

function remove_tag_from_asset(filepath::String, tag::String)
    explorer = JulGame.EditorState["file_explorer"]
    
    if haskey(explorer.asset_metadata, filepath)
        metadata = explorer.asset_metadata[filepath]
        delete!(metadata.tags, lowercase(tag))
        save_metadata_to_disk(metadata)
    end
end

function get_assets_with_tag(tag::String)::Vector{String}
    explorer = JulGame.EditorState["file_explorer"]
    tagged_assets = String[]
    
    for (filepath, metadata) in explorer.asset_metadata
        if lowercase(tag) in metadata.tags
            push!(tagged_assets, filepath)
        end
    end
    
    return tagged_assets
end

function get_all_tags()::Vector{String}
    explorer = JulGame.EditorState["file_explorer"]
    all_tags = Set{String}()
    
    for (filepath, metadata) in explorer.asset_metadata
        union!(all_tags, metadata.tags)
    end
    
    return sort(collect(all_tags))
end

"""
    Dependency tracking
"""

function scan_scene_dependencies(scene_path::String)
    if !isfile(scene_path)
        return
    end
    
    try
        # Read scene file (assuming JSON format)
        scene_content = read(scene_path, String)
        
        # Extract asset references (simplified - would need proper scene parser)
        asset_references = extract_asset_references_from_text(scene_content)
        
        # Update metadata for referenced assets
        for asset_path in asset_references
            full_asset_path = resolve_asset_path(asset_path)
            if isfile(full_asset_path)
                metadata = get_or_create_metadata(full_asset_path)
                push!(metadata.used_in_scenes, scene_path)
                metadata.reference_count += 1
                metadata.last_accessed = now()
            end
        end
        
    catch e
        @error "Error scanning scene dependencies for $scene_path: $e"
    end
end

function extract_asset_references_from_text(text::String)::Vector{String}
    references = String[]
    
    # Look for common asset reference patterns
    patterns = [
        r"\"imagePath\":\s*\"([^\"]+)\"",
        r"\"path\":\s*\"([^\"]+)\"",
        r"\"soundPath\":\s*\"([^\"]+)\"",
        r"\"fontPath\":\s*\"([^\"]+)\""
    ]
    
    for pattern in patterns
        for match_result in eachmatch(pattern, text)
            if length(match_result.captures) > 0 && match_result.captures[1] !== nothing
                push!(references, match_result.captures[1])
            end
        end
    end
    
    return unique(references)
end

function resolve_asset_path(relative_path::String)::String
    # Resolve relative asset path to absolute path
    if isabspath(relative_path)
        return relative_path
    end
    
    # Try different common asset locations
    possible_paths = [
        joinpath(JulGame.BasePath, "assets", relative_path),
        joinpath(JulGame.BasePath, relative_path),
        joinpath(JulGame.BasePath, "assets", "images", relative_path),
        joinpath(JulGame.BasePath, "assets", "sounds", relative_path)
    ]
    
    for path in possible_paths
        if isfile(path)
            return path
        end
    end
    
    return relative_path  # Return original if not found
end

"""
    Metadata persistence
"""

function get_metadata_file_path(asset_path::String)::String
    # Store metadata in a hidden directory alongside assets
    metadata_dir = joinpath(dirname(asset_path), ".julgame_metadata")
    if !isdir(metadata_dir)
        mkpath(metadata_dir)
    end
    
    asset_name = basename(asset_path)
    metadata_filename = "$(asset_name).metadata.json"
    return joinpath(metadata_dir, metadata_filename)
end

function save_metadata_to_disk(metadata::AssetMetadata)
    try
        metadata_path = get_metadata_file_path(metadata.file_path)
        
        # Convert metadata to serializable format
        metadata_dict = Dict(
            "file_path" => metadata.file_path,
            "file_type" => string(metadata.file_type),
            "tags" => collect(metadata.tags),
            "description" => metadata.description,
            "custom_properties" => metadata.custom_properties,
            "used_in_scenes" => collect(metadata.used_in_scenes),
            "reference_count" => metadata.reference_count,
            "last_accessed" => string(metadata.last_accessed),
            "metadata_version" => metadata.metadata_version
        )
        
        # Write to file
        open(metadata_path, "w") do io
            JSON3.write(io, metadata_dict)
        end
        
    catch e
        @debug "Failed to save metadata for $(metadata.file_path): $e"
    end
end

function load_metadata_from_disk(asset_path::String)::Union{AssetMetadata, Nothing}
    try
        metadata_path = get_metadata_file_path(asset_path)
        
        if !isfile(metadata_path)
            return nothing
        end
        
        # Read metadata file
        metadata_dict = open(metadata_path, "r") do io
            JSON3.read(io, Dict{String, Any})
        end
        
        # Create metadata object
        metadata = AssetMetadata(asset_path)
        metadata.tags = Set(metadata_dict["tags"])
        metadata.description = get(metadata_dict, "description", "")
        metadata.custom_properties = get(metadata_dict, "custom_properties", Dict{String, Any}())
        metadata.used_in_scenes = Set(get(metadata_dict, "used_in_scenes", String[]))
        metadata.reference_count = get(metadata_dict, "reference_count", 0)
        metadata.metadata_version = get(metadata_dict, "metadata_version", 1)
        
        if haskey(metadata_dict, "last_accessed")
            try
                metadata.last_accessed = DateTime(metadata_dict["last_accessed"])
            catch
                metadata.last_accessed = now()
            end
        end
        
        return metadata
        
    catch e
        @debug "Failed to load metadata for $asset_path: $e"
        return nothing
    end
end

"""
    UI components for metadata display and editing
"""

function show_asset_metadata_editor(filepath::String)
    metadata = get_or_create_metadata(filepath)
    
    CImGui.Text("Asset Metadata")
    CImGui.Separator()
    
    # Basic information
    CImGui.Text("File: $(basename(filepath))")
    CImGui.Text("Type: $(string(metadata.file_type))")
    CImGui.Text("Size: $(format_file_size(metadata.file_size))")
    CImGui.Text("Modified: $(Dates.format(metadata.modified_time, "yyyy-mm-dd HH:MM:SS"))")
    
    CImGui.Separator()
    
    # Description editor
    CImGui.Text("Description:")
    description_buf = "$(metadata.description)" * "\0"^512
    if CImGui.InputTextMultiline("##description", description_buf, length(description_buf), ImVec2(0, 60))
        # Extract description (following ImportFile pattern)
        current_text = ""
        for character_index in eachindex(description_buf)
            if Int32(description_buf[character_index]) == 0 
                if character_index != 1
                    current_text = String(SubString(description_buf, 1, character_index-1))
                end
                break
            end
        end
        metadata.description = current_text
        save_metadata_to_disk(metadata)
    end
    
    CImGui.Separator()
    
    # Tags editor
    show_tags_editor(metadata)
    
    CImGui.Separator()
    
    # Type-specific metadata
    show_type_specific_metadata(metadata)
    
    CImGui.Separator()
    
    # Usage information
    if !isempty(metadata.used_in_scenes)
        CImGui.Text("Used in scenes:")
        for scene_path in metadata.used_in_scenes
            CImGui.Text("• $(basename(scene_path))")
        end
    else
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "Not used in any scenes")
    end
end

function show_tags_editor(metadata::AssetMetadata)
    CImGui.Text("Tags:")
    
    # Display existing tags
    tags_to_remove = String[]
    for tag in metadata.tags
        CImGui.SameLine()
        
        # Tag button with remove option
        if CImGui.SmallButton("$(tag) ✖")
            push!(tags_to_remove, tag)
        end
    end
    
    # Remove tags
    for tag in tags_to_remove
        delete!(metadata.tags, tag)
        save_metadata_to_disk(metadata)
    end
    
    # Add new tag input
    CImGui.Text("Add tag:")
    CImGui.SameLine()
    CImGui.SetNextItemWidth(150)
    
    new_tag_buf = "\0"^64
    if CImGui.InputText("##new_tag", new_tag_buf, length(new_tag_buf), CImGui.ImGuiInputTextFlags_EnterReturnsTrue)
        # Extract tag text
        new_tag = ""
        for character_index in eachindex(new_tag_buf)
            if Int32(new_tag_buf[character_index]) == 0 
                if character_index != 1
                    new_tag = String(SubString(new_tag_buf, 1, character_index-1))
                end
                break
            end
        end
        
        if !isempty(strip(new_tag))
            add_tag_to_asset(metadata.file_path, new_tag)
        end
    end
end

function show_type_specific_metadata(metadata::AssetMetadata)
    if metadata.file_type == :image && metadata.image_metadata !== nothing
        CImGui.Text("Image Properties:")
        for (key, value) in metadata.image_metadata
            CImGui.Text("$(key): $(value)")
        end
    elseif metadata.file_type == :audio && metadata.audio_metadata !== nothing
        CImGui.Text("Audio Properties:")
        for (key, value) in metadata.audio_metadata
            CImGui.Text("$(key): $(value)")
        end
    elseif metadata.file_type == :script && metadata.script_metadata !== nothing
        CImGui.Text("Script Properties:")
        for (key, value) in metadata.script_metadata
            if key == "function_names" && isa(value, Vector)
                CImGui.Text("Functions: $(join(value, ", "))")
            else
                CImGui.Text("$(key): $(value)")
            end
        end
    end
end

"""
    Batch metadata operations
"""

function refresh_all_metadata_in_directory(directory_path::String)
    try
        for (root, dirs, files) in walkdir(directory_path)
            for file in files
                filepath = joinpath(root, file)
                if should_track_metadata(filepath)
                    metadata = get_or_create_metadata(filepath)
                    refresh_metadata!(metadata)
                end
            end
        end
        @debug "Refreshed metadata for directory: $directory_path"
    catch e
        @error "Error refreshing metadata for directory $directory_path: $e"
    end
end

function should_track_metadata(filepath::String)::Bool
    # Don't track metadata files themselves
    if occursin(".julgame_metadata", filepath)
        return false
    end
    
    # Only track supported file types
    file_type = get_file_type(filepath)
    return file_type in [:image, :audio, :script, :scene, :font, :model, :config]
end

# Export functions for integration
export get_or_create_metadata, add_tag_to_asset, remove_tag_from_asset
export get_assets_with_tag, show_asset_metadata_editor, scan_scene_dependencies
export refresh_all_metadata_in_directory
