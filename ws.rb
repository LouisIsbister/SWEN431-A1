require 'matrix'

class Stack
  attr_accessor :stack

  def initialize
    @stack = []
  end

  # simply removes and returns the top of the stack
  def pop
    raise "Stack empty" if stack_empty?
    @stack.pop
  end

  def stack_empty?
    @stack.empty?
  end
  
  def size
    @stack.size
  end

  def peek
    raise "Stack empty" if stack_empty?
    @stack.last
  end

  # takes a token and executes immediately, unless its quoted!
  def push(token)
    if !stack_empty? && peek == "'"
      @stack[-1] = token    # replace the ' with the token!
    else 
      token = execute_token(token)
      @stack.push(token) unless token == nil
    end
  end

  # Given a token determine how to handle its action
  # @return nil for all void functions [DROP, DUP...]
  #         the value resulting from IFELSE or EVAL statements
  #         the result from applying an operator on the top of the stack
  #         nil for Lambda's, as they modify the stack itself
  #         otherwise Integer, Float, String, or Boolean value
  def execute_token(token)
    case token
      # functions that return nil/nothing
      when /DROP/i   then drop
      when /DUP/i    then duplicate
      when /SWAP/i   then swap
      when /ROT/i    then rotate
      when /ROLLD/i  then rolld
      when /ROLL/i   then roll
      when /TRANSP/i then transp

      # if else and eval functions
      when /IFELSE/i then ifelse
      when /EVAL/i   then eval

      when Operator  then token.apply(self)
      when Lambda    then token.execute(self)
      else token
    end
  end

  # void functions that manipulate the stack
  def drop
    raise "Stack must not be empty to DROP!" if stack_empty?
    pop; nil
  end

  def duplicate
    raise "Stack must not be empty to DUP!" if stack_empty?
    push(peek); nil
  end

  def swap
    raise "Must have 2 elements to SWAP!" if size < 2
    @stack[-1], @stack[-2] = @stack[-2], @stack[-1]; nil
  end

  def rotate
    rotate_left(3)
  end

  def rotate_left(elements_to_rot)
    raise "Must have #{elements_to_rot} elements to ROT!" if size < elements_to_rot

    start_idx = size - elements_to_rot
    @stack[start_idx, elements_to_rot] = @stack[start_idx, elements_to_rot].rotate
    nil
  end

  def roll
    raise "Cannot ROLL an empty stack" if stack_empty?
    elements_to_roll = pop
    raise "Tried to ROLL more items than are in the stack!" if size < elements_to_roll

    rotate_left(elements_to_roll)
  end

  def rolld
    raise "Cannot ROLLD an empty stack" if stack_empty?
    elements_to_roll = pop
    raise "Tried to ROLLD more items than are in the stack!" if size < elements_to_roll

    (1..(elements_to_roll - 1)).each { |_|
      rotate_left(elements_to_roll)
    }
    nil
  end

  # pops the top 3 elements, ensures the top is a boolean
  # and executes
  def ifelse
    cond = pop
    raise "Cannot perform IFELSE on non-boolean value: #{cond}" if !cond.is_a?(TrueClass) && !cond.is_a?(FalseClass)

    false_branch, true_branch = pop, pop
    cond ? execute_token(true_branch) : execute_token(false_branch)
  end

  # Evaluates the top item of the stack by simply popping it
  # and then pushing it back onto the stack and returns nil
  # to ensure it doesn't get added to the stack
  def eval
    raise "Cannot EVAL an empty stack!" if stack_empty?
    push(pop); nil
  end

  # Transposes the top element of the stack, so long
  # as it is a matrix
  def transp
    raise "Cannot TRANSP an empty stack!" if stack_empty?
    x = pop
    raise "Cannot TRANSP a non-Matrix type! #{x}" unless x.is_a?(Matrix)
    push(x.transpose); nil
  end

  # Stringifies the stack for easy viewing and comparison to
  # expected output
  def elems_to_s
    @stack.map do |elem|
      # if a resulting element is a string literal, add the quotes around it
      case elem
        when String then "\"#{elem}\""
        when Matrix, Vector then elem.to_s[6..]
        else elem.to_s
      end
    end
  end
end

class Lambda

  # @param [Array] lambda_tokens
  # @param [Integer] var_count
  def initialize(lambda_tokens, var_count)
    @lambda_tokens = lambda_tokens
    @var_count = var_count
  end

  # @return [Lambda]
  def recursive_clone
    Lambda.new(@lambda_tokens, @var_count)
  end

  # @param [Stack] global_stack
  def execute(global_stack)
    lambda_tokens = @lambda_tokens.dup
    lambda_tokens = apply_variable_values(global_stack, lambda_tokens)
    until lambda_tokens.empty?
      token = lambda_tokens.shift
      if token == 'SELF'
        global_stack.push("'")
        global_stack.push(recursive_clone)
      else
        global_stack.push(token)
      end
    end
  end

  # @param [Stack] global_stack
  def apply_variable_values(global_stack, lambda_tokens)
    # @var_count may be a nested lambda that returns an int!
    # hence we need to execute it to receive the param count
    var_count = global_stack.execute_token(@var_count)

    # create the key-value variables
    vars = {}
    (0..var_count - 1).each { |i|
      var_name = "x#{var_count - i - 1}"
      vars[var_name] = global_stack.pop
    }

    # swap each variable with its value
    lambda_tokens.each_with_index { |token, idx|
      lambda_tokens[idx] = vars[token] if /\A(x[0-9]+)/.match(token.to_s)
    }
    lambda_tokens
  end

end

class Operator
  attr_accessor :operator

  # @param [String] op
  def initialize(op)
    @operator = op
  end

  # checks to see what operator this one is, and performs operation
  # based upon the matched branch
  #
  # @param [Stack] stack
  def apply(stack)
    @stack = stack
    case @operator
      when /\*\*/ then binary_operation(Proc.new { |a, b| a ** b })

      # If a and b are vectors, perform vector multiplication
      when /\*/  then binary_operation(Proc.new { |a, b| (a.is_a?(Vector) && b.is_a?(Vector)) ? a.inner_product(b) : a * b })
      when /x/   then binary_operation(Proc.new { |a, b| a.cross_product(b) }) # cross product of vectors
      when /-/   then binary_operation(Proc.new { |a, b| a - b })
      when /\+/  then binary_operation(Proc.new { |a, b| a + b })
      when /\//  then binary_operation(Proc.new { |a, b| a / b })
      when /%/   then binary_operation(Proc.new { |a, b| a % b })

      # bitshift
      when />>/  then binary_operation(Proc.new { |a, b| a >> b })
      when /<</  then binary_operation(Proc.new { |a, b| a << b })

      # boolean
      when /==/  then binary_operation(Proc.new { |a, b| a == b })
      when /!=/  then binary_operation(Proc.new { |a, b| a != b })
      when /<=>/ then binary_operation(Proc.new { |a, b| a <=> b })
      when />=/  then binary_operation(Proc.new { |a, b| a >= b })
      when /<=/  then binary_operation(Proc.new { |a, b| a <= b })
      when />/   then binary_operation(Proc.new { |a, b| a > b })
      when /</   then binary_operation(Proc.new { |a, b| a < b })
      when /&/   then binary_operation(Proc.new { |a, b| a & b })
      when /\|/  then binary_operation(Proc.new { |a, b| a | b })
      when /\^/  then binary_operation(Proc.new { |a, b| a ^ b })

      # unary numeric operators
      when /!/   then unary_operation(Proc.new { |a| !a })
      when /~/   then unary_operation(Proc.new { |a| ~a })
      else raise "Unknown operator : #{@operator}"
    end
  end

  # @param [Proc] func
  def binary_operation(func)
    raise 'Binary operation requires 2 args!' if @stack.size < 2

    x, y = @stack.pop, @stack.pop
    x = @stack.execute_token x
    y = @stack.execute_token y
    func.call(y, x)
  end

  # @param [Proc] func
  def unary_operation(func)
    raise 'Unary operation requires 1 args!' if @stack.size < 1
    x = @stack.execute_token(@stack.pop)
    func.call x
  end

  # @param [Unknown] token
  # @param [String] op_type
  # @return Boolean
  def self.is_operator?(token, op_type)
    return token.is_a?(Operator) && token.operator == op_type
  end

  def to_s
    @operator.to_s
  end
end

module Parser
  # @param [String] input
  def self.tokenize_input(input)
    ret = []
    until input.empty?
      token, input = next_token(input)
      ret << token
      input.strip! # ensure any preceding whitespace is removed
    end
    ret
  end

  # @param [String] input
  def self.next_token(input)
    case input
      # stack manipulation functions
      when /\A(DROP|DUP|SWAP|ROT|ROLLD|ROLL|IFELSE|SELF|EVAL|TRANSP)/ then [$1, input[$1.to_s.length..]]

      # raw types
      when /\A(-?\d+\.\d+)/ then [$1.to_f, input[$1.to_s.length..]]  # float
      when /\A(-?\d+)/      then [$1.to_i, input[$1.to_s.length..]]   # integer
      when /\A(true)/i      then [true, input[$1.to_s.length..]]   # true
      when /\A(false)/i     then [false, input[$1.to_s.length..]]    # false
      when /\A(".*?")/i     then [$1[1..-2], input[$1.to_s.length..]]   # strings
      when /\A(x[0-9]+)/    then [$1, input[$1.to_s.length..]]   # variables

      # binary operators
      when /\A(\*\*|\+|-|\*|\/|%|x)/ then [Operator.new($1.to_s), input[$1.to_s.length..]]
      when /\A(&|\||\^|<<|>>)/       then [Operator.new($1.to_s), input[$1.to_s.length..]]
      when /\A(==|!=|<=>|>=|<=|>|<)/ then [Operator.new($1.to_s), input[$1.to_s.length..]]
      # unary operators
      when /\A([!~])/ then [Operator.new($1.to_s), input[1..]]
      # symbols
      when /\A([x\[\],{}'])/ then [$1, input[1..]]

      else raise "Invalid token at beginning of input! '#{input}'"
    end
  end

  # Iterates through the parsed tokens using simple backtracking algorithm.
  # Add each token to the ret array, if the token is a right brace then
  # generate a lambda from the previous tokens. If it is a right square-bracket
  # then generate a vector or matrix!
  # @param [Array] tokens
  def self.parse_lambdas_and_arrays(tokens)
    ret = []
    until tokens.empty?
      token = tokens.shift
      ret << case token
             when ']' then Parser.parse_arraylike ret
             when '}' then Parser.parse_lambda ret
             else token
             end
    end
    ret
  end

  # Parse a lambda function by retrieving all the tokens from the end of
  # tokens (ret), to the first occurrence of a '{'. Shift tokens to remove
  # '{', shift again to get the number of parameters for the lambda, shift
  # a final time to remove the |. The remaining tokens make up the lambda
  # body itself!
  # @param [Array] tokens
  def self.parse_lambda(tokens)
    lambda_start = tokens.rindex '{'
    raise 'There is no { to match the }!' if lambda_start == nil

    # the lambda tokens takes everything from the { to the end of the list
    lambda_tokens = tokens.slice!(lambda_start, tokens.length - lambda_start)
    raise "Unreachable error!" unless lambda_tokens.is_a?(Array)

    _ = lambda_tokens.shift  # remove the {
    param_count = lambda_tokens.shift

    # ensure the next token is a |
    bar_token = lambda_tokens.shift
    raise "Require |!" unless Operator.is_operator?(bar_token, '|')

    Lambda.new(lambda_tokens, param_count)
  end

  # @param [Array] tokens
  def self.parse_arraylike(tokens)
    arr_start = tokens.rindex '['
    raise 'There is no [ to match the ]!' if arr_start == nil

    # the lambda tokens takes everything from the { to the end of the list
    arr_tokens = tokens.slice!(arr_start, tokens.length - arr_start)
    raise "Unreachable error!" unless arr_tokens.is_a?(Array)

    _ = arr_tokens.shift  # remove the [
    arr_tokens.reject!{ |elem| elem == ',' }  # remove commas

    is_matrix = arr_tokens.any? {|t| t.is_a?(Vector) }
    return is_matrix ? Matrix[*arr_tokens] : Vector[*arr_tokens]
  end
end



##################
# Execution code #
##################

# get the passed argument
input_file = ARGV[0]
xyz = input_file.scan(/\d{3}/).first
output_file = "output-#{xyz}.txt"

begin
  # generate tokens from the input
  input_content = File.readlines(input_file).join
  tokens = Parser.tokenize_input(input_content)
  tokens = Parser.parse_lambdas_and_arrays(tokens)

  # create a new stack, pushing & executing each token
  stack = Stack.new
  tokens.each { |elem| stack.push(elem) }

  # write the remaining stack elements to the output file
  File.open(output_file, 'w') { |file|
    stack.elems_to_s.each { |e| file.puts e }
  }
rescue Exception  # error was thrown, simply create an empty file
  File.open(output_file, 'w') { |file| file.puts '' }
end
