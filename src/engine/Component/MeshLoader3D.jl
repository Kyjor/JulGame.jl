module MeshLoader3DModule
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using FileIO, MeshIO
    using GeometryBasics
    using ..Math3DModule
    using ..Geometry3DModule
    using ..Materials3DModule
    
    # Import the types we need
    using ..Math3DModule: Vec3D
    using ..Geometry3DModule: UV
    using ..Materials3DModule: RenderMaterial
    
    export parse_obj_file, parse_mtl_file, parse_obj_materials, load_texture_average_color

    # Extract dominant color from texture image by sampling multiple pixels
    # This handles textures with multiple colors like golf courses (green + brown)
    function load_texture_average_color(texture_path::String)::Vec3D
        try
            # Load the image using SDL to get the actual color
            surface = SDL2.IMG_Load(texture_path)
            if surface == C_NULL
                @warn "Failed to load texture for color extraction: $texture_path"
                return Vec3D(0.8, 0.8, 0.8)  # Default gray
            end
            
            # Get surface information
            surface_ref = unsafe_load(surface)
            width = surface_ref.w
            height = surface_ref.h
            format = unsafe_load(surface_ref.format)
            
            pixel_data = surface_ref.pixels
            bytes_per_pixel = format.BytesPerPixel
            
            if bytes_per_pixel >= 3  # RGB or RGBA
                # Sample multiple pixels to get a better representation
                total_r = 0.0
                total_g = 0.0
                total_b = 0.0
                sample_count = 0
                
                # Sample every pixel for small textures (8x8), or sample a grid for larger ones
                sample_step = max(1, div(min(width, height), 4))  # Sample at least 4x4 grid
                
                for y in 1:sample_step:height
                    for x in 1:sample_step:width
                        pixel_offset = ((y-1) * surface_ref.pitch + (x-1) * bytes_per_pixel)
                        
                        r = unsafe_load(Ptr{UInt8}(pixel_data + pixel_offset + 0)) / 255.0
                        g = unsafe_load(Ptr{UInt8}(pixel_data + pixel_offset + 1)) / 255.0
                        b = unsafe_load(Ptr{UInt8}(pixel_data + pixel_offset + 2)) / 255.0
                        
                        total_r += r
                        total_g += g
                        total_b += b
                        sample_count += 1
                    end
                end
                
                # Calculate average color
                if sample_count > 0
                    avg_r = total_r / sample_count
                    avg_g = total_g / sample_count
                    avg_b = total_b / sample_count
                    
                    SDL_FreeSurface(surface)
                    
                    @info "Extracted average color from texture '$texture_path' ($(sample_count) samples): RGB($avg_r, $avg_g, $avg_b)"
                    return Vec3D(avg_r, avg_g, avg_b)
                else
                    SDL_FreeSurface(surface)
                    @warn "No pixels sampled from texture: $texture_path"
                    return Vec3D(0.8, 0.8, 0.8)  # Default gray
                end
            else
                SDL_FreeSurface(surface)
                @warn "Unsupported pixel format for texture: $texture_path"
                return Vec3D(0.8, 0.8, 0.8)  # Default gray
            end
            
        catch e
            @warn "Failed to extract color from texture $texture_path: $e"
            return Vec3D(0.8, 0.8, 0.8)  # Default gray
        end
    end

    # Parse OBJ file to extract vertices, UV coordinates, faces and materials
    function parse_obj_file(obj_path::String)::Tuple{Vector{Vec3D}, Vector{UV}, Vector{Tuple{Vector{Int}, Vector{Int}, String}}}
        vertices = Vec3D[]
        uv_coords = UV[]
        faces_with_materials = Tuple{Vector{Int}, Vector{Int}, String}[]  # (vertex_indices, uv_indices, material)
        
        if !isfile(obj_path)
            return (vertices, uv_coords, faces_with_materials)
        end
        
        current_material = "default"
        
        for line in eachline(obj_path)
            stripped = strip(line)
            if isempty(stripped) || startswith(stripped, "#")
                continue
            end
            
            tokens = split(stripped)
            if isempty(tokens)
                continue
            end
            
            if tokens[1] == "v" && length(tokens) >= 4
                # Vertex position: v x y z
                x = parse(Float64, tokens[2])
                y = parse(Float64, tokens[3])
                z = parse(Float64, tokens[4])
                push!(vertices, Vec3D(x, y, z))
                
            elseif tokens[1] == "vt" && length(tokens) >= 3
                # Texture coordinate: vt u v
                u = parse(Float64, tokens[2])
                v = parse(Float64, tokens[3])
                push!(uv_coords, UV(u, v))
                
            elseif tokens[1] == "usemtl" && length(tokens) >= 2
                current_material = tokens[2]
                @info "OBJ: Switching to material '$current_material'"
                
            elseif tokens[1] == "f" && length(tokens) >= 4
                # Face definition: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3 [v4/vt4/vn4]
                vertex_indices = Int[]
                uv_indices = Int[]
                
                # Parse face vertices (handle triangles and quads)
                face_vertices = tokens[2:end]
                
                for vertex_data in face_vertices
                    # Split by '/' to get vertex/texture/normal indices
                    parts = split(vertex_data, '/')
                    
                    # Vertex index (1-based in OBJ, convert to 1-based for Julia)
                    if !isempty(parts[1])
                        push!(vertex_indices, parse(Int, parts[1]))
                    end
                    
                    # UV index (optional)
                    if length(parts) >= 2 && !isempty(parts[2])
                        push!(uv_indices, parse(Int, parts[2]))
                    else
                        push!(uv_indices, 0)  # No UV coordinate
                    end
                end
                
                if length(vertex_indices) >= 3
                    if length(vertex_indices) == 3
                        # Triangle
                        push!(faces_with_materials, (vertex_indices, uv_indices, current_material))
                    elseif length(vertex_indices) == 4
                        # Quad - split into two triangles
                        # Triangle 1: v1, v2, v3
                        push!(faces_with_materials, ([vertex_indices[1], vertex_indices[2], vertex_indices[3]], 
                                                    [uv_indices[1], uv_indices[2], uv_indices[3]], current_material))
                        # Triangle 2: v1, v3, v4
                        push!(faces_with_materials, ([vertex_indices[1], vertex_indices[3], vertex_indices[4]], 
                                                    [uv_indices[1], uv_indices[3], uv_indices[4]], current_material))
                    else
                        # Polygon - use fan triangulation
                        for i in 2:(length(vertex_indices)-1)
                            push!(faces_with_materials, ([vertex_indices[1], vertex_indices[i], vertex_indices[i+1]], 
                                                        [uv_indices[1], uv_indices[i], uv_indices[i+1]], current_material))
                        end
                    end
                end
            end
        end
        
        @info "OBJ: Parsed $(length(vertices)) vertices, $(length(uv_coords)) UV coordinates, $(length(faces_with_materials)) faces"
        return (vertices, uv_coords, faces_with_materials)
    end

    # Legacy function for backward compatibility
    function parse_obj_materials(obj_path::String)::Dict{Int, String}
        face_materials = Dict{Int, String}()
        
        if !isfile(obj_path)
            return face_materials
        end
        
        current_material = "default"
        face_index = 0
        
        for line in eachline(obj_path)
            stripped = strip(line)
            if isempty(stripped) || startswith(stripped, "#")
                continue
            end
            
            tokens = split(stripped)
            if isempty(tokens)
                continue
            end
            
            if tokens[1] == "usemtl" && length(tokens) >= 2
                current_material = tokens[2]
            elseif tokens[1] == "f" && length(tokens) >= 4
                # Face definition - assign current material
                face_index += 1
                face_materials[face_index] = current_material
                
                # Check if it's a quad (will be split into 2 triangles)
                if length(tokens) == 5  # f v1 v2 v3 v4
                    face_index += 1
                    face_materials[face_index] = current_material
                end
            end
        end
        
        return face_materials
    end

    # Parse MTL file for materials
    function parse_mtl_file(mtl_path::String)::Dict{String, RenderMaterial}
        materials = Dict{String, RenderMaterial}()
        
        if !isfile(mtl_path)
            return materials
        end
        
        current_material = nothing
        current_name = ""
        
        for line in eachline(mtl_path)
            tokens = split(strip(line))
            if isempty(tokens) || startswith(tokens[1], "#")
                continue
            end
            
            if tokens[1] == "newmtl" && length(tokens) >= 2
                # Save previous material if exists
                if current_material !== nothing && current_name != ""
                    materials[current_name] = current_material
                end
                
                # Start new material
                current_name = tokens[2]
                current_material = RenderMaterial()
                
            elseif tokens[1] == "Kd" && length(tokens) >= 4 && current_material !== nothing
                # Diffuse color
                r = parse(Float64, tokens[2])
                g = parse(Float64, tokens[3])
                b = parse(Float64, tokens[4])
                current_material.diffuse_color = Vec3D(r, g, b)
                
            elseif tokens[1] == "Ka" && length(tokens) >= 4 && current_material !== nothing
                # Ambient color
                r = parse(Float64, tokens[2])
                g = parse(Float64, tokens[3])
                b = parse(Float64, tokens[4])
                current_material.ambient_color = Vec3D(r, g, b)
                
            elseif tokens[1] == "Ks" && length(tokens) >= 4 && current_material !== nothing
                # Specular color
                r = parse(Float64, tokens[2])
                g = parse(Float64, tokens[3])
                b = parse(Float64, tokens[4])
                current_material.specular_color = Vec3D(r, g, b)
                
            elseif (tokens[1] == "d" || tokens[1] == "Tr") && length(tokens) >= 2 && current_material !== nothing
                # Alpha/transparency
                alpha = parse(Float64, tokens[2])
                current_material.alpha = tokens[1] == "Tr" ? (1.0 - alpha) : alpha
                
            elseif tokens[1] == "map_Kd" && length(tokens) >= 2 && current_material !== nothing
                # Diffuse texture map
                texture_filename = join(tokens[2:end], " ")  # Handle filenames with spaces
                
                # Resolve texture path relative to MTL file
                mtl_dir = dirname(mtl_path)
                if isabspath(texture_filename)
                    texture_path = texture_filename
                else
                    texture_path = joinpath(mtl_dir, texture_filename)
                end
                
                # Check if texture file exists
                if isfile(texture_path)
                    current_material.has_texture = true
                    current_material.texture_path = texture_path
                    
                    # Only extract color from texture if no Kd color was specified
                    if current_material.diffuse_color == Vec3D(0.8, 0.8, 0.8)  # Default color
                        texture_color = load_texture_average_color(texture_path)
                        current_material.diffuse_color = texture_color
                        @info "Material '$current_name' no Kd specified, using texture color: RGB($(texture_color.x), $(texture_color.y), $(texture_color.z))"
                    else
                        @info "Material '$current_name' using specified Kd color: RGB($(current_material.diffuse_color.x), $(current_material.diffuse_color.y), $(current_material.diffuse_color.z)) with texture: $texture_path"
                    end
                else
                    @warn "Texture file not found: $texture_path"
                end
            end
        end
        
        # Save last material
        if current_material !== nothing && current_name != ""
            materials[current_name] = current_material
        end
        
        return materials
    end

end 