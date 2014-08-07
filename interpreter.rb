# Interpreter for language
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: var[code] means while(var){code}
# Function definition: func name(args){code}
# Function invocation: name(args)
# Scope: local in functions, global

require '.\parser.rb'

class Interpreter
	@@actions = { }

	attr_accessor :parser
	def initialize
		@parser = Parser.new
		@vartab = { }
		@functab = { } #associates the name of a function with an array of trees corresponding to its statements
		@currentnode = nil
	end

	def self.binop(name, type, &action) #takes a name, a type, and an action for a binary operation, and returns a proc that applies the operation to its inputs
		@@actions[name] = Proc.new do |a, b|
			if (a.is_a? Node) && (b.is_a? Node)
				left = $i.lang_eval a
				right = $i.lang_eval b #to handle nested expressions
				if (left.is_a? type) && (right.is_a? type)
					result = Parser.symtab['literal'].clone
					result::left = action.call(left, right)
					return result
				else
					raise '%s required for %s, at line %d' % type.to_s, name, ($i::parser::tokenizer::lineno+1)
				end
			else
				raise 'Node expected, at line %d' % ($i::parser::tokenizer::lineno+1)
			end
		end
	end
	
	binop('+', Integer) do |a, b| return a + b end
	binop('-', Integer) do |a, b| return a - b end
	binop('*', Integer) do |a, b| return a * b end
	binop('/', Integer) do |a, b| return a / b end
	
	def lang_eval(node)  #Takes a node in the parse tree and evaluates it
		case node::id
			when '+' 
				return @@actions['+'].call(node::left, node::right) if (node::right)
				raise 'Missing operand for +, at line %d' % (@parser::tokenizer::lineno+1)
			when '-'
				return @@actions['-'].call(node::left, node::right) if (node::right)
				raise 'Missing operand for -, at line %d' % (@parser::tokenizer::lineno+1)
			when '*'
				return @@actions['*'].call(node::left, node::right) if (node::right)
				raise 'Missing operand for *, at line %d' % (@parser::tokenizer::lineno+1)
			when '/'
				return @@actions['/'].call(node::left, node::right) if (node::right)
				raise 'Missing operand for /, at line %d' % (@parser::tokenizer::lineno+1)
			when 'name'
				return @vartab[node::left] if @vartab[node::left]
				raise '%s has no value, at line %d' % @vartab[node::left], (@parser::tokenizer::lineno+1)
			when 'literal'
				return node::left if node::left
				raise 'Value doesn\'t exist, at line %d' %  (@parser::tokenizer::lineno+1)
			else
				return 'stub'
		end
	end
end

$i = Interpreter.new
#$p = Parser.new
#from_file = ($ARGV) ? 1 : 0

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
	output = $i::parser.read lines
else
	until ((lines[0] = gets.chomp) == 'q')
		output << ($i::parser.read lines[0])
	end
end

output.each do |tree| puts tree.to_s; puts $i.lang_eval(tree); end