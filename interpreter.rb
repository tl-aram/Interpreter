# Interpreter for language
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: var[code] means while(var){code}
# Function definition: func name(args){code}
# Function invocation: name(args)
# Scope: local in functions, global

require '.\parser.rb'

class Interpreter
	@@actions = { } #Similarly to the parser, this stores the actions associated with each operator.  binop(), etc acts like symbol() in Parser

	attr_accessor :parser, :vartab, :functab
	def initialize
		@parser = Parser.new
		@vartab = { }
		@functab = { } #associates the name of a function with an array of trees corresponding to its statements
		@currentnode = nil
	end

	def self.binop(name, type, &action) #takes a name, a type, and an action for a binary operation, and returns a proc that applies the operation to its inputs
		@@actions[name] = lambda do |a, b|
			if (a.is_a? Node) && (b.is_a? Node)
				left = $i.lang_eval a
				right = $i.lang_eval b #to handle nested expressions
				left = left::left if left.is_a? Node
				right = right::left if right.is_a? Node
				if (left.is_a? type) && (right.is_a? type)
					result = Parser.symtab['literal'].clone
					result::left = action.call(left, right)
					return result
				else
					raise '%s required for %s, at line %d' % type.to_s, name, ($i::parser::tokenizer::lineno+1) #doesn't work
				end
			else
				raise 'Node expected, at line %d' % ($i::parser::tokenizer::lineno+1)
			end
		end
	end
	
	@@actions['='] = lambda do |a, b|
		if (a.is_a? Node) && (b.is_a? Node)
			if a::id != 'name' #get a variable name, if it isn't already there
				a = $i.lang_eval a
				raise 'Bad lvalue, at line %d' % ($i::parser::tokenizer::lineno+1) if a::id != 'name'
			end
			if b::id == 'literal'
				$i::vartab[a::left] = b::left
			elsif b::id == 'name'
				raise '%s has no value' % b::left unless $i::vartab[b::left]
				$i::vartab[a::left] = b::left
			else
				b = $i.lang_eval b
				if b::id == 'literal'
					$i::vartab[a::left] = b::left
				elsif b::id == 'name'
					raise '%s has no value' % b::left unless $i::vartab[b::left]
					$i::vartab[a::left] = b::left
				else
					raise 'Bad rvalue, at line %d' % ($i::parser::tokenizer::lineno+1)
				end
			end
		else
			raise 'Node expected, at line %d' % ($i::parser::tokenizer::lineno+1)
		end
	end
	
	binop('+', Integer) do |a, b| a + b end
	binop('-', Integer) do |a, b| a - b end
	binop('*', Integer) do |a, b| a * b end
	binop('/', Integer) do |a, b| (a / b).to_i end
	binop('%', Integer) do |a, b| a % b end
	binop('<'. Integer) do |a, b| (a < b) ? true : false end
	binop('<='. Integer) do |a, b| (a <= b) ? true : false end
	binop('!='. Integer) do |a, b| (a != b) ? true : false end
	binop('=='. Integer) do |a, b| (a == b) ? true : false end
	binop('>='. Integer) do |a, b| (a >= b) ? true : false end
	binop('>'. Integer) do |a, b| (a > b) ? true : false end
	
	def lang_eval(node)  #Takes a node in the parse tree and evaluates it

		case node::id
			when '='
				return @@actions['='].call(node::left, node::right) if (node::right)
				raise 'Missing operand for =, at line %d' % (@parser::tokenizer::lineno+1)
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
			when '<'
				return @@actions['<'].call(node::left, node::right) if (node::right)
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

lines = [ ]
parseoutput = [ ]
lineno = 0
unless ARGV.empty?
	ARGF.each do |line| lines[lineno] = line.chomp; lineno+=1; end
	lines.each do |line| parseoutput << ($i::parser.read line) end
	parseoutput.each do |tree| puts $i.lang_eval tree; end
else
	puts 'Press q, then enter, to exit'
	until ((lines[lineno] = gets.chomp) == 'q')
		parseoutput << ($i::parser.read lines[lineno])
		puts $i.lang_eval parseoutput[lineno]
		lineno+=1
	end
end