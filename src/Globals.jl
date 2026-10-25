MAIN = nothing
"""Typed access to `MAIN` (a MainLoop once the game runs). Method defined in MainLoop.jl."""
function main_loop end

IS_WEB::Bool = false
IS_DEBUG::Bool = false
IS_PACKAGE_COMPILED::Bool = false
IS_CHANGING_SCENE::Bool = false
SCALE_QUALITY::String = "2"

# Temporary variable for recent project path selection
TEMP_SELECTED_PATH::String = ""
    
DELTA_TIME::Float64 = 0.0
    
SCENE_CACHE::Dict{String, JSONValue} = Dict{String, JSONValue}()
IMAGE_CACHE::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
FONT_CACHE::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
AUDIO_CACHE::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
    
BUILT_IN_ASSETS::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
BUILT_IN_ASSETS["Font"] = read(joinpath(@__DIR__, "engine", "Assets", "Fonts", "FiraCode-Regular.ttf"))
    
IS_EDITOR::Bool = false
IS_EDITOR_PLAY_MODE::Bool = false
    
RENDER_FUNCTIONS::Vector{RenderFunction} = RenderFunction[]

ProjectModule::String = ""
ScriptModule::Module = Module(:Scripts)
LoadedScripts::Set{String} = Set{String}()