require_relative 'stack'

def parse_input(input)
  File.readlines(input)
end

# get the passed argument
input_file = ARGV[0]
expected_file = input_file.gsub('input', 'expected')
expected_output = parse_input(expected_file).map { |elem| elem.chomp }

puts input_file, expected_file

# generate tokens from the input
input_content = parse_input(input_file).join
tokens = Parser.tokenize_input(input_content)
tokens = Parser.parse_lambdas_and_array(tokens)
# tokens = Parser.generate_arrays(tokens)

# create a new stack, pushing & executing each token
stack = Stack.new
tokens.each { |elem| stack.push(elem) }
result_stack = stack.result

puts "Result stack: #{result_stack}"
puts "Expected: #{expected_output}"
puts "Result: #{result_stack == expected_output}\n\n"

