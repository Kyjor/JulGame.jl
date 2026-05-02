module ShapeModule
    using ..Component.JulGame
    import ..Component

    @inline _shape_round_to_i32(x::Float64)::Int32 =
        Math.TypeConversions.safe_int32_convert(Base.round(x)::Float64)

    export Shape
    struct Shape
        color::Math.Vector3
        isFilled::Bool
        isWorldEntity::Bool
        layer::Int
        offset::Math.Vector2f
        position::Math.Vector2f
        size::Math.Vector2f
        alpha::Int # 0-255
    end

    export InternalShape
    mutable struct InternalShape
        position::Math.Vector2f
        isFilled::Bool
        isWorldEntity::Bool
        layer::Int
        color::Math.Vector3
        alpha::Int # 0-255
        offset::Math.Vector2f
        parent::JulGame.IEntity
        size::Math.Vector2f
        
        function InternalShape(parent::Any, color::Math.Vector3 = Math.Vector3(255,0,0), isFilled::Bool = true, offset::Math.Vector2f = Math.Vector2f(0,0), size::Math.Vector2f = Math.Vector2f(1,1); isWorldEntity::Bool = true, position::Math.Vector2f = Math.Vector2f(0,0), layer::Int = 0, alpha::Int = 255)
            this = new()
            
            this.color = color
            this.size = size
            this.isFilled = isFilled
            this.isWorldEntity = isWorldEntity
            this.layer = layer
            this.offset = offset
            this.parent = parent
            this.position = position
            this.alpha = alpha

            return this
        end
    end

    function Shape(layer::Int = 0, alpha::Int = 255)
        # Convert layer and alpha to Int32
        layer = Math.TypeConversions.safe_int32_convert(layer)
        alpha = Math.TypeConversions.safe_int32_convert(alpha)
        
        return new(layer, alpha)
    end

    function Component.draw(this::InternalShape, camera = nothing)
        if JulGame.Renderer::Ptr{SDL2.SDL_Renderer} == C_NULL
            return                    
        end

        tr = getfield(this.parent, :transform)::JulGame.TransformModule.Transform
        pos = getfield(tr, :position)::JulGame.Math._Vector3{Float64}
        scl = getfield(tr, :scale)::JulGame.Math._Vector3{Float64}
        scaleX = getfield(scl, :x)::Float64
        scaleY = getfield(scl, :y)::Float64

        S = ((this.isWorldEntity && camera !== nothing) ? JulGame.pixels_per_world_unit(camera) : JulGame.scale_units())::Float64
        cameraDiff = if this.isWorldEntity && camera !== nothing
            JulGame.Math._Vector2{Int32}(
                Math.TypeConversions.safe_int32_convert((camera.position.x + camera.offset.x) * S),
                Math.TypeConversions.safe_int32_convert((camera.position.y + camera.offset.y) * S),
            )
        else
            JulGame.Math._Vector2{Int32}(0, 0)
        end
        posx::Float64 = this.isWorldEntity ? getfield(pos, :x) : getfield(this.position, :x)::Float64
        posy::Float64 = this.isWorldEntity ? getfield(pos, :y) : getfield(this.position, :y)::Float64
        offx = getfield(this.offset, :x)::Float64
        offy = getfield(this.offset, :y)::Float64
        camdx = Float64(getfield(cameraDiff, :x))
        camdy = Float64(getfield(cameraDiff, :y))

        xn = (posx + offx) * S - camdx - (scaleX * S - S) / 2
        yn = (posy + offy) * S - camdy - (scaleY * S - S) / 2
        wn = scaleX * S
        hn = scaleY * S
        xi = _shape_round_to_i32(xn)::Int32
        yi = _shape_round_to_i32(yn)::Int32
        wi = _shape_round_to_i32(wn)::Int32
        hi = _shape_round_to_i32(hn)::Int32
        outlineRect = Ref(SDL2.SDL_FRect(Float64(xi), Float64(yi), Float64(wi), Float64(hi)))

        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(0)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)

        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.color.x, this.color.y, this.color.z, this.alpha);      
        this.isFilled ? SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, outlineRect) : SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, outlineRect);
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
    end

    function Component.duplicate(this::InternalShape, parent::Any)
        newShape = InternalShape(parent, this.color, this.isFilled, this.offset, this.size, isWorldEntity=this.isWorldEntity, position=this.position, layer=this.layer, alpha=this.alpha)
        return newShape
    end
end
