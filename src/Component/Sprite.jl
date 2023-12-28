module SpriteModule
    using ..Component.JulGame

    export Sprite
    mutable struct Sprite
        color::Math.Vector3
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        image::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Surface}}
        imagePath::String
        isWorldEntity::Bool
        layer::Integer
        offset::Math.Vector2f
        parent::Any # Entity
        position::Math.Vector2f
        rotation::Float64
        pixelsPerUnit::Integer
        size::Math.Vector2
        renderer::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Renderer}}
        texture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
        
        function Sprite(imagePath::String, crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL, isFlipped::Bool=false, color::Math.Vector3 = Math.Vector3(255,255,255), isCreatedInEditor::Bool=false; pixelsPerUnit=-1, isWorldEntity::Bool=true, position::Math.Vector2f = Math.Vector2f())
            this = new()

            this.offset = Math.Vector2f()
            this.isFlipped = isFlipped
            this.imagePath = imagePath
            this.color = color
            this.crop = crop
            this.image = C_NULL
            this.isWorldEntity = isWorldEntity
            this.layer = 0
            this.pixelsPerUnit = pixelsPerUnit
            this.position = position
            this.rotation = 0.0
            this.texture = C_NULL

            if isCreatedInEditor
                return this
            end
        
            SDL2.SDL_ClearError()
            fullPath = joinpath(BasePath, "assets", "images", imagePath)
            this.image = SDL2.IMG_Load(fullPath)
            surface = unsafe_wrap(Array, this.image, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
            error = unsafe_string(SDL2.SDL_GetError())
            if !isempty(error)
                SDL2.SDL_ClearError()
        
                println(fullPath)
                println(string("Couldn't open image! SDL Error: ", error))
            end
        
            return this
        end
    end

    function Base.getproperty(this::Sprite, s::Symbol)
        if s == :draw
            function()
                if this.image == C_NULL || MAIN.renderer == C_NULL
                    return
                end

                if this.texture == C_NULL
                    this.texture = SDL2.SDL_CreateTextureFromSurface(MAIN.renderer, this.image)
                    this.setColor()
                end

                parentTransform = this.parent.getTransform()

                cameraDiff = this.isWorldEntity ? 
                Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
                Math.Vector2(0,0)
                position = this.isWorldEntity ?
                parentTransform.getPosition() :
                this.position

                srcRect = (this.crop == Math.Vector4() || this.crop == C_NULL) ? C_NULL : Ref(SDL2.SDL_Rect(this.crop.x,this.crop.y,this.crop.w,this.crop.h))
                dstRect = Ref(SDL2.SDL_Rect(
                    convert(Integer, round((position.x + this.offset.x) * SCALE_UNITS - cameraDiff.x - (parentTransform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2)),
                    convert(Integer, round((position.y + this.offset.y) * SCALE_UNITS - cameraDiff.y - (parentTransform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2)),
                    convert(Integer, round(parentTransform.getScale().x * SCALE_UNITS)),
                    convert(Integer, round(parentTransform.getScale().y * SCALE_UNITS))
                ))
                
                if this.pixelsPerUnit > 0
                    dstRect = Ref(SDL2.SDL_Rect(
                        convert(Integer, round((position.x + this.offset.x) * SCALE_UNITS - cameraDiff.x - (this.size.x * SCALE_UNITS / this.pixelsPerUnit - SCALE_UNITS) / 2)),
                        convert(Integer, round((position.y + this.offset.y) * SCALE_UNITS - cameraDiff.y - (this.size.y * SCALE_UNITS / this.pixelsPerUnit - SCALE_UNITS) / 2)),
                        convert(Integer, round(this.size.x * SCALE_UNITS/this.pixelsPerUnit)),
                        convert(Integer, round(this.size.y * SCALE_UNITS/this.pixelsPerUnit))
                    ))                
                end

                SDL2.SDL_RenderCopyEx(
                    MAIN.renderer, 
                    this.texture, 
                    srcRect, 
                    dstRect,
                    this.rotation, # ROTATION
                    C_NULL, # Ref(SDL2.SDL_Point(0,0)) CENTER
                    this.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE)
                
            end
        elseif s == :initialize
            function()
                this.renderer = JulGame.Renderer
                if this.image == C_NULL
                    return
                end

                this.texture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.image)
            end
        elseif s == :flip
            function()
                this.isFlipped = !this.isFlipped
            end
        elseif s == :setParent
            function(parent::Any)
                this.parent = parent
            end
        elseif s == :loadImage
            function(imagePath::String)
                SDL2.SDL_ClearError()
                this.renderer = MAIN.renderer
                this.image = SDL2.IMG_Load(joinpath(BasePath, "assets", "images", imagePath))
                error = unsafe_string(SDL2.SDL_GetError())
                if !isempty(error)
                    println(string("Couldn't open image! SDL Error: ", error))
                    SDL2.SDL_ClearError()
                    this.image = C_NULL
                    return
                end

                surface = unsafe_wrap(Array, this.image, 10; own = false)
                this.size = Math.Vector2(surface[1].w, surface[1].h)
                
                this.imagePath = imagePath
                this.texture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.image)
                this.setColor()
            end
        elseif s == :destroy
            function()
                if this.image == C_NULL
                    return
                end

                SDL2.SDL_DestroyTexture(this.texture)
                SDL2.SDL_FreeSurface(this.image)
                this.image = C_NULL
                this.texture = C_NULL
            end
        elseif s == :setColor
            function ()
                SDL2.SDL_SetTextureColorMod(this.texture, UInt8(this.color.x%256), UInt8(this.color.y%256), (this.color.z%256));
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
