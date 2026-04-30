module FastObj
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component

    export FastObjParser, parse_obj_file

    # Import necessary types from Mesh3D
    using ..JulGame.Component.Mesh3DModule: vec3d, Material, Texture, TEXTURE_TYPE_DIFFUSE, load_texture

    mutable struct FastObjParser
        vertices::Vector{vec3d}
        normals::Vector{vec3d}
        texcoords::Vector{vec3d}
        faces::Vector{Vector{Int}}
        face_texcoords::Vector{Vector{Int}}
        face_normals::Vector{Vector{Int}}
        materials::Dict{String, Material}
        current_material::String
        data::Vector{UInt8}
        pos::Int
    end

    function parse_obj_file(file_path::String)
        # Read the entire file into memory
        data = read(file_path)
        
        # Initialize parser
        parser = FastObjParser(
            vec3d[],  # vertices
            vec3d[],  # normals
            vec3d[],  # texcoords
            Vector{Int}[],  # faces
            Vector{Int}[],  # face_texcoords
            Vector{Int}[],  # face_normals
            Dict{String, Material}(),  # materials
            "default",  # current_material
            data,  # data
            1  # pos
        )

        # Parse the file
        while parser.pos <= length(parser.data)
            # Skip whitespace
            while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
                parser.pos += 1
            end
            if parser.pos > length(parser.data)
                break
            end

            # Get the first character of the line
            c = parser.data[parser.pos]
            parser.pos += 1

            # Skip comments
            if c == UInt8('#')
                while parser.pos <= length(parser.data) && parser.data[parser.pos] != UInt8('\n')
                    parser.pos += 1
                end
                continue
            end

            # Parse based on the first character
            if c == UInt8('v')
                if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('n')
                    # Normal
                    parser.pos += 1
                    x = parse_float(parser)
                    y = parse_float(parser)
                    z = parse_float(parser)
                    push!(parser.normals, vec3d(x, y, z))
                elseif parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('t')
                    # Texture coordinate
                    parser.pos += 1
                    u = parse_float(parser)
                    v = parse_float(parser)
                    push!(parser.texcoords, vec3d(u, v, 0.0))
                else
                    # Vertex
                    x = parse_float(parser)
                    y = parse_float(parser)
                    z = parse_float(parser)
                    push!(parser.vertices, vec3d(x, y, z))
                end
            elseif c == UInt8('f')
                # Face
                faces, face_texcoords, face_normals = parse_face(parser)
                println("Parsed face data:")
                println("Faces: $faces")
                println("Face texcoords: $face_texcoords")
                println("Face normals: $face_normals")
                
                # Add all faces to the parser
                for i in 1:length(faces)
                    push!(parser.faces, faces[i])
                    if i <= length(face_texcoords)
                        push!(parser.face_texcoords, face_texcoords[i])
                    end
                    if i <= length(face_normals)
                        push!(parser.face_normals, face_normals[i])
                    end
                end
            elseif c == UInt8('m')
                # Material library
                if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('t')
                    parser.pos += 1
                    if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('l')
                        parser.pos += 1
                        if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('l')
                            parser.pos += 1
                            # Skip whitespace
                            while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
                                parser.pos += 1
                            end
                            # Parse material library file path
                            mtl_path = parse_string(parser)
                            if !isempty(mtl_path)
                                load_material_library(parser, joinpath(dirname(file_path), mtl_path))
                            end
                        end
                    end
                end
            elseif c == UInt8('u')
                # Use material
                if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('s')
                    parser.pos += 1
                    if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('e')
                        parser.pos += 1
                        if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('m')
                            parser.pos += 1
                            if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('t')
                                parser.pos += 1
                                if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('l')
                                    parser.pos += 1
                                    # Skip whitespace
                                    while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
                                        parser.pos += 1
                                    end
                                    # Parse material name
                                    parser.current_material = parse_string(parser)
                                end
                            end
                        end
                    end
                end
            end

            # Skip to next line
            while parser.pos <= length(parser.data) && parser.data[parser.pos] != UInt8('\n')
                parser.pos += 1
            end
            parser.pos += 1
        end

        println("Final parser results:")
        println("Vertices: $(length(parser.vertices))")
        println("Normals: $(length(parser.normals))")
        println("Texcoords: $(length(parser.texcoords))")
        println("Faces: $(length(parser.faces))")
        println("Face texcoords: $(length(parser.face_texcoords))")
        println("Face normals: $(length(parser.face_normals))")

        return parser.vertices, parser.normals, parser.texcoords, parser.faces, 
               parser.face_texcoords, parser.face_normals, parser.materials
    end

    function parse_float(parser::FastObjParser)::Float64
        # Skip whitespace
        while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
            parser.pos += 1
        end
        
        # Find the end of the number
        end_pos = parser.pos
        while end_pos <= length(parser.data) && !isspace(Char(parser.data[end_pos]))
            end_pos += 1
        end
        
        # Parse the number
        num_str = String(parser.data[parser.pos:end_pos-1])
        parser.pos = end_pos
        return parse(Float64, num_str)
    end

    function parse_int(parser::FastObjParser)::Union{Int, Nothing}
        # Skip whitespace
        while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
            parser.pos += 1
        end
        
        if parser.pos > length(parser.data)
            return nothing
        end
        
        # Find the end of the number
        end_pos = parser.pos
        while end_pos <= length(parser.data) && !isspace(Char(parser.data[end_pos])) && parser.data[end_pos] != UInt8('/')
            end_pos += 1
        end
        
        if end_pos == parser.pos
            return nothing
        end
        
        # Parse the number
        num_str = String(parser.data[parser.pos:end_pos-1])
        parser.pos = end_pos
        return parse(Int, num_str)
    end

    function parse_string(parser::FastObjParser)::String
        # Skip whitespace
        while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
            parser.pos += 1
        end
        
        # Find the end of the string
        end_pos = parser.pos
        while end_pos <= length(parser.data) && !isspace(Char(parser.data[end_pos]))
            end_pos += 1
        end
        
        # Get the string
        str = String(parser.data[parser.pos:end_pos-1])
        parser.pos = end_pos
        return str
    end

    function load_material_library(parser::FastObjParser, mtl_path::String)
        if !isfile(mtl_path)
            @warn "Material library file not found: $mtl_path"
            return
        end

        current_material = nothing
        f = open(mtl_path, "r")
        
        while !eof(f)
            line = readline(f)
            s = split(line)
            
            if isempty(s)
                continue
            end

            if s[1] == "newmtl"
                current_material = Material(string(s[2]))
                parser.materials[s[2]] = current_material
            elseif current_material !== nothing
                if s[1] == "Ka" && length(s) >= 4
                    # Ambient color
                    current_material.ambient = (
                        parse(Float32, s[2]),
                        parse(Float32, s[3]),
                        parse(Float32, s[4])
                    )
                elseif s[1] == "Kd" && length(s) >= 4
                    # Diffuse color
                    current_material.diffuse = (
                        parse(Float32, s[2]),
                        parse(Float32, s[3]),
                        parse(Float32, s[4])
                    )
                elseif s[1] == "Ks" && length(s) >= 4
                    # Specular color
                    current_material.specular = (
                        parse(Float32, s[2]),
                        parse(Float32, s[3]),
                        parse(Float32, s[4])
                    )
                elseif s[1] == "Ns" && length(s) >= 2
                    # Specular exponent
                    current_material.shininess = parse(Float32, s[2])
                elseif s[1] == "map_Kd"
                    # Load texture
                    texture_path = joinpath(dirname(mtl_path), s[2])
                    if isfile(texture_path)
                        texture = load_texture(texture_path)
                        current_material.textures[TEXTURE_TYPE_DIFFUSE] = texture
                    else
                        @warn "Texture file not found: $texture_path"
                    end
                end
            end
        end

        close(f)
    end

    function parse_face(parser::FastObjParser)::Tuple{Vector{Vector{Int}}, Vector{Vector{Int}}, Vector{Vector{Int}}}
        faces = Vector{Vector{Int}}()
        face_texcoords = Vector{Vector{Int}}()
        face_normals = Vector{Vector{Int}}()
        
        # Skip whitespace before face definition
        while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
            parser.pos += 1
        end
        
        if parser.pos > length(parser.data)
            return faces, face_texcoords, face_normals
        end
        
        # Parse all vertices for this face
        vertices = Int[]
        texcoords = Int[]
        normals = Int[]
        
        while parser.pos <= length(parser.data) && !isspace(Char(parser.data[parser.pos]))
            # Parse vertex index
            v_idx = parse_int(parser)
            if v_idx === nothing
                break
            end
            
            # Handle negative indices (relative to current position)
            if v_idx < 0
                v_idx = length(parser.vertices) + v_idx + 1
            end
            
            # Add vertex index
            push!(vertices, v_idx)
            
            # Check for texture coordinate and normal indices
            if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('/')
                parser.pos += 1
                
                # Parse texture coordinate index if present
                if parser.pos <= length(parser.data) && !isspace(Char(parser.data[parser.pos])) && parser.data[parser.pos] != UInt8('/')
                    vt_idx = parse_int(parser)
                    if vt_idx !== nothing
                        if vt_idx < 0
                            vt_idx = length(parser.texcoords) + vt_idx + 1
                        end
                        push!(texcoords, vt_idx)
                    end
                end
                
                # Parse normal index if present
                if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('/')
                    parser.pos += 1
                    if parser.pos <= length(parser.data) && !isspace(Char(parser.data[parser.pos]))
                        vn_idx = parse_int(parser)
                        if vn_idx !== nothing
                            if vn_idx < 0
                                vn_idx = length(parser.normals) + vn_idx + 1
                            end
                            push!(normals, vn_idx)
                        end
                    end
                end
            end
        end
        
        println("Parsed face with $(length(vertices)) vertices")
        println("Vertex indices: $vertices")
        println("Texture coordinate indices: $texcoords")
        println("Normal indices: $normals")
        
        # Triangulate the face using triangle fan approach
        if length(vertices) >= 3
            # For each vertex after the first two, create a triangle with the first vertex
            for i in 2:(length(vertices)-1)
                # Create triangle using first vertex and current edge
                triangle = [vertices[1], vertices[i], vertices[i+1]]
                push!(faces, triangle)
                println("Created triangle: $triangle")
                
                # Add corresponding texture coordinates if available
                if !isempty(texcoords)
                    tex_triangle = [texcoords[1], texcoords[i], texcoords[i+1]]
                    push!(face_texcoords, tex_triangle)
                    println("Added texture coordinates: $tex_triangle")
                end
                
                # Add corresponding normals if available
                if !isempty(normals)
                    normal_triangle = [normals[1], normals[i], normals[i+1]]
                    push!(face_normals, normal_triangle)
                    println("Added normal indices: $normal_triangle")
                end
            end
        else
            @warn "Face has less than 3 vertices, skipping"
        end
        
        println("Created $(length(faces)) triangles from face")
        return faces, face_texcoords, face_normals
    end
end 