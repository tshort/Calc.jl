
import Base: LineEdit, REPL

const stack = Any[]

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
                if !haskey(s.mode_state,panel)
                    s.mode_state[panel] = LineEdit.init_state(repl.t,panel)
                end
                println()
                println("Calculator stack")
                println(stack)
                println()
                LineEdit.transition(s,panel)
            else
                LineEdit.edit_insert(s,'=')
            end
        end
    )
    
    # Setup the repl panel
    panel = LineEdit.Prompt("Calc> ";
        # Copy colors from the prompt object
        prompt_prefix = Base.text_colors[:blue],
        prompt_suffix = main_mode.prompt_suffix,
        on_enter = Base.REPL.return_callback)

    hp = main_mode.hist
    hp.mode_mapping[:calc] = panel
    panel.hist = hp
    
    panel.on_done = REPL.respond(repl, panel; pass_empty = false) do line
        if !isempty(line)
            # :( push!($stack, $(Base.parse_input_line(line))); )
            :( show($stack) )
        else
            :(  )
        end
    end

    function calcfun(fun, n = 0, splatoutput = false)
        (s, args...) -> begin
            b = LineEdit.buffer(s)
            println()
            val = eval(Main, Base.parse_input_line(takebuf_string(b)))
            if val != nothing
                push!(stack, val)
            end
            # LineEdit.accept_result(s, panel)
            if n == 0
                val = fun()
                if val != nothing
                    if splatoutput
                        push!(stack, val...)
                    else
                        push!(stack, val)
                    end
                end
            elseif n > 0 
                ns = length(stack)
                args = reverse(splice!(stack, ns-n+1:ns))
                if splatoutput
                    push!(stack, fun(args...)...)
                else
                    push!(stack, fun(args...))
                end
                    
            else       # Negative: pass and return the whole stack
                stack[:] = fun(stack)
            end
            # LineEdit.refresh_line(s)
            show(stack)
            println()
            :done
        end
    end

    const calc_keymap = Dict{Any,Any}(
        "*" => calcfun(*, 2),
        "+" => calcfun(+, 2),
        "-" => calcfun(-, 2),
        "n" => calcfun(-, 1),
        "^" => calcfun(^, 2),
        # trig
        "S" => calcfun(sind, 1),
        "C" => calcfun(cosd, 1),
        "T" => calcfun(tand, 1),
        "IS" => calcfun(asind, 1),
        "IC" => calcfun(acosd, 1),
        "IT" => calcfun(atand, 1),
        "P" => calcfun(() -> pi, 0),
        # complex numbers
        "A" => calcfun(abs, 1),
        "J" => calcfun(conj, 1),
        "G" => calcfun(angle, 1),
        " " => calcfun(() -> nothing, 0),
        "\r" => LineEdit.KeyAlias(" "),
        "\n" => LineEdit.KeyAlias(" "),
        "g" => (s, buf, ok) -> begin
                    dump(s.mode_state[s.current_mode],2)
                    nothing
                end
    )
    
    push!(mirepl.interface.modes, panel)

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    mk = REPL.mode_keymap(main_mode)

    b = Dict{Any,Any}[skeymap, mk, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]

    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, calc_launch_keymap)
    panel.keymap_dict = LineEdit.keymap_merge(LineEdit.keymap(b), calc_keymap)
    # panel.keymap_dict = calc_keymap
    nothing
end

initiate_calc_repl()
