using Base.Test
using Calc

# Setup. From package LispREPL that in turn came from the Julia base repo.

type FakeTerminal <: Base.Terminals.UnixTerminal
    in_stream::Base.IO
    out_stream::Base.IO
    err_stream::Base.IO
    hascolor::Bool
    raw::Bool
    FakeTerminal(stdin,stdout,stderr,hascolor=true) =
        new(stdin,stdout,stderr,hascolor,false)
end

Base.Terminals.hascolor(t::FakeTerminal) = t.hascolor
Base.Terminals.raw!(t::FakeTerminal, raw::Bool) = t.raw = raw
Base.Terminals.size(t::FakeTerminal) = (24, 80)

function fake_repl()
    # Use pipes so we can easily do blocking reads
    # In the future if we want we can add a test that the right object
    # gets displayed by intercepting the display
    stdin_read,stdin_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    stdout_read,stdout_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    stderr_read,stderr_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    Base.link_pipe(stdin_read,true,stdin_write,true)
    Base.link_pipe(stdout_read,true,stdout_write,true)
    Base.link_pipe(stderr_read,true,stderr_write,true)

    repl = Base.REPL.LineEditREPL(FakeTerminal(stdin_read, stdout_write, stderr_write))
    stdin_write, stdout_read, stderr_read, repl
end

# Writing ^C to the repl will cause sigint, so let's not die on that
ccall(:jl_exit_on_sigint, Void, (Cint,), 0)
stdin_write, stdout_read, stderr_read, repl = fake_repl()

repl.specialdisplay = Base.REPL.REPLDisplay(repl)
repl.history_file = false

repltask = @async Base.REPL.run_repl(repl)

sendrepl(cmd) = write(stdin_write,"inc || wait(b); r = $cmd; notify(c); r\r")

inc = false
b = Condition()
c = Condition()
sendrepl("\"Hello REPL\"")
inc=true
begin
    notify(b)
    wait(c)
end

Calc.initiate_calc_repl(repl)

# Tests.
function testentry(input, outputs...) 
    write(stdin_write, input)
    println(input)
    for o in outputs
        readuntil(stdout_read, o)
    end
end
    
# General
testentry("=", "calc> ")
testentry("2\n3+", "1: 5")
testentry("4\t", "2: 4", "1: 5")
testentry("\t",  "2: 5", "1: 4")
testentry("\e[3~", "1: 5")  # delete key
testentry("U", "1: 4")
testentry("D", "1: 5")
testentry("U", "1: 4")
testentry("=", "calc= ")
testentry("2+_2\n", "1: 7", "calc> ")
# Arithmetic
testentry("4 3+",  "1: 7")
testentry("4n",    "1: -4")
testentry("4 3*",  "1: 12")
testentry("4 3/",  "1: 1.33333")
testentry("4&",    "1: 0.25")
testentry("4 3%",  "1: 1")
testentry("4nA",   "1: 4")
testentry("4fs",   "1: 1")
testentry("4nfs",  "1: -1")
testentry("4 3fn", "1: 3")
testentry("4 3fx", "1: 4")
testentry("4f[",   "1: 3")
testentry("4f]",   "1: 5")
# Algebraic
testentry("4Q",    "1: 2.0")
testentry("4IQ",   "1: 16")
testentry("2LIL",  "1: 2.0")
testentry("2LE",   "1: 2.0")
testentry("2HLIHL","1: 2.0")
testentry("8 2B",  "1: 3.0")
testentry("2 3^",  "1: 8")
testentry("8 3I^", "1: 2.0")
testentry("4 3fh", "1: 5.0")
# Trig
testentry("P",     "1: π = ")
testentry("mr",    "Using radians...")
testentry("PC",    "[rad|", "1: -1.0")
testentry("P2/S",  "1: 1.0")
testentry("P4/T",  "1: 1.0")
testentry("1ICC",  "1: 1.0")
testentry("1ISS",  "1: 1.0")
testentry("1ITT",  "1: 1.0")
testentry("md",    "Using degrees...")
testentry("180C",  "[deg|", "1: -1.0")
testentry("90S",   "1: 1.0")
testentry("45T",   "1: 1.0")
testentry("1IC",   "1: 0.0")
testentry("1IS",   "1: 90.0")
testentry("1IT",   "1: 45.0")
# Complex numbers
testentry("1 2X",    "1: 1+2im")
testentry("1 45Z",   "1: 0.707107+0.707107im")
testentry("1 2XIX",  "2: 1", "1: 2")
testentry("1 45ZIZ", "2: 1", "1: 45")
testentry("1 2XJ",   "1: 1-2im")
testentry("1 1XG",   "1: 45.0")
testentry("1 2Xfr",  "1: 1")
testentry("1 2Xfi",  "1: 2")
testentry("mp",      "Using polar coordinates...")
testentry("1 1X",    "1: 1.41421∠45.0°")
testentry("mp",      "Using rectangular coordinates...")
# Percentages
testentry("50\e%",    "1: 0.5")
testentry("0.5c%",    "1: 50.0")
testentry("100 70b%", "1: -30.0")
# Vectors
testentry("Vp\e[3~", ".")  # delete the stack by packing and then the del key
testentry("1 2|3|",  "1: [1,2,3]")
testentry("Vu",      "3: 1", "2: 2", "1: 3")
# testentry("Vp",      "1,2,3]")
# Statistics
testentry("Uu#",   "1: 3")
testentry("Uu+",   "1: 6")
testentry("Uu*",   "1: 6")
testentry("UuX",   "1: 3")
testentry("UuN",   "1: 1")
testentry("UuM",   "1: 2.0")
testentry("UHuM",  "1: 2.0")
testentry("UuS",   "1: 1.0")
testentry("UHuS",  "1: 1.0")
# Storing
testentry("12 ss", "Variable name> ")  # Space is needed because this doesn't read the current value
testentry("x\n",   "12")
testentry("=x\n",  "1: 12")
testentry("sS",    "Variable name> ")
testentry("y\n",   "-element Calc.CalcStack")

# User-defined keys
Calc.setkeys(Dict("fp" => Calc.calcfun((y, x) -> 1 / (1/y + 1/x), 2)))
testentry("3 1fp",  "1: 0.75")
