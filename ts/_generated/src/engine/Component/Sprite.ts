export {}
import { clamp, joinpath, unsafe_string } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..Component.JulGame
    // using ..Component.(globalThis as any).JulGame.ResourceModule
    // import ..Component
    // Effects imports - will be available after Effects 
    // import ..Component.JulGame as JG
    // include(joinpath(@__DIR__, "Sprite", "constants.jl"))

    
    class Sprite {
        color: [number, number, number, number]
        crop: null | Vector4
        isFlipped: boolean
        imagePath: string
        layer: number
        offset: Vector2f
        position: Vector2f
        rotation: number
        pixelsPerUnit: number
        center: Vector2f
        anchor: string
        isStatic: boolean
    }

    
    class InternalSprite { 
        imagePath: string
        layer: number
        offset: Vector2f
        center: Vector2f
        rotation: number
        color: [number, number, number, number]
        crop: null | Vector4
        isFlipped: boolean
        isFloatPrecision: boolean
        image: null | any
        parent: IEntity // Entity
        lastRenderedScreenPosition: Vector2f | null
        lastRenderedScreenSize: Vector2f | null
        pixelsPerUnit: number
        size: Vector2
        texture: null | any
        position: Vector2f
        anchor: string
        isStatic: boolean
        //  effects support
        effects: any[]  // Will hold Effect objects
        effectTexture: null | any
        effectSize: Vector2  // Size of effect texture (may be larger due to glow padding)
        effectCacheKey: string  // Cache key for sharing effect textures
        needsEffectUpdate: boolean
        useEffectTexture: boolean  // Toggle to enable/disable effect texture rendering
        interactionScale: number  // Scale factor for hover/click hitbox (1.0 = full size, <1.0 = smaller)
        
        constructor(parent: IEntity, imagePath: string, crop: null | Vector4=null, isFlipped: boolean=false, color: [number, number, number, number] = [255,255,255,255], isCreatedInEditor: boolean=false, pixelsPerUnit: number=0, position = {x: 0, y: 0}, rotation: number = 0.0, layer: number = 0, center = {x: 0.5, y: 0.5}, anchor: string = "center", offset = {x: 0, y: 0}, isStatic: boolean = false) {
            

            this.offset = offset
            this.isFlipped = isFlipped
            console.debug(`attemping to load sprite with path: ${imagePath}`)
            this.imagePath = imagePath
            this.center = center
            this.color = color
            this.crop = crop
            this.image = null
            this.layer = layer
            this.parent = parent
            this.pixelsPerUnit = pixelsPerUnit
            this.position = position
            this.rotation = rotation
            this.texture = null
            this.isFloatPrecision = false
            this.lastRenderedScreenPosition = null
            this.lastRenderedScreenSize = null
            this.anchor = anchor

            this.isStatic = isStatic
            
            // Initialize effects
            this.effects = []
            this.effectTexture = null
            this.effectSize = {x: 0, y: 0}
            this.effectCacheKey = ""
            this.needsEffectUpdate = false
            this.useEffectTexture = true  // Default to showing effects when applied
            this.interactionScale = 1.0  // Default to full-size hitbox

            // Early returns
            if (isCreatedInEditor) {

            }

            Component_load_image(this, imagePath)
            if (this.image == null) {
                let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())


                return
            }
            let surface = unsafe_wrap(Array, this.image, 10; own = false)
            this.size = {x: surface[0].w, y: surface[0].h}

        }
    }
    
    function Component_draw(self: InternalSprite, camera = null) {
        if (self.image == null || (globalThis as any).JulGame.Renderer == null) {
            return
        }
        
        // Update effects if needed
        if (!isempty(self.effects) && self.needsEffectUpdate) {

        }
    
        // Use effect texture if available and enabled, otherwise use regular texture
        let texture_to_render = null
        if (self.useEffectTexture && !isempty(self.effects) && self.effectTexture != null) {

        } else {
            // Create or get cached texture if it doesn't exist
            if (self.texture == null && self.image != null) {
                self.texture = get_or_create_texture(self.imagePath, self.image)
                Component_set_color(self)
            }
            texture_to_render = self.texture
        }
    
        // Check and set color if necessary (for both regular and effect textures)
        let colorRefs = (0, 0, 0)
        let alphaRef = 0;
        (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(texture_to_render, colorRefs...);
        (globalThis as any).JulGameSdl.glue_SDL_GetTextureAlphaMod(texture_to_render, alphaRef)
        if (colorRefs[0][] != self.color[0] || colorRefs[1][] != self.color[1] || colorRefs[2][] != self.color[2] || self.color[3] != alphaRef) {
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(texture_to_render, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(texture_to_render, Number(clamp(self.color[3], 0, 255)))
        }
    
        let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
        // Calculate camera difference
        let cameraDiff = camera !== null ? 
            {x: (camera.position.x + camera.offset.x) * S, y: (camera.position.y + camera.offset.y) * S} : 
            {x: 0, y: 0}
    
        // Calculate position
        let position = self.parent.transform.position
    
        // Calculate source rectangle
        let srcRect = (self.crop == Vector4(0, 0, 0, 0) || self.crop == null) ? null : (globalThis as any).JulGameSdl.glue_SDL_Rect(self.crop.x, self.crop.y, self.crop.z, self.crop.t)
    
        // Calculate pixels per unit
        let ppu = self.pixelsPerUnit > 0 ? self.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
    
        // Check if // using effect texture
        let usingEffectTex = texture_to_render == self.effectTexture && self.effectSize != {x: 0, y: 0}
        
        // Always use original sprite size for positioning calculations
        let cropWidth = srcRect == null ? self.size.x : self.crop.z
        let cropHeight = srcRect == null ? self.size.y : self.crop.t
        let scaleX = self.parent.transform.scale.x
        let scaleY = self.parent.transform.scale.y
    
        // Compute position adjustment
        let adjustedX = vecSub(vecMul(vecAdd(position.x, self.offset.x), S), cameraDiff.x)
        let adjustedY = vecSub(vecMul(vecAdd(position.y, self.offset.y), S), cameraDiff.y)
    
        // Handle pixelsPerUnit == 0 (use true size without scaling)
        if (self.pixelsPerUnit == 0) {
            let scaledWidth = cropWidth * scaleX * S / 64.0
            let scaledHeight = cropHeight * scaleY * S / 64.0
        } else {
            // Use pixelsPerUnit or default PIXELS_PER_UNIT for scaling
            ppu = self.pixelsPerUnit > 0 ? self.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
            let scaleFactor = S / ppu
            scaledWidth = cropWidth * scaleFactor * scaleX
            scaledHeight = cropHeight * scaleFactor * scaleY
        }
    
        // Compute position based on anchor (// using original sprite dimensions)
        let centeredX = adjustedX
        let centeredY = adjustedY
        
        // Apply anchor positioning
        if (self.anchor == :center) {
            // Center anchor (default behavior)
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (self.anchor == :top) {
            // Top anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            // No adjustment for Y
        } else if (self.anchor == :bottom) {
            // Bottom anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY)
        } else if (self.anchor == :left) {
            // Left anchor
            centeredY -= (scaledHeight - S * scaleY) / 2
            // No adjustment for X
        } else if (self.anchor == :right) {
            // Right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (self.anchor == :topleft) {
            // Top-left anchor
            // No adjustment needed
        } else if (self.anchor == :topright) {
            // Top-right anchor
            centeredX -= (scaledWidth - S * scaleX)
        } else if (self.anchor == :bottomleft) {
            // Bottom-left anchor
            centeredY -= (scaledHeight - S * scaleY)
        } else if (self.anchor == :bottomright) {
            // Bottom-right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY)
        }
        
        // AFTER anchor positioning: expand render size for effect texture and offset to center it
        if (usingEffectTex) {
            scaleFactor = self.pixelsPerUnit == 0 ? (S / 64.0) : (S / ppu)
            let effectScaledWidth = self.effectSize.x * scaleFactor * scaleX
            let effectScaledHeight = self.effectSize.y * scaleFactor * scaleY
            // Offset to center the larger effect texture over the original sprite position
            centeredX -= (effectScaledWidth - scaledWidth) / 2
            centeredY -= (effectScaledHeight - scaledHeight) / 2
            // Use effect dimensions for rendering
            scaledWidth = effectScaledWidth
            scaledHeight = effectScaledHeight
        }
    
        // Select float or integer precision
        if (self.isFloatPrecision) {
            let dstRect = (globalThis as any).JulGameSdl.glue_SDL_FRect(centeredX, centeredY, scaledWidth, scaledHeight)
        } else {
            dstRect = (globalThis as any).JulGameSdl.glue_SDL_Rect(
                Math.round(centeredX),
                Math.round(centeredY),
                Math.round(scaledWidth),
                Math.round(scaledHeight)
            )
        }
    
        // Calculate center for rotation
        let calculatedCenter = {x: dstRect.w * (self.center.x % 1), y: dstRect.h * (self.center.y % 1)}
        let rotationCenter = !self.isFloatPrecision ? 
            (globalThis as any).JulGameSdl.glue_SDL_Point(Math.round(calculatedCenter.x), Math.round(calculatedCenter.y)) :
            (globalThis as any).JulGameSdl.glue_SDL_FPoint(calculatedCenter.x, calculatedCenter.y)
    
        self.lastRenderedScreenPosition = {x: convert(Float64, dstRect.x), y: convert(Float64, dstRect.y)}
        self.lastRenderedScreenSize = {x: convert(Float64, dstRect.w), y: convert(Float64, dstRect.h)}
        // Render with appropriate precision
        let renderFn = self.isFloatPrecision ? SDL2.SDL_RenderCopyExF : SDL2.SDL_RenderCopyEx
        if (renderFn() {
            (globalThis as any).JulGame.Renderer, 
            texture_to_render, 
            srcRect, 
            dstRect,
            self.rotation, 
            rotationCenter, 
            self.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE
        ) != 0
            let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
        }
    }

    function Component_initialize(self: InternalSprite) {
        if (self.image == null) {
            return
        }

        self.texture = get_or_create_texture(self.imagePath, self.image)
    }

    function Component_flip(self: InternalSprite) {
        self.isFlipped = !self.isFlipped
    }

    function get_or_create_texture(imagePath: string, surface: any) {
        if (haskey(TEXTURE_CACHE, imagePath)) {
            console.debug(`Using cached texture for: ${imagePath}`)
            return TEXTURE_CACHE[imagePath]
        }
        let tex = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, surface)
        if (tex != null) {
            TEXTURE_CACHE[imagePath] = tex
            console.debug(`Created and cached texture for: ${imagePath}`)
        } else {

        }
        return tex
    }
    
    function serialize_effects(effects: any[]): string
        if (isempty(effects)) {
            return "[]"
        }
        let parts = []
        for (const eff of effects) {
            let T = typeof(eff)
            let fnames = fieldnames(T)
            let vals = []
            for (const f of fnames) {
                let v = getfield(eff, f)
                if (v isa Ptr) {
                    vals.push([f, "=Ptr"].join(""))
                } else {
                    vals.push([f, "=", v].join(""))
                }
            }
            parts.push([nameof(T), "(", vals.join(","), ")"].join(""))
        }
        return "[" * parts.join(";") * "]"
    }
    
    function generate_effect_cache_key(self: InternalSprite): string
        // Cache key based on image path, size, and effects - NOT instance ID
        // This allows sharing effect textures across sprites with same visuals
        let content = [this.imagePath, "|", this.size.x, "x", this.size.y, "|", serialize_effects(this.effects)].join("")
        return String(hash(content))
    }
    
    //  effects API
    function Component_apply_effects(self: InternalSprite, effects: Vector) {
        self.effects = Any[effect for effect in effects]  // Convert to Vector{Any}
        
        // Generate cache key and check if we need to recompute
        let newKey = generate_effect_cache_key(self)
        if (self.effectCacheKey == newKey && self.effectTexture != null) {
            // Already have self effect cached on self sprite
            console.debug("Sprite.apply_effects!: cache key unchanged; skipping recompute") path=self.imagePath

        }
        
        self.effectCacheKey = newKey
        self.needsEffectUpdate = true


    }
    
    function apply_style(self: InternalSprite, style) {
        return apply_effects(self, style.effects)
    }


        empty(SPRITE_EFFECT_CACHE)
    }

        return snapshot
    }

        empty(TEXTURE_CACHE)
    }

    function load_fallback_image() {
        let rwops = (globalThis as any).JulGameSdl.glue_SDL_RWFromMem(pointer(FALLBACK_IMAGE_BYTES), FALLBACK_IMAGE_BYTES.length)
        if (rwops == null) {

            return null
        }
        let image = SDL2.IMG_Load_RW(rwops, 1)  // Load directly from memory and free rwops after use
        return image
    }

    function Component_load_image(self: InternalSprite, imagePath: string) {
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()

        let fullPath = joinpath(BasePath, "assets", "images", imagePath)
        self.image = load_image_sdl(fullPath, imagePath)
        let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
    
        if (!isempty(error) || self.image == null) {
            try {

            } catch (e) {


            }
            (globalThis as any).JulGameSdl.glue_SDL_ClearError()
    
            // Load from byte array
            self.image = load_fallback_image()
            setfield(self, :imagePath, "fallback.png")
            self.pixelsPerUnit = 0
            if (self.image == null) {

                return
            }
        } else if (self.imagePath != imagePath) {
            self.imagePath = imagePath
        }
    
        // Get image size
        let surface = unsafe_wrap(Array, self.image, 10; own = false)
        self.size = {x: surface[0].w, y: surface[0].h}

        // Create or get cached texture
        self.texture = get_or_create_texture(self.imagePath, self.image)

        if (self.texture == null) {


            return
        }

        Component_set_color(self)
    }

    function load_image_sdl(fullPath: string, imagePath: string) {
        let commaSeparatedPath = (globalThis as any).JulGame.get_comma_separated_path(imagePath)
        console.debug(`Loading image from disk ${fullPath} for sprite, there are ${(globalThis as any).JulGame.IMAGE_CACHE.length} images in cache`)

        return SDL2.IMG_Load(fullPath)
    }

    function Component_destroy(self: InternalSprite) {
        if (self.image == null) {
            return
        }

        // Only destroy texture if it's not in the shared cache
        if (self.texture != null && !haskey(TEXTURE_CACHE, self.imagePath)) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.texture)
        }
        self.image = null
        self.texture = null
    }

    function Component_set_color(self: InternalSprite) {
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(self.texture, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(self.texture, Number(clamp(self.color[3], 0, 255)));
    }

    function Component_duplicate(self: InternalSprite, parent: any) {
        let newSprite = new InternalSprite(parent, self.imagePath, self.crop, self.isFlipped, self.color, false; pixelsPerUnit=self.pixelsPerUnit, position=self.position, rotation=self.rotation, layer=self.layer, center=self.center, anchor=self.anchor, offset=self.offset, isStatic=self.isStatic)
        newSprite.interactionScale = self.interactionScale
        Component_initialize(newSprite)
        return newSprite
    }

    function Component_is_mouse_hovering(self: InternalSprite) {
       // TODO: check if the mouse is hovering over any of the sprites pixels
       return false
    }

