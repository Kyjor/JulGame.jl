using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
MAIN = nothing

IS_WEB::Bool = false
IS_DEBUG::Bool = false
IS_PACKAGE_COMPILED::Bool = false
IS_CHANGING_SCENE::Bool = false
SCALE_QUALITY::String = "2"

# Temporary variable for recent project path selection
TEMP_SELECTED_PATH::String = ""
    
DELTA_TIME = 0.0
    
SCENE_CACHE::Dict = Dict{String, Any}()
PRELOADED_SCENES::Dict = Dict{String, Any}()
IMAGE_CACHE::Dict = Dict{String, Any}()
FONT_CACHE::Dict = Dict{String, Any}()
AUDIO_CACHE::Dict = Dict{String, Any}()
    
BUILT_IN_ASSETS::Dict = Dict{String, Any}()
BUILT_IN_ASSETS["Font"] = read(joinpath(@__DIR__, "engine", "Assets", "Fonts", "FiraCode-Regular.ttf"))
    
IS_EDITOR::Bool = false
IS_EDITOR_PLAY_MODE::Bool = false
    
Coroutines::Vector = []
RENDER_FUNCTIONS::Vector = []

ProjectModule = ""
ScriptModule = Module(:Scripts)
LoadedScripts = Set{String}()