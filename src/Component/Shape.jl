module ShapeModule
    using ..Component.JulGame

    export Shape
    struct Shape
        color::Math.Vector3
        dimensions::Math.Vector2f
        isFilled::Bool
        isWorldEntity::Bool
        offset::Math.Vector2f
        position::Math.Vector2f
    end

    export InternalShape
    mutable struct InternalShape
        color::Math.Vector3
        dimensions::Math.Vector2f
        isFilled::Bool
        isWorldEntity::Bool
        offset::Math.Vector2f
        position::Math.Vector2f
        parent::Any # Entity
        
        function InternalShape(parent::Any, dimensions::Math.Vector2f = Math.Vector2f(1,1), color::Math.Vector3 = Math.Vector3(255,0,0), isFilled::Bool = true, offset::Math.Vector2f = Math.Vector2f(0,0); isWorldEntity::Bool = true, position::Math.Vector2f = Math.Vector2f(0,0))
            this = new()
            
            this.color = color
            this.dimensions = dimensions
            this.isFilled = isFilled
            this.isWorldEntity = isWorldEntity
            this.offset = offset
            this.parent = parent
            this.position = position

            return this
        end
    end

    function Base.getproperty(this::InternalShape, s::Symbol)
        if s == :draw
            function()
                if JulGame.Renderer == C_NULL
                    return                    
                end

                parentTransform = this.parent.transform

                cameraDiff = this.isWorldEntity ? 
                Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
                Math.Vector2(0,0)
                position = this.isWorldEntity ?
                parentTransform.getPosition() :
                this.position

                outlineRect = Ref(SDL2.SDL_Rect(convert(Int,round((position.x + this.offset.x) * SCALE_UNITS - cameraDiff.x - (parentTransform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2)), 
                convert(Int,round((position.y + this.offset.y) * SCALE_UNITS - cameraDiff.y - (parentTransform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2)),
                convert(Int,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Int,round(1 * parentTransform.getScale().y * SCALE_UNITS))))
                SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, this.color.x, this.color.y, this.color.z, SDL2.SDL_ALPHA_OPAQUE );      

                this.isFilled ? SDL2.SDL_RenderFillRect( JulGame.Renderer, outlineRect) : SDL2.SDL_RenderDrawRect( JulGame.Renderer, outlineRect);
                
            end
    elseif s == :setParent
            function(parent::Any)
                this.parent = parent
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end
end
