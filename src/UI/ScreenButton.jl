using SimpleDirectMediaLayer.LibSDL2

mutable struct ScreenButton
    currentSprite
    buttonDownSprite
    buttonUpSprite
    dimensions
    image
    mouseOverSprite
    position

    function ScreenButton(dimensions::Vector2f, position::Vector2f, image)
        this = new()
        
        this.dimensions = dimensions
        this.position = position
        if image != C_NULL
            this.image = IMG_Load(image)
        else
            this.image = IMG_Load("../../assets/images/buttons.png")
        end

        return this
    end
end

function Base.getproperty(this::ScreenButton, s::Symbol)
    if s == :render
        function()

            SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                Ref(SDL_Rect(this.frameToDraw * 16,0,16,16)), 
                Ref(SDL_Rect(convert(Int32,round((parentTransform.getPosition().x - SceneInstance.camera.position.x) * SCALE_UNITS)), 
                convert(Int32,round((parentTransform.getPosition().y - SceneInstance.camera.position.y) * SCALE_UNITS)),
                convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS)))), 
                0.0, 
                C_NULL, 
                this.isFlipped ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE)
        end
    elseif s == :setPosition
        function(position::Vector2f)
        end
    elseif s == :handleEvent
        function(evt, x, y)
          
            if evt.type == SDL_MOUSEMOTION || evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP
                #println("mouse event")
            end 

            
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end