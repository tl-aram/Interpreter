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
		@mainblock = Block.new(nil, nil, nil) #the block in which all execution happens, and the one that has the global variables
		@currentblock = @mainblock
	end

	def self.binop(name, type, &action) #takes a name, a type, and an action for a binary operation, and returns a proc that applies the operation to its inputs
		@@actions[name] = lambda do |a, b|
			if (a.is_a? Node) && (b.is_a? Node)
				left = $i.stmt_eval a
				right = $i.stmt_eval b #to handle nested expressions
				left = left::left if left.is_a? Node
				right = right::left if right.is_a? Node
				if (left.is_a? type) && (right.is_a? type)
					result = Parser.symtab['literal'].clone
					result::left = action.call(left, right)
					return result
				else
					raise '%s required for %s' % [type.to_s, name]
				end
			else
				raise 'Node expected'
			end
		end
	end
	
	@@actions['='] = lambda do |a, b|
		raise 'Node expected' % $i::parser::tokenizer::lineno unless (a.is_a? Node) && (b.is_a? Node)
#		if a::id != 'name' #get a variable name, if it isn't already there
#			a = $i.stmt_eval a
		raise 'Bad lvalue' if a::id != 'name'
#		end
		b = $i.stmt_eval b unless b::id == 'literal'
		$i::currentblock::vartab[a::left] = b::left #for now, only variables in current block can be assigned.  Change later
	end
	
	@@actions['?'] = lambda do |a, b|
		raise 'Node expected' unless (a.is_a? Node and b.is_a? Node)
		raise 'Improper ?: expression' unless (b::id == ':' and b::left and b::right)
		ifclause = $i.stmt_eval a
		ifclause = ifclause::left if ifclause.is_a? Node
		if ifclause
			if b::left::id == 'literal'
				return b::left
			else
				return $i.stmt_eval b::left
			end
		else
			if b::right::id == 'literal'
				return b::right
			else
				return stmt_eval b::right
			end
		end
	end
	
	binop(',', Object) do |a, b| [a, b].flatten end #without flattening, there'd be a nested array, since comma lists are represented as trees
	@@actions['!'] = lambda do |a|
		raise 'Node expected' unless a.is_a? Node
		term = $i.stmt_eval a
		term = term::left if term.is_a? Node
		term ? false : true
	end
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
	@@actions['('] = lambda do |name, args| #( will only show up in the parse tree if a function is being called
		function = $i.namesearch(name::left, true)
		args = $i.stmt_eval args #either a literal corresponding to the expression in parens, or an array of literals
		if args.is_a? Node
			if args::left.is_a? Array
				raise 'Wrong number of arguments for \'%s\'' % name::left if function::expr.size != args::left.size #check
				i = 0
				args::left.each do |arg|
					function::vartab[function::expr[i]::left] = arg
					i+=1
				end
			else #a name was passed
				raise 'Wrong number of arguments for \'%s\'' % name::left unless function::expr::left.is_a? String
				function::vartab[function::expr::left] = args::left				
			end
		else #a literal
			raise 'Wrong number of arguments for \'%s\'' % name::left unless function::expr::left.is_a? String
			function::vartab[function::expr::left] = args
		end
		function.block_eval
	end
	
	def namesearch(name, function=false) #looks for a var or function in available tables, and returns it if it can find it
		if function
			block = @currentblock
			until block::functab[name]
				break unless block::parentblock
				block = block::parentblock
			end
			return block::functab[name] if block::functab[name]
			raise 'Function %s has no value' % name
		else
			block = @currentblock
			until block::vartab[name]
				break unless block::parentblock
				block = block::parentblock
			end
			return block::vartab[name] if block::vartab[name]
			raise 'Variable %s has no value' % name
		end
	end
	
	def stmt_eval(node)  #Takes a node in the parse tree and evaluates it
		case node::id
			when /^[,=?&|+\-*\/%(]$/ #logic, math, ternary, and assignment operators
				return @@actions[node::id].call(node::left, node::right) if (node::right)
				raise 'Missing operand for %c' % node::id unless node::id == '?'
				raise 'Missing operand for ?:'
			when /[<!=>]=?/ #comparison operators
				return @@actions[node::id].call(node::left, node::right) if (node::right)
				raise 'Missing operand for %s' % node::id
			when '!' #so far, the only unary operator
				return @@actions['!'].call(node::left)
			when 'name' #searches available blocks for variable corresponding to name
				return namesearch node::left
			when 'literal'
				return node::left if node::left
				raise 'Value doesn\'t exist'
			else
				return 'stub'
		end
	end
	
	def lang_eval(line) #Takes a line of source code, parses it, and executes it
		tree = @parser.read line
		begin #also, catch-all handling for execution errors
			@currentblock << tree if (tree and tree != 'end')
			if (tree.is_a? Node and @currentblock::type != Whileblock and @currentblock::type != Funcblock) #if block is being defined, code shouldn't be run immediately
				result = stmt_eval @currentblock.last
				puts result if $live
			elsif tree.is_a? Block
				@currentblock = tree #switch to new block is done here, not in read(), since I don't know whether a ref is being copied
				if @currentblock::type == Funcblock #check for correct argument form in definition
					if @currentblock::expr.is_a? Node
						if @currentblock::expr::id = 'name'
							@currentblock::vartab[@currentblock::expr::left] = 0 #for now, function vars initialized at declaration
						elsif @currentblock::expr::id == ','
							arglist = stmt_eval @currentblock::expr
							arglist.each do |arg|
								raise 'Bad form for function declaration' unless arg::id == 'name'
								@currentblock::vartab[arg::left] = 0
							end
						end
					else
						raise 'Bad form for function declaration'
					end
				end
			elsif tree == 'end'
				if @currentblock::type == Whileblock
					@currentblock.block_eval
				elsif @currentblock::type == Funcblock
					@currentblock::parentblock::functab[@currentblock::name::left] = @currentblock	
				end
				@currentblock = @currentblock::parentblock #when a block ends, this returns interpreter to its parent
			end
		rescue Exception => error
			puts error.to_s + (', at line %d' % @parser::tokenizer::lineno)
		end
	end
end

$i = Interpreter.new #later, make this a non-global variable
lines = [ ]
lineno = 0

unless ARGV.empty?
	ARGF.each do |line| lines[lineno] = line.chomp; lineno+=1; end
	lines.each do |line| $i::lang_eval line end
else
	$live = 0 #if the interpreter is reading from stdin
	puts 'Press q, then enter, to exit'
	until ((lines[lineno] = gets.chomp) == 'q')
		$i::lang_eval lines[lineno]
		lineno+=1
	end
end