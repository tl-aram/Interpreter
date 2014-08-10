# Interpreter for language
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: var{code} means while(var){code}
# Function definition: func name(args){code}
# Function invocation: name(args)
# Scope: local in functions, global

require '.\parser.rb'

class Interpreter
	@@actions = { } #Similarly to the parser, this stores the actions associated with each operator.  binop(), etc acts like symbol() in Parser

	attr_accessor :parser, :mainblock, :currentblock
	def initialize
		@parser = Parser.new
		@currentnode = nil
		@mainblock = Block.new #the block in which all execution happens, and the one that has the global variables
		@currentblock = @mainblock
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
		raise 'Node expected, at line %d' % ($i::parser::tokenizer::lineno+1) unless (a.is_a? Node) && (b.is_a? Node)
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
	end
	
	@@actions['?'] = lambda do |a, b|
		raise 'Node expected, at line %d' % ($i::parser::tokenizer::lineno+1) unless (a.is_a? Node and b.is_a? Node)
		raise 'Improper ?: expression, at line %d' % ($i::parser::tokenizer::lineno+1) unless (b::id == ':' and b::left and b::right)
		ifclause = lang_eval a
		ifclause = ifclause::left if ifclause.is_a? Node
		if ifclause
			if b::left::id == 'literal'
				return b::left
			else
				return lang_eval b::left
			end
		else
			if b::right::id == 'literal'
				return b::right
			else
				return lang_eval b::right
			end
		end
	end
	
	binop('!', Object) do |a| a ? false : true end
	binop('&', Object) do |a, b| (a && b) ? true : false end
	binop('|', Object) do |a, b| (a || b) ? true : false end
	binop('<', Integer) do |a, b| (a < b) ? true : false end
	binop('<=', Integer) do |a, b| (a <= b) ? true : false end
	binop('!=', Integer) do |a, b| (a != b) ? true : false end
	binop('==', Integer) do |a, b| (a == b) ? true : false end
	binop('>=', Integer) do |a, b| (a >= b) ? true : false end
	binop('>', Integer) do |a, b| (a > b) ? true : false end
	binop('+', Integer) do |a, b| a + b end
	binop('-', Integer) do |a, b| a - b end
	binop('*', Integer) do |a, b| a * b end
	binop('/', Integer) do |a, b| (a / b).to_i end
	binop('%', Integer) do |a, b| a % b end
	
	
	def lang_eval(node)  #Takes a node in the parse tree and evaluates it
		case node::id
			when /^[=?!&|+\-*\/%]$/ #logic, math, ternary, and assignment operators
				return @@actions[node::id].call(node::left, node::right) if (node::right)
				raise 'Missing operand for %c, at line %d' % node::id, (@parser::tokenizer::lineno+1) unless node::id == '?'
				raise 'Missing operand for ?:, at line %d' % (@parser::tokenizer::lineno+1)
			when /[<!=>]=?/ #comparison operators
				return @@actions[node::id].call(node::left, node::right) if (node::right)
				raise 'Missing operand for %s, at line %d' % node::id, (@parser::tokenizer::lineno+1)
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

$i = Interpreter.new #later, make this a non-global variable

lines = [ ]
lineno = 0
unless ARGV.empty?
	ARGF.each do |line| lines[lineno] = line.chomp; lineno+=1; end
	lines.each do |line|
		tree = $i::parser.read line
		$i::currentblock << tree
		if tree.is_a? Node
			puts $i.lang_eval $i::currentblock.last
		elsif tree.is_a? Block
			$i::currentblock = tree #switch to new block is done here, not in read(), since I don't know whether a ref is being copied
		elsif !tree
			if $i::currentblock::type == Whileblock
				test = $i::lang_eval $i::currentblock::expr
				while test::left
					$i::currentblock.block_eval
					test = $i::lang_eval $i::currentblock::expr
				end
			elsif $i::currentblock::type == Funcblock
				
			end
			$i::currentblock = $i::currentblock::parentblock #when a block ends, this returns interpreter to its parent
		end
	end
else
	puts 'Press q, then enter, to exit'
	until ((lines[lineno] = gets.chomp) == 'q')
		tree = ($i::parser.read lines[lineno])
		$i::currentblock << tree
		if tree.is_a? Node
			puts $i.lang_eval $i::currentblock.last
		elsif tree.is_a? Block
			$i::currentblock = tree #switch to new block is done here, not in read(), since I don't know whether a ref is being copied
		elsif !tree
			if $i::currentblock::type == Whileblock
				test = $i::lang_eval $i::currentblock::expr
				while test::left
					$i::currentblock.block_eval
					test = $i::lang_eval $i::currentblock::expr
				end
			elsif $i::currentblock::type == Funcblock
				
			end
			$i::currentblock = $i::currentblock::parentblock #when a block ends, this returns interpreter to its parent
		end
	end
end