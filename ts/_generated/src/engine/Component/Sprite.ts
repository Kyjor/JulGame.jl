export {}
import { clamp, joinpath, unsafe_string } from "../../../../src/engine/core/juliaHelpers";


    // using ..Component.JulGame
    // using ..Component.(globalThis as any).JulGame.ResourceModule
    // import ..Component
    // Effects imports - will be available after Effects 
    // import ..Component.JulGame as JG
    // include(joinpath(@__DIR__, "Sprite", "constants.jl"))
    // include(joinpath(@__DIR__, "Sprite", "effects_functions.jl"))

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
            this.size = { x: 0, y: 0 }
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
                console.error(["Couldn't open image! path: $(fullPath) SDL Error: ", error].join(""))

                return
            }

        }
    }
    
    /** JSON / Julia sometimes leaves `{}` or partial crop; NaN rects look "broken". */
    function spriteEffectiveCrop(self: InternalSprite): null | Vector4 {
        const c = self.crop;
        if (c == null) {
            return null;
        }
        const x = Number((c as Vector4).x);
        const y = Number((c as Vector4).y);
        const z = Number((c as Vector4).z);
        const t = Number((c as Vector4).t);
        if (!Number.isFinite(z) || !Number.isFinite(t) || z <= 0 || t <= 0) {
            return null;
        }
        if (!Number.isFinite(x) || !Number.isFinite(y)) {
            return null;
        }
        if (x === 0 && y === 0 && z === 0 && t === 0) {
            return null;
        }
        return { x, y, z, t };
    }

    function Component_draw(self: InternalSprite, camera: any = null) {
        if (self.image == null || (globalThis as any).JulGame.Renderer == null) {
            return
        }
        
        // Update effects if needed
        if (self.effects.length > 0 && self.needsEffectUpdate) {

        }
    
        // Use effect texture if available and enabled, otherwise use regular texture
        let texture_to_render = null
        if (self.useEffectTexture && self.effects.length > 0 && self.effectTexture != null) {

        } else {
            // Create or get cached texture if it doesn't exist
            if (self.texture == null && self.image != null) {
                self.texture = get_or_create_texture(self.imagePath, self.image)
                Component_set_color(self)
            }
            texture_to_render = self.texture
        }
    
        // Check and set color if necessary (for both regular and effect textures)
        // Set color mod (skip SDL_GetTextureColorMod — not exposed to JS heap in wasm glue)
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(texture_to_render, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(texture_to_render, Number(clamp(self.color[3], 0, 255)))
    
        let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
        // Calculate camera difference
        let cameraDiff = camera !== null ? 
            {x: (camera.position.x + camera.offset.x) * S, y: (camera.position.y + camera.offset.y) * S} : 
            {x: 0, y: 0}
    
        // Calculate position
        let position = self.parent.transform.position
    
        let ec = spriteEffectiveCrop(self)
        // Calculate source rectangle
        let srcRect = ec === null ? null : (globalThis as any).JulGameSdl.glue_SDL_Rect(ec.x, ec.y, ec.z, ec.t)
    
        // Calculate pixels per unit
        let ppu = self.pixelsPerUnit > 0 ? self.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
    
        // Check if // using effect texture
        let usingEffectTex = texture_to_render == self.effectTexture && (self.effectSize == null || self.effectSize.x !== 0 || self.effectSize.y !== 0)
        
        // Always use original sprite size for positioning calculations
        let crop = ec === null ? {x: 0, y: 0, z: 0, t: 0} : ec
        let cropWidth = srcRect == null ? self.size.x : crop.z
        let cropHeight = srcRect == null ? self.size.y : crop.t
        let scaleX = self.parent.transform.scale.x
        let scaleY = self.parent.transform.scale.y
    
        // Compute position adjustment
        // VERBOSE because of transpiler 
        let adjustedX = position.x
        adjustedX += self.offset.x
        adjustedX *= S
        adjustedX -= cameraDiff.x
        let adjustedY = position.y
        adjustedY += self.offset.y
        adjustedY *= S
        adjustedY -= cameraDiff.y
    
        // Handle pixelsPerUnit == 0 (use true size without scaling)
        let scaledWidth = 0.0
        let scaledHeight = 0.0
        if (self.pixelsPerUnit == 0) {
            const su = (globalThis as any).JulGame.SCALE_UNITS as number;
            scaledWidth = (cropWidth * scaleX * S) / su;
            scaledHeight = (cropHeight * scaleY * S) / su;
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
        if (self.anchor == "center") {
            // Center anchor (default behavior)
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (self.anchor == "top") {
            // Top anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            // No adjustment for Y
        } else if (self.anchor == "bottom") {
            // Bottom anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY)
        } else if (self.anchor == "left") {
            // Left anchor
            centeredY -= (scaledHeight - S * scaleY) / 2
            // No adjustment for X
        } else if (self.anchor == "right") {
            // Right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (self.anchor == "topleft") {
            // Top-left anchor
            // No adjustment needed
        } else if (self.anchor == "topright") {
            // Top-right anchor
            centeredX -= (scaledWidth - S * scaleX)
        } else if (self.anchor == "bottomleft") {
            // Bottom-left anchor
            centeredY -= (scaledHeight - S * scaleY)
        } else if (self.anchor == "bottomright") {
            // Bottom-right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY)
        }

        if (!(scaledWidth > 0 && scaledHeight > 0) || !Number.isFinite(scaledWidth) || !Number.isFinite(scaledHeight) || !Number.isFinite(centeredX) || !Number.isFinite(centeredY)) {
            console.warn(`Component_draw: skip sprite (bad geometry) ${self.imagePath}`, {
                scaledWidth,
                scaledHeight,
                centeredX,
                centeredY,
                cropWidth,
                cropHeight,
                S,
            })
            return
        }
        
        // AFTER anchor positioning: expand render size for effect texture and offset to center it
    
        // Select float or integer precision
        let dstRect = (globalThis as any).JulGameSdl.glue_SDL_FRect(centeredX, centeredY, scaledWidth, scaledHeight)
        if (!self.isFloatPrecision) {
            dstRect = (globalThis as any).JulGameSdl.glue_SDL_Rect(
                Math.round(centeredX),
                Math.round(centeredY),
                Math.round(scaledWidth),
                Math.round(scaledHeight)
            )
        }
    
        // Calculate center for rotation
        let calculatedCenter = {x: dstRect.w * (self.center.x % 1), y: dstRect.h * (self.center.y % 1)}
        let rotationCenter = !self.isFloatPrecision
            ? (globalThis as any).JulGameSdl.glue_SDL_Point(Math.round(calculatedCenter.x), Math.round(calculatedCenter.y))
            : (globalThis as any).JulGameSdl.glue_SDL_FPoint(calculatedCenter.x, calculatedCenter.y)
    
        self.lastRenderedScreenPosition = {x: Number(dstRect.x), y: Number(dstRect.y)}
        self.lastRenderedScreenSize = {x: Number(dstRect.w), y: Number(dstRect.h)}
        // Render with appropriate precision
        let renderFn = self.isFloatPrecision ? (globalThis as any).JulGameSdl.glue_SDL_RenderCopyExF : (globalThis as any).JulGameSdl.glue_SDL_RenderCopyEx
        if (renderFn((globalThis as any).JulGame.Renderer, texture_to_render, srcRect, dstRect, self.rotation, rotationCenter, self.isFlipped ? 1 : 0) != 0) {
            let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
            console.error(`Failed to render sprite: ${error}`)
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
        let tex = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, surface)
        if (tex != null) {

            console.debug(`Created and cached texture for: ${imagePath}`)
        } else {
            console.error(`Failed to create texture for: ${imagePath}`)
        }
        return tex
    }
    
    // function load_fallback_image()
    //     rwops = (globalThis as any).JulGameSdl.glue_SDL_RWFromMem(pointer(FALLBACK_IMAGE_BYTES), FALLBACK_IMAGE_BYTES.length)
    //     if rwops == null
    //         console.error("Failed to create SDL_RWops for fallback image.")
    //         return null
    //     }
    //     image = (globalThis as any).JulGameSdl.glue_IMG_Load_RW(rwops, 1)  // Load directly from memory and free rwops after use
    //     return image
    // }

    function Component_load_image(self: InternalSprite, imagePath: string) {
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()

        let fullPath = joinpath((globalThis as any).JulGame.BasePath, "assets", "images", imagePath)
        self.image = load_image_sdl(fullPath, imagePath)
        let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
    
        // if error.length > 0 || self.image == null
        //     try

        //     catch e
        //         console.error("Error loading image '$imagePath'! SDL Error: ", e)

        //     }
        //     (globalThis as any).JulGameSdl.glue_SDL_ClearError()
    
        //     // Load from byte array
        //     this.image = load_fallback_image()
        //     setfield(this, :imagePath, "fallback.png")
        //     this.pixelsPerUnit = 0
        //     if this.image == null
        //         console.error("Fallback image also failed to load! $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
        //         return
        //     }
        // elseif this.imagePath != imagePath
        //     this.imagePath = imagePath
        // }
    
        // Get image size from SDL surface
        if (self.image != null) {
            self.size = {
                x: (globalThis as any).JulGameSdl.glue_surface_w(self.image),
                y: (globalThis as any).JulGameSdl.glue_surface_h(self.image),
            }
        } else {
            self.size = { x: 0, y: 0 }
        }

        // Create or get cached texture
        self.texture = get_or_create_texture(self.imagePath, self.image)

        if (self.texture == null) {
            console.error("Failed to create texture from image.")

            return
        }

        Component_set_color(self)
    }

    function load_image_sdl(fullPath: string, imagePath: string) {
        let commaSeparatedPath = (globalThis as any).JulGame.get_comma_separated_path(imagePath)
        console.debug(`Loading image from disk ${fullPath} for sprite, there are ${(globalThis as any).JulGame.IMAGE_CACHE.length} images in cache`)

        return (globalThis as any).JulGameSdl.glue_IMG_Load(fullPath)
    }

    function Component_destroy(self: InternalSprite) {
        if (self.image == null) {
            return
        }

        // Only destroy texture if it's not in the shared cache
        self.image = null
        self.texture = null
    }

    function Component_set_color(self: InternalSprite) {
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(self.texture, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(self.texture, Number(clamp(self.color[3], 0, 255)));
    }

    function Component_duplicate(self: InternalSprite, parent: any) {
        let newSprite = new InternalSprite(parent, self.imagePath, self.crop, self.isFlipped, self.color, false, self.pixelsPerUnit, self.position, self.rotation, self.layer, self.center, self.anchor, self.offset, self.isStatic)
        newSprite.interactionScale = self.interactionScale
        Component_initialize(newSprite)
        return newSprite
    }

    function Component_is_mouse_hovering(self: InternalSprite) {
       // TODO: check if the mouse is hovering over any of the sprites pixels
       return false
    }

export { InternalSprite, Component_draw, Component_initialize }