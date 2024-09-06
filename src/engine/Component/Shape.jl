module ShapeModule
    using ..Component.JulGame
    import ..Component
    export Shape
    struct Shape
        color::Math.Vector3
        size::Math.Vector2f
        isFilled::Bool
        isWorldEntity::Bool
        offset::Math.Vector2f
        position::Math.Vector2f
    end

    export InternalShape
    mutable struct InternalShape
        color::Math.Vector3
        isFilled::Bool
        isWorldEntity::Bool
        layer::Int32
        offset::Math.Vector2f
        position::Math.Vector2f
        parent::Any # Entity
        size::Math.Vector2f
        
        function InternalShape(parent::Any, size::Math.Vector2f = Math.Vector2f(1,1), color::Math.Vector3 = Math.Vector3(255,0,0), isFilled::Bool = true, offset::Math.Vector2f = Math.Vector2f(0,0); isWorldEntity::Bool = true, position::Math.Vector2f = Math.Vector2f(0,0))
            this = new()
            
            this.color = color
            this.size = size
            this.isFilled = isFilled
            this.isWorldEntity = isWorldEntity
            this.layer = 0
            this.offset = offset
            this.parent = parent
            this.position = position

            return this
        end
    end

    function Component.draw(this::InternalShape)
        if JulGame.Renderer::Ptr{SDL2.SDL_Renderer} == C_NULL
            return                    
        end

        parentTransform = this.parent.transform

        cameraDiff = this.isWorldEntity && MAIN.scene.camera !== nothing ? 
        Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
        Math.Vector2(0,0)
        position = this.isWorldEntity ?
        parentTransform.position :
        this.position

        outlineRect = Ref(SDL2.SDL_FRect(convert(Int32,round((position.x + this.offset.x) * SCALE_UNITS - cameraDiff.x - (parentTransform.scale.x * SCALE_UNITS - SCALE_UNITS) / 2)), 
        convert(Int32,round((position.y + this.offset.y) * SCALE_UNITS - cameraDiff.y - (parentTransform.scale.y * SCALE_UNITS - SCALE_UNITS) / 2)),
        convert(Int32,round(parentTransform.scale.x * SCALE_UNITS)), 
        convert(Int32,round(parentTransform.scale.y * SCALE_UNITS))))
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.color.x, this.color.y, this.color.z, SDL2.SDL_ALPHA_OPAQUE );      

        this.isFilled ? SDL2.SDL_RenderFillRectF( JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, outlineRect) : SDL2.SDL_RenderDrawRectF( JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, outlineRect);
        
    end

    function Component.set_parent(this::InternalShape, parent::Any)
        this.parent = parent
    end
end
