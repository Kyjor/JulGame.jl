module JulGameEditor
    include("../Editor.jl")
    
    function run()
       Editor.run()
    end

    julia_main() = run()
end
# Uncomment to allow for direct execution of this file. If you want to build this project with PackageCompiler, comment the line below
#JulGameEditor.run()