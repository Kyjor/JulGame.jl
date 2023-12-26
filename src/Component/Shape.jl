module ShapeModule
    using ..Component.JulGame

    export Shape
    mutable struct Shape
        color::Math.Vector3
        dimensions::Math.Vector2
        isFilled::Bool
        isWorldEntity::Bool
        offset::Math.Vector2
        position::Math.Vector2f
        parent::Any # Entity
        
        function Shape(dimensions::Math.Vector2 = Math.Vector2(1,1), color::Math.Vector3 = Math.Vector3(255,0,0), isFilled::Bool = true, offset::Math.Vector2 = Math.Vector2(); isWorldEntity::Bool = true, position::Math.Vector2f = Math.Vector2f())
            this = new()
            
            this.color = color
            this.dimensions = dimensions
            this.isFilled = isFilled
            this.isWorldEntity = isWorldEntity
            this.offset = offset
            this.position = position

            return this
        end
    end

    function Base.getproperty(this::Shape, s::Symbol)
        if s == :draw
            function()
                if JulGame.Renderer == C_NULL
                    return                    
                end

                parentTransform = this.parent.getTransform()

                cameraDiff = this.isWorldEntity ? 
                Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
                Math.Vector2(0,0)
                position = this.isWorldEntity ?
                parentTransform.getPosition() :
                this.position

                outlineRect = Ref(SDL2.SDL_Rect(convert(Integer,round((position.x + this.offset.x) * SCALE_UNITS - cameraDiff.x - (parentTransform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2)), 
                convert(Integer,round((position.y + this.offset.y) * SCALE_UNITS - cameraDiff.y - (parentTransform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2)),
                convert(Integer,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Integer,round(1 * parentTransform.getScale().y * SCALE_UNITS))))
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
