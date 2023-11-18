module ShapeModule
    using ..Component.JulGame

    export Shape
    mutable struct Shape
        color::Math.Vector3
        dimensions::Math.Vector2
        isFilled::Bool
        offset::Math.Vector2
        parent::Any # Entity
        position::Math.Vector2
        renderer::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Renderer}}
        
        function Shape(dimensions::Math.Vector2 = Math.Vector2(1,1), color::Math.Vector3 = Math.Vector3(255,0,0), isFilled::Bool = true, offset::Math.Vector2 = Math.Vector2())
            this = new()
            
            this.color = color
            this.dimensions = dimensions
            this.isFilled = isFilled
            this.offset = offset

            return this
        end
    end

    function Base.getproperty(this::Shape, s::Symbol)
        if s == :draw
            function()
                if MAIN.renderer == C_NULL #|| this.renderer == Ptr{nothing}
                    return                    
                end

                parentTransform = this.parent.getTransform()

                outlineRect = Ref(SDL2.SDL_Rect(convert(Int32,round((parentTransform.getPosition().x + this.offset.x - MAIN.scene.camera.position.x) * SCALE_UNITS)), 
                convert(Int32,round((parentTransform.getPosition().y + this.offset.y - MAIN.scene.camera.position.y) * SCALE_UNITS)),
                convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS))))
                SDL2.SDL_SetRenderDrawColor(MAIN.renderer, this.color.x, this.color.y, this.color.z, SDL2.SDL_ALPHA_OPAQUE );      

                this.isFilled ? SDL2.SDL_RenderFillRect( MAIN.renderer, outlineRect) : SDL2.SDL_RenderDrawRect( MAIN.renderer, outlineRect);
                
            end
        elseif s == :injectRenderer
            function(renderer::Ptr{SDL2.LibSDL2.SDL_Renderer})
                this.renderer = renderer
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
