require_relative 'ws'

# get the passed argument
input_file = ARGV[0]
# puts input_file.split('-')[1]
expected_file = input_file.gsub('input', 'expected')
puts input_file, expected_file

# generate tokens from the input
input_content = File.readlines(input_file).join
tokens = Parser.tokenize_input(input_content)
tokens = Parser.parse_lambdas_and_arrays(tokens)

# create a new stack, pushing & executing each token
stack = Stack.new
tokens.each { |elem| stack.push(elem) }

xyz = input_file.scan(/\d{3}/).first
output_file = "output/output-#{xyz}.txt"

File.open(output_file, 'w') do |file|
  stack.elems_to_s.each do |e|
    file.puts e
  end
end

my_output = File.readlines(output_file, chomp: true).to_s
expected_output = File.readlines(expected_file, chomp: true).to_s
is_equal = my_output == expected_output

puts "Result:   #{my_output}"
puts "Expected: #{expected_output}"
puts "Is Equal? #{is_equal}\n\n"

raise "#{input} test failed!" unless is_equal

