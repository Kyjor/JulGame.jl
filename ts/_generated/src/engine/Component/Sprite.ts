export {}
import { clamp, haskey, joinpath, pointer, unsafe_string, unsafe_wrap } from "../../../../src/engine/core/juliaHelpers";
import { scheduleImageFetch } from "../../../../src/engine/runtime/memfsImage";

/** Emscripten null pointers arrive as `0`; `0 != null` is true in JS. */
function isSdlPtr(p: unknown): p is number {
    return typeof p === "number" && p !== 0;
}


    // using ..Component.JulGame
    // using ..Component.(globalThis as any).JulGame.ResourceModule
    // import ..Component
    // Effects imports - will be available after Effects 
    // import ..Component.JulGame as JG

    
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
            if (!isSdlPtr(this.image)) {
                // Missing MEMFS file: load_image_sdl already scheduled a fetch.
                return
            }
            let surface = unsafe_wrap(Array, this.image, 10, false)
            this.size = {x: surface[0].w, y: surface[0].h}

        }
    }

    // include(joinpath(@__DIR__, "Sprite", "constants.jl"))
    // include(joinpath(@__DIR__, "Sprite", "effects_functions.jl"))
    
    function Component_draw(self: InternalSprite, camera: any = null) {
        // Runtime-spawned sprites may construct before MEMFS fetch finishes — retry quietly.
        if (!isSdlPtr(self.image) && self.imagePath) {
            Component_load_image(self, self.imagePath)
        }
        if (!isSdlPtr(self.image) || (globalThis as any).JulGame.Renderer == null) {
            return
        }
        
        // Update effects if needed
        if (self.effects.length > 0 && self.needsEffectUpdate) {

        }
    
        // Use effect texture if available and enabled, otherwise use regular texture
        let texture_to_render = null
        if (self.useEffectTexture && self.effects.length > 0 && isSdlPtr(self.effectTexture)) {

        } else {
            // Create or get cached texture if it doesn't exist
            if (!isSdlPtr(self.texture) && isSdlPtr(self.image)) {
                self.texture = get_or_create_texture(self.imagePath, self.image)
                Component_set_color(self)
            }
            texture_to_render = self.texture
        }

        if (!isSdlPtr(texture_to_render)) {
            return
        }
    
        // Check and set color if necessary (for both regular and effect textures)
        if (!isSdlPtr(texture_to_render)) { return }
        let _textureColor = (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(texture_to_render)

        let _textureAlpha = (globalThis as any).JulGameSdl.glue_SDL_GetTextureAlphaMod(texture_to_render)

        if (_textureColor.r != self.color[0] || _textureColor.g != self.color[1] || _textureColor.b != self.color[2] || self.color[3] != _textureAlpha) {
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
        let srcRect = (self.crop == null || (self.crop.x === 0 && self.crop.y === 0 && self.crop.z === 0 && self.crop.t === 0)) ? null : (globalThis as any).JulGameSdl.glue_SDL_Rect(self.crop.x, self.crop.y, self.crop.z, self.crop.t)
    
        // Calculate pixels per unit
        let ppu = self.pixelsPerUnit > 0 ? self.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
    
        // Check if // using effect texture
        let usingEffectTex = texture_to_render == self.effectTexture && (self.effectSize == null || self.effectSize.x !== 0 || self.effectSize.y !== 0)
        
        // Always use original sprite size for positioning calculations
        let crop = self.crop == null ? {x: 0, y: 0, z: 0, t: 0} : self.crop
        let cropWidth = srcRect == null ? (self.size?.x ?? 0) : crop.z
        let cropHeight = srcRect == null ? (self.size?.y ?? 0) : crop.t
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
            scaledWidth = cropWidth * scaleX * S / 64.0
            scaledHeight = cropHeight * scaleY * S / 64.0
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
        let rotationCenter = !self.isFloatPrecision ? 
            (globalThis as any).JulGameSdl.glue_SDL_Point(Math.round(calculatedCenter.x), Math.round(calculatedCenter.y)) :
            (globalThis as any).JulGameSdl.glue_SDL_FPoint(calculatedCenter.x, calculatedCenter.y)
    
        self.lastRenderedScreenPosition = {x: Number(dstRect.x), y: Number(dstRect.y)}
        self.lastRenderedScreenSize = {x: Number(dstRect.w), y: Number(dstRect.h)}
        // Render with appropriate precision
        let renderFn = self.isFloatPrecision ? (globalThis as any).JulGameSdl.glue_SDL_RenderCopyExF : (globalThis as any).JulGameSdl.glue_SDL_RenderCopyEx
        ;(globalThis as any).JulGameSdl.glue_SDL_ClearError?.()
        if (renderFn((globalThis as any).JulGame.Renderer, texture_to_render, srcRect, dstRect, self.rotation, rotationCenter, self.isFlipped ? 1 : 0) != 0) {
            let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
            console.error(`Failed to render sprite ${self.imagePath}: ${error}`)
            // Self-heal once: drop the (likely dangling) texture so the next draw
            // recreates it. Avoid thrashing every frame on persistent failures.
            if (texture_to_render == self.texture && !(self as any)._renderHealAttempted) {
                ;(self as any)._renderHealAttempted = true
                const cache = (globalThis as any).JulGame.TEXTURE_CACHE
                if (cache[self.imagePath] == self.texture) {
                    delete cache[self.imagePath]
                }
                self.texture = null
            }
            return
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

    // Shared texture cache for base images (keyed by image path) — TEXTURE_CACHE in constants.jl

    // Shared surface cache for base images (keyed by image path). Sprites that
    // use the same image share one decoded surface instead of re-decoding the
    // PNG on every spawn. Cached surfaces are owned by the cache: they must
    // never be freed by individual sprites (see is_shared_surface guards).
    const SURFACE_CACHE = {}
    const SURFACE_CACHE_PTRS = new Set()

    function is_shared_surface(surface: any): boolean { return SURFACE_CACHE_PTRS.has(surface) }

    function get_or_load_surface(fullPath: string, imagePath: string) {
        let cached = SURFACE_CACHE[imagePath] ?? null
        if (isSdlPtr(cached)) {
            return cached
        }
        let surface = load_image_sdl(fullPath, imagePath)
        if (isSdlPtr(surface)) {
            SURFACE_CACHE[imagePath] = surface
            SURFACE_CACHE_PTRS.add(surface)
            return surface
        }
        return null
    }

        function clear_surface_cache() {
    for (const imagePath of Object.keys(SURFACE_CACHE)) {
        const surface = SURFACE_CACHE[imagePath]
        if (surface != null) {
            (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
        }
        delete SURFACE_CACHE[imagePath]
    }
    SURFACE_CACHE_PTRS.clear()
}

        function get_or_create_texture(imagePath: string, surface: any) {
    const cache = (globalThis as any).JulGame.TEXTURE_CACHE
    if (isSdlPtr(cache[imagePath])) {
        return cache[imagePath]
    }
    if (!isSdlPtr(surface)) {
        return null
    }
    let tex = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, surface)
    if (isSdlPtr(tex)) {
        cache[imagePath] = tex
        return tex
    }
    console.error(`Failed to create texture for: ${imagePath}`)
    return null
}
function pump_effect_prewarm() {}
function prewarm_effect_textures(_imagePath: string, _effects: any[]) {}
function compute_effect_prewarm_surface(_imagePath: string, _effects: any[]) { return null }
function finalize_effect_prewarm(_key: string, _surface: any) {}
function effect_prewarm_pending() { return false }

function Component_load_image(self: InternalSprite, imagePath: string) {
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()

        let fullPath = joinpath((globalThis as any).JulGame.BasePath, "assets", "images", imagePath)
        self.imagePath = imagePath
        self.image = get_or_load_surface(fullPath, imagePath)
        if (!isSdlPtr(self.image)) {
            self.texture = null
            return
        }
    
        // Get image size
        let surface = unsafe_wrap(Array, self.image, 10, false)
        self.size = {x: surface[0].w, y: surface[0].h}

        // Create or get cached texture
        self.texture = get_or_create_texture(self.imagePath, self.image)

        if (!isSdlPtr(self.texture)) {
            return
        }

        Component_set_color(self)
    }

    function load_image_sdl(fullPath: string, imagePath: string) {
        let commaSeparatedPath = (globalThis as any).JulGame.get_comma_separated_path(imagePath)
        if (haskey((globalThis as any).JulGame.IMAGE_CACHE, commaSeparatedPath)) {
            let raw_data = (globalThis as any).JulGame.IMAGE_CACHE[commaSeparatedPath]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (isSdlPtr(rw)) {
                console.debug("loading image from cache")
                console.debug("comma separated path: ", commaSeparatedPath)
                const fromRw = (globalThis as any).JulGameSdl.glue_IMG_Load_RW(rw, 1)
                if (isSdlPtr(fromRw)) {
                    return fromRw
                }
            }
        }
        console.debug(`Loading image from disk ${fullPath} for sprite, there are ${Object.keys((globalThis as any).JulGame.IMAGE_CACHE).length} images in cache`)

        let surface = (globalThis as any).JulGameSdl.glue_IMG_Load(fullPath)
        if (isSdlPtr(surface)) {
            return surface
        }
        // Runtime-spawned / inactive-entity paths often miss scene preload.
        scheduleImageFetch(imagePath)
        ;(globalThis as any).JulGameSdl.glue_SDL_ClearError?.()
        return null
    }

    function Component_destroy(self: InternalSprite) {
        if (self.image == null) {
            return
        }

        // Only destroy texture if it's not in the shared cache
        // Shared surfaces are owned by SURFACE_CACHE; only free sprite-owned
        // surfaces (e.g. replaced by ImageFX, or the fallback image).
        if (!is_shared_surface(self.image)) {
            (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(self.image)
        }
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
export { Component_destroy, Component_draw, Component_duplicate, Component_flip, Component_initialize, Component_is_mouse_hovering, Component_load_image, Component_set_color, InternalSprite, Sprite, clear_surface_cache, compute_effect_prewarm_surface, effect_prewarm_pending, finalize_effect_prewarm, get_or_create_texture, get_or_load_surface, is_shared_surface, load_image_sdl, prewarm_effect_textures, pump_effect_prewarm }
