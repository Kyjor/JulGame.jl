"""
    This module contains background effects that can be rendered as screen overlays or world effects.
"""
module BackgroundFXModule
    using ..FX.JulGame
    import ..Math
    using ..FX.SDL2  # Use SDL2 directly
    
    include("Easings.jl")

    export MovingCirclesEffect, create_moving_circles_effect, update_moving_circles_effect, render_moving_circles_effect

    """
    Internal data structure for individual circles.
    """
    mutable struct CircleData
        x::Float64
        y::Float64
        size::Float64
        color::NTuple{4, UInt8}
        progress::Float64  # 0.0 to 1.0, represents journey progress
        
        CircleData(x, y) = new(x, y, 0.0, (255, 255, 255, 255), 0.0)
    end

    """
    Data structure for a moving circles background effect.
    """
    mutable struct MovingCirclesEffect
        circles::Vector{CircleData}
        spacing::Float64  # Distance between circles
        speed::Float64    # Movement speed
        start_size::Float64
        target_size::Float64
        start_color::NTuple{4, UInt8}  # RGBA
        target_color::NTuple{4, UInt8}  # RGBA
        screen_width::Float64
        screen_height::Float64
        direction::Symbol  # :left_to_right, :right_to_left, :top_to_bottom, :bottom_to_top, :top_left_to_bottom_right, :top_right_to_bottom_left, :bottom_left_to_top_right, :bottom_right_to_top_left
        line_angle::Float64    # Angle in degrees for the line of circles (0 = horizontal, 90 = vertical, 45 = diagonal)
        is_filled::Bool
        is_world_entity::Bool  # Whether to use world coordinates or screen coordinates
        last_spawn_time::Float64  # Track time since last spawn for backup spawning
        size_easing::Symbol    # Easing function for size interpolation
        color_easing::Symbol   # Easing function for color interpolation
        
        MovingCirclesEffect() = new(
            Vector{CircleData}(),
            100.0,  # Default spacing
            50.0,   # Default speed
            5.0,    # Default start size
            20.0,   # Default target size
            (255, 0, 0, 100),  # Red start color
            (0, 255, 0, 255),  # Green target color
            800.0,  # Default screen width
            600.0,  # Default screen height
            :left_to_right,
            90.0,   # Default line angle (vertical line for horizontal movement)
            true,   # Filled circles by default
            false,  # Screen coordinates by default
            0.0,    # Initial spawn time
            :ease_out_quad,  # Default size easing
            :ease_in_out_sine  # Default color easing
        )
    end

    """
    Creates a new moving circles effect with the specified parameters.
    
    # Arguments
    - `spacing::Float64`: Distance between circles
    - `speed::Float64`: Movement speed in pixels per second
    - `start_size::Float64`: Initial circle size
    - `target_size::Float64`: Final circle size
    - `start_color`: Initial RGBA color as a 4-tuple (e.g., (255, 100, 100, 80))
    - `target_color`: Final RGBA color as a 4-tuple (e.g., (100, 255, 100, 200))
    - `screen_width::Float64`: Screen width for spawning circles
    - `screen_height::Float64`: Screen height for spawning circles
    - `direction::Symbol`: Movement direction (:left_to_right, :right_to_left, :top_to_bottom, :bottom_to_top, :top_left_to_bottom_right, :top_right_to_bottom_left, :bottom_left_to_top_right, :bottom_right_to_top_left)
    - `line_angle::Float64`: Angle in degrees for the line of circles (0 = horizontal, 90 = vertical, 45 = diagonal). If nothing, uses logical defaults based on direction.
    - `size_easing::Symbol`: Easing function for size interpolation (e.g., :ease_out_quad, :ease_in_out_cubic, :linear)
    - `color_easing::Symbol`: Easing function for color interpolation (e.g., :ease_in_out_sine, :ease_out_bounce, :linear)
    - `is_filled::Bool`: Whether circles are filled or just outlines
    - `is_world_entity::Bool`: Whether to use world coordinates
    
    # Returns
    - A new MovingCirclesEffect instance
    """
    function create_moving_circles_effect(;
        spacing::Float64 = 100.0,
        speed::Float64 = 50.0,
        start_size::Float64 = 5.0,
        target_size::Float64 = 20.0,
        start_color = (255, 0, 0, 100),
        target_color = (0, 255, 0, 255),
        screen_width::Float64 = 800.0,
        screen_height::Float64 = 600.0,
        direction::Symbol = :left_to_right,
        line_angle::Union{Float64, Nothing} = nothing,
        size_easing::Symbol = :ease_out_quad,
        color_easing::Symbol = :ease_in_out_sine,
        is_filled::Bool = true,
        is_world_entity::Bool = false
    )
        effect = MovingCirclesEffect()
        effect.spacing = spacing
        effect.speed = speed
        effect.start_size = start_size
        effect.target_size = target_size
        # Convert input colors to NTuple{4, UInt8}
        effect.start_color = (UInt8(start_color[1]), UInt8(start_color[2]), UInt8(start_color[3]), UInt8(start_color[4]))
        effect.target_color = (UInt8(target_color[1]), UInt8(target_color[2]), UInt8(target_color[3]), UInt8(target_color[4]))
        effect.screen_width = screen_width
        effect.screen_height = screen_height
        effect.direction = direction
        
        # Set line angle based on direction if not specified
        effect.line_angle = if line_angle === nothing
            get_default_line_angle(direction)
        else
            line_angle
        end
        
        effect.is_filled = is_filled
        effect.is_world_entity = is_world_entity
        effect.last_spawn_time = 0.0
        effect.size_easing = size_easing
        effect.color_easing = color_easing
        
        return effect
    end

    """
    Updates the moving circles effect, adding new circles and updating existing ones.
    
    # Arguments
    - `effect::MovingCirclesEffect`: The effect to update
    - `delta_time::Float64`: Time elapsed since last update in seconds
    """
    function update_moving_circles_effect(effect::MovingCirclesEffect, delta_time::Float64)
        # Remove circles that have gone off screen
        initial_count = length(effect.circles)
        filter!(circle -> is_circle_on_screen(circle, effect), effect.circles)
        
        # Add new circles if needed
        spawn_new_circles(effect, delta_time)
        
        # Update existing circles
        for circle in effect.circles
            update_circle(circle, effect, delta_time)
        end
        
        # Debug: Print circle count changes (remove this later if desired)
        if length(effect.circles) != initial_count
            # println("Circles: $initial_count → $(length(effect.circles))")
        end
    end

    """
    Renders all circles in the effect using SDL GFX functions.
    
    # Arguments
    - `effect::MovingCirclesEffect`: The effect to render
    - `camera`: Optional camera for world coordinate calculations
    """
    function render_moving_circles_effect(effect::MovingCirclesEffect, camera = nothing)
        if JulGame.Renderer == C_NULL
            return
        end

        for circle in effect.circles
            render_circle(circle, effect, camera)
        end
    end

    # Helper functions

    function get_easing_function(easing_symbol::Symbol)
        if easing_symbol == :linear
            return x -> x
        elseif easing_symbol == :ease_in_sine
            return ease_in_sine
        elseif easing_symbol == :ease_out_sine
            return ease_out_sine
        elseif easing_symbol == :ease_in_out_sine
            return ease_in_out_sine
        elseif easing_symbol == :ease_in_quad
            return ease_in_quad
        elseif easing_symbol == :ease_out_quad
            return ease_out_quad
        elseif easing_symbol == :ease_in_out_quad
            return ease_in_out_quad
        elseif easing_symbol == :ease_in_cubic
            return ease_in_cubic
        elseif easing_symbol == :ease_out_cubic
            return ease_out_cubic
        elseif easing_symbol == :ease_in_out_cubic
            return ease_in_out_cubic
        elseif easing_symbol == :ease_in_quart
            return ease_in_quart
        elseif easing_symbol == :ease_out_quart
            return ease_out_quart
        elseif easing_symbol == :ease_in_out_quart
            return ease_in_out_quart
        elseif easing_symbol == :ease_in_quint
            return ease_in_quint
        elseif easing_symbol == :ease_out_quint
            return ease_out_quint
        elseif easing_symbol == :ease_in_out_quint
            return ease_in_out_quint
        elseif easing_symbol == :ease_in_expo
            return ease_in_expo
        elseif easing_symbol == :ease_out_expo
            return ease_out_expo
        elseif easing_symbol == :ease_in_out_expo
            return ease_in_out_expo
        elseif easing_symbol == :ease_in_circ
            return ease_in_circ
        elseif easing_symbol == :ease_out_circ
            return ease_out_circ
        elseif easing_symbol == :ease_in_out_circ
            return ease_in_out_circ
        elseif easing_symbol == :ease_in_back
            return ease_in_back
        elseif easing_symbol == :ease_out_back
            return ease_out_back
        elseif easing_symbol == :ease_in_out_back
            return ease_in_out_back
        elseif easing_symbol == :ease_in_elastic
            return ease_in_elastic
        elseif easing_symbol == :ease_out_elastic
            return ease_out_elastic
        elseif easing_symbol == :ease_in_out_elastic
            return ease_in_out_elastic
        elseif easing_symbol == :ease_in_bounce
            return ease_in_bounce
        elseif easing_symbol == :ease_out_bounce
            return ease_out_bounce
        elseif easing_symbol == :ease_in_out_bounce
            return ease_in_out_bounce
        else
            # Default to linear if unknown
            @warn "Unknown easing function: $easing_symbol, using linear"
            return x -> x
        end
    end

    function get_default_line_angle(direction::Symbol)
        if direction in [:left_to_right, :right_to_left]
            return 90.0  # Vertical line for horizontal movement
        elseif direction in [:top_to_bottom, :bottom_to_top]
            return 0.0   # Horizontal line for vertical movement
        elseif direction == :top_left_to_bottom_right
            return 45.0  # Diagonal line / for diagonal movement
        elseif direction == :top_right_to_bottom_left
            return -45.0 # Diagonal line \ for diagonal movement
        elseif direction == :bottom_left_to_top_right
            return -45.0 # Diagonal line \ for diagonal movement
        elseif direction == :bottom_right_to_top_left
            return 45.0  # Diagonal line / for diagonal movement
        else
            return 90.0  # Default fallback
        end
    end

    function is_circle_on_screen(circle::CircleData, effect::MovingCirclesEffect)
        margin = max(effect.start_size, effect.target_size) + 100  # Larger margin to ensure visibility
        
        # Always check both x and y bounds for all directions
        x_in_bounds = circle.x >= -margin && circle.x <= effect.screen_width + margin
        y_in_bounds = circle.y >= -margin && circle.y <= effect.screen_height + margin
        
        return x_in_bounds && y_in_bounds
    end

    function spawn_new_circles(effect::MovingCirclesEffect, delta_time::Float64)
        effect.last_spawn_time += delta_time
        
        # Calculate spawn interval based on speed and spacing
        spawn_interval = effect.spacing / effect.speed
        
        # Check if we need to spawn a new line of circles
        time_based_spawn = effect.last_spawn_time >= spawn_interval
        position_based_spawn = should_spawn_new_line(effect)
        
        if time_based_spawn || position_based_spawn
            spawn_line_of_circles(effect)
            effect.last_spawn_time = 0.0  # Reset spawn timer
        end
    end
    
    function should_spawn_new_line(effect::MovingCirclesEffect)
        if isempty(effect.circles)
            return true
        end
        
        # Find the most recently spawned circle (closest to spawn position)
        spawn_x = get_spawn_x(effect)
        spawn_y = get_spawn_y(effect)
        
        # Find the circle closest to the spawn point
        closest_circle = nothing
        min_distance = Inf
        
        for circle in effect.circles
            distance = √((circle.x - spawn_x)^2 + (circle.y - spawn_y)^2)
            if distance < min_distance
                min_distance = distance
                closest_circle = circle
            end
        end
        
        if closest_circle === nothing
            return true
        end
        
        # Check if we need to spawn based on movement direction and spacing
        spawn_threshold = effect.spacing
        
        if effect.direction == :left_to_right
            return closest_circle.x >= (spawn_x + spawn_threshold)
        elseif effect.direction == :right_to_left
            return closest_circle.x <= (spawn_x - spawn_threshold)
        elseif effect.direction == :top_to_bottom
            return closest_circle.y >= (spawn_y + spawn_threshold)
        elseif effect.direction == :bottom_to_top
            return closest_circle.y <= (spawn_y - spawn_threshold)
        else  # Diagonal directions
            return min_distance >= spawn_threshold
        end
    end
    
    function spawn_line_of_circles(effect::MovingCirclesEffect)
        # Get starting position for the new line
        start_x = get_spawn_x(effect)
        start_y = get_spawn_y(effect)
        
        # Convert angle to radians
        angle_rad = deg2rad(effect.line_angle)
        
        # Calculate how many circles we need to span the screen diagonal
        max_dimension = max(effect.screen_width, effect.screen_height)
        diagonal_length = √(effect.screen_width^2 + effect.screen_height^2)
        num_circles = ceil(Int, diagonal_length / effect.spacing) + 2
        
        # Create circles along the line
        for i in 0:(num_circles-1)
            # Calculate position along the line
            line_offset = (i - num_circles÷2) * effect.spacing
            circle_x = start_x + line_offset * cos(angle_rad)
            circle_y = start_y + line_offset * sin(angle_rad)
            
            circle = CircleData(circle_x, circle_y)
            push!(effect.circles, circle)
        end
    end
    
    function get_spawn_x(effect::MovingCirclesEffect)
        margin = max(effect.start_size, effect.target_size) + 50
        if effect.direction in [:left_to_right, :top_left_to_bottom_right, :bottom_left_to_top_right]
            return -margin
        elseif effect.direction in [:right_to_left, :top_right_to_bottom_left, :bottom_right_to_top_left]
            return effect.screen_width + margin
        else  # Vertical movement
            return effect.screen_width / 2
        end
    end
    
    function get_spawn_y(effect::MovingCirclesEffect)
        margin = max(effect.start_size, effect.target_size) + 50
        if effect.direction in [:top_to_bottom, :top_left_to_bottom_right, :top_right_to_bottom_left]
            return -margin
        elseif effect.direction in [:bottom_to_top, :bottom_left_to_top_right, :bottom_right_to_top_left]
            return effect.screen_height + margin
                 else  # Horizontal movement
             return effect.screen_height / 2
         end
     end
     
     function get_movement_vector(direction::Symbol)
         if direction == :left_to_right
             return (1.0, 0.0)
         elseif direction == :right_to_left
             return (-1.0, 0.0)
         elseif direction == :top_to_bottom
             return (0.0, 1.0)
         elseif direction == :bottom_to_top
             return (0.0, -1.0)
         elseif direction == :top_left_to_bottom_right
             return (1/√2, 1/√2)
         elseif direction == :top_right_to_bottom_left
             return (-1/√2, 1/√2)
         elseif direction == :bottom_left_to_top_right
             return (1/√2, -1/√2)
         elseif direction == :bottom_right_to_top_left
             return (-1/√2, -1/√2)
         else
             return (1.0, 0.0)  # Default fallback
         end
     end
     
     function calculate_progress(circle::CircleData, effect::MovingCirclesEffect)
         # Calculate progress based on position relative to screen bounds
         margin = max(effect.start_size, effect.target_size) + 50
         
         if effect.direction in [:left_to_right]
             total_distance = effect.screen_width + 2 * margin
             traveled = circle.x + margin
             return clamp(traveled / total_distance, 0.0, 1.0)
         elseif effect.direction in [:right_to_left]
             total_distance = effect.screen_width + 2 * margin
             traveled = (effect.screen_width + margin) - circle.x
             return clamp(traveled / total_distance, 0.0, 1.0)
         elseif effect.direction in [:top_to_bottom]
             total_distance = effect.screen_height + 2 * margin
             traveled = circle.y + margin
             return clamp(traveled / total_distance, 0.0, 1.0)
         elseif effect.direction in [:bottom_to_top]
             total_distance = effect.screen_height + 2 * margin
             traveled = (effect.screen_height + margin) - circle.y
             return clamp(traveled / total_distance, 0.0, 1.0)
         else  # Diagonal movement
             # Calculate diagonal progress
             diagonal_distance = √(effect.screen_width^2 + effect.screen_height^2) + 2 * margin
             start_x = get_spawn_x(effect)
             start_y = get_spawn_y(effect)
             traveled = √((circle.x - start_x)^2 + (circle.y - start_y)^2)
             return clamp(traveled / diagonal_distance, 0.0, 1.0)
         end
     end



    function update_circle(circle::CircleData, effect::MovingCirclesEffect, delta_time::Float64)
        # Get movement vector based on direction
        dx, dy = get_movement_vector(effect.direction)
        
        # Update position
        distance = effect.speed * delta_time
        circle.x += dx * distance
        circle.y += dy * distance
        
        # Calculate progress based on how far the circle has traveled across the screen
        circle.progress = calculate_progress(circle, effect)
        
        # Apply easing to interpolations
        size_easing_func = get_easing_function(effect.size_easing)
        color_easing_func = get_easing_function(effect.color_easing)
        
        # Apply easing to progress for different aspects
        eased_size_progress = size_easing_func(circle.progress)
        eased_color_progress = color_easing_func(circle.progress)
        
        # Interpolate size with easing
        circle.size = effect.start_size + (effect.target_size - effect.start_size) * eased_size_progress
        
        # Interpolate color with easing and proper clamping and rounding
        r = UInt8(clamp(round(effect.start_color[1] + (Int64(effect.target_color[1]) - Int64(effect.start_color[1])) * eased_color_progress), 0, 255))
        g = UInt8(clamp(round(effect.start_color[2] + (Int64(effect.target_color[2]) - Int64(effect.start_color[2])) * eased_color_progress), 0, 255))
        b = UInt8(clamp(round(effect.start_color[3] + (Int64(effect.target_color[3]) - Int64(effect.start_color[3])) * eased_color_progress), 0, 255))
        a = UInt8(clamp(round(effect.start_color[4] + (Int64(effect.target_color[4]) - Int64(effect.start_color[4])) * eased_color_progress), 0, 255))
        
        circle.color = (r, g, b, a)
    end

    function render_circle(circle::CircleData, effect::MovingCirclesEffect, camera)
        # Calculate screen coordinates
        screen_x, screen_y = if effect.is_world_entity && camera !== nothing
            # Convert world coordinates to screen coordinates
            world_x = circle.x - (camera.position.x + camera.offset.x) * SCALE_UNITS
            world_y = circle.y - (camera.position.y + camera.offset.y) * SCALE_UNITS
            (Int32(round(world_x)), Int32(round(world_y)))
        else
            (Int32(round(circle.x)), Int32(round(circle.y)))
        end
        
        radius = Int32(round(circle.size))
        
        # Save current render draw color before drawing
        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(0)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        
        # Use SDL GFX functions to draw the circle
        if effect.is_filled
            SDL2.LibSDL2.filledCircleRGBA(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                screen_x,
                screen_y,
                radius,
                circle.color[1],
                circle.color[2],
                circle.color[3],
                circle.color[4]
            )
        else
            SDL2.LibSDL2.aacircleRGBA(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                screen_x,
                screen_y,
                radius,
                circle.color[1],
                circle.color[2],
                circle.color[3],
                circle.color[4]
            )
        end
        
        # Restore the original render draw color
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[])
    end

end 