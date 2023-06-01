# What is julGame?
julGame is a game engine based on the julia programming language with the help of SDL2. Users are able to build their projects out to windows .exe files at the moment.

# Why are you making this?
Honestly, only because I find Julia interesting. I would like to see a game dev scene around it as there isn't much of one now. I am not a Julia programmer, so I am sure there is a lot I am doing wrong. If you see anything that I can fix, please just let me know with a discussion or an issue.

# How to install as a package: 
] add https://github.com/Kyjor/julgame for main
] add https://github.com/Kyjor/julgame#develop for develop

# How to build the platformer project

Navigate to demos, and start the julia repl in this folder. Use cd("full\\path\\to\\demos"). Run "using PackageCompiler" (install PackageCompiler if you haven't already). Run the function create_app("platformer","NameOfTheBuildFileFolder"). Replace "NameOfTheBuildFileFolder" with whatever you want to name it.
