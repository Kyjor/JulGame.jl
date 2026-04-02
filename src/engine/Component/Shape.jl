module ShapeModule
    using ..Component.JulGame
    import ..Component
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

        parentTransform = this.parent.transform

        S = (this.isWorldEntity && camera !== nothing) ? JulGame.pixels_per_world_unit(camera) : JulGame.SCALE_UNITS
        cameraDiff = this.isWorldEntity && camera !== nothing ? 
        Math.Vector2((camera.position.x + camera.offset.x) * S, (camera.position.y + camera.offset.y) * S) : 
        Math.Vector2(0,0)
        position = this.isWorldEntity ?
        parentTransform.position :
        this.position

        # Convert coordinates to Int32 for SDL
        x = Math.TypeConversions.safe_int32_convert(round((position.x + this.offset.x) * S - cameraDiff.x - (parentTransform.scale.x * S - S) / 2))
        y = Math.TypeConversions.safe_int32_convert(round((position.y + this.offset.y) * S - cameraDiff.y - (parentTransform.scale.y * S - S) / 2))
        w = Math.TypeConversions.safe_int32_convert(round(parentTransform.scale.x * S))
        h = Math.TypeConversions.safe_int32_convert(round(parentTransform.scale.y * S))
        
        outlineRect = Ref(SDL2.SDL_FRect(x, y, w, h))

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
