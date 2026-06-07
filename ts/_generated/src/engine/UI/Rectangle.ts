export {}
import { unsafe_string } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..UI.JulGame
    // using ..UI.(globalThis as any).JulGame.Math
    // import ..UI
    // using (globalThis as any).JulGame.EffectsModule
    // using (globalThis as any).JulGame.EffectRendererModule
    // using (globalThis as any).JulGame.EffectCacheModule
    
    
    class Rectangle extends UI.UIElement {
        fillMode: boolean
        isActive: boolean
        isWorldEntity: boolean
        persistentBetweenScenes: boolean
        borderRadius: number
        borderWidth: number
        borderColor: [number, number, number, number]
        //  effects support
        effects: any[]  // Will hold Effect objects
        effectTexture: any | null
        needsEffectUpdate: boolean
        effectCacheKey: string
        
        function Rectangle(;
            id: string=(globalThis as any).JulGame.generate_uuid(), 
            name: string = "TextBox", 
            anchor: string = "none",
            anchorOffset = {x: 0, y: 0}, 
            isWorldEntity: boolean=false, 
            layer: number=0,
            position = {x: 0, y: 0}, 
            clickEvents: Function[] = [],
            hoverEnterEvents: Function[] = [],
            hoverExitEvents: Function[] = [],
            isActive: boolean=true,
            persistentBetweenScenes: boolean=false,
            color= [255, 255, 255, 255], 
            parent: UIElement | null | any=null,
            fillMode: boolean=true,
            borderRadius: number=0, 
            borderWidth: number=0, 
            borderColor= [0, 0, 0, 255], 
            size = {x: 100, y: 100},
            forceClickCheck: boolean=false
        )                  
            
            
            // Set fields that are part of the Rectangle class this {.color = color
            this.fillMode = fillMode
            this.id = id
            this.isActive = isActive
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = persistentBetweenScenes
            this.position = position
            this.size = size
            this.borderRadius = borderRadius
            this.borderWidth = borderWidth
            this.borderColor = borderColor
            this.isHovered = false
            this.layer = layer
            this.forceClickCheck = forceClickCheck
            // Initialize effects
            this.effects = []
            this.effectTexture = null
            this.needsEffectUpdate = false
            this.effectCacheKey = ""
            
            // Now set fields that are part of UIElementInstance through the relationship system
            // These need to be set after the Rectangle is constructed
            this.anchor = (globalThis as any).JulGame.Enum{Any}(
                "center",
                "top",
                "bottom",
                "left",
                "right",
                "topLeft",
                "topRight",
                "bottomLeft",
                "bottomRight",
                "centerLeft",
                "centerRight",
                "centerTop",
                "centerBottom",
                "none"
            )
            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents
            this.parent = parent

        }
    }
    
    /*
    Draw a filled arc (quarter circle) with center, radius, and start/} angles
    */
    function draw_filled_arc(renderer, x, y, radius, start_angle, end_angle, color) {
        // Save the current renderer color and blend mode
        let r = 0
        let g = 0
        let b = 0
        let a = 0;
        (globalThis as any).JulGameSdl.glue_SDL_GetRenderDrawColor(renderer, r, g, b, a);
        
        // Set the color for the arc
        (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(
            renderer, 
            Number(color[0]), 
            Number(color[1]), 
            Number(color[2]), 
            Number(color[3])
        )
        
        // Draw the filled arc by drawing lines from the center to points on the arc
        let steps = Math.max(10, radius ÷ 2)  // Number of steps based on radius size
        let angle_step = (end_angle - start_angle) / steps
        
        for (const i of 0:steps) {
            let angle = start_angle + i * angle_step
            let end_x = x + radius * cos(angle)
            let end_y = y + radius * sin(angle);
            
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(
                renderer,
                Number(x),
                Number(y),
                Number(end_x),
                Number(end_y)
            )
        };
        
        // Restore the original renderer color
        (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(renderer, r, g, b, a)
    }
    
    /*
    Draw a rounded rectangle with the specified border radius
    */
    function draw_rounded_rectangle(renderer, rect, radius, color, fill_mode) {
        // Ensure the radius isn't too large for the rectangle
        radius = Math.min(radius, Math.min(rect.w, rect.h) ÷ 2)
        
        if (radius <= 0) {
            // If radius is 0 or negative, draw a regular rectangle
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(
                renderer,
                Number(color[0]),
                Number(color[1]),
                Number(color[2]),
                Number(color[3])
            )
            
            if (fill_mode) {
                (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF(renderer, rect)
            } else {
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF(renderer, rect)
            }
            return
        }
        
        // Center points for the corner arcs
        let top_left_center_x = rect.x + radius
        let top_left_center_y = rect.y + radius
        
        let top_right_center_x = rect.x + rect.w - radius
        let top_right_center_y = rect.y + radius
        
        let bottom_left_center_x = rect.x + radius
        let bottom_left_center_y = rect.y + rect.h - radius
        
        let bottom_right_center_x = rect.x + rect.w - radius
        let bottom_right_center_y = rect.y + rect.h - radius
        
        if (fill_mode) {
            // Draw the main rectangle (excluding corners)
            let main_rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                rect.x,
                rect.y + radius,
                rect.w,
                rect.h - 2 * radius
            );
            
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(
                renderer,
                Number(color[0]),
                Number(color[1]),
                Number(color[2]),
                Number(color[3])
            );
            
            (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF(renderer, main_rect)
            
            // Draw the top and bottom rectangles (excluding corners)
            let top_rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                rect.x + radius,
                rect.y,
                rect.w - 2 * radius,
                radius
            )
            
            let bottom_rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                rect.x + radius,
                rect.y + rect.h - radius,
                rect.w - 2 * radius,
                radius
            );
            
            (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF(renderer, top_rect);
            (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF(renderer, bottom_rect)
            
            // Draw the four corner arcs
            // Top-left corner (π to 3π/2)
            draw_filled_arc(renderer, top_left_center_x, top_left_center_y, 
                            radius, π, 3π/2, color)
            
            // Top-right corner (3π/2 to 2π)
            draw_filled_arc(renderer, top_right_center_x, top_right_center_y, 
                            radius, 3π/2, 2π, color)
            
            // Bottom-left corner (π/2 to π)
            draw_filled_arc(renderer, bottom_left_center_x, bottom_left_center_y, 
                            radius, π/2, π, color)
            
            // Bottom-right corner (0 to π/2)
            draw_filled_arc(renderer, bottom_right_center_x, bottom_right_center_y, 
                            radius, 0, π/2, color)
        } else {
            // Draw the outline of a rounded rectangle
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(
                renderer,
                Number(color[0]),
                Number(color[1]),
                Number(color[2]),
                Number(color[3])
            );
            
            // Draw the top line
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(
                renderer,
                Number(rect.x + radius),
                Number(rect.y),
                Number(rect.x + rect.w - radius),
                Number(rect.y)
            );
            
            // Draw the bottom line
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(
                renderer,
                Number(rect.x + radius),
                Number(rect.y + rect.h),
                Number(rect.x + rect.w - radius),
                Number(rect.y + rect.h)
            );
            
            // Draw the left line
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(
                renderer,
                Number(rect.x),
                Number(rect.y + radius),
                Number(rect.x),
                Number(rect.y + rect.h - radius)
            );
            
            // Draw the right line
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(
                renderer,
                Number(rect.x + rect.w),
                Number(rect.y + radius),
                Number(rect.x + rect.w),
                Number(rect.y + rect.h - radius)
            )
            
            // Draw corner arcs
            // Draw corner arcs // using approx. line segments
            let steps = Math.max(10, radius ÷ 2)
            
            // Top-left corner
            for (const i of 0:steps) {
                let angle1 = π + i * (π/2) / steps
                let angle2 = π + (i + 1) * (π/2) / steps
                
                let x1 = top_left_center_x + radius * cos(angle1)
                let y1 = top_left_center_y + radius * sin(angle1)
                let x2 = top_left_center_x + radius * cos(angle2)
                let y2 = top_left_center_y + radius * sin(angle2);
                
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(renderer, Number(x1), Number(y1), Number(x2), Number(y2))
            }
            
            // Top-right corner
            for (const i of 0:steps) {
                angle1 = 3π/2 + i * (π/2) / steps
                angle2 = 3π/2 + (i + 1) * (π/2) / steps
                
                x1 = top_right_center_x + radius * cos(angle1)
                y1 = top_right_center_y + radius * sin(angle1)
                x2 = top_right_center_x + radius * cos(angle2)
                y2 = top_right_center_y + radius * sin(angle2);
                
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(renderer, Number(x1), Number(y1), Number(x2), Number(y2))
            }
            
            // Bottom-left corner
            for (const i of 0:steps) {
                angle1 = π/2 + i * (π/2) / steps
                angle2 = π/2 + (i + 1) * (π/2) / steps
                
                x1 = bottom_left_center_x + radius * cos(angle1)
                y1 = bottom_left_center_y + radius * sin(angle1)
                x2 = bottom_left_center_x + radius * cos(angle2)
                y2 = bottom_left_center_y + radius * sin(angle2);
                
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(renderer, Number(x1), Number(y1), Number(x2), Number(y2))
            }
            
            // Bottom-right corner
            for (const i of 0:steps) {
                angle1 = 0 + i * (π/2) / steps
                angle2 = 0 + (i + 1) * (π/2) / steps
                
                x1 = bottom_right_center_x + radius * cos(angle1)
                y1 = bottom_right_center_y + radius * sin(angle1)
                x2 = bottom_right_center_x + radius * cos(angle2)
                y2 = bottom_right_center_y + radius * sin(angle2);
                
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLineF(renderer, Number(x1), Number(y1), Number(x2), Number(y2))
            }
        }
    }
    
    /*
    Draw a border around a rounded rectangle
    */
    function draw_rounded_border(renderer, rect, radius, border_width, color) {
        // Draw multiple concentric borders
        for (const i of 0:border_width-1) {
            let border_rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                rect.x - Number(i),
                rect.y - Number(i),
                rect.w + Number(i * 2),
                rect.h + Number(i * 2)
            )
            
            draw_rounded_rectangle(
                renderer, 
                border_rect, 
                radius + i, 
                color, 
                false
            )
        }
    }
    
    function UI_render(self: Rectangle) {
        if (!self.isActive) {
            return
        }
        
        // Apply anchor positioning
        UI.align_to_anchor(self)
        
        // Update effects if needed
        if (self.needsEffectUpdate && !isempty(self.effects)) {
            console.debug(`Updating effects for rectangle: ${self.name}`)

        }
        
        // Use effect texture if available, otherwise use direct rendering
        if (!isempty(self.effects) && self.effectTexture != null) {
            render_rectangle_with_effects(self)
            return
        }
        
        let camera = MAIN.scene.camera
        
        // Calculate drawing coordinates based on world or screen position
        if (self.isWorldEntity && camera !== null) {
            let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
            let posX = vecMul(vecSub(self.position.x, vecAdd(camera.position.x, camera.offset.x)), S)
            let posY = vecMul(vecSub(self.position.y, vecAdd(camera.position.y, camera.offset.y)), S)
            let width = self.size.x * S
            let height = self.size.y * S
            
            let rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                Number(posX),
                Number(posY),
                Number(width),
                Number(height)
            )
        } else {
            rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                Number(self.position.x),
                Number(self.position.y),
                Number(self.size.x),
                Number(self.size.y)
            )
        }
        
        // Save current render draw color
        let r = 0
        let g = 0
        let b = 0
        let a = 0;
        (globalThis as any).JulGameSdl.glue_SDL_GetRenderDrawColor((globalThis as any).JulGame.Renderer, r, g, b, a);
(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawBlendMode_BLEND()
        // Draw the rectangle with or without rounded corners
        if (self.borderRadius > 0) {
            // Draw with rounded corners
            draw_rounded_rectangle(
                (globalThis as any).JulGame.Renderer,
                rect,
                self.borderRadius,
                self.color,
                self.fillMode
            )
            
            // Draw border if borderWidth > 0
            if (self.borderWidth > 0) {
                draw_rounded_border(
                    (globalThis as any).JulGame.Renderer,
                    rect,
                    self.borderRadius,
                    self.borderWidth,
                    self.borderColor
                )
            }
        } else {
            // Regular rectangle (no rounded corners)
            // Set new color
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(Number(self.color[0]), 
                Number(self.color[1]), 
                Number(self.color[2]), 
                Number(self.color[3])
            )
            
            // Draw rectangle
            if (self.fillMode) {
                (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF((globalThis as any).JulGame.Renderer, rect)
            } else {
                (globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF((globalThis as any).JulGame.Renderer, rect)
            }
            
            // Draw border if borderWidth > 0
            if (self.borderWidth > 0) {
                // Set border color
                (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(Number(self.borderColor[0]), 
                    Number(self.borderColor[1]), 
                    Number(self.borderColor[2]), 
                    Number(self.borderColor[3])
                )
                
                // Draw border
                for (const i of 0:self.borderWidth-1) {
                    let border_rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                        rect.x - Number(i),
                        rect.y - Number(i),
                        rect.w + Number(i * 2),
                        rect.h + Number(i * 2)
                    );
                    (globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF((globalThis as any).JulGame.Renderer, border_rect)
                }
            }
        };
        
        // Restore original color
        (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(r, g, b, a)
    }
    
    function UI_initialize(self: Rectangle) {
        // null needed for initialization
    }

    function UI_add_click_event(self: Rectangle, event) {
        self.clickEvents.push(event)
    }

    //= function UI.add_hover_event(this, event)
        this.hoverEvents.push(event)
    } =//

    function UI_destroy(self: Rectangle) {
        // Effect textures may be cached and reused elsewhere. Just clear the reference.
        if (self.effectTexture != null) {
            self.effectTexture = null
        }
        
        MAIN.scene.uiElements = filter(x => x !== self, MAIN.scene.uiElements)
    }
    
    //  effects API
    function UI_apply_effects(self: Rectangle, effects: Vector) {
        self.effects = Any[effect for effect in effects]
        // compute cache key and flag update only when changed
        let newKey = generate_effect_cache_key(self)
        if (self.effectCacheKey != newKey) {
            self.effectCacheKey = newKey
            self.needsEffectUpdate = true
        } else {
            console.debug("Rectangle.apply_effects!: cache key unchanged; skipping recompute") name=self.name
        }

    }
    
    function apply_style(self: Rectangle, style) {
        return apply_effects(self, style.effects)
    }

    
    function render_rectangle_with_effects(self: Rectangle) {
        // console.debug("render_rectangle_with_effects: Starting for rectangle $(self.name)")
        // console.debug("render_rectangle_with_effects: effectTexture=$(self.effectTexture)")
        
        let camera = MAIN.scene.camera
        
        // Calculate position
        if (self.isWorldEntity && camera !== null) {
            let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
            let posX = vecMul(vecSub(self.position.x, vecAdd(camera.position.x, camera.offset.x)), S)
            let posY = vecMul(vecSub(self.position.y, vecAdd(camera.position.y, camera.offset.y)), S)
            let width = self.size.x * S
            let height = self.size.y * S
        } else {
            posX = self.position.x
            posY = self.position.y
            width = self.size.x
            height = self.size.y
        }
        
     //   console.debug("render_rectangle_with_effects: Rendering at ($posX, $posY) with size $(width)x$(height)")
        
        // Render effect texture
        let result = (globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
            (globalThis as any).JulGame.Renderer,
            self.effectTexture,
            null,
            (globalThis as any).JulGameSdl.glue_SDL_FRect(Number(posX), Number(posY), Number(width), Number(height))
        )
        
        if (result != 0) {
            console.error(`render_rectangle_with_effects: SDL_RenderCopyF failed: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        } else {
         //   console.debug("render_rectangle_with_effects: Successfully rendered effect texture")
        }
    }

    // Helpers to serialize effects and generate cache keys (mirrors UIImage)
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

    function generate_effect_cache_key(self: Rectangle): string
        // Cache key excludes position/rotation (and other transform-only changes)
        // Effects depend on size, color, border properties, and effect params
        let content = [this.size, "|", this.color, "|", this.borderRadius, "|", this.borderWidth, "|", this.borderColor, "|", this.fillMode, "|", serialize_effects(this.effects)].join("")
        return String(hash(content))
    }

    // Local effects cache for Rectangle
    const EFFECT_CACHE = {}
    const MAX_CACHE_SIZE = 100

    function cache_effect_texture(key: string, texture: any) {
        EFFECT_CACHE[key] = texture
        console.debug(`Cached Rectangle effect texture for key: ${key}`)
    }

    function clear_effects_cache() {
        for (key, texture) in EFFECT_CACHE
            if (texture != null) {
                (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(texture)
            }
        }
        empty(EFFECT_CACHE)
    }

        return snapshot
    }
export { Rectangle, UI_add_click_event, UI_apply_effects, UI_destroy, UI_initialize, UI_render, apply_style, cache_effect_texture, clear_effects_cache, draw_filled_arc, draw_rounded_border, draw_rounded_rectangle, generate_effect_cache_key, render_rectangle_with_effects, serialize_effects }
