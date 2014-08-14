# Lexer/parser for language DEBUGGING REQUIRED
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: has form while(var){code}
# Function definition: func name(args){code}
# Both of these use block, which are collections of code together with local variables.
# Blocks can be nested, and a block can access the variables of the blocks that contains it.
# Function invocation: name(args)
# Scope: local in functions, global

class Token
	attr_accessor :type, :value
	def initialize
		@type = nil
		@value = nil
	end
end

class Lexer
	attr_accessor :lineno, :source, :tok_start, :cur
	def initialize
		@lineno = 0
		@source = [ ]
		@tok_start = 0
		@cur = 0
	end
	
	def get_token
		t = Token.new
		while (@source[@lineno][@cur]) =~ /\s/ #should match newlines too
			@cur+=1
		end
		if @source[@lineno][@cur].nil? #probably change to empty?
			t::type = 'end'
			return t
		end
		@tok_start = @cur
		if (@source[@lineno][@cur]) =~ /[A-Za-z_]/
			if @source[@lineno][@cur, 4] == 'func'
				@cur+=4
				t::type = t::value = 'func'
				return t
			elsif @source[@lineno][@cur, 5] == 'while'
				@cur+=5
				t::type = t::value = 'while'
				return t
			end
			@cur+=1
			t::type = 'name'
			while @source[@lineno][@cur] =~ /[A-Za-z_]/
				@cur+=1
			end
			t::value = @source[@lineno][@tok_start..@cur-1]
			return t #since @cur is already incremented to point to the next char, we return early
		end
		if (@source[@lineno][@cur]) =~ /\d/ # Only ints for now
				@cur+=1
			while @source[@lineno][@cur] =~ /\d/
				@cur+=1
			end
			t::type = 'number'
			t::value = @source[@lineno][@tok_start..@cur-1]
			return t
		end
		def compsym(sym) # A proc, no, method, just to make the code shorter
			if @source[@lineno][@cur.next] == '='
				@cur+=1
				sym + '='
			else
				sym
			end
		end
		case @source[@lineno][@cur] #maybe find better way to write this
			when '{' then t::value = '{'
			when '}' then t::value = '}'
			when '[' then t::value = '['
			when ']' then t::value = ']'
			when '(' then t::value = '('
			when ')' then t::value = ')'
			when ',' then t::value = ','
			when ';' then t::value = ';'
			when '=' then t::value = compsym('=')
			when '?' then t::value = '?'
			when ':' then t::value = ':'
			when '|' then t::value = '|'
			when '&' then t::value = '&'
			when '!' then t::value = compsym('!')
			when '<' then t::value = compsym('<')
			when '>' then t::value = compsym('>')
			when '+' then t::value = '+'
			when '-' then t::value = '-'
			when '*' then t::value = '*'
			when '/' then t::value = '/'
			when '%' then t::value = '%'
			when "'" then
				@cur+=1
				while @source[@lineno][@cur]
					if @source[@lineno][@cur] == "'"
						break
					else
						@cur+=1
					end
					if @source[@lineno][@cur].nil? # maybe use better end-of-input handling?
						raise 'End of string (\') expected'
					end
				end
				t::type = 'string'
				t::value = @source[@lineno][@tok_start..@cur]
		end
		t::type = 'operator' if t::value && !(t::type) # Maybe write a better check for operators
		raise 'Unknown token: ' + @source[@lineno][@cur] if t::type.nil?
		@cur+=1
		t
	end
end

# Ripped off, poorly, from Vaughan Pratt's TDOP algorithm (http://javascript.crockford.com/tdop/tdop.html)

class Node #I actually forgot there was an existing Symbol class, and tried to call it that, not knowing why I was getting errors
	attr_accessor :id, :lbp, :nud, :led, :left, :right
	def initialize(id, bp) #I know, the symbol creation in the original is all in one place
		@id = id
		@lbp = bp
		@nud = Proc.new { raise "Undefined." } #null denotation
		@led = Proc.new { raise "Undefined." } #left denotation.	Should be something less clunky; no actual first order first-order functions here
	end
	
	def to_s(indent=0)
		raise "Node has no children" if @left.nil?
		if @right
			return ("(%s\n" +
							("   " * (indent+1)) +
							"%s\n" +
							("   " * (indent+1)) +
							"%s)") % [@id,
												(if (@left.class == Node)
														 @left.to_s(indent+1)
												 else @left.to_s end
												),
												(if (@right.class == Node)
														 @right.to_s(indent+1)
												 else @right.to_s end
												)
												]
		else
			return ("(%s" +
							" "	  +
							"%s)") % [@id,
												(if (@left.class == Node)
														@left.to_s(indent+1)
												 else @left.to_s end
												)
											 ]
		end
	end
end

Whileblock = 0
Funcblock = 1 #values for @type
class Block < Array #a series of parse trees, corresponding to statements, along with local variables and nested blocks
	attr_accessor :expr, :type, :name, :vartab, :functab, :parentblock #functab associates the name of a function with an array of trees corresponding to its statements	
	def initialize(parent, expr, type, name=nil)
		super()
		@type = type
		@vartab = { }
		@functab = { }
		@parentblock = parent
		@expr = expr #holds either the condition, for 'while', or the parameter list, for 'func'
		@name = name #for a function
	end
	
	def block_eval
		if @type == Whileblock
			test = $i.stmt_eval @expr
			while test::left
				self.each do |tree|
					if tree.is_a? Node
						result = $i.stmt_eval tree
						puts result if $live
					elsif tree.is_a? Block and tree::type == Whileblock
						$i.block_eval tree
					end
				end
				test = $i.stmt_eval @expr
			end
		elsif @type == Funcblock
			
		end
	end
	
	def to_s
		if @type == Whileblock
			puts 'While block, with condition:'
		elsif @type == Funcblock
			puts 'Function block, for %s, with parameters:' % @name
		end
		puts @expr.to_s
		print 'Variables: %s' % @vartab.to_s unless @vartab.empty?
		print 'Functions: %s' % @functab.to_s unless @functab.empty?
		print 'Code: '
		super
	end
end

class Parser
	@@symtab = {} # Contains all the valid language tokens.  I'm not entirely sure about declaring it a class var
	def self.symtab
			@@symtab
	end

	attr_accessor :node, :sav, :tokenizer #done to get parentheses working.  Fix later
	def initialize
		@tokenizer = Lexer.new # why the defined method is initialize and the called method is new mystifies me
		@token = nil
		@blocklevel = 0
		@node = nil
		@sav = nil
	end

	def self.symbol(id, bp=0) #Returns symbol, takes value and binding power
		if @@symtab[id]
			if bp > @@symtab[id]::lbp
				@@symtab[id]::lbp = bp
			end
		else
			@@symtab[id] = Node.new(id, bp)
		end
		@@symtab[id]
	end

	def self.prefix(id, bp=0, &nud)
		sym = symbol(id, bp)
		if nud
			sym::nud = nud
		else
			sym::nud = Proc.new do |node|
				node::left = $i::parser.expression bp
				node
			end
		end
		sym
	end
	
	def self.infix(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left|
				node::left = left
				node::right = $i::parser.expression bp
				node
			end
			sym
		end
	end
	
	def self.infixr(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left|
				node::left = left
				node::right = $i::parser.expression bp-1
				node
			end
		end
		sym
	end
	
	symbol('{')
	symbol('}')
	symbol(';')
	prefix('+', 10)
	prefix('-', 10)
	prefix('!', 70)
	prefix('(', 80) do |node|
		node = $i::parser.expression 0
#		$i::parser::sav = $i::parser::node
		$i::parser.expect ')'
		node
	end
	infix('(', 80) do |node, left| #for function calls
		raise 'Function called with bad name' if left::id != 'name'
		node::left = left
		node::right = $i::parser::expression 0
		$i::parser.expect ')'
		node
	end
	symbol(')')
	infix(',')
	infixr('=', 10) do |node, left|
		raise 'Left side of \'=\' not an lvalue' if left::id != 'name'
		node::left = left
		node::right = $i::parser.expression 9
		node
	end
	infix('?', 20) do |node, left|
		node::left = left
		middle = $i::parser.expression 20
		$i::parser.expect ':'
		node::right = @@symtab[':'].clone
		node::right::led.call(node::right, middle)
		node
	end
	infix(':', 20)
	infixr('&', 30)
	infixr('|', 30)
	infix('>', 40)
	infix('<', 40)
	infix('<=', 40)
	infix('==', 40)
	infix('!=', 40)
	infix('>=', 40)
	infix('+', 50)
	infix('-', 50)
	infix('*', 60)
	infix('/', 60)
	infix('%', 60)
	# symbol('*', 20)::led = Proc.new do |node, left|
		# node::left = left
		# node::right = $i::parser.expression 20
		# node
	# end
	symbol('literal')::nud = Proc.new do |node|
		node
	end
	symbol('string')::nud = Proc.new do |node|
		node
	end
	symbol('name')::nud = Proc.new do |node|
		node
	end
	prefix('while')::nud = Proc.new do |node|
		$i::parser.expect '('
		$i::parser::sav = $i::parser::node
		$i::parser::expect
		cond = $i::parser::sav::nud.call($i::parser::sav)
		cond
	end
	prefix('func')::nud = Proc.new do |node|
		name = $i::parser::expect 'name'
		$i::parser.expect '('
		args = $i::parser::node::nud.call($i::parser::node)
		[name, args]
	end
	symbol('end')::nud = Proc.new do |node|
		node
	end
	
	def expect(expected=nil)
		if expected
			if @node::id != expected #doesn't actually get new token properly.  Fix later
				expect
				raise SyntaxError, "%s expected, but %s received instead" % [expected, (@node ? ("symbol " + @node.id) : "nothing")] if @node::id != expected
			end
		else
			@token = @tokenizer.get_token
			case @token::type
				when 'operator'
					nextnode = @@symtab[@token::value].clone #probably not the best way to do, maybe use metaprogramming
				when 'number'
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value.to_i
				when 'string'
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value
				when 'name'
					nextnode = @@symtab['name'].clone
					nextnode::left = @token::value
				when 'func'
					nextnode = @@symtab['func'].clone
					nextnode::left = @token::value
				when 'while'
					nextnode = @@symtab['while'].clone
					nextnode::left = @token::value
				when 'end'
					nextnode = @@symtab['end'].clone
			end
#			if @sav == @node #When we need to get a new token/node, which is most of the time
				@node = nextnode
#			end
#			if expected	#caused trouble with the ';'
#				if nextnode::id != expected
#					raise SyntaxError, "%s expected, but %s received instead" % [expected, (nextnode ? ("symbol " + nextnode.id) : "nothing")]
#				end
#			end
			@node #Either we have a new node, or will just use the existing one
		end
	end
	
	def expression(rbp)
		@sav = @node
		expect
		left = @sav::nud.call(@sav)
		while rbp < @node.lbp
			@sav = @node
 			expect
			left = @sav::led.call(@sav, left)
		end
		left
	end
	
	def statement
		expect
		tree = expression 0
		expect ';'
		tree
	end

	def read(line) #Parses a line of text input and returns a parse tree, or handles block creation
		@tokenizer::source << line
		begin #Catch-all error handling for syntax errors
			if line =~ /^\s*while/
				expect
				cond = @node::nud.call(@node)
				expect '{'
				@blocklevel+=1
				tree = Block.new($i::currentblock, cond, Whileblock)
			elsif line =~ /^\s*func/
				expect #'func' token
				nameandargs = @node::nud.call(@node)
				expect '{'
				@blocklevel+=1
				tree = Block.new($i::currentblock, nameandargs[1], Funcblock, nameandargs[0])
			elsif line == '}'
				@blocklevel-=1
				tree = 'end' #this is so, when the interpreter checks if the return type is Block, it only works if a block is beginning
			elsif line != ''
				tree = statement
			end
		rescue Exception => error
			puts error.to_s + (', at line %d' % @tokenizer::lineno)
		ensure
			@tokenizer::lineno+=1
			@tokenizer::tok_start = @tokenizer::cur = 0
			@sav = @node = nil #to clear the state for the next line
		end
		tree
	end
end