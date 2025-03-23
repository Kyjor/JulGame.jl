###
# UI Factory Functions
# This file contains factory functions for creating UI elements
###

using ..Math
using ..UI.JulGame
using ..UI.ProgressBarModule
using ..UI.RectangleModule
using ..UI.LineModule
using ..UI.CircleModule
using ..UI.TextBoxModule
using ..UI.ScreenButtonModule

"""
    create_progress_bar(position::Vector2, size::Vector2, progress::Number=0.5, 
                      fillColor::Tuple{Int32, Int32, Int32, Int32}=(0, 255, 0, 255),
                      backgroundColor::Tuple{Int32, Int32, Int32, Int32}=(100, 100, 100, 200),
                      borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255);
                      name::String="ProgressBar", id::String="", isWorldEntity::Bool=false,
                      borderWidth::Int32=1, borderRadius::Int32=0, vertical::Bool=false, 
                      showBackground::Bool=true, alpha::Int32=255)

Create a new progress bar UI element.

# Arguments
- `position::Vector2`: The position of the progress bar.
- `size::Vector2`: The size of the progress bar.
- `progress::Number=0.5`: The initial progress value (0.0 to 1.0).
- `fillColor::Tuple{Int32, Int32, Int32, Int32}=(0, 255, 0, 255)`: The color of the progress fill in RGBA format.
- `backgroundColor::Tuple{Int32, Int32, Int32, Int32}=(100, 100, 100, 200)`: The background color in RGBA format.
- `borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255)`: The border color in RGBA format.
- `name::String="ProgressBar"`: An optional name for the progress bar.
- `id::String=""`: An optional ID for the progress bar.
- `isWorldEntity::Bool=false`: Whether this is a world entity or a screen-space UI element.
- `borderWidth::Int32=1`: The width of the border in pixels.
- `borderRadius::Int32=0`: The radius of the border corners in pixels.
- `vertical::Bool=false`: Whether the progress bar fills vertically (bottom to top) or horizontally (left to right).
- `showBackground::Bool=true`: Whether to display the background.
- `alpha::Int32=255`: Transparency of the progress bar (0-255).

# Returns
A new ProgressBar object.
"""
function create_progress_bar(position::Vector2, size::Vector2, progress::Number=0.5, 
                           fillColor::Tuple{Int32, Int32, Int32, Int32}=(0, 255, 0, 255),
                           backgroundColor::Tuple{Int32, Int32, Int32, Int32}=(100, 100, 100, 200),
                           borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255);
                           name::String="ProgressBar", id::String="", isWorldEntity::Bool=false,
                           borderWidth::Int32=1, borderRadius::Int32=0, vertical::Bool=false, 
                           showBackground::Bool=true, alpha::Int32=255)
    
    # Convert progress to Float32 and clamp to valid range
    progressFloat = Float32(clamp(progress, 0.0, 1.0))
    
    # Create the progress bar 
    progressBar = ProgressBar(
        name, 
        position, 
        size, 
        progressFloat,
        fillColor,
        backgroundColor,
        borderColor;
        id=id == "" ? JulGame.generate_uuid() : id,
        isWorldEntity=isWorldEntity,
        borderWidth=borderWidth,
        borderRadius=borderRadius,
        vertical=vertical,
        showBackground=showBackground
    )
    
    # Set alpha if different from default
    if alpha != 255
        progressBar.alpha = alpha
    end
    
    # Add to scene
    push!(MAIN.scene.uiElements, progressBar)
    
    return progressBar
end

"""
    create_rectangle(position::Vector2, size::Vector2, 
                   color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
                   fillMode::Bool=true;
                   name::String="Rectangle", id::String="", isWorldEntity::Bool=false,
                   borderRadius::Int32=0, borderWidth::Int32=0, 
                   borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255))

Create a new rectangle UI element.

# Arguments
- `position::Vector2`: The position of the rectangle.
- `size::Vector2`: The size of the rectangle.
- `color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255)`: The fill color in RGBA format.
- `fillMode::Bool=true`: Whether to fill the rectangle or just draw the outline.
- `name::String="Rectangle"`: An optional name for the rectangle.
- `id::String=""`: An optional ID for the rectangle.
- `isWorldEntity::Bool=false`: Whether this is a world entity or a screen-space UI element.
- `borderRadius::Int32=0`: The radius of the border corners in pixels.
- `borderWidth::Int32=0`: The width of the border in pixels.
- `borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255)`: The border color in RGBA format.

# Returns
A new Rectangle object.
"""
function create_rectangle(position::Vector2, size::Vector2, 
                         color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
                         fillMode::Bool=true;
                         name::String="Rectangle", id::String="", isWorldEntity::Bool=false,
                         borderRadius::Int32=0, borderWidth::Int32=0, 
                         borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255))
    
    # Create the rectangle
    rectangle = Rectangle(
        name,
        position,
        size,
        color,
        fillMode;
        id=id == "" ? JulGame.generate_uuid() : id,
        isWorldEntity=isWorldEntity,
        borderRadius=borderRadius,
        borderWidth=borderWidth,
        borderColor=borderColor
    )
    
    # Add to scene
    push!(MAIN.scene.uiElements, rectangle)
    
    return rectangle
end

"""
    create_line(start::Vector2, ending::Vector2, color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
               thickness::Int32=1; name::String="Line", id::String="", isWorldEntity::Bool=false)

Create a new line UI element.

# Arguments
- `start::Vector2`: The start position of the line.
- `ending::Vector2`: The end position of the line.
- `color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255)`: The line color in RGBA format.
- `thickness::Int32=1`: The thickness of the line in pixels.
- `name::String="Line"`: An optional name for the line.
- `id::String=""`: An optional ID for the line.
- `isWorldEntity::Bool=false`: Whether this is a world entity or a screen-space UI element.

# Returns
A new Line object.
"""
function create_line(start::Vector2, ending::Vector2, 
                    color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
                    thickness::Int32=1;
                    name::String="Line", id::String="", isWorldEntity::Bool=false)
    
    # Create the line
    line = Line(
        name,
        start,
        ending,
        color,
        thickness;
        id=id == "" ? JulGame.generate_uuid() : id,
        isWorldEntity=isWorldEntity
    )
    
    # Add to scene
    push!(MAIN.scene.uiElements, line)
    
    return line
end

"""
    create_circle(center::Vector2, radius::Int32, 
                color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
                fillMode::Bool=true;
                name::String="Circle", id::String="", isWorldEntity::Bool=false)

Create a new circle UI element.

# Arguments
- `center::Vector2`: The center position of the circle.
- `radius::Int32`: The radius of the circle in pixels.
- `color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255)`: The circle color in RGBA format.
- `fillMode::Bool=true`: Whether to fill the circle or just draw the outline.
- `name::String="Circle"`: An optional name for the circle.
- `id::String=""`: An optional ID for the circle.
- `isWorldEntity::Bool=false`: Whether this is a world entity or a screen-space UI element.

# Returns
A new Circle object.
"""
function create_circle(center::Vector2, radius::Int32, 
                      color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255),
                      fillMode::Bool=true;
                      name::String="Circle", id::String="", isWorldEntity::Bool=false,
                      borderWidth::Int32=0, borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255))
    
    # Create the circle
    circle = Circle(
        name,
        center,
        radius,
        color,
        fillMode;
        id=id == "" ? JulGame.generate_uuid() : id,
        isWorldEntity=isWorldEntity,
        borderWidth=borderWidth,
        borderColor=borderColor
    )
    
    # Add to scene
    push!(MAIN.scene.uiElements, circle)
    
    return circle
end 