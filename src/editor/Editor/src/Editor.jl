module Editor
    using JulGame

    function run()
       JulGame.Editor.run()
    end

    julia_main() = run()
end
# Uncommented to allow for direct execution of this file. If you want to build this project with PackageCompiler, comment the line below
Editor.run()