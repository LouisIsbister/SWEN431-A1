require 'matrix'

class Stack
  attr_accessor :stack

  def initialize
    @stack = []
  end

  # simply removes and returns the top of the stack
  def pop
    return if stack_empty?
    @stack.pop
  end

  def peek; @stack.last; end
  def stack_empty?; @stack.empty?; end
  def size; @stack.size; end

  # takes a token and executes it so long as it isn't quoted
  # @param [Boolean] push_inplace, allows elements to be pushed without
  # immediate execution, important for recursive lambda's and eval
  def push(token, push_inplace=false)
    if push_inplace || peek == "'"
      _ = pop if peek == "'"  # remove the quote as now the token can be executed when eval is called
      @stack.push token
      return
    end

    token = execute_token(token)
    @stack.push(token) unless token == nil
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
      when /DROP/i then drop
      when /DUP/i then duplicate
      when /SWAP/i then swap
      when /ROT/i then rotate
      when /ROLLD/i then rolld
      when /ROLL/i then roll
      when /TRANSP/i then transp

      # if else and eval functions
      when /IFELSE/i then ifelse
      when /EVAL/i then eval

      when Operator then token.apply(self)
      when Lambda then token.execute(self)
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
  def to_s
    @stack.map do |elem|
      # if a resulting element is a string literal, add the quotes around it
      case elem
        when String then "\"#{elem}\""
        when Matrix, Vector then elem.to_s[6..]
        else elem.to_s
      end
    end.to_s
  end
end

class Lambda
  # @param [Array] lambda_tokens
  # @param [Integer] var_count
  def initialize(lambda_tokens, var_count)
    @tokens = lambda_tokens
    @var_count = var_count
  end

  # @return [Lambda]
  def recursive_clone
    Lambda.new(@tokens, @var_count)
  end

  # @param [Stack] global_stack
  def execute(global_stack)
    tokens = @tokens.dup
    tokens = apply_variable_values(global_stack, tokens)
    until tokens.empty?
      token = tokens.shift
      if token == 'SELF'
        global_stack.push(recursive_clone, push_inplace=true)
      else
        global_stack.push(token)
      end
    end
  end

  # @param [Stack] global_stack
  def apply_variable_values(global_stack, tokens)
    # create the key-value variables
    vars = {}
    (0..@var_count - 1).each { |i|
      var_name = "x#{@var_count - i - 1}"
      vars[var_name] = global_stack.pop
    }

    # swap each variable with its value
    tokens.each_with_index do |token, idx|
      tokens[idx] = vars[token] if /\A(x[0-9]+)/.match(token.to_s)
    end
    tokens
  end

  def to_s
    "Lambda: [#{@var_count}] #{@tokens}"
  end
end

class Operator
  attr_accessor :operator

  # @param [String] op
  def initialize(op)
    @operator = op
  end

  # @param [Stack] stack
  def apply(stack)
    @stack = stack
    case @operator
      when /\*\*/ then binary_operation(Proc.new { |a, b| a ** b })

      # If a and b are vectors, perform vector multiplication
      when /\*/ then binary_operation(Proc.new { |a, b| (a.is_a?(Vector) && b.is_a?(Vector)) ? a.inner_product(b) : a * b })
      when /x/ then binary_operation(Proc.new { |a, b| a.cross_product(b) }) # cross product of vectors
      when /-/ then binary_operation(Proc.new { |a, b| a - b })
      when /\+/ then binary_operation(Proc.new { |a, b| a + b })
      when /\// then binary_operation(Proc.new { |a, b| a / b })
      when /%/ then binary_operation(Proc.new { |a, b| a % b })

      # bitshift
      when />>/ then binary_operation(Proc.new { |a, b| a >> b })
      when /<</ then binary_operation(Proc.new { |a, b| a << b })

      # boolean
      when /==/ then binary_operation(Proc.new { |a, b| a == b })
      when /!=/ then binary_operation(Proc.new { |a, b| a != b })
      when /<=>/ then binary_operation(Proc.new { |a, b| a <=> b })
      when />=/ then binary_operation(Proc.new { |a, b| a >= b })
      when /<=/ then binary_operation(Proc.new { |a, b| a <= b })
      when />/ then binary_operation(Proc.new { |a, b| a > b })
      when /</ then binary_operation(Proc.new { |a, b| a < b })
      when /&/ then binary_operation(Proc.new { |a, b| a & b })
      when /\|/ then binary_operation(Proc.new { |a, b| a | b })
      when /\^/ then  binary_operation(Proc.new { |a, b| a ^ b })

      # unary numeric operators
      when /!/ then unary_operation(Proc.new { |a| !a })
      when /~/ then unary_operation(Proc.new { |a| ~a })
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

  def to_s
    @operator.to_s
  end
end

class Parser
  # @param [String] input
  def self.tokenize_input(input)
    ret = []
    until input.empty?
      token, input = next_token(input)
      input.strip!
      ret << token
    end
    ret
  end

  # @param [String] input
  def self.next_token(input)
    case input
      when /\A(DROP|DUP|SWAP|ROT|ROLLD|ROLL|IFELSE|SELF|EVAL|TRANSP)/ then [$1, input[$1.to_s.length..]]

      # raw types
      when /\A(-?\d+\.\d+)/ then [$1.to_f, input[$1.to_s.length..]]  # float
      when /\A(-?\d+)/ then [$1.to_i, input[$1.to_s.length..]]   # integer
      when /\A(true)/i then [true, input[$1.to_s.length..]]   # true
      when /\A(false)/i then [false, input[$1.to_s.length..]]    # false
      when /\A(".*?")/i then [$1[1..$1.to_s.length - 2], input[$1.to_s.length..]]   # strings
      when /\A(x[0-9]+)/ then [$1, input[$1.to_s.length..]]   # variables

      # binary operators
      when /\A(\*\*|\+|-|\*|\/|%|x)/ then [Operator.new($1.to_s), input[$1.to_s.length..]]
      when /\A(&|\||\^|<<|>>)/ then [Operator.new($1.to_s), input[$1.to_s.length..]]
      when /\A(==|!=|<=>|>=|<=|>|<)/ then [Operator.new($1.to_s), input[$1.to_s.length..]]
      # unary operators
      when /\A([!~])/ then [Operator.new($1.to_s), input[1..]]
      # symbols
      when /\A([x\[\],{}'])/ then [$1, input[1..]]

      else raise "Invalid token at beginning of input! '#{input}'"
    end
  end

  # Iterates through the parsed tokens, adding each to the ret array.
  # If the token is a left brace then generate a lambda, otherwise
  # if it is a left square-bracket the generate a vector or matrix!
  # @param [Array] tokens
  def self.parse_lambdas_and_arrays(tokens)
    ret = []
    until tokens.empty?
      elem = tokens.shift
      if elem == '{'
        elem = Parser.parse_lambda(tokens)
      elsif elem == '['
        elem = Parser.parse_array(tokens)
      end
      ret << elem
    end
    ret
  end

  # Parse a lambda function by popping off the top stack element which is the
  # number of variables. The retrieve the lambda function body by taking all
  # tokens until an '}' is found. Finally, remove the lambda tokens from
  # the tokens array along with the trailing '}'!
  # @param [Array] tokens
  def self.parse_lambda(tokens)
    param_count = tokens.shift

    # ensure the next token is a |
    next_t = tokens.shift
    raise "Require |!" if !next_t.is_a?(Operator) || next_t.operator != '|'
    
    lambda_tokens = tokens.take_while { |token| token != '}' }
    _ = tokens.shift(lambda_tokens.size + 1)   # +1 captures the '}'
    Lambda.new(lambda_tokens, param_count)
  end

  # @param [Array] tokens
  def self.parse_array(tokens)
    array_tokens = []
    until tokens.at(0) == ']'
      token = tokens.shift
      next if token == ','
      array_tokens << (if token == '[' then parse_array(tokens) else token end)
    end
    _ = tokens.shift # remove the ']'

    is_matrix = array_tokens.any? {|t| t.is_a?(Vector) }
    return is_matrix ? Matrix[*array_tokens] : Vector[*array_tokens]
  end
end
