module Calc

import Base: LineEdit, REPL
import Base.LineEdit: terminal

type CalcStack <: AbstractArray{Any, 1}
    x::Array{Any}
end
CalcStack() = CalcStack(Any[])
Base.getindex(s::CalcStack, i) = s.x[i]
Base.setindex!(s::CalcStack, x, i) = setindex!(s.x, x, i)
Base.size(s::CalcStack, o...) = size(s.x, o...)
Base.linearindexing(::Type{CalcStack}) = Base.LinearFast()
Base.similar(s::CalcStack) = CalcStack()
Base.push!(s::CalcStack, x) = push!(s.x, x)
Base.splice!(s::CalcStack, i) = splice!(s.x, i)
Base.copy(s::CalcStack) = CalcStack(copy(s.x))
function Base.show(io::IO, s::CalcStack)
    println(io)
    println(io, "Stack [$(state.usedegrees ? "deg" : "rad")|$(state.usepolar ? "polr" : "rect")]")
    n = length(s)
    for i in 1:n
        print(io, n-i+1, ": ")
        printelement(io, s.x[i])
        println(io)
    end
    if n == 0 
        println(io, ".")
    end
end    

cs(x) = sprint(showcompact, x)
printelement(io::IO, x) = showcompact(io, x)
printelement(io::IO, x::Complex) = state.usepolar ? print(io, "$(cs(abs(x)))∠$(cs(rad2deg(angle(x))))°") : showcompact(io, x)

type CalcState
    history::Array{CalcStack}
    panel
    position::Int
    usedegrees::Bool
    usepolar::Bool
end

const state = CalcState(CalcStack[CalcStack()], 0, 1, true, false)

activestack() = state.history[state.position]

function advance(stack)
    if stack != activestack()
        state.position += 1
        if state.position > length(state.history)
             push!(state.history, stack)
        else
             state.history[state.position] = stack
             if state.position < length(state.history)
                 state.history = state.history[1:state.position]
             end
        end
    end
end

"""
    calcfun(fun, n = 0, splatoutput = false)

where

* `fun` : defines the operation using the stack.
* `n`   : number of stack elements to pass to `fun`. If negative, pass the whole 
          stack.
* `splatoutput` : if `true`, splat the results back on to the stack. This is
          useful for vector operations and entering multiple values on the
          stack.

As part of this operation, `n` elements are removed from the stack.

With one argument (`n == 1`), the top of the stack `x` is passed to `fun`. 
With `n > 1`, the top `n` stack elements are passed to `fun` in reverse order.
By convention, `x` is the top of the stack, and `y` is the second element, so
`function(y, x)` is the appropriate order for two arguments. 

Here are examples taken from the core key definitions using `setkeys`:

```julia
Calc.setkeys(Dict(
    "P"  => Calc.calcfun(() -> pi, 0),
    "Q"  => Calc.calcfun(sqrt, 1),
    "-"  => Calc.calcfun(-, 2),
    "n"  => Calc.calcfun(-, 1),   # negate
    # tab - swap x & y on the stack
    "\t" => Calc.calcfun((y, x) -> Any[x, y], 2, true),
    "fs" => Calc.calcfun(sign, 1),
    # pack the stack into a vector
    "Vp" => Calc.calcfun(x -> Any[x], -1)
))
```
Returns a function for use in a keymap.
"""
function calcfun(fun, n = 0, splatoutput = false)
    (s, args...) -> begin
        println(terminal(s))
        stack = copy(activestack())
        b = LineEdit.buffer(s)
        newval = eval(Main, Base.parse_input_line(takebuf_string(b)))
        if newval != nothing
            push!(stack, newval)
            advance(stack)
            stack = copy(stack)
        end
        if n ≥ 0 
            ns = length(stack)
            args = splice!(stack, ns-n+1:ns)
            val = fun(args...)
            if val != nothing
                if splatoutput
                    push!(stack, val...)
                else
                    push!(stack, val)
                end
            end
        else       # Negative: pass and return the whole stack
            stack.x = fun(stack.x)
        end
        advance(stack)
        show(terminal(s), activestack())
        :done
    end
end

## This code was adapted from the following:
##    https://github.com/Keno/Gallium.jl/blob/1ef7111880495f3c5a7989d88a5fbc60e7eeb285/src/lldbrepl.jl
## Copyright (c) 2015: Keno Fischer. Licensed under the MIT "Expat" License:
##    https://github.com/Keno/Gallium.jl/blob/b4bc668a4cbd0f2d4f63fbdb0597a1264afd7b4d/LICENSE.md

function initiate_calc_repl(repl)
    mirepl = isdefined(repl,:mi) ? repl.mi : repl

    main_mode = mirepl.interface.modes[1]

    const calc_launch_keymap = Dict{Any,Any}(
        '=' => function (s,args...)
            if isempty(s)
                if !haskey(s.mode_state, panel)
                    s.mode_state[panel] = LineEdit.init_state(repl.t, panel)
                end
                println(terminal(s))
                println(terminal(s))
                show(terminal(s), activestack())
                println(terminal(s))
                LineEdit.transition(s,panel)
            else
                LineEdit.edit_insert(s,'=')
            end
        end
    )
    
    # Setup the repl panel
    panel = LineEdit.Prompt("calc> ";
        # Copy colors from the prompt object
        prompt_prefix = Base.text_colors[:blue],
        prompt_suffix = main_mode.prompt_suffix,
        on_enter = Base.REPL.return_callback)
    panel.on_done = REPL.respond(repl, panel; pass_empty = false) do line
        :(  )
    end
    # Setup the alternate repl panel for algebraic entry
    # Setup the panel for input
    inputpanel = LineEdit.Prompt(">>>>> ";
        prompt_prefix = Base.text_colors[:cyan],
        prompt_suffix = main_mode.prompt_suffix,
        on_enter = s -> true)
    inputpanel.on_done = REPL.respond(repl, panel; pass_empty = false) do line
        isempty(line) ? :() : line
    end

    hp = main_mode.hist
    hp.mode_mapping[:calc] = panel
    panel.hist = hp
    
    push!(mirepl.interface.modes, panel)

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    mk = REPL.mode_keymap(main_mode)

    b = Dict{Any,Any}[skeymap, mk, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]
    
    function input(fun::Function, s, prompt::AbstractString)
        inputpanel.prompt = prompt
        inputpanel.on_done = REPL.respond(repl, panel; pass_empty = false) do line
            :( $(try fun(line) catch e warn(e) end) )
        end
        if !haskey(s.mode_state, inputpanel)
            s.mode_state[inputpanel] = LineEdit.init_state(repl.t, inputpanel)
        end
        LineEdit.transition(s, inputpanel)
    end

    const calc_keymap = Dict{Any,Any}(
    # arithmetic
        "+" => calcfun(+, 2),
        "-" => calcfun(-, 2),
        "n" => calcfun(-, 1),   # negate
        "*" => calcfun(*, 2),
        "/" => calcfun(/, 2),
        "&" => calcfun(x -> 1/x, 1),
        "%" => calcfun(%, 2),
        "A" => calcfun(abs, 1),
        "fs" => calcfun(sign, 1),
        "fn" => calcfun(min, 2),
        "fx" => calcfun(max, 2),
        "f[" => calcfun(x -> x - 1, 1),
        "f]" => calcfun(x -> x + 1, 1),
    # algebraic
        "Q" => calcfun(sqrt, 1),
        "IQ" => calcfun(x -> x*x, 1),
        "L" => calcfun(log, 1),
        "E" => calcfun(exp, 1),
        "IL" => calcfun(exp, 1),
        "HL" => calcfun(log10, 1),
        "IHL" => calcfun(x -> 10^x, 1),
        "B" => calcfun((y, x) -> log(x, y), 2),
        "^" => calcfun(^, 2),
        "I^" => calcfun((y, x) -> y ^ (1/x), 2),
        "fh" => calcfun((y, x) -> sqrt(y^2 + x^2), 2),
    # trig
        "S" => calcfun(x -> state.usedegrees ? sind(x) : sin(x), 1),
        "C" => calcfun(x -> state.usedegrees ? cosd(x) : cos(x), 1),
        "T" => calcfun(x -> state.usedegrees ? tand(x) : tan(x), 1),
        "IS" => calcfun(x -> state.usedegrees ? asind(x) : asin(x), 1),
        "IC" => calcfun(x -> state.usedegrees ? acosd(x) : acos(x), 1),
        "IT" => calcfun(x -> state.usedegrees ? atand(x) : atan(x), 1),
        "P" => calcfun(() -> pi, 0),
    # settings
        "mr" =>  (s, o...) -> (println(terminal(s), "\nUsing radians..."); state.usedegrees = false; :done),
        "md" =>  (s, o...) -> (println(terminal(s), "\nUsing degrees..."); state.usedegrees = true; :done),
        "mp" =>  (s, o...) -> (state.usepolar = !state.usepolar; println(terminal(s), "\nUsing $(state.usepolar ? "polar" : "rectangular") coordinates..."); :done),
    # complex numbers
        "X" => calcfun(complex, 2),
        "IX" => calcfun(x -> [real(x), imag(x)], 1, true),
        # polar entry with y in degrees
        "Z" => calcfun((y, x) -> y * exp(1.0im * x * π / 180), 2),  
        "IZ" => calcfun(x -> [abs(x), rad2deg(angle(x))], 1, true),
        "J" => calcfun(conj, 1),
        "G" => calcfun(x -> state.usedegrees ? rad2deg(angle(x)) : angle(x), 1),
        "fr" => calcfun(real, 1),
        "fi" => calcfun(imag, 1),
    # percentages
        "\e%" => calcfun(x -> x/100, 1),
        "c%" => calcfun(x -> 100x, 1),
        "b%" => calcfun((y, x) -> 100(x-y)/y, 2),
    # vectors
        "|" => calcfun(vcat, 2),
        "Vu" => calcfun(x -> x, 1, true),
        "Vp" => calcfun(x -> Any[x], -1),
    # statistics
        "u#" => calcfun(length, 1),
        "u+" => calcfun(sum, 1),
        "u*" => calcfun(prod, 1),
        "uX" => calcfun(maximum, 1),
        "uN" => calcfun(minimum, 1),
        "uM" => calcfun(mean, 1),
        "HuM" => calcfun(median, 1),
        "uS" => calcfun(std, 1),
        "HuS" => calcfun(var, 1),
    # storing/recalling
        # store x in the prompted variable
        "ss" => (s, o...) -> input(s, "Variable name> ") do x
                    eval(Main, Expr(:(=), Symbol(x), activestack()[end]))
                end,
        # store the whole stack in the prompted variable
        "sS" => (s, o...) -> input(s, "Variable name> ") do x
                    eval(Main, Expr(:(=), Symbol(x), activestack()))
                end,
    # general
        # Meta-k - Copy `x` to the clipboard
        "\ek" => calcfun(x -> (clipboard(x); x), 1),
        # Ctrl-k - Pop `x` to the clipboard -- not sure why "^K" doesn't work
        "\u0b"  => calcfun(x -> (clipboard(x); return nothing), 1),
        # delete
        "\e[3~" => (s,o...)-> eof(LineEdit.buffer(s)) ? calcfun((stack) -> stack[1:end-1], -1)(s,o...) : LineEdit.edit_delete(s),
        # tab - swap x & y on the stack
        "\t" => calcfun((y, x) -> Any[x, y], 2, true),
        # space / Enter for stack entry
        " " => calcfun(x -> x, -1),
        "\r" => LineEdit.KeyAlias(" "),
        "\n" => LineEdit.KeyAlias(" "),
        # undo
        "U" => (s, o...) -> begin
                    if state.position > 1
                        state.position -= 1
                    end
                    show(terminal(s), activestack())
                    :done
                end,
        # redo
        "D" => (s, o...) -> begin
                    if state.position < length(state.history)
                        state.position += 1
                    end
                    show(terminal(s), activestack())
                    :done
                end,
        # trigger algebraic entry
        "=" => (s, o...) -> input(s, "calc= ") do line
                    stack = copy(Calc.activestack())
                    push!(stack, eval(Main, fixrefs(Base.parse_input_line(line))))
                    Calc.advance(stack)
                    show(terminal(s), activestack())
                end
    )
    
    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, calc_launch_keymap)
    panel.keymap_dict = LineEdit.keymap_merge(LineEdit.keymap(b), calc_keymap)
    state.panel = panel
    
    # Finish the input repl panel
    hp.mode_mapping[:input] = inputpanel
    inputpanel.hist = hp

   # Convert _1, _2, ... to stack references    
    fixrefs(x) = x
    fixrefs(e::Expr) = Expr(e.head, Any[fixrefs(a) for a in e.args]...)
    function fixrefs(s::Symbol)
        st = string(s)
        if first(st) != '_'
            return s
        end
        n = try parse(st[2:end]) catch "" end
        if isa(n, Integer) && n > 0
            return :( $activestack()[end - $n + 1] )
        else
            return s
        end
    end

    push!(mirepl.interface.modes, inputpanel)
    inputpanel.keymap_dict = LineEdit.keymap(b)
    
    nothing
end

"""
    setkeys(keymap::Dict)

Merge `keymap` with the Calc keymap. Use to define or replace keys in the
calculator. `keymap` is a mapping from a key sequence to a function that 
defines the operation. Keys and key sequences are defined using Unix-style
key definitions (I haven't found a good link). Use `^` for a CTRL key modifier
and `\e` for a Meta or ALT modifier.

See `Calc.calcfun` for a helper function for defining operations on the stack.
Here is an example:

```julia
Calc.setkeys(Dict("fp" => Calc.calcfun((y, x) -> 1 / (1/y + 1/x), 2)))
```
Returns the new keymap.    
"""
function setkeys(keymap)
    state.panel.keymap_dict = LineEdit.keymap_merge(state.panel.keymap_dict, keymap)
end

function __init__()
    isdefined(Base, :active_repl) && initiate_calc_repl(Base.active_repl)
end

end # module
