module SoftwareRenderer3DModule
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component
    using ..JulGame.InputModule
    
    # Import MeshIO and FileIO for 3D file loading
        using FileIO, MeshIO
        using GeometryBasics
        global MESHIO_AVAILABLE = true
    

    export SoftwareRenderer3D, Vec3D, Mat4x4, Triangle3D, Vertex3D, RenderBox, RenderMesh, load_mesh_from_file!

    # 3D Vector structure
    mutable struct Vec3D
        x::Float64
        y::Float64
        z::Float64
        w::Float64

        function Vec3D(x::Number = 0.0, y::Number = 0.0, z::Number = 0.0, w::Number = 1.0)
            new(convert(Float64, x), convert(Float64, y), convert(Float64, z), convert(Float64, w))
        end
    end

    # Vector operations
    Base.:+(a::Vec3D, b::Vec3D) = Vec3D(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
    Base.:-(a::Vec3D, b::Vec3D) = Vec3D(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
    Base.:*(a::Vec3D, s::Number) = Vec3D(a.x * s, a.y * s, a.z * s, a.w * s)
    Base.:*(s::Number, a::Vec3D) = a * s
    Base.:-(a::Vec3D) = Vec3D(-a.x, -a.y, -a.z, -a.w)

    function dot(a::Vec3D, b::Vec3D)::Float64
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
    end

    function length_of(v::Vec3D)::Float64
        return sqrt(v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w)
    end

    function normalize(v::Vec3D, new_length::Float64 = 1.0)::Vec3D
        len = length_of(v)
        if len == 0.0
            return Vec3D(0, 0, 0, 0)
        end
        return v * (new_length / len)
    end

    function min_pairwise(a::Vec3D, b::Vec3D)::Vec3D
        return Vec3D(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z), min(a.w, b.w))
    end

    function max_pairwise(a::Vec3D, b::Vec3D)::Vec3D
        return Vec3D(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z), max(a.w, b.w))
    end

    # 4x4 Matrix structure
    mutable struct Mat4x4
        rows::Vector{Vec3D}

        function Mat4x4()
            new([Vec3D(1, 0, 0, 0), Vec3D(0, 1, 0, 0), Vec3D(0, 0, 1, 0), Vec3D(0, 0, 0, 1)])
        end

        function Mat4x4(r1::Vec3D, r2::Vec3D, r3::Vec3D, r4::Vec3D)
            new([r1, r2, r3, r4])
        end
    end

    # Matrix operations
    function Base.:*(m::Mat4x4, v::Vec3D)::Vec3D
        return Vec3D(
            dot(m.rows[1], v),
            dot(m.rows[2], v),
            dot(m.rows[3], v),
            dot(m.rows[4], v)
        )
    end

    function Base.:*(a::Mat4x4, b::Mat4x4)::Mat4x4
        # Get columns of b
        col1 = Vec3D(b.rows[1].x, b.rows[2].x, b.rows[3].x, b.rows[4].x)
        col2 = Vec3D(b.rows[1].y, b.rows[2].y, b.rows[3].y, b.rows[4].y)
        col3 = Vec3D(b.rows[1].z, b.rows[2].z, b.rows[3].z, b.rows[4].z)
        col4 = Vec3D(b.rows[1].w, b.rows[2].w, b.rows[3].w, b.rows[4].w)

        return Mat4x4(
            Vec3D(dot(a.rows[1], col1), dot(a.rows[1], col2), dot(a.rows[1], col3), dot(a.rows[1], col4)),
            Vec3D(dot(a.rows[2], col1), dot(a.rows[2], col2), dot(a.rows[2], col3), dot(a.rows[2], col4)),
            Vec3D(dot(a.rows[3], col1), dot(a.rows[3], col2), dot(a.rows[3], col3), dot(a.rows[3], col4)),
            Vec3D(dot(a.rows[4], col1), dot(a.rows[4], col2), dot(a.rows[4], col3), dot(a.rows[4], col4))
        )
    end

    # Matrix creation functions
    function translation_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(1, 0, 0, x),
            Vec3D(0, 1, 0, y),
            Vec3D(0, 0, 1, z),
            Vec3D(0, 0, 0, 1)
        )
    end

    function scaling_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(x, 0, 0, 0),
            Vec3D(0, y, 0, 0),
            Vec3D(0, 0, z, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function x_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(1, 0, 0, 0),
            Vec3D(0, c, -s, 0),
            Vec3D(0, s, c, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function y_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(c, 0, s, 0),
            Vec3D(0, 1, 0, 0),
            Vec3D(-s, 0, c, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function z_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(c, -s, 0, 0),
            Vec3D(s, c, 0, 0),
            Vec3D(0, 0, 1, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function rotation_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return x_rotation_matrix(x) * y_rotation_matrix(y) * z_rotation_matrix(z)
    end

    function viewport_matrix(width::Float64, height::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(width / 2.0, 0, 0, width / 2.0),
            Vec3D(0, -height / 2.0, 0, height / 2.0),
            Vec3D(0, 0, -1, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function perspective_matrix(fov::Float64, aspect::Float64, near::Float64, far::Float64)::Mat4x4
        f = 1.0 / tan(fov / 2.0)
        nf = 1.0 / (near - far)
        return Mat4x4(
            Vec3D(f / aspect, 0, 0, 0),
            Vec3D(0, f, 0, 0),
            Vec3D(0, 0, (far + near) * nf, 2 * far * near * nf),
            Vec3D(0, 0, -1, 0)
        )
    end

    # Vertex structure for rendering
    mutable struct Vertex3D
        x::Float64
        y::Float64
        z::Float64
        color::SDL_Color
        u::Float64
        v::Float64

        function Vertex3D(x::Float64, y::Float64, z::Float64, color::SDL_Color, u::Float64 = 0.0, v::Float64 = 0.0)
            new(x, y, z, color, u, v)
        end
    end

    # Triangle structure
    mutable struct Triangle3D
        vertices::Vector{Vertex3D}

        function Triangle3D(v1::Vertex3D, v2::Vertex3D, v3::Vertex3D)
            new([v1, v2, v3])
        end
    end

    # AABB structure
    mutable struct AABB
        min::Vec3D
        max::Vec3D

        function AABB(min::Vec3D, max::Vec3D)
            new(min, max)
        end
    end

    # Render state
    mutable struct RenderState
        transform::Mat4x4
        fill_color::SDL_Color
        stroke_color::SDL_Color

        function RenderState()
            new(Mat4x4(), SDL_Color(255, 255, 255, 255), SDL_Color(0, 0, 0, 255))
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

    # Material for faces
    mutable struct RenderMaterial
        diffuse_color::Vec3D
        ambient_color::Vec3D
        specular_color::Vec3D
        alpha::Float64
        
        function RenderMaterial(diffuse::Vec3D = Vec3D(0.8, 0.8, 0.8), 
                               ambient::Vec3D = Vec3D(0.2, 0.2, 0.2), 
                               specular::Vec3D = Vec3D(0.0, 0.0, 0.0), 
                               alpha::Float64 = 1.0)
            new(diffuse, ambient, specular, alpha)
        end
    end

    # Face with material information
    mutable struct MaterialFace
        vertex_indices::Vector{Int}
        material_name::String
        
        function MaterialFace(indices::Vector{Int}, material::String = "default")
            new(indices, material)
        end
    end

    # Mesh structure for rendering loaded 3D files
    mutable struct RenderMesh
        vertices::Vector{Vec3D}
        faces::Vector{MaterialFace}  # Each face has material information
        materials::Dict{String, RenderMaterial}
        use_materials::Bool
        position::Vec3D
        rotation::Vec3D
        scale::Vec3D
        default_fill_color::SDL_Color
        default_stroke_color::SDL_Color
        file_path::String

        function RenderMesh(file_path::String = "", 
                           position::Vec3D = Vec3D(0, 0, 0), 
                           rotation::Vec3D = Vec3D(0, 0, 0),
                           scale::Vec3D = Vec3D(1, 1, 1),
                           fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                           stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))
            new(Vec3D[], MaterialFace[], Dict{String, RenderMaterial}(), false, position, rotation, scale, fill_color, stroke_color, file_path)
        end
    end

    # Main Software Renderer component
    mutable struct SoftwareRenderer3D
        parent
        layer::Int
        isWorldEntity::Bool
        
        # Rendering properties
        triangles::Vector{Triangle3D}
        state::RenderState
        state_stack::Vector{RenderState}
        boxes::Vector{RenderBox}
        meshes::Vector{RenderMesh}
        
        # Camera properties
        camera_position::Vec3D
        camera_rotation::Vec3D
        camera_zoom::Vec3D
        perspective_enabled::Bool
        reverse_sort_triangles::Bool
        
        # Projection properties
        fov::Float64
        aspect_ratio::Float64
        near::Float64
        far::Float64

        function SoftwareRenderer3D()
            this = new()
            this.parent = C_NULL
            this.layer = 0
            this.isWorldEntity = true
            
            this.triangles = Triangle3D[]
            this.state = RenderState()
            this.state_stack = RenderState[]
            this.boxes = RenderBox[]
            this.meshes = RenderMesh[]
            
            this.camera_position = Vec3D(0, 0, 0)
            this.camera_rotation = Vec3D(0, 0, 0)
            this.camera_zoom = Vec3D(1, 1, 1)
            this.perspective_enabled = true
            this.reverse_sort_triangles = false
            
            this.fov = π / 3.0  # 60 degrees
            this.aspect_ratio = 1.0
            this.near = 1.0 / 1024.0
            this.far = 1024.0
            
            return this
        end
    end

    # Perspective divide
    function perspective_divide!(v::Vec3D)
        if v.w != 0.0
            v.x /= v.w
            v.y /= v.w
            v.z /= v.w
            v.w = 1.0
        end
    end

    # Add triangle to render queue
    function add_triangle!(renderer::SoftwareRenderer3D, color::SDL_Color, 
                          a::Vec3D, b::Vec3D, c::Vec3D,
                          u1::Float64 = 0.0, v1::Float64 = 0.0,
                          u2::Float64 = 0.0, v2::Float64 = 0.0,
                          u3::Float64 = 0.0, v3::Float64 = 0.0)::AABB
        
        if color.a == 0
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Transform vertices
        ta = renderer.state.transform * a
        tb = renderer.state.transform * b
        tc = renderer.state.transform * c
        
        # Check if behind camera
        if ta.w <= 0 || tb.w <= 0 || tc.w <= 0
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Perspective divide
        perspective_divide!(ta)
        perspective_divide!(tb)
        perspective_divide!(tc)
        
        # Frustum culling (basic)
        windowSize = JulGame.MAIN.windowManager.windowSize
        width = windowSize.x
        height = windowSize.y
        
        if (ta.x < 0 && tb.x < 0 && tc.x < 0) ||
           (ta.x > width && tb.x > width && tc.x > width) ||
           (ta.y < 0 && tb.y < 0 && tc.y < 0) ||
           (ta.y > height && tb.y > height && tc.y > height)
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Create triangle
        triangle = Triangle3D(
            Vertex3D(ta.x, ta.y, ta.z, color, u1, v1),
            Vertex3D(tb.x, tb.y, tb.z, color, u2, v2),
            Vertex3D(tc.x, tc.y, tc.z, color, u3, v3)
        )
        
        push!(renderer.triangles, triangle)
        
        return AABB(min_pairwise(ta, min_pairwise(tb, tc)), max_pairwise(ta, max_pairwise(tb, tc)))
    end

    # Add rectangle
    function add_fill_rectangle!(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D, d::Vec3D)::AABB
        aabb1 = add_triangle!(renderer, renderer.state.fill_color, a, b, c, 0.0, 0.0, 0.5, 0.0, 0.5, 0.5)
        aabb2 = add_triangle!(renderer, renderer.state.fill_color, d, a, c, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5)
        return AABB(min_pairwise(aabb1.min, aabb2.min), max_pairwise(aabb1.max, aabb2.max))
    end

    function add_stroke_rectangle!(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D, d::Vec3D)::AABB
        aabb1 = add_triangle!(renderer, renderer.state.stroke_color, a, b, c, 0.5, 0.5, 1.0, 0.5, 1.0, 1.0)
        aabb2 = add_triangle!(renderer, renderer.state.stroke_color, d, a, c, 0.5, 1.0, 0.5, 0.5, 1.0, 1.0)
        return AABB(min_pairwise(aabb1.min, aabb2.min), max_pairwise(aabb1.max, aabb2.max))
    end

    # Add box
    function add_box!(renderer::SoftwareRenderer3D, box::RenderBox)::AABB
        # Box vertices
        p1 = Vec3D(-0.5, +0.5, +0.5, 1.0)
        p2 = Vec3D(+0.5, +0.5, +0.5, 1.0)
        p3 = Vec3D(+0.5, -0.5, +0.5, 1.0)
        p4 = Vec3D(-0.5, -0.5, +0.5, 1.0)
        p5 = Vec3D(-0.5, +0.5, -0.5, 1.0)
        p6 = Vec3D(+0.5, +0.5, -0.5, 1.0)
        p7 = Vec3D(+0.5, -0.5, -0.5, 1.0)
        p8 = Vec3D(-0.5, -0.5, -0.5, 1.0)
        
        # Save current state
        old_fill = renderer.state.fill_color
        old_stroke = renderer.state.stroke_color
        old_transform = renderer.state.transform
        
        # Apply box transformation
        renderer.state.fill_color = box.fill_color
        renderer.state.stroke_color = box.stroke_color
        
        # Apply transformations
        box_transform = translation_matrix(box.position.x, box.position.y, box.position.z) *
                       rotation_matrix(box.rotation.x, box.rotation.y, box.rotation.z) *
                       scaling_matrix(box.dimensions.x, box.dimensions.y, box.dimensions.z)
        
        renderer.state.transform = old_transform * box_transform
        
        # Add faces
        aabb = AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        
        # Fill faces
        faces = [
            (p1, p2, p3, p4),  # front
            (p2, p6, p7, p3),  # right
            (p6, p5, p8, p7),  # back
            (p5, p1, p4, p8),  # left
            (p5, p6, p2, p1),  # top
            (p4, p3, p7, p8)   # bottom
        ]
        
        for face in faces
            face_aabb = add_fill_rectangle!(renderer, face[1], face[2], face[3], face[4])
            aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
        end
        
        # Stroke faces
        for face in faces
            face_aabb = add_stroke_rectangle!(renderer, face[1], face[2], face[3], face[4])
            aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
        end
        
        # Restore state
        renderer.state.fill_color = old_fill
        renderer.state.stroke_color = old_stroke
        renderer.state.transform = old_transform
        
        return aabb
    end

    # Helper function to convert Vec3D color to SDL_Color
    function vec3d_to_sdl_color(color::Vec3D, alpha::Float64 = 1.0)::SDL_Color
        r = clamp(round(Int, color.x * 255), 0, 255)
        g = clamp(round(Int, color.y * 255), 0, 255)
        b = clamp(round(Int, color.z * 255), 0, 255)
        a = clamp(round(Int, alpha * 255), 0, 255)
        return SDL_Color(r, g, b, a)
    end

    # Parse OBJ file to extract material usage per face
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
                @info "OBJ: Switching to material '$current_material'"
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
        
        @info "OBJ: Parsed material assignments for $(length(face_materials)) faces"
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
            end
        end
        
        # Save last material
        if current_material !== nothing && current_name != ""
            materials[current_name] = current_material
        end
        
        return materials
    end

    # Load mesh from file using MeshIO
    function load_mesh_from_file!(renderer::SoftwareRenderer3D, file_path::String, 
                                 position::Vec3D = Vec3D(0, 0, 0),
                                 rotation::Vec3D = Vec3D(0, 0, 0),
                                 scale::Vec3D = Vec3D(1, 1, 1),
                                 fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                 stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))::Union{RenderMesh, Nothing}
        
        if !MESHIO_AVAILABLE
            @error "MeshIO not available. Cannot load 3D files. Install with: using Pkg; Pkg.add([\"FileIO\", \"MeshIO\"])"
            return nothing
        end
        
        if !isfile(file_path)
            @error "Mesh file not found: $file_path"
            return nothing
        end
        
        try
            # Load the mesh using FileIO/MeshIO
            mesh_data = load(file_path)
            println(mesh_data)
            # Create our RenderMesh
            render_mesh = RenderMesh(file_path, position, rotation, scale, fill_color, stroke_color)
            
            # Check if this is a MetaMesh with material support (OBJ files)
            face_materials = Dict{Int, String}()
            
            # Try to extract materials from MetaMesh if available
            if isa(mesh_data, GeometryBasics.MetaMesh) && haskey(mesh_data, :materials)
                @info "Found materials in MetaMesh"
                
                # Extract materials from MetaMesh
                for (material_name, material_data) in mesh_data[:materials]
                    material = RenderMaterial()
                    
                    # Extract diffuse color
                    if haskey(material_data, "diffuse")
                        diffuse = material_data["diffuse"]
                        if isa(diffuse, AbstractVector) && length(diffuse) >= 3
                            material.diffuse_color = Vec3D(diffuse[1], diffuse[2], diffuse[3])
                        end
                    end
                    
                    # Extract ambient color
                    if haskey(material_data, "ambient")
                        ambient = material_data["ambient"]
                        if isa(ambient, AbstractVector) && length(ambient) >= 3
                            material.ambient_color = Vec3D(ambient[1], ambient[2], ambient[3])
                        end
                    end
                    
                    # Extract specular color
                    if haskey(material_data, "specular")
                        specular = material_data["specular"]
                        if isa(specular, AbstractVector) && length(specular) >= 3
                            material.specular_color = Vec3D(specular[1], specular[2], specular[3])
                        end
                    end
                    
                    render_mesh.materials[string(material_name)] = material
                    @info "Material '$material_name': diffuse=$(material.diffuse_color)"
                end
                
                # Extract material assignments per submesh
                if haskey(mesh_data, :material_names)
                    material_names = mesh_data[:material_names]
                    @info "Found material assignments: $material_names"
                    
                    # Split the mesh to get submeshes with their materials
                    submeshes = GeometryBasics.split_mesh(mesh_data.mesh)
                    @info "Split mesh into $(length(submeshes)) submeshes"
                    
                    # Process each submesh with its material
                    face_counter = 0
                    for (i, submesh) in enumerate(submeshes)
                        material_name = string(material_names[i])
                        @info "Processing submesh $i with material '$material_name'"
                        
                        # Add vertices for this submesh
                        vertex_offset = length(render_mesh.vertices)
                        vertices = GeometryBasics.coordinates(submesh)
                        for vertex in vertices
                            if length(vertex) >= 3
                                push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                            else
                                push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                            end
                        end
                        
                        # Add faces for this submesh with material assignment
                        faces = GeometryBasics.faces(submesh)
                        for face in faces
                            face_indices = Int[]
                            if isa(face, GeometryBasics.TriangleFace)
                                push!(face_indices, convert(Int, face[1]) + vertex_offset, convert(Int, face[2]) + vertex_offset, convert(Int, face[3]) + vertex_offset)
                                push!(render_mesh.faces, MaterialFace(face_indices, material_name))
                            elseif isa(face, GeometryBasics.QuadFace)
                                # Split quad into two triangles
                                push!(face_indices, convert(Int, face[1]) + vertex_offset, convert(Int, face[2]) + vertex_offset, convert(Int, face[3]) + vertex_offset)
                                push!(render_mesh.faces, MaterialFace(copy(face_indices), material_name))
                                face_indices = [convert(Int, face[1]) + vertex_offset, convert(Int, face[3]) + vertex_offset, convert(Int, face[4]) + vertex_offset]
                                push!(render_mesh.faces, MaterialFace(face_indices, material_name))
                            end
                        end
                    end
                    
                    render_mesh.use_materials = !isempty(render_mesh.materials)
                    @info "Successfully loaded $(length(render_mesh.materials)) materials with proper assignments"
                    
                    # Skip the normal mesh processing since we handled it above
                    if !isempty(render_mesh.vertices) && !isempty(render_mesh.faces)
                        push!(renderer.meshes, render_mesh)
                        @info "Successfully loaded mesh from $file_path: $(length(render_mesh.vertices)) vertices, $(length(render_mesh.faces)) faces"
                        return render_mesh
                    end
                end
            else
                @info "No materials found in mesh data, using fallback material loading"
                
                # Fallback: Try to load materials from MTL file and parse OBJ for material usage
                mtl_path = splitext(file_path)[1] * ".mtl"
                
                if isfile(mtl_path)
                    @info "Loading materials from $mtl_path"
                    render_mesh.materials = parse_mtl_file(mtl_path)
                    render_mesh.use_materials = !isempty(render_mesh.materials)
                    @info "Parsed $(length(render_mesh.materials)) materials"
                    for (name, material) in render_mesh.materials
                        @info "Material '$name': diffuse=($(material.diffuse_color.x), $(material.diffuse_color.y), $(material.diffuse_color.z))"
                    end
                    
                    # Parse OBJ file for material usage if it's an OBJ file
                    if lowercase(splitext(file_path)[2]) == ".obj"
                        face_materials = parse_obj_materials(file_path)
                    end
                else
                    @info "No material file found (looked for: $mtl_path)"
                    render_mesh.use_materials = false
                end
            end
            
            # Extract vertices and faces based on mesh type
            if isa(mesh_data, GeometryBasics.Mesh)
                # Standard GeometryBasics Mesh
                vertices = GeometryBasics.coordinates(mesh_data)
                faces = GeometryBasics.faces(mesh_data)
                
                # Convert vertices to our Vec3D format
                for vertex in vertices
                    # Handle different vertex types
                    if length(vertex) >= 3
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), Float64(vertex[3])))
                    else
                        push!(render_mesh.vertices, Vec3D(Float64(vertex[1]), Float64(vertex[2]), 0.0))
                    end
                end
                
                                                    # Convert faces to our format
                face_counter = 0
                for face in faces
                    # Convert to 1-based indexing and handle different face types
                    face_indices = Int[]
                    if isa(face, GeometryBasics.TriangleFace)
                        push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                        face_counter += 1
                        material_name = get(face_materials, face_counter, "default")
                        push!(render_mesh.faces, MaterialFace(face_indices, material_name))
                    elseif isa(face, GeometryBasics.QuadFace)
                        # Split quad into two triangles
                        push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                        face_counter += 1
                        material_name = get(face_materials, face_counter, "default")
                        push!(render_mesh.faces, MaterialFace(copy(face_indices), material_name))
                        face_indices = [convert(Int, face[1]), convert(Int, face[3]), convert(Int, face[4])]
                        face_counter += 1
                        material_name = get(face_materials, face_counter, "default")
                        push!(render_mesh.faces, MaterialFace(face_indices, material_name))
                        continue
                    else
                        # Generic face - try to extract indices
                        for i in 1:length(face)
                            push!(face_indices, convert(Int, face[i]))
                        end
                        # If more than 3 vertices, triangulate (simple fan triangulation)
                        if length(face_indices) > 3
                            for i in 2:(length(face_indices)-1)
                                triangle_indices = [face_indices[1], face_indices[i], face_indices[i+1]]
                                face_counter += 1
                                material_name = get(face_materials, face_counter, "default")
                                push!(render_mesh.faces, MaterialFace(triangle_indices, material_name))
                            end
                            continue
                        else
                            face_counter += 1
                            material_name = get(face_materials, face_counter, "default")
                            push!(render_mesh.faces, MaterialFace(face_indices, material_name))
                        end
                    end
                end
                
            elseif isa(mesh_data, GeometryBasics.MetaMesh)
                # Handle MetaMesh format (common for OBJ files with materials/groups)
                @info "Loading MetaMesh format"
                
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
                                # Handle GLIndex conversion properly
                                push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                            elseif isa(face, GeometryBasics.QuadFace)
                                # Split quad into two triangles
                                push!(face_indices, convert(Int, face[1]), convert(Int, face[2]), convert(Int, face[3]))
                                push!(render_mesh.faces, MaterialFace(copy(face_indices), "default"))
                                face_indices = [convert(Int, face[1]), convert(Int, face[3]), convert(Int, face[4])]
                            else
                                # Generic face - try to extract indices
                                for i in 1:length(face)
                                    push!(face_indices, convert(Int, face[i]))
                                end
                                # If more than 3 vertices, triangulate (simple fan triangulation)
                                if length(face_indices) > 3
                                    for i in 2:(length(face_indices)-1)
                                        triangle_indices = [face_indices[1], face_indices[i], face_indices[i+1]]
                                        push!(render_mesh.faces, MaterialFace(triangle_indices, "default"))
                                    end
                                    continue
                                end
                            end
                            push!(render_mesh.faces, MaterialFace(face_indices, "default"))
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
                            push!(render_mesh.faces, MaterialFace(face_indices, "default"))
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
                        push!(render_mesh.faces, MaterialFace(face_indices, "default"))
                    elseif length(face_indices) == 4
                        # Split quad into two triangles
                        push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[2], face_indices[3]], "default"))
                        push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[3], face_indices[4]], "default"))
                    else
                        # Triangulate polygon using fan method
                        for i in 2:(length(face_indices)-1)
                            push!(render_mesh.faces, MaterialFace([face_indices[1], face_indices[i], face_indices[i+1]], "default"))
                        end
                    end
                end
            else
                @error "Unsupported mesh format for file: $file_path"
                return nothing
            end
            
            # Add to renderer
            push!(renderer.meshes, render_mesh)
            
            @info "Successfully loaded mesh from $file_path: $(length(render_mesh.vertices)) vertices, $(length(render_mesh.faces)) faces"
            return render_mesh
            
        catch e
            @error "Failed to load mesh from $file_path: $e"
            return nothing
        end
    end

    # Render a mesh
    function add_mesh!(renderer::SoftwareRenderer3D, mesh::RenderMesh)::AABB
        if isempty(mesh.vertices) || isempty(mesh.faces)
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Save current state
        old_fill = renderer.state.fill_color
        old_stroke = renderer.state.stroke_color
        old_transform = renderer.state.transform
        
        # Apply mesh transformation
        renderer.state.fill_color = mesh.default_fill_color
        renderer.state.stroke_color = mesh.default_stroke_color
        
        # Apply transformations
        mesh_transform = translation_matrix(mesh.position.x, mesh.position.y, mesh.position.z) *
                        rotation_matrix(mesh.rotation.x, mesh.rotation.y, mesh.rotation.z) *
                        scaling_matrix(mesh.scale.x, mesh.scale.y, mesh.scale.z)
        
        renderer.state.transform = old_transform * mesh_transform
        
        # Render all faces
        aabb = AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        
        for face in mesh.faces
            if length(face.vertex_indices) >= 3
                # Get vertices for this face
                v1 = mesh.vertices[face.vertex_indices[1]]
                v2 = mesh.vertices[face.vertex_indices[2]]
                v3 = mesh.vertices[face.vertex_indices[3]]
                
                # Determine color to use
                face_color = renderer.state.fill_color
                if mesh.use_materials && haskey(mesh.materials, face.material_name)
                    material = mesh.materials[face.material_name]
                    face_color = vec3d_to_sdl_color(material.diffuse_color, material.alpha)
                    # Debug: only print for first few faces to avoid spam
                    if length(renderer.triangles) < 3
                        @info "Using material '$(face.material_name)' with color $(material.diffuse_color)"
                    end
                else
                    # Debug: only print for first few faces to avoid spam
                    if length(renderer.triangles) < 3
                        @info "No material found for face material '$(face.material_name)', using default color"
                    end
                end
                
                # Add triangle with material color
                face_aabb = add_triangle!(renderer, face_color, v1, v2, v3)
                aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
            end
        end
        
        # Restore state
        renderer.state.fill_color = old_fill
        renderer.state.stroke_color = old_stroke
        renderer.state.transform = old_transform
        
        return aabb
    end

    # Push/pop state
    function push_state!(renderer::SoftwareRenderer3D)
        push!(renderer.state_stack, RenderState())
        renderer.state_stack[end].transform = renderer.state.transform
        renderer.state_stack[end].fill_color = renderer.state.fill_color
        renderer.state_stack[end].stroke_color = renderer.state.stroke_color
    end

    function pop_state!(renderer::SoftwareRenderer3D)
        if !isempty(renderer.state_stack)
            renderer.state = pop!(renderer.state_stack)
        end
    end

    function apply_transform!(renderer::SoftwareRenderer3D, matrix::Mat4x4)
        renderer.state.transform = renderer.state.transform * matrix
    end

    # Flush triangles (render them)
    function flush_triangles!(renderer::SoftwareRenderer3D)::Int
        if isempty(renderer.triangles)
            return 0
        end
        
        # Sort vertices in each triangle by z
        for triangle in renderer.triangles
            sort!(triangle.vertices, by = v -> v.z)
        end
        
        # Sort triangles by average z
        sort!(renderer.triangles, by = tri -> sum(v.z for v in tri.vertices) / 3)
        
        if renderer.reverse_sort_triangles
            reverse!(renderer.triangles)
        end
        
        # Render triangles using SDL
        triangle_count = 0
        for triangle in renderer.triangles
            vertices = triangle.vertices
            
            # Convert to SDL vertices
            sdl_vertices = [
                SDL_Vertex(SDL_FPoint(vertices[1].x, vertices[1].y), vertices[1].color, SDL_FPoint(vertices[1].u, vertices[1].v)),
                SDL_Vertex(SDL_FPoint(vertices[2].x, vertices[2].y), vertices[2].color, SDL_FPoint(vertices[2].u, vertices[2].v)),
                SDL_Vertex(SDL_FPoint(vertices[3].x, vertices[3].y), vertices[3].color, SDL_FPoint(vertices[3].u, vertices[3].v))
            ]
            
            # Render the geometry
            result = SDL_RenderGeometry(JulGame.Renderer, C_NULL, sdl_vertices, length(sdl_vertices), C_NULL, 0)
            if result < 0
                println("SDL_RenderGeometry failed: ", unsafe_string(SDL_GetError()))
            else
                triangle_count += 1
            end
        end
        
        # Clear triangles
        empty!(renderer.triangles)
        
        return triangle_count
    end

    # Component interface implementations
    function Component.initialize(this::SoftwareRenderer3D, main)
        windowSize = main.windowManager.windowSize
        this.aspect_ratio = windowSize.x / windowSize.y
        
        # Add some default boxes for demonstration
        push!(this.boxes, RenderBox(
            Vec3D(1, 1, 1),
            Vec3D(0, 0, -5),
            Vec3D(0, 0, 0),
            SDL_Color(255, 200, 150, 255),
            SDL_Color(0, 0, 0, 255)
        ))
        
        # Add a ground plane
        push!(this.boxes, RenderBox(
            Vec3D(10, 0.1, 10),
            Vec3D(0, -2, -5),
            Vec3D(0, 0, 0),
            SDL_Color(100, 100, 100, 255),
            SDL_Color(50, 50, 50, 255)
        ))
    end

    function Component.update(this::SoftwareRenderer3D, deltaTime::Float64)
        if !this.parent.isActive
            return
        end

        # Only use internal camera controls if no engine camera is available
        if JulGame.IS_DEBUG && JulGame.MAIN.scene.camera === nothing
            move_speed = 5.0 * deltaTime
            rot_speed = π * deltaTime
            
            # Movement
            if JulGame.InputModule.get_button_held_down("A")
                this.camera_position.x -= move_speed
            elseif JulGame.InputModule.get_button_held_down("D")
                this.camera_position.x += move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("W")
                this.camera_position.z -= move_speed
            elseif JulGame.InputModule.get_button_held_down("S")
                this.camera_position.z += move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("Q")
                this.camera_position.y -= move_speed
            elseif JulGame.InputModule.get_button_held_down("E")
                this.camera_position.y += move_speed
            end
            
            # Rotation
            if JulGame.InputModule.get_button_held_down("Left")
                this.camera_rotation.y += rot_speed
            elseif JulGame.InputModule.get_button_held_down("Right")
                this.camera_rotation.y -= rot_speed
            end
            
            if JulGame.InputModule.get_button_held_down("Up")
                this.camera_rotation.x += rot_speed
            elseif JulGame.InputModule.get_button_held_down("Down")
                this.camera_rotation.x -= rot_speed
            end
            
            # Reset camera
            if JulGame.InputModule.get_button_pressed("R")
                this.camera_position = Vec3D(0, 0, 0)
                this.camera_rotation = Vec3D(0, 0, 0)
                this.camera_zoom = Vec3D(1, 1, 1)
            end
        end
        
        # Handle perspective toggle regardless of camera system
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("P")
            this.perspective_enabled = !this.perspective_enabled
            this.reverse_sort_triangles = !this.perspective_enabled
        end
        
        # Animate the first box
        if !isempty(this.boxes)
            this.boxes[1].rotation.y += π * deltaTime
            this.boxes[1].rotation.x += π * 0.5 * deltaTime
        end
    end

    function Component.render(this::SoftwareRenderer3D, main)
        windowSize = main.windowManager.windowSize
        width = Float64(windowSize.x)
        height = Float64(windowSize.y)
        
        # Clear triangles
        empty!(this.triangles)
        
        # Setup render state
        push_state!(this)
        
        # Apply viewport transform
        apply_transform!(this, viewport_matrix(Float64(width), Float64(height)))
        
        # Apply projection
        if this.perspective_enabled
            apply_transform!(this, perspective_matrix(this.fov, this.aspect_ratio, this.near, this.far))
        else
            # Orthographic projection
            scale = 0.04 * height / width
            apply_transform!(this, scaling_matrix(Float64(scale), Float64(scale), Float64(scale)))
        end
        
        # Use engine's camera if available, otherwise fall back to internal camera
        if main.scene.camera !== nothing
            # Use the engine's camera system (controlled by Manager.jl)
            engine_camera = main.scene.camera
            camera_pos = Vec3D(Float64(engine_camera.position.x), Float64(engine_camera.position.y), Float64(engine_camera.position.z))
            camera_yaw = Float64(engine_camera.yaw)
            camera_pitch = Float64(engine_camera.pitch)
            
            # Convert yaw/pitch to rotation radians
            yaw_rad = deg2rad(camera_yaw)
            pitch_rad = deg2rad(camera_pitch)
            
            # Apply camera transform
            apply_transform!(this, scaling_matrix(Float64(this.camera_zoom.x), Float64(this.camera_zoom.y), 1.0))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, rotation_matrix(-pitch_rad, -yaw_rad, 0.0))
            apply_transform!(this, translation_matrix(-camera_pos.x, -camera_pos.y, -camera_pos.z))
        else
            # Fall back to internal camera system
            apply_transform!(this, scaling_matrix(Float64(this.camera_zoom.x), Float64(this.camera_zoom.y), 1.0))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, rotation_matrix(Float64(-this.camera_rotation.x), Float64(-this.camera_rotation.y), Float64(-this.camera_rotation.z)))
            apply_transform!(this, translation_matrix(Float64(-this.camera_position.x), Float64(-this.camera_position.y), Float64(-this.camera_position.z)))
        end
        
        # Render all boxes
        for box in this.boxes
            add_box!(this, box)
        end
        
        # Render all meshes
        for mesh in this.meshes
            add_mesh!(this, mesh)
        end
        
        pop_state!(this)
        
        # Flush all triangles
        triangle_count = flush_triangles!(this)
        
        if JulGame.IS_DEBUG
            println("Rendered $triangle_count triangles")
        end
    end

    function Component.destroy(this::SoftwareRenderer3D)
        empty!(this.triangles)
        empty!(this.boxes)
        empty!(this.meshes)
        empty!(this.state_stack)
    end

    # Utility functions for users
    function add_box!(renderer::SoftwareRenderer3D, position::Vec3D, dimensions::Vec3D, rotation::Vec3D, 
                     fill_color::SDL_Color, stroke_color::SDL_Color)
        box = RenderBox(dimensions, position, rotation, fill_color, stroke_color)
        push!(renderer.boxes, box)
        return box
    end

    function clear_boxes!(renderer::SoftwareRenderer3D)
        empty!(renderer.boxes)
    end

    function clear_meshes!(renderer::SoftwareRenderer3D)
        empty!(renderer.meshes)
    end

    function clear_all!(renderer::SoftwareRenderer3D)
        empty!(renderer.boxes)
        empty!(renderer.meshes)
    end

    function set_camera_position!(renderer::SoftwareRenderer3D, position::Vec3D)
        renderer.camera_position = position
    end

    function set_camera_rotation!(renderer::SoftwareRenderer3D, rotation::Vec3D)
        renderer.camera_rotation = rotation
    end

    # Convenience function to load and add a mesh in one call
    function add_mesh_from_file!(renderer::SoftwareRenderer3D, file_path::String, 
                                position::Vec3D = Vec3D(0, 0, 0),
                                rotation::Vec3D = Vec3D(0, 0, 0),
                                scale::Vec3D = Vec3D(1, 1, 1),
                                fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))::Union{RenderMesh, Nothing}
        return load_mesh_from_file!(renderer, file_path, position, rotation, scale, fill_color, stroke_color)
    end

    # Get mesh by file path
    function get_mesh_by_path(renderer::SoftwareRenderer3D, file_path::String)::Union{RenderMesh, Nothing}
        for mesh in renderer.meshes
            if mesh.file_path == file_path
                return mesh
            end
        end
        return nothing
    end

    # Remove mesh by file path
    function remove_mesh_by_path!(renderer::SoftwareRenderer3D, file_path::String)::Bool
        for (i, mesh) in enumerate(renderer.meshes)
            if mesh.file_path == file_path
                deleteat!(renderer.meshes, i)
                return true
            end
        end
        return false
    end

end 