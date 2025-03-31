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
                face = Int[]
                face_tex = Int[]
                face_norm = Int[]
                
                # Parse face indices
                while parser.pos <= length(parser.data) && !isspace(Char(parser.data[parser.pos]))
                    # Vertex index
                    v_idx = parse_int(parser)
                    push!(face, v_idx)
                    
                    # Check for texture coordinate and normal
                    if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('/')
                        parser.pos += 1
                        if parser.pos <= length(parser.data) && parser.data[parser.pos] != UInt8('/')
                            t_idx = parse_int(parser)
                            push!(face_tex, t_idx)
                        end
                        
                        if parser.pos <= length(parser.data) && parser.data[parser.pos] == UInt8('/')
                            parser.pos += 1
                            n_idx = parse_int(parser)
                            push!(face_norm, n_idx)
                        end
                    end
                end
                
                if !isempty(face)
                    push!(parser.faces, face)
                    if !isempty(face_tex)
                        push!(parser.face_texcoords, face_tex)
                    end
                    if !isempty(face_norm)
                        push!(parser.face_normals, face_norm)
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

    function parse_int(parser::FastObjParser)::Int
        # Skip whitespace
        while parser.pos <= length(parser.data) && isspace(Char(parser.data[parser.pos]))
            parser.pos += 1
        end
        
        # Find the end of the number
        end_pos = parser.pos
        while end_pos <= length(parser.data) && !isspace(Char(parser.data[end_pos])) && parser.data[end_pos] != UInt8('/')
            end_pos += 1
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
            elseif s[1] == "map_Kd" && current_material !== nothing
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

        close(f)
    end
end 