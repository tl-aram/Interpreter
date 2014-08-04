# Lexer/parser for language
# Operators: = + - (unary and n-ary) * / % & | ! (last 3 are logical) == != (inequality) < <= > >= ?:
# Statements end with ;
# While loop: var[code] means while(var){code}
# Function definition: func name(args){code}
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
			if @source[@lineno][@cur, 4] == 'func' #So far our only reserved word
				@cur+=4
				t::type = t::value = 'func'
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
				return sym + '='
			else
				return sym
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
						raise "End of string (') expected at line %d" % (@lineno + 1)
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

class Parser
	@@symtab = {} # Contains all the valid language tokens.  I'm not entirely sure about declaring it a class var
	attr_accessor :node, :sav #done to get parentheses working.  Fix later
	def initialize
		@tokenizer = Lexer.new # why the defined method is initialize and the called method is new mystifies me
		@token = nil
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
				node::left = $p.expression bp
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
				node::right = $p.expression bp
				node
			end
		end
		sym
	end
	
	def self.infixr(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left|
				node::left = left
				node::right = $p.expression bp-1
				node
			end
		end
		sym
	end
	
	symbol(';')
	prefix('+', 10)
	prefix('-', 10)
	prefix('!', 70)
	prefix('(', 80) do |node|
		node = $p.expression 0
#		$p::sav = $p::node
		$p.expect ')'
		node
	end
	symbol(')')
	infixr('=', 10) do |node, left|
		raise 'Left side of \'=\' not an lvalue' if left::id != 'name'
		node::left = left
		node::right = $p.expression 9
		node
	end
	infix('?', 20) do |node, left|
		node::left = left
		middle = $p.expression 20
		$p.expect ':'
		node::right = @@symtab[':'].clone
		node::right::led.call(node::right, middle)
		node
	end
	infix(':', 20)
	infixr('&', 30)
	infixr('|', 30)
	infix('<', 40)
	infix('<=', 40)
	infix('==', 40)
	infix('!=', 40)
	infix('>=', 40)
	infix('>', 40)
	infix('+', 50)
	infix('-', 50)
	infix('*', 60)
	infix('/', 60)
	infix('%', 60)
	# symbol('*', 20)::led = Proc.new do |node, left|
		# node::left = left
		# node::right = $p.expression 20
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
	symbol('end')::nud = Proc.new do |node|
		node
	end
	
	# def accept
		# if @sav == @node #When we need to get a new token, which is most of the time
			# tok = @tokenizer.get_token
			# case tok::type
				# when 'operator'
					# @node = @@symtab[tok::value].clone #probably not the best way to do, maybe use metaprogramming
				# when 'number'
					# @node = @@symtab['literal'].clone
					# @node::left = tok::value
				# when 'end'
					# @node = @@symtab['end'].clone
			# end
			# @token = tok #not seeing much use for ext. token var
		# end
	# end
	
	def expect(expected=nil)
		if expected
			if @node::id != expected #doesn't actually get new token properly.  Fix later
				expect
				raise SyntaxError, "%s expected, but %s received instead" % [expected, (@node ? ("symbol " + @node.id) : "nothing")] if @node::id != expected
			end
		end
		@token = @tokenizer.get_token
		case @token::type
			when 'operator'
				nextnode = @@symtab[@token::value].clone #probably not the best way to do, maybe use metaprogramming
			when 'number'
				nextnode = @@symtab['literal'].clone
				nextnode::left = @token::value
			when 'string'
				nextnode = @@symtab['literal'].clone
				nextnode::left = @token::value
			when 'name'
				nextnode = @@symtab['name'].clone
				nextnode::left = @token::value
			when 'func'
				nextnode = @@symtab['func'].clone
				nextnode::left = @token::value
			when 'end'
				nextnode = @@symtab['end'].clone
		end
#		if @sav == @node #When we need to get a new token/node, which is most of the time
			@node = nextnode
#		end
#		if expected	#caused trouble with the ';'
#			if nextnode::id != expected
#				raise SyntaxError, "%s expected, but %s received instead" % [expected, (nextnode ? ("symbol " + nextnode.id) : "nothing")]
#			end
#		end
		@node #Either we have a new node, or will just use the existing one
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
	
	def parse
		line = ''
		until ((line = gets.chomp) == 'q')
			@tokenizer::source << line
			begin
				puts statement.to_s unless line == ''
			rescue Exception => error
				puts error.to_s + (', at line %d' % (@tokenizer::lineno + 1))
			ensure
				@tokenizer::lineno+=1
				@tokenizer::tok_start = @tokenizer::cur = 0
				@sav = @node = nil #to clear the state for the next line
			end
		end
	end
end

#Temporarily moved symbol declarations out of Parser class

$p = Parser.new
$p.parse