
Dir.entries('input').select do |file|
  next if %w[. ..].include?(file) # skip the prev directories
  next unless file.start_with?('input-225')

  # invoke the stack for each input file
  system("ruby ws.rb input/#{file}")
end
