# Calc - an RPN calculator for the Julia REPL

[![Build Status](https://travis-ci.org/tshort/Calc.jl.svg?branch=master)](https://travis-ci.org/tshort/Calc.jl)

This Julia package implements an RPN calculator for use at the Julia command
line (the REPL). The reverse-polish notation is popular with some scientific
calculators. See the [HP 48](http://www.ces.clemson.edu/ge/staff/park/Class/ENGR130/Handouts/BasicSkills/Calculators/HP48G/HP48G.html)
for example.

This package enables a new REPL mode. Use the equals key (`=`) at the start of a
line to start the calculator. RPN commands operate on a stack that is
redisplayed after every operation. Use Backspace at a blank prompt to return to
the normal Julia prompt.

The calculator keys tend to match that of [Emacs
Calc](https://www.gnu.org/software/emacs/manual/html_mono/calc.html). See the
following for a handy cheat sheet in several formats:

* https://github.com/SueDNymme/emacs-calc-qref/releases

Not all of the Emacs Calc operations are supported, but most basic arithmetic
operations are supported.

Here are some example keys. Some operations are consecutive keystrokes.

* `*` - multiply
* `-` - subtract
* `Q` - sqrt
* 'n' - negate
* '&' - reciprocal 
* 'A' - abs
* `U` - undo
* `D` - redo
* `P` - enter π on the stack
* `\t` (tab) - swap the top two elements on the stack
* `s s` - assign the top of the stack to a Julia variable
* `s S` - assign the whole stack to a Julia variable

By default, trig operations are entered and displayed in degrees. This setting
can be changed with `m r` for radians and `m d` for degrees. Another setting
controls display of complex numbers. The default display is in polar
coordinates. Use `m p` to toggle between polar and rectangular coordinates.

Here are some operations that are not in Emacs Calc:

* 'X' - create a complex number from `x` and `y` on the stack as rectangular
  coordinates.

* 'Y' - create a complex number from `x` and `y` on the stack in polar
  coordinates as `x∠y` with the angle in degrees.

This calculator also supports algebraic entry (normal Julia syntax). Within the
`calc> ` prompt, use `=` to switch to algebraic entry. This is useful for
evaluating expressions that are difficult with the default Calc.jl keys. Examples
include:

- Using a function that doesn't have a key defined.
- Entering a Julia variable onto the stack.
- Entering a negative number (`=` `-23` is an alternative to `23` `n`).

With algebraic entry, you can refer to stack variables with `_1`, `_2`, `_3`,
and so on. 


