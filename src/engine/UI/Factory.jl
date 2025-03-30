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
                      fillColor::NTuple{4, Int}=(0, 255, 0, 255),
                      backgroundColor::NTuple{4, Int}=(100, 100, 100, 200),
                      borderColor::NTuple{4, Int}=(0, 0, 0, 255);
                      name::String="ProgressBar", id::String="", isWorldEntity::Bool=false,
                      borderWidth::Int=1, borderRadius::Int=0, vertical::Bool=false, 
                      showBackground::Bool=true, alpha::Int=255, layer::Int=0)

Create a new progress bar UI element.

# Arguments
- `position::Vector2`: The position of the progress bar.
- `size::Vector2`: The size of the progress bar.
- `progress::Number=0.5`: The initial progress value (0.0 to 1.0).
- `fillColor::NTuple{4, Int}=(0, 255, 0, 255)`: The color of the progress fill in RGBA format.
- `backgroundColor::NTuple{4, Int}=(100, 100, 100, 200)`: The background color in RGBA format.
- `borderColor::NTuple{4, Int}=(0, 0, 0, 255)`: The border color in RGBA format.
- `name::String="ProgressBar"`: The name of the progress bar.
- `id::String=""`: The unique identifier for the progress bar. If empty, a UUID will be generated.
- `isWorldEntity::Bool=false`: Whether the progress bar should be positioned in world space.
- `borderWidth::Int=1`: The width of the border.
- `borderRadius::Int=0`: The radius of the border rounded corners.
- `vertical::Bool=false`: Whether the progress bar fills vertically (bottom to top) instead of horizontally.
- `showBackground::Bool=true`: Whether to show the background of the progress bar.
- `alpha::Int=255`: The transparency of the progress bar (0-255).
- `layer::Int=0`: The rendering layer (higher values render on top).

# Returns
The newly created ProgressBar object
"""
function create_progress_bar(position::Vector2, size::Vector2, progress::Number=0.5, 
                           fillColor::NTuple{4, Int}=(0, 255, 0, 255),
                           backgroundColor::NTuple{4, Int}=(100, 100, 100, 200),
                           borderColor::NTuple{4, Int}=(0, 0, 0, 255);
                           name::String="ProgressBar", id::String="", isWorldEntity::Bool=false,
                           borderWidth::Int=1, borderRadius::Int=0, vertical::Bool=false, 
                           showBackground::Bool=true, alpha::Int=255, layer::Int=0)
    
    # Convert progress to Float32 and clamp to valid range
    progress = Float32(clamp(progress, 0.0, 1.0))
    
    # Create a UUID if not provided
    if id == ""
        id = JulGame.generate_uuid()
    end
    
    # Create the progress bar
    progressBar = ProgressBar(name, position, size, progress, fillColor, backgroundColor, borderColor;
                             id=id, isWorldEntity=isWorldEntity, borderWidth=borderWidth,
                             borderRadius=borderRadius, vertical=vertical, showBackground=showBackground,
                             layer=layer)
    
    progressBar.alpha = alpha
    
    # Add the progress bar to the scene
    push!(MAIN.scene.uiElements, progressBar)
    
    return progressBar
end

"""
    create_rectangle(position::Vector2, size::Vector2, color::NTuple{4, Int}=(255, 255, 255, 255),
                   fillMode::Bool=true;
                   name::String="Rectangle", id::String="", isWorldEntity::Bool=false,
                   borderRadius::Int=0, borderWidth::Int=0, 
                   borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                   layer::Int=0)

Create a new rectangle UI element.

# Arguments
- `position::Vector2`: The position of the rectangle
- `size::Vector2`: The size of the rectangle
- `color::NTuple{4, Int}`: The color of the rectangle in RGBA format
- `fillMode::Bool=true`: Whether to fill the rectangle or just draw the outline
- `name::String="Rectangle"`: The name of the rectangle
- `id::String=""`: The unique identifier for the rectangle. If empty, a UUID will be generated
- `isWorldEntity::Bool=false`: Whether the rectangle should be positioned in world space
- `borderRadius::Int=0`: The radius of the border rounded corners
- `borderWidth::Int=0`: The width of the border
- `borderColor::NTuple{4, Int}=(0, 0, 0, 255)`: The color of the border in RGBA format
- `layer::Int=0`: The rendering layer (higher values render on top)

# Returns
The newly created Rectangle object
"""
function create_rectangle(position::Vector2, size::Vector2, color::NTuple{4, Int}=(255, 255, 255, 255),
                         fillMode::Bool=true;
                         name::String="Rectangle", id::String="", isWorldEntity::Bool=false,
                         borderRadius::Int=0, borderWidth::Int=0, 
                         borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                         layer::Int=0)
    
    # Create a UUID if not provided
    if id == ""
        id = JulGame.generate_uuid()
    end
    
    # Create the rectangle
    rectangle = Rectangle(name, position, size, color, fillMode;
                         id=id, isWorldEntity=isWorldEntity,
                         borderRadius=borderRadius, borderWidth=borderWidth, 
                         borderColor=borderColor, layer=layer)
    
    # Add the rectangle to the scene
    push!(MAIN.scene.uiElements, rectangle)
    
    return rectangle
end

"""
    create_line(start::Vector2, ending::Vector2, color::NTuple{4, Int}=(255, 255, 255, 255),
               thickness::Int=1; name::String="Line", id::String="", isWorldEntity::Bool=false, layer::Int=0)

Create a new line UI element.

# Arguments
- `start::Vector2`: The start position of the line
- `ending::Vector2`: The end position of the line
- `color::NTuple{4, Int}=(255, 255, 255, 255)`: The color of the line in RGBA format
- `thickness::Int=1`: The thickness of the line in pixels
- `name::String="Line"`: The name of the line
- `id::String=""`: The unique identifier for the line. If empty, a UUID will be generated
- `isWorldEntity::Bool=false`: Whether the line should be positioned in world space
- `layer::Int=0`: The rendering layer (higher values render on top)

# Returns
The newly created Line object
"""
function create_line(start::Vector2, ending::Vector2, 
                    color::NTuple{4, Int}=(255, 255, 255, 255),
                    thickness::Int=1;
                    name::String="Line", id::String="", isWorldEntity::Bool=false, layer::Int=0)
    
    # Create a UUID if not provided
    if id == ""
        id = JulGame.generate_uuid()
    end
    
    # Create the line
    line = Line(name, start, ending, color, thickness; id=id, isWorldEntity=isWorldEntity, layer=layer)
    
    # Add the line to the scene
    push!(MAIN.scene.uiElements, line)
    
    return line
end

"""
    create_circle(center::Vector2, radius::Number, color::NTuple{4, Int}=(255, 255, 255, 255),
                 fillMode::Bool=true; name::String="Circle", id::String="", isWorldEntity::Bool=false,
                 borderWidth::Int=0, borderColor::NTuple{4, Int}=(0, 0, 0, 255), layer::Int=0)

Create a new circle UI element.

# Arguments
- `center::Vector2`: The center position of the circle
- `radius::Number`: The radius of the circle
- `color::NTuple{4, Int}=(255, 255, 255, 255)`: The color of the circle in RGBA format
- `fillMode::Bool=true`: Whether to fill the circle or just draw the outline
- `name::String="Circle"`: The name of the circle
- `id::String=""`: The unique identifier for the circle. If empty, a UUID will be generated
- `isWorldEntity::Bool=false`: Whether the circle should be positioned in world space
- `borderWidth::Int=0`: The width of the border
- `borderColor::NTuple{4, Int}=(0, 0, 0, 255)`: The color of the border in RGBA format
- `layer::Int=0`: The rendering layer (higher values render on top)

# Returns
The newly created Circle object
"""
function create_circle(center::Vector2, radius::Number, 
                      color::NTuple{4, Int}=(255, 255, 255, 255),
                      fillMode::Bool=true;
                      name::String="Circle", id::String="", isWorldEntity::Bool=false,
                      borderWidth::Int=0, borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                      layer::Int=0)
    
    # Create a UUID if not provided
    if id == ""
        id = JulGame.generate_uuid()
    end
    
    # Create the circle
    circle = Circle(name, center, Float32(radius), color, fillMode; 
                   id=id, isWorldEntity=isWorldEntity, 
                   borderWidth=borderWidth, borderColor=borderColor, layer=layer)
    
    # Add the circle to the scene
    push!(MAIN.scene.uiElements, circle)
    
    return circle
end 