module MeshLoaderIntegrationModule
    using FileIO #, MeshIO
    using GeometryBasics
    using ..Math3DModule
    using ..Geometry3DModule
    using ..Materials3DModule
    using ..MeshLoader3DModule
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    
    # Import the types we need
    using ..Math3DModule: Vec3D
    using ..Geometry3DModule: UV
    using ..Materials3DModule: RenderMaterial, MaterialFace, RenderMesh, compute_mesh_bounds!
    using ..MeshLoader3DModule: parse_mtl_file
    
    export load_mesh_from_file!

    # Load mesh from file using MeshIO
    function load_mesh_from_file!(renderer, file_path::String, 
                                 position::Vec3D = Vec3D(0, 0, 0),
                                 rotation::Vec3D = Vec3D(0, 0, 0),
                                 scale::Vec3D = Vec3D(1, 1, 1),
                                 fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                 stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255),
                                 normalize_uv::Bool = false)::Union{RenderMesh, Nothing}
        
        if !isfile(file_path)
            @error "Mesh file not found: $file_path"
            return nothing
        end
        
        try
            # Load the mesh using FileIO/MeshIO
            mesh_data = load(file_path)
            println("Loaded mesh data of type: ", typeof(mesh_data))
            
            # Create our RenderMesh
            render_mesh = RenderMesh(file_path, position, rotation, scale, fill_color, stroke_color, normalize_uv)
            
            # Check for MTL file and parse it
            mtl_path = splitext(file_path)[1] * ".mtl"
            if isfile(mtl_path)
                @debug "Loading materials from $mtl_path"
                render_mesh.materials = parse_mtl_file(mtl_path)
                render_mesh.use_materials = !isempty(render_mesh.materials)
                @debug "Parsed $(length(render_mesh.materials)) materials"
            end
            
            # For OBJ files, use custom parser that preserves material assignments
            if lowercase(splitext(file_path)[2]) == ".obj"
                @debug "🔧 USING CUSTOM OBJ PARSER for material preservation - file: $file_path"
                vertices, uv_coords, faces_with_materials = parse_obj_file(file_path)
                
                # Convert vertices to our format
                for vertex in vertices
                    push!(render_mesh.vertices, vertex)
                end
                
                # Convert UV coordinates
                for uv in uv_coords
                    push!(render_mesh.uv_coordinates, uv)
                end
                
                # Convert faces with proper material assignments
                for (face_idx, (vertex_indices, uv_indices, material_name)) in enumerate(faces_with_materials)
                    if face_idx <= 3  # Debug first few faces
                        @debug "MeshLoader: Converting face $face_idx: vertex_indices=$vertex_indices, uv_indices=$uv_indices, material='$material_name'"
                    end
                    face = MaterialFace(vertex_indices, uv_indices, material_name)
                    if face_idx <= 3  # Debug first few faces  
                        @debug "MeshLoader: Created MaterialFace $face_idx: vertex_indices=$(face.vertex_indices), uv_indices=$(face.uv_indices), material='$(face.material_name)'"
                    end
                    push!(render_mesh.faces, face)
                end
                
                @debug "Custom OBJ parser loaded $(length(render_mesh.vertices)) vertices, $(length(render_mesh.uv_coordinates)) UVs, $(length(render_mesh.faces)) faces"
                
                # Compute and cache bounding box for shadow calculations (performance optimization)
                compute_mesh_bounds!(render_mesh)
                
                # Add to renderer and return early
                push!(renderer.meshes, render_mesh)
                return render_mesh
            end
            
            # Extract vertices and faces based on mesh type (for non-OBJ files)
            if isa(mesh_data, GeometryBasics.Mesh)
                # Standard GeometryBasics Mesh
                vertices = GeometryBasics.coordinates(mesh_data)
                faces = GeometryBasics.faces(mesh_data)
                
                # Convert vertices to our Vec3D format
                for vertex in vertices
                    if length(vertex) >= 3
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                    else
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                    end
                end
                
                # Convert faces to our format
                for face in faces
                    face_indices = Int[]
                    if isa(face, GeometryBasics.TriangleFace)
                        push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                        push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                    elseif isa(face, GeometryBasics.QuadFace)
                        # Split quad into two triangles
                        push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                        push!(render_mesh.faces, MaterialFace(copy(face_indices), Int[], "default"))
                        face_indices = [convert(Int, face[1]), convert(Int, face[3]), convert(Int, face[4])]
                        push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                    else
                        # Generic face - try to extract indices
                        for i in 1:length(face)
                            push!(face_indices, convert(Int, face[i]))
                        end
                        # If more than 3 vertices, triangulate (simple fan triangulation)
                        if length(face_indices) > 3
                            for i in 2:(length(face_indices)-1)
                                triangle_indices = [face_indices[1], face_indices[i], face_indices[i+1]]
                                push!(render_mesh.faces, MaterialFace(triangle_indices, Int[], "default"))
                            end
                        else
                            push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                        end
                    end
                end
                
            elseif isa(mesh_data, GeometryBasics.MetaMesh)
                # Handle MetaMesh format (common for OBJ files with materials/groups)
                @debug "Loading MetaMesh format"
                
                # Try to extract the mesh using GeometryBasics.expand_faceviews
                try
                    expanded_mesh = GeometryBasics.expand_faceviews(mesh_data)
                    
                    # Now work with the expanded mesh as a regular Mesh
                    vertices = GeometryBasics.coordinates(expanded_mesh)
                    faces = GeometryBasics.faces(expanded_mesh)
                    
                    # Convert vertices to our Vec3D format
                    for vertex in vertices
                        if length(vertex) >= 3
                            push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                        else
                            push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                        end
                    end
                    
                    # Convert faces to our format
                    for face in faces
                        face_indices = Int[]
                        if isa(face, GeometryBasics.TriangleFace)
                            push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                            push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                        elseif isa(face, GeometryBasics.QuadFace)
                            # Split quad into two triangles
                            push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                            push!(render_mesh.faces, MaterialFace(copy(face_indices), Int[], "default"))
                            face_indices = [convert(Int, face[1]), convert(Int, face[3]), convert(Int, face[4])]
                            push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                        else
                            # Generic face - try to extract indices
                            for i in 1:length(face)
                                push!(face_indices, convert(Int, face[i]))
                            end
                            # If more than 3 vertices, triangulate (simple fan triangulation)
                            if length(face_indices) > 3
                                for i in 2:(length(face_indices)-1)
                                    triangle_indices = [face_indices[1], face_indices[i], face_indices[i+1]]
                                    push!(render_mesh.faces, MaterialFace(triangle_indices, Int[], "default"))
                                end
                            else
                                push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                            end
                        end
                    end
                catch expand_error
                    @warn "Failed to expand MetaMesh, trying alternative approach: $expand_error"
                    
                    # Alternative approach: try to access the mesh directly
                    if hasfield(typeof(mesh_data), :mesh)
                        base_mesh = mesh_data.mesh
                        vertices = GeometryBasics.coordinates(base_mesh)
                        faces = GeometryBasics.faces(base_mesh)
                        
                        # Convert vertices
                        for vertex in vertices
                            if length(vertex) >= 3
                                push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                            else
                                push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                            end
                        end
                        
                        # Convert faces
                        for face in faces
                            face_indices = [convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3])]
                            push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                        end
                    else
                        @error "Cannot extract mesh data from MetaMesh"
                        return nothing
                    end
                end
            elseif hasfield(typeof(mesh_data), :position) && hasfield(typeof(mesh_data), :faces)
                # Other mesh formats with position and faces fields
                vertices = mesh_data.position
                faces = mesh_data.faces
                
                # Convert vertices
                for vertex in vertices
                    if length(vertex) >= 3
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                    else
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                    end
                end
                
                # Convert faces
                for face in faces
                    face_indices = [Int(i) for i in face]
                    if length(face_indices) == 3
                        push!(render_mesh.faces, MaterialFace(face_indices, Int[], "default"))
                    elseif length(face_indices) == 4
                        # Split quad into two triangles
                        push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[2], face_indices[3]], Int[], "default"))
                        push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[3], face_indices[4]], Int[], "default"))
                    else
                        # Triangulate polygon using fan method
                        for i in 2:(length(face_indices)-1)
                            push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[i], face_indices[i+1]], Int[], "default"))
                        end
                    end
                end
            else
                @error "Unsupported mesh format for file: $file_path. Type: $(typeof(mesh_data))"
                return nothing
            end
            
            # Compute and cache bounding box for shadow calculations (performance optimization)
            compute_mesh_bounds!(render_mesh)
            
            # Add to renderer
            push!(renderer.meshes, render_mesh)
            
            @debug "Successfully loaded mesh from $file_path: $(length(render_mesh.vertices)) vertices, $(length(render_mesh.faces)) faces"
            return render_mesh
            
        catch e
            @error "Failed to load mesh from $file_path: $e"
            return nothing
        end
    end

end 