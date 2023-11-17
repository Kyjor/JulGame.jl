module ShapeModule
    using ..Component.JulGame

    const SCALE_UNITS = Ref{Float64}(64.0)[]

    export Shape
    mutable struct Shape
        dimensions::Union{Ptr{Nothing}, Math.Vector4}
        offset::Math.Vector2f
        parent::Any # Entity
        position::Math.Vector2f
        renderer::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Renderer}}
        
        function Shape(dimensions::Union{Ptr{Nothing}, Math.Vector4}=C_NULL)
            this = new()
            
            this.offset = Math.Vector2f()
            this.dimensions = dimensions
            this.position = Math.Vector2f(0.0, 0.0)

            return this
        end
    end

    function Base.getproperty(this::Shape, s::Symbol)
        if s == :draw
            function()
                
                # Render green outlined quad
                #outlineRect = SDL_Rect(SCREEN_WIDTH / 6, SCREEN_HEIGHT / 6, SCREEN_WIDTH * 2 / 3, SCREEN_HEIGHT * 2 / 3);
                #SDL_SetRenderDrawColor( gRenderer, 0x00, 0xFF, 0x00, 0xFF );        
                #SDL_RenderDrawRect( gRenderer, &outlineRect );
                
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
