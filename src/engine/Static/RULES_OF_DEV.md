# Rules of Development for StaticCompiler Game Project

## 🚨 CRITICAL CONSTRAINT: NO GARBAGE COLLECTION

This project uses **StaticCompiler.jl** to compile Julia code to LLVM IR and then to WebAssembly/native code. **The compiled code runs WITHOUT the Julia garbage collector**, which means:

### ❌ FORBIDDEN: Things that trigger GC or require runtime

1. **NO dynamic allocations that rely on Julia's GC**
   - ❌ `String` (use `WallocString` instead)
   - ❌ `Vector`, `Array` (use `MallocArray` from StaticTools or manual pointer arrays)
   - ❌ `Dict`, `Set`, or any standard library collections
   - ❌ Dynamic dispatch or runtime type inference
   - ❌ Closures or anonymous functions
   - ❌ String interpolation: `"value: $x"` (use `printf` instead)
   - ❌ `println()` or `print()` (use `printf` from StaticTools)

2. **NO Julia runtime features**
   - ❌ Exceptions (try/catch)
   - ❌ Broadcasting syntax (`.` operators)
   - ❌ Multiple dispatch that requires runtime resolution
   - ❌ `eval()` or other metaprogramming at runtime
   - ❌ Module imports at runtime
   - ❌ `@assert` macros (they generate runtime checks)

3. **Do NOT annotate compiled engine/game functions with `::Cvoid`**
   - ❌ `function foo()::Cvoid` in code you pass to `StaticCompiler.generate_obj` — often emits `ijl_invoke` / `julia_convert_*` and breaks the link
   - ✅ Omit the return type, or use `::Int32` (etc.) with an explicit `return`
   ```julia
   # ❌ Bad for StaticCompiler
   function begin_frame(renderer::Ptr{SDL_Renderer})::Cvoid
       llvm_SDL_RenderClear(renderer)
   end

   # ✅ Good
   function begin_frame(renderer::Ptr{SDL_Renderer})
       llvm_SDL_RenderClear(renderer)
   end
   ```
   (`llvm_bindings.jl` wrappers may still use `::Cvoid`; don't copy that pattern in `engine/`.)

4. **NO standard library functions that allocate**
   - ❌ `push!`, `append!`, `pop!` on standard arrays
   - ❌ `map`, `filter`, `reduce` (they allocate)
   - ❌ `split`, `join`, `replace` on strings
   - ❌ Most functions from `Base` that return new objects

## ✅ ALLOWED: Safe patterns for this project

### Memory Management

1. **Manual memory allocation with `wasm_malloc` and `wasm_free`**
   ```julia
   # Allocate memory
   ptr::Ptr{MyStruct} = Ptr{MyStruct}(wasm_malloc(UInt32(sizeof(MyStruct))))
   
   # Initialize with unsafe_store!
   unsafe_store!(ptr, MyStruct(...))
   
   # Access with unsafe_load
   value = unsafe_load(ptr)
   
   # Free when done
   wasm_free(Ptr{Cvoid}(ptr))
   ```

2. **Always specify exact types**
   ```julia
   # ✅ Good: explicit types
   x::Int32 = Int32(42)
   y::Float64 = Float64(3.14)
   
   # ❌ Bad: type inference
   x = 42
   y = 3.14
   ```

3. **Use StaticTools types**
   - `WallocString` for strings (with `w"..."` macro)
   - `MallocArray{T}` for arrays
   - `printf` with `c"..."` format strings

### Struct Patterns

1. **All structs must be concrete and immutable**
   ```julia
   struct MyStruct
       field1::Int32
       field2::Float64
       field3::Ptr{OtherStruct}
   end
   ```

2. **Pointer access requires custom getproperty/setproperty!**
   ```julia
   function Base.getproperty(x::Ptr{MyStruct}, f::Symbol)
       f === :field1 && return unsafe_load(Ptr{Int32}(x + offsetof(MyStruct, Val(:field1))))
       f === :field2 && return unsafe_load(Ptr{Float64}(x + offsetof(MyStruct, Val(:field2))))
   end
   
   function Base.setproperty!(x::Ptr{MyStruct}, f::Symbol, v::Any)
       f === :field1 && return unsafe_store!(Ptr{Int32}(x + offsetof(MyStruct, Val(:field1))), v)
       f === :field2 && return unsafe_store!(Ptr{Float64}(x + offsetof(MyStruct, Val(:field2))), v)
   end
   ```

3. **Use `offsetof` for struct field offsets**
   ```julia
   @generated function offsetof(::Type{X}, ::Val{field}) where {X,field}
       idx = findfirst(f->f==field, fieldnames(X))
       return fieldoffset(X, idx)
   end
   ```

### String Handling

1. **Use WallocString for string literals**
   ```julia
   # ✅ Good
   name = w"Game test"
   
   # Convert to Ptr{UInt8} for C functions
   name_ptr = str_ptr(w"Game test")
   # Don't forget to free!
   wasm_free(name_ptr)
   ```

2. **⚠️ WARNING: `str_ptr` has a buffer overflow bug**
   - The `str_ptr()` function in `wallocstring.jl` has a known bug where it writes one byte past the allocated buffer
   - This causes memory corruption when the total string length (chars + null terminator) is a **multiple of 16 bytes** (16, 32, 48, 64, etc.)
   - **Examples of problematic lengths**:
     - 15 chars + null = 16 bytes ❌
     - 31 chars + null = 32 bytes ❌
     - 47 chars + null = 48 bytes ❌
   - **Workaround**: Ensure string length (including null) is NOT a multiple of 16
   - **Better workaround**: Manually allocate and copy strings, or fix `str_ptr` to allocate `len + 1` bytes
   - **Symptoms**: "memory access out of bounds" errors at runtime in WASM

2. **Use printf for output**
   ```julia
   # ✅ Good
   printf(c"Loading sprite\n")
   printf(c"Value: %d\n", my_int)
   printf(c"Float: %f\n", my_float)
   
   # ❌ Bad
   println("Loading sprite")
   ```

### Function Signatures

1. **Always specify return types**
   ```julia
   # ✅ Good
   function my_function(x::Int32)::Float64
       return Float64(x) * 2.0
   end
   
   # ❌ Bad
   function my_function(x)
       return x * 2.0
   end
   ```

2. **Use explicit type conversions**
   ```julia
   # ✅ Good
   result::Float64 = Float64(int_value)
   
   # ❌ Bad
   result = int_value  # implicit conversion
   ```

3. **NO redeclaring variable types in the same function**
   ```julia
   # ❌ Bad: multiple type declarations for same variable
   function test(x::Int32)::Int32
       if x > 0
           f::Int32 = Int32(0)
       else
           f::Int32 = Int32(0)  # ERROR: "multiple type declarations for f"
       end
       return f
   end
   
   # ✅ Good: declare type once at the top
   function test(x::Int32)::Int32
       f::Int32 = Int32(-1)  # Declare once with initial value
       if x > 0
           f = Int32(0)  # Assign without redeclaring type
       else
           f = Int32(0)  # Assign without redeclaring type
       end
       return f
   end
   ```

4. **All conditional branches must have explicit returns**
   ```julia
   # ✅ Good: explicit returns in all branches
   function process(x::Int32)::Float64
       if x > 0
           return Float64(x)
       else
           return 0.0
       end
   end
   
   # ✅ Good: even Cvoid needs explicit return
   function update_state(ptr::Ptr{GameState})::Cvoid
       if ptr.active
           ptr.counter = ptr.counter + Int32(1)
           return nothing
       else
           return nothing
       end
   end
   
   # ❌ Bad: missing return in else branch
   function process(x::Int32)::Float64
       if x > 0
           return Float64(x)
       end
       # implicit return causes issues
   end
   
   # ❌ Bad: ::Cvoid on compiled game code (see FORBIDDEN §3)
   function update_state(ptr::Ptr{GameState})::Cvoid
       ptr.counter = ptr.counter + Int32(1)
   end
   ```

### Control Flow

1. **Simple if/elseif/else is safe**
   ```julia
   if condition
       do_something()
   elseif other_condition
       do_other()
   else
       do_default()
   end
   ```

2. **While loops are safe**
   ```julia
   while condition
       do_work()
   end
   ```

3. **For loops with known bounds**
   ```julia
   for i in 1:10
       process(i)
   end
   ```

### Math and Literals

1. **Use explicit type literals**
   ```julia
   # ✅ Good
   x::Float64 = Float64(3.14)
   y::Float32 = 3.14f0
   z::Int32 = Int32(42)
   
   # ❌ Bad
   x = 3.14  # might be Float64 or Float32
   ```

2. **Cast numeric operations**
   ```julia
   # ✅ Good
   result::Float64 = Float64(a * b) + Float64(c)
   
   # ❌ Bad
   result = a * b + c  # implicit type inference
   ```

3. **Use `unsafe_trunc` for Float to Int conversions (avoids GC)**
   ```julia
   # ✅ Good: unsafe_trunc doesn't trigger GC
   x::Float64 = Float64(3.7)
   y::Int32 = unsafe_trunc(Int32, x)  # Result: 3
   
   # ❌ Bad: Int32() constructor may trigger allocations
   y::Int32 = Int32(x)  # Can cause GC issues in static compilation
   ```
   
   **When to use `unsafe_trunc`:**
   - Converting `Float64`/`Float32` to `Int32`/`Int64`/`UInt32`/`UInt64`
   - Converting after rounding operations: `unsafe_trunc(Int32, llvm_SDL_round(value))`
   - Any numeric truncation in hot paths or tight loops
   
   **When `Int32()` is acceptable:**
   - Converting integer literals: `Int32(42)` is fine
   - Converting between integer types: `Int32(uint_value)` is usually fine
   - Compile-time constant expressions

## 🏗️ Project Structure Patterns

### Adding New Structs

1. Define the struct in `game_structs.jl` or `structs.jl`
2. Add `getproperty` and `setproperty!` methods for pointer access
3. Include proper initialization in the game state or relevant init function
4. Remember to free allocated memory in the cleanup function

### Adding New State

1. Add fields to `GameState` struct
2. Update `GameState` getproperty/setproperty! methods
3. Initialize in `j_init_game_state`
4. Clean up in `cleanup` function

### Input Handling Pattern

- `keys_down`: Tracks if a key is currently held down (continuous)
- `keys_up`: Tracks if a key was just released this frame (one-time)
- `keys_pressed`: Tracks if a key was just pressed this frame (one-time)
- Reset `keys_up` and `keys_pressed` at the start of each frame
- Set them during event polling (SDL_KEYDOWN, SDL_KEYUP)

### SDL/C Interop

1. **Use llvm_* wrapper functions** for SDL calls (defined in `llvm_bindings.jl`)
   ```julia
   window = llvm_SDL_CreateWindow(name, x, y, w, h, flags)
   ```

2. **Pass pointers to SDL functions**
   ```julia
   # Allocate memory for struct
   rect_ptr = wasm_malloc(UInt32(sizeof(SDL_FRect)))
   unsafe_store!(Ptr{SDL_FRect}(rect_ptr), my_rect)
   llvm_SDL_RenderFillRectF(renderer, Ptr{SDL_FRect}(rect_ptr))
   wasm_free(rect_ptr)
   ```

3. **Free all allocated memory** after passing to C functions

## 🔧 Compilation Process

### Compile for Web (WASM)
```bash
julia compile_game.jl web
```
- Generates LLVM IR (.ll files) in `game_wasm/`
- Links with emcc to create WebAssembly
- Requires Emscripten SDK

### Compile for Desktop
```bash
julia compile_game.jl desktop
```
- Generates object files (.o) in `game_desktop/`
- Links with gcc to create native executable
- Requires SDL2 development libraries

### Functions to Export

Update `functions_to_compile` in `compile_game.jl`:
```julia
functions_to_compile = [
    (my_function, (ArgType1, ArgType2), "my_function"),
]
```

## 🐛 Common Errors and Solutions

### Error: "UndefVarError" or "MethodError"
- **Cause**: Missing type annotation or using dynamic dispatch
- **Solution**: Add explicit type annotations `::Type` everywhere

### Error: Segmentation fault
- **Cause**: Using freed memory or null pointer
- **Solution**: Check pointer validity before dereferencing

### Error: Compilation fails with LLVM errors
- **Cause**: Using Julia runtime features
- **Solution**: Remove GC-dependent code, use manual memory management

### Error: `undefined reference to ijl_invoke` / `julia_convert_*` when linking `host`
- **Cause**: `::Cvoid` on a function compiled with StaticCompiler (especially with no explicit return)
- **Solution**: Remove `::Cvoid` from `engine/` and game code; use untyped fall-through or `::Int32` + `return`

### Error: "ccall not supported"
- **Cause**: Direct ccall in code to be compiled
- **Solution**: Use llvmcall wrappers instead (see `llvm_wrappers.jl`)

### Error: "syntax: multiple type declarations for 'variable'"
- **Cause**: Declaring the same variable with a type annotation multiple times in the same function (e.g., in different if/else branches)
- **Solution**: Declare the variable with its type once at the top of the function, then assign to it without redeclaring the type in conditional branches

### Error: "memory access out of bounds" at runtime (WASM)
- **Cause**: Buffer overflow in `str_ptr()` function - it allocates `len` bytes but writes `len + 1` bytes (including null terminator)
- **Symptoms**: Crashes when string length (with null terminator) is a multiple of 16 bytes (16, 32, 48, etc.)
- **Pattern**: 15 chars, 31 chars, 47 chars, etc. will crash
- **Solution**: 
  - Avoid strings where (length + 1) is a multiple of 16 when using `str_ptr()`
  - Or manually allocate: `ptr = wasm_malloc(UInt32(len + 1))` and copy manually
  - Or fix `wallocstring.jl` line 30 to allocate `len + 1` instead of `len`

## 📋 Pre-Commit Checklist

- [ ] No String literals (use `WallocString` with `w"..."`)
- [ ] No println/print (use `printf` with `c"..."`)
- [ ] All functions have explicit return types `::Type`
- [ ] No `::Cvoid` on `engine/` or game functions compiled with StaticCompiler
- [ ] All variables have explicit type annotations `::Type`
- [ ] No variable type redeclarations in the same function (declare once at top, assign in branches)
- [ ] All allocations use `wasm_malloc` and are freed with `wasm_free`
- [ ] All struct pointer access uses custom getproperty/setproperty!
- [ ] No dynamic arrays (use `MallocArray` or manual pointers)
- [ ] No exceptions, closures, or runtime features
- [ ] All numeric literals are explicitly typed

## 📚 Key Files Reference

- `game.jl` - Main game loop and initialization
- `game_structs.jl` - Game-specific structs and pointer accessors
- `structs.jl` - SDL2 struct definitions and bindings
- `sprite.jl` - Sprite loading and rendering
- `llvm_bindings.jl` - SDL2 function bindings via llvmcall
- `llvm_wrappers.jl` - malloc/free wrappers
- `wallocstring.jl` - String type that works without GC
- `compile_game.jl` - Build script for web/desktop targets

## 💡 Remember

**When in doubt, think like you're writing C code with Julia syntax.**

This is NOT normal Julia programming - it's static compilation to native code without any runtime support. Every allocation must be manual, every type must be known at compile time, and every resource must be explicitly freed.

