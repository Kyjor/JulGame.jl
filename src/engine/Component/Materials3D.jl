module Materials3DModule
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..Math3DModule
    using ..Geometry3DModule
    
    export RenderMaterial, MaterialFace, RenderBox, RenderMesh, compute_mesh_bounds!

    # Material for faces
    mutable struct RenderMaterial
        diffuse_color::Vec3D
        ambient_color::Vec3D
        specular_color::Vec3D
        alpha::Float64
        has_texture::Bool
        texture_path::String
        # Cached texture file existence (computed once at load time for performance)
        texture_file_exists::Bool
        
        function RenderMaterial(diffuse::Vec3D = Vec3D(0.8, 0.8, 0.8), 
                               ambient::Vec3D = Vec3D(0.2, 0.2, 0.2), 
                               specular::Vec3D = Vec3D(0.0, 0.0, 0.0), 
                               alpha::Float64 = 1.0,
                               has_texture::Bool = false,
                               texture_path::String = "")
            # Compute texture file existence once at creation
            texture_file_exists = has_texture && texture_path != "" && isfile(texture_path)
            new(diffuse, ambient, specular, alpha, has_texture, texture_path, texture_file_exists)
        end
    end

    # Face with material information and UV coordinates
    mutable struct MaterialFace
        vertex_indices::Vector{Int}
        uv_indices::Vector{Int}  # Indices into UV coordinate array
        material_name::String
        
        function MaterialFace(indices::Vector{Int}, uv_indices::Vector{Int} = Int[], material::String = "default")
            new(indices, uv_indices, material)
        end
    end

    # Box structure for rendering
    mutable struct RenderBox
        dimensions::Vec3D
        position::Vec3D
        rotation::Vec3D
        fill_color::SDL_Color
        stroke_color::SDL_Color

        function RenderBox(dimensions::Vec3D = Vec3D(1, 1, 1), position::Vec3D = Vec3D(0, 0, 0), 
                          rotation::Vec3D = Vec3D(0, 0, 0), 
                          fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                          stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))
            new(dimensions, position, rotation, fill_color, stroke_color)
        end
    end

    # Mesh structure for rendering loaded 3D files
    mutable struct RenderMesh
        vertices::Vector{Vec3D}
        uv_coordinates::Vector{UV}  # UV texture coordinates
        faces::Vector{MaterialFace}  # Each face has material information and UV indices
        materials::Dict{String, RenderMaterial}
        use_materials::Bool
        position::Vec3D
        rotation::Vec3D
        scale::Vec3D
        default_fill_color::SDL_Color
        default_stroke_color::SDL_Color
        file_path::String
        normalize_uv_coordinates::Bool  # Whether to normalize UV coordinates to [0,1] range
        # Cached bounding box (computed once, used for shadow calculations)
        cached_bounds_min::Union{Nothing, Vec3D}
        cached_bounds_max::Union{Nothing, Vec3D}

        function RenderMesh(file_path::String = "", 
                           position::Vec3D = Vec3D(0, 0, 0), 
                           rotation::Vec3D = Vec3D(0, 0, 0),
                           scale::Vec3D = Vec3D(1, 1, 1),
                           fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                           stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255),
                           normalize_uv::Bool = false)
            new(Vec3D[], UV[], MaterialFace[], Dict{String, RenderMaterial}(), false, position, rotation, scale, fill_color, stroke_color, file_path, normalize_uv, nothing, nothing)
        end
    end

    # Compute and cache bounding box for a mesh (call this when mesh is loaded/updated)
    function compute_mesh_bounds!(mesh::RenderMesh)
        if isempty(mesh.vertices)
            mesh.cached_bounds_min = nothing
            mesh.cached_bounds_max = nothing
            return
        end
        
        # Calculate simple bounding box
        min_bounds = mesh.vertices[1]
        max_bounds = mesh.vertices[1]
        
        for vertex in mesh.vertices
            min_bounds = Vec3D(min(min_bounds.x, vertex.x), min(min_bounds.y, vertex.y), min(min_bounds.z, vertex.z))
            max_bounds = Vec3D(max(max_bounds.x, vertex.x), max(max_bounds.y, vertex.y), max(max_bounds.z, vertex.z))
        end
        
        # Cache the bounds
        mesh.cached_bounds_min = min_bounds
        mesh.cached_bounds_max = max_bounds
    end

end 