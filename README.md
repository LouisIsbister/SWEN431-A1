# SWEN431-A1
Submission for the first SWEN431 ("Advanced Progamming Languages") assignment. The goal of this assignment is to write simple stack-based intepreter with the following capabilities:  
 1. Integer, float, and string values and operations.
 2. Boolean values and comparision operators.
 3. Matrix and vector values and operators.
 4. Stack manipulation functions such as ROLL, SWAP, ROT etc.
 5. Lambdas and recursive calls with SELF operator, variable quoting, and EVAL command.   

For example, the following input specifies a lambda whose body contains two variables `x0`, and `x1`, and computes the factorial of the top element of the stack! (In this case 5 and results in 120):

```ruby
1 5
{ 2 | x0 x1 * x1 1 - DUP 0 > SELF ’DROP ROT IFELSE EVAL}
```
To test the code simply run the `tester.py` file which automatically envokes each of the `input-xyz.txt` files, then compares the generated output with the expected result found in the `expected-xyz.txt` file.