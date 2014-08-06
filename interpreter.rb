# Interpreter for language
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: var[code] means while(var){code}
# Function definition: func name(args){code}
# Function invocation: name(args)
# Scope: local in functions, global

require '.\parser.rb'

class Interpreter
	def initialize()
		@vartab = { }
		@functab = { } #associates the name of a function with an array of trees corresponding to its statements
		@currentnode = nil
	end

	def add(a, b)
		if (a.is_a? Node && b.is_a? Node)
			if (a::left.is_a? Integer && b::left.is_a? Integer)
				return a + b
			elsif (a::left.is_a? String && b::left.is_a? String)
				return a + b
			else
				raise ArgumentError, 'Addends must both be integers or strings'
			end
		else
			raise 'Parse error: nodes expected'
		end
	end
	
	def subtract(subtrahend, minuend)
		
	end
	
	def multiply(a, b)
		
	end
	
	def divide(dividend, divisor)
		
	end
	
	def eval(node)  #Takes a node in the parse tree and evaluates it
		
	end
end

$p = Parser.new
lines = [ ]
output = [ ]
if $ARGV
	for filename in $ARGV
		if !(File.exists? filename)
			puts '%s doesn\'t exist' % filename
		else
			if File.directory? filename
				puts '%s is a folder' % filename
			else
				lines << ARGF.readlines
			end
		end
	end
	lines = lines.each do |line| line.chomp end
	output = $p.parse lines
else
	until ((lines[0] = gets.chomp) == 'q')
		output << ($p.parse lines)
	end
end

output.each do |tree| puts tree.to_s end