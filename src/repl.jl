
import Base: LineEdit, REPL

type CalcState
    history::Array{Array{Any}}
    position::Int
end

const state = CalcState(Any[Any[]], 1)

activestack() = state.history[state.position]

function showstack()
    println()
    println()
    show(activestack())
    println()
end

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

function calcfun(fun, n = 0, splatoutput = false)
    (s, args...) -> begin
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
            if splatoutput
                push!(stack, fun(args...)...)
            else
                push!(stack, fun(args...))
            end
        else       # Negative: pass and return the whole stack
            stack = fun(stack)
        end
        advance(stack)
        showstack()
        :done
    end
end

## This code was adapted from the following:
##    https://github.com/Keno/Gallium.jl/blob/1ef7111880495f3c5a7989d88a5fbc60e7eeb285/src/lldbrepl.jl
## Copyright (c) 2015: Keno Fischer. Licensed under the MIT "Expat" License:
##    https://github.com/Keno/Gallium.jl/blob/b4bc668a4cbd0f2d4f63fbdb0597a1264afd7b4d/LICENSE.md

function initiate_calc_repl()
    repl = Base.active_repl
    mirepl = isdefined(repl,:mi) ? repl.mi : repl

    main_mode = mirepl.interface.modes[1]

    const calc_launch_keymap = Dict{Any,Any}(
        '=' => function (s,args...)
            if isempty(s)
                if !haskey(s.mode_state, panel)
                    s.mode_state[panel] = LineEdit.init_state(repl.t, panel)
                end
                println()
                println("Calculator stack")
                showstack()
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
        repl = Base.active_repl
        inputpanel.prompt = prompt
        inputpanel.on_done = REPL.respond(repl, panel; pass_empty = false) do line
            :( $(fun(line)) )
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
        "B" => calcfun((x ,y) -> log(y, x), 2),
        "^" => calcfun(^, 2),
        "I^" => calcfun((x, y) -> y ^ (1/x), 2),
        "fh" => calcfun((x, y) -> sqrt(x^2 + y^2), 2),
    # trig
        "S" => calcfun(sind, 1),
        "C" => calcfun(cosd, 1),
        "T" => calcfun(tand, 1),
        "IS" => calcfun(asind, 1),
        "IC" => calcfun(acosd, 1),
        "IT" => calcfun(atand, 1),
        "P" => calcfun(() -> pi, 0),
    # complex numbers
        "X" => calcfun(complex, 2),
        "Z" => calcfun((x, y) -> x * exp(1.0im * y * π / 180), 2),
        "J" => calcfun(conj, 1),
        "G" => calcfun(angle, 1),
        "fr" => calcfun(real, 1),
        "fi" => calcfun(imag, 1),
    # percentages
        "\e%" => calcfun(x -> x/100, 1),
        "c%" => calcfun(x -> 100x, 1),
        "b%" => calcfun((x, y) -> 100(y-x)/x, 2),
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
        # delete
        "\e[3~" => (s,o...)-> eof(LineEdit.buffer(s)) ? calcfun((stack) -> stack[1:end-1], -1)(s,o...) : LineEdit.edit_delete(s),
        # tab - swap x & y on the stack
        "\t" => calcfun((x, y) -> [y, x], 2, true),
        # space / Enter for stack entry
        " " => calcfun(x -> x, -1),
        "\r" => LineEdit.KeyAlias(" "),
        "\n" => LineEdit.KeyAlias(" "),
        # undo
        "U" => (s, o...) -> begin
                    if state.position > 1
                        state.position -= 1
                    end
                    showstack()
                    :done
                end,
        # redo
        "D" => (s, o...) -> begin
                    if state.position < length(state.history)
                        state.position += 1
                    end
                    showstack()
                    :done
                end,
        # trigger algebraic entry
        "=" => (s, o...) -> input(s, "calc= ") do line
                    stack = copy(Calc.activestack())
                    push!(stack, eval(Main, fixrefs(line)))
                    Calc.advance(stack)
                    Calc.showstack()
                end
    )
    
    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, calc_launch_keymap)
    panel.keymap_dict = LineEdit.keymap_merge(LineEdit.keymap(b), calc_keymap)
    
    # Finish the input repl panel
    hp.mode_mapping[:input] = inputpanel
    inputpanel.hist = hp

   # Convert _1, _2, ... to stack references    
    fixrefs(x) = x
    fixrefs(line::AbstractString) = fixrefs(Base.parse_input_line(line))
    fixrefs(e::Expr) = Expr(e.head, Any[fixrefs(a) for a in e.args]...)
    function fixrefs(s::Symbol)
        st = string(s)
        if first(st) != '_'
            return s
        end
        n = try parse(st[2:end]) catch "" end
        if isa(n, Integer) && n > 0
            return :(stack[end - $n + 1])
        else
            return s
        end
    end

    push!(mirepl.interface.modes, inputpanel)
    inputpanel.keymap_dict = LineEdit.keymap(b)
    
    nothing
end

initiate_calc_repl()
