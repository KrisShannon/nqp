# Copyright (C) 2009, Patrick R. Michaud
# $Id$

=head1 NAME

Regex::P6Regex - Parser/compiler for Perl 6 regexes

=head1 DESCRIPTION

=cut

### .include 'src/cheats/hll-compiler.pir'
# we have to overload PCT::HLLCompiler's parse method to support P6Regex grammars


.namespace ['HLL';'Compiler']

.sub '' :anon :init :load
    load_bytecode 'PCT.pbc'
    .local pmc p6meta
    p6meta = get_hll_global 'P6metaclass'
    p6meta.'new_class'('HLL::Compiler', 'parent'=>'PCT::HLLCompiler')
.end
   

.sub 'parse' :method
    .param pmc source
    .param pmc options         :slurpy :named

    .local pmc parsegrammar, parseactions, match
    parsegrammar = self.'parsegrammar'()
    parseactions = self.'parseactions'()
    $I0 = isa parsegrammar, ['Regex';'Cursor']
    unless $I0 goto parse_old

    match = parsegrammar.'parse'(source, 'from'=>0, 'action'=>parseactions)
    unless match goto err_parsefail
    .return (match)

  err_parsefail:
    self.'panic'('Unable to parse source')
    .return (match)

  parse_old:
    $I0 = isa parsegrammar, ['NameSpace']
    if $I0 goto parse_old_1
    ##  switch from protoobjects to classes, then call parent
    $P0 = parsegrammar.'HOW'()
    $P0 = getattribute $P0, 'parrotclass'
    parsegrammar = $P0.'get_namespace'()
    self.'parsegrammar'(parsegrammar)

    $P0 = parseactions.'HOW'()
    $P0 = getattribute $P0, 'parrotclass'
    parseactions = $P0.'get_namespace'()
    self.'parseactions'(parseactions)

  parse_old_1:
    $P0 = get_hll_global ['PCT'], 'HLLCompiler'
    $P1 = find_method $P0, 'parse'
    .tailcall self.$P1(source, options :flat :named)
.end

# these will eventually move to Regex.pir
### .include 'src/PAST/Regex.pir'
# $Id: Regex.pir 41578 2009-09-30 14:45:23Z pmichaud $

=head1 NAME

PAST::Regex - Regex nodes for PAST

=head1 DESCRIPTION

This file implements the various abstract syntax tree nodes
for regular expressions.  

=cut

.namespace ['PAST';'Regex']

.sub '' :init :load
    load_bytecode 'PCT.pbc'
    .local pmc p6meta
    p6meta = get_hll_global 'P6metaclass'
    p6meta.'new_class'('PAST::Regex', 'parent'=>'PAST::Node')
.end


.sub 'backtrack' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('backtrack', value, has_value)
.end


.sub 'capnames' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('capnames', value, has_value)
.end


.sub 'negate' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('negate', value, has_value)
.end


.sub 'min' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('min', value, has_value)
.end


.sub 'max' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('max', value, has_value)
.end


.sub 'pasttype' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('pasttype', value, has_value)
.end


.sub 'sep' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('sep', value, has_value)
.end


.sub 'subtype' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('subtype', value, has_value)
.end


.sub 'zerowidth' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('zerowidth', value, has_value)
.end


=item peek()

Returns the prefixes associated with the regex tree rooted
at this node.

=cut

.sub 'peek' :method
    .local pmc list
    list = new ['ResizablePMCArray']

    $I0 = isa self, ['PAST';'Regex']
    unless $I0 goto peek_stop

    .local pmc child_it
    child_it = self.'iterator'()

    .local string pasttype
    pasttype = self.'pasttype'()
    if pasttype == 'concat' goto concat
    if pasttype == '' goto concat
    if pasttype == 'literal' goto literal
    if pasttype == 'alt' goto alt
    if pasttype == 'alt_longest' goto alt_longest

  peek_stop:
    list = 0
    .return (list)

  peek_zero:
    list = 1
    list[0] = ''
    .return (list)

  # temporal alternation returns the prefixes of its first child
  alt:
    unless child_it goto peek_stop
    $P0 = shift child_it
    .tailcall 'peek'($P0)

  # declarative alternation returns prefixes of all children
  alt_longest:
    unless child_it goto alt_longest_done
    $P0 = shift child_it
    $P1 = 'peek'($P0)
    $I0 = elements list
    splice list, $P1, $I0, 0
    goto alt_longest
  alt_longest_done:
    .return (list)

  concat:
    unless child_it goto peek_zero
    $P0 = shift child_it
    list = 'peek'($P0)
    unless list goto peek_stop
  concat_loop:
    unless child_it goto concat_done
    .local pmc catlist
    $P0 = shift child_it
    catlist = 'peek'($P0)
    unless catlist goto concat_done
    # concatenate all elements of list with catlist
    .local pmc newlist, i1, i2
    newlist = new ['ResizablePMCArray']
    i1 = iter list
  concat_i1_loop:
    unless i1 goto concat_i1_done
    $S1 = shift i1
    i2 = iter catlist
  concat_i2_loop:
    unless i2 goto concat_i1_loop
    $S2 = shift i2
    $S2 = concat $S1, $S2
    push newlist, $S2
    goto concat_i2_loop
  concat_i1_done:
    list = newlist
    goto concat_loop
  concat_done:
    .return (list)
    
  literal:
    $P0 = self[0]
    $I0 = isa $P0, 'String'
    if $I0 goto literal_constant
    .return (list)
  literal_constant:
    push list, $P0
    .return (list)

.end

=back

=head1 AUTHOR

Patrick Michaud <pmichaud@pobox.com> is the author and maintainer.
Please send patches and suggestions to the Parrot porters or
Perl 6 compilers mailing lists.

=head1 COPYRIGHT

Copyright (C) 2009, Patrick R. Michaud.

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
### .include 'src/PAST/Compiler-Regex.pir'
# $Id$

=head1 NAME

PAST::Compiler-Regex - Compiler for PAST::Regex nodes

=head1 DESCRIPTION

PAST::Compiler-Regex implements the transformations to convert 
PAST::Regex nodes into POST.  It's still a part of PAST::Compiler;
we've separated out the regex-specific transformations here for
better code management and debugging.

=head2 Compiler methods

=head3 C<PAST::Regex>

=over 4

=item as_post(PAST::Regex node)

Return the POST representation of the regex AST rooted by C<node>.

=cut

.include 'cclass.pasm'
### .include 'src/Regex/constants.pir'
.const int CURSOR_FAIL = -1
.const int CURSOR_FAIL_GROUP = -2
.const int CURSOR_FAIL_RULE = -3
.const int CURSOR_FAIL_MATCH = -4

.namespace ['PAST';'Compiler']

.sub 'as_post' :method :multi(_, ['PAST';'Regex'])
    .param pmc node
    .param pmc options         :slurpy :named

    .local pmc ops
    ops = self.'post_new'('Ops', 'node'=>node)

    .local pmc reghash
    reghash = new ['Hash']
    .lex '$*REG', reghash

    .local pmc regexname
    $P0 = get_global '@?BLOCK'
    $P1 = $P0[0]
    $S0 = $P1.'name'()
    regexname = box $S0
    .lex '$*REGEXNAME', regexname

    .local string prefix, rname, rtype
    prefix = self.'unique'('rx')
    concat prefix, '_'
    $P0 = split ' ', 'tgt string pos int off int eos int rep int cur pmc'
    $P1 = iter $P0
  iter_loop:
    unless $P1 goto iter_done
    rname = shift $P1
    rtype = shift $P1
    $S1 = concat prefix, rname
    reghash[rname] = $S1
    $S2 = concat '.local ', rtype
    ops.'push_pirop'($S2, $S1)
    goto iter_loop
  iter_done:

    .local pmc startlabel, donelabel, faillabel
    $S0 = concat prefix, 'start'
    startlabel = self.'post_new'('Label', 'result'=>$S0)
    $S0 = concat prefix, 'done'
    donelabel = self.'post_new'('Label', 'result'=>$S0)
    $S0 = concat prefix, 'fail'
    faillabel = self.'post_new'('Label', 'result'=>$S0)
    reghash['fail'] = faillabel

    # If capnames is available, it's a hash where each key is the
    # name of a potential subcapture and the value is greater than 1
    # if it's to be an array.  This builds a list of arrayed subcaptures
    # for use by "!cursor_caparray" below.
    .local pmc capnames, capnames_it, caparray
    capnames = node.'capnames'()
    caparray = box 0
    unless capnames goto capnames_done
    capnames_it = iter capnames
    caparray = new ['ResizablePMCArray']
  capnames_loop:
    unless capnames_it goto capnames_done
    $S0 = shift capnames_it
    $I0 = capnames[$S0]
    unless $I0 > 1 goto capnames_loop
    $S0 = self.'escape'($S0)
    push caparray, $S0
    goto capnames_loop
  capnames_done:

    .local string cur, rep, pos, tgt, off, eos
    (cur, rep, pos, tgt, off, eos) = self.'!rxregs'('cur rep pos tgt off eos')

    $S0 = concat '(', cur
    concat $S0, ', '
    concat $S0, pos
    concat $S0, ', '
    concat $S0, tgt
    concat $S0, ', $I10)'
    ops.'push_pirop'('callmethod', '"!cursor_start"', 'self', 'result'=>$S0)
    unless caparray goto caparray_skip
    self.'!cursorop'(ops, '!cursor_caparray', 0, caparray :flat)
  caparray_skip:

    ops.'push_pirop'('.lex', 'unicode:"$\x{a2}"', cur)
    ops.'push_pirop'('length', eos, tgt, 'result'=>eos)

    # On Parrot, indexing into variable-width encoded strings 
    # (such as utf8) becomes much more expensive as we move
    # farther away from the beginning of the string (via calls
    # to utf8_skip_forward).  For regexes that are starting a match 
    # at a position other than the beginning of the string (e.g.,
    # a subrule call), we can save a lot of useless scanning work
    # in utf8_skip_forward by removing the first C<off = from-1> 
    # characters from the target and then performing all indexed
    # operations on the resulting target relative to C<off>.
    
    ops.'push_pirop'('set', off, 0)
    ops.'push_pirop'('lt', '$I10', 2, startlabel)
    ops.'push_pirop'('sub', off, '$I10', 1, 'result'=>off)
    ops.'push_pirop'('substr', tgt, tgt, off, 'result'=>tgt)
    ops.'push'(startlabel)

    $P0 = self.'post_regex'(node)
    ops.'push'($P0)
    ops.'push'(faillabel)
    self.'!cursorop'(ops, '!mark_fail', 4, rep, pos, '$I10', '$P10', 0)
    ops.'push_pirop'('lt', pos, CURSOR_FAIL, donelabel)
    ops.'push_pirop'('eq', pos, CURSOR_FAIL, faillabel)
    ops.'push_pirop'('jump', '$I10')
    ops.'push'(donelabel)
    self.'!cursorop'(ops, '!cursor_fail', 0)
    ops.'push_pirop'('return', cur)
    .return (ops)
.end

=item !cursorop(ops, func, retelems, arg :slurpy)

Helper function to push POST nodes onto C<ops> that perform C<func>
on the regex's current cursor.  By default this ends up being a method
call on the cursor, but some values of C<func> can result in inlined
code to perform the equivalent operation without using the method call.

The C<retelems> argument is the number of elements in C<arg> that
represent return values from the function; any remaining elements in arg
are passed to the function as input arguments.

=cut

.sub '!cursorop' :method
    .param pmc ops
    .param string func
    .param int retelems
    .param pmc args            :slurpy

    if retelems < 1 goto result_done
    .local pmc retargs
    retargs = new ['ResizableStringArray']
    $I0 = retelems
  retargs_loop:
    unless $I0 > 0 goto retargs_done
    $S0 = shift args
    push retargs, $S0
    dec $I0
    goto retargs_loop
  retargs_done:
    .local string result
    result = join ', ', retargs
    result = concat '(', result
    concat result, ')'
  result_done:

    .local pmc cur
    cur = self.'!rxregs'('cur')
    $S0 = self.'escape'(func)
    $P0 = ops.'push_pirop'('callmethod', $S0, cur, args :flat)
    if retelems < 1 goto done
    $P0.'result'(result)
  done:
    .return (ops)
.end
    

=item !rxregs(keystr)

Helper function -- looks up the current regex register table
in the dynamic scope and returns a slice based on the keys
given in C<keystr>.

=cut

.sub '!rxregs' :method
    .param string keystr

    .local pmc keys, reghash, vals
    keys = split ' ', keystr
    reghash = find_dynamic_lex '$*REG'
    vals = new ['ResizablePMCArray']
  keys_loop:
    unless keys goto keys_done
    $S0 = shift keys
    $P0 = reghash[$S0]
    push vals, $P0
    goto keys_loop
  keys_done:
    .return (vals :flat)
.end


=item post_regex(PAST::Regex node)

Return the POST representation of the regex component given by C<node>.
Normally this is handled by redispatching to a method corresponding to
the node's "pasttype" and "backtrack" attributes.  If no "pasttype" is
given, then "concat" is assumed.

=cut

.sub 'post_regex' :method :multi(_, ['PAST';'Regex'])
    .param pmc node
    .param string cur          :optional
    .param int have_cur        :opt_flag

    .local string pasttype
    pasttype = node.'pasttype'()
    if pasttype goto have_pasttype
    pasttype = 'concat'
  have_pasttype:
    $P0 = find_method self, pasttype
    $P1 = self.$P0(node)
    unless have_cur goto done
    $S0 = $P1.'result'()
    if $S0 == cur goto done
    $P1 = self.'coerce'($P1, cur)
  done:
    .return ($P1)
.end


.sub 'post_regex' :method :multi(_, _)
    .param pmc node
    .param string cur          :optional
    .param int have_cur        :opt_flag

    $P0 = self.'as_post'(node)
    unless have_cur goto done
    $P0 = self.'coerce'($P0, cur)
  done:
    .return ($P0)
.end


=item alt(PAST::Regex node)

=cut

.sub 'alt' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos
    (cur, pos) = self.'!rxregs'('cur pos')

    .local string name
    name = self.'unique'('alt')
    concat name, '_'

    .local pmc ops, iter
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
    iter = node.'iterator'()
    unless iter goto done

    .local int acount
    .local pmc alabel, endlabel
    acount = 0
    $S0 = acount
    $S0 = concat name, $S0
    alabel = self.'post_new'('Label', 'result'=>$S0)
    $S0 = concat name, 'end'
    endlabel = self.'post_new'('Label', 'result'=>$S0)

  iter_loop:
    ops.'push'(alabel)
    .local pmc apast, apost
    apast = shift iter
    apost = self.'post_regex'(apast, cur)
    unless iter goto iter_done
    inc acount
    $S0 = acount
    $S0 = concat name, $S0
    alabel = self.'post_new'('Label', 'result'=>$S0)
    ops.'push_pirop'('set_addr', '$I10', alabel)
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, '$I10')
    ops.'push'(apost)
    ops.'push_pirop'('goto', endlabel)
    goto iter_loop
  iter_done:
    ops.'push'(apost)
    ops.'push'(endlabel)
  done:
    .return (ops)
.end


=item alt_longest(PAST::Regex node)

Same as 'alt' above, but use declarative/LTM semantics.
(Currently we cheat and just use 'alt' above.)

=cut

.sub 'alt_longest' :method
    .param pmc node
    .tailcall self.'alt'(node)
.end


=item anchor(PAST::Regex node)

Match various anchor points, including ^, ^^, $, $$.

=cut

.sub 'anchor' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, tgt, pos, off, eos, fail, ops
    (cur, tgt, pos, off, eos, fail) = self.'!rxregs'('cur tgt pos off eos fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local string subtype
    subtype = node.'subtype'()

    ops.'push_pirop'('inline', subtype, 'inline'=>'  # rxanchor %0')

    if subtype == 'null' goto done
    if subtype == 'fail' goto anchor_fail
    if subtype == 'bos' goto anchor_bos
    if subtype == 'eos' goto anchor_eos
    if subtype == 'lwb' goto anchor_lwb
    if subtype == 'rwb' goto anchor_rwb

    .local pmc donelabel
    $S0 = self.'unique'('rxanchor')
    concat $S0, '_done'
    donelabel = self.'post_new'('Label', 'result'=>$S0)

    if subtype == 'bol' goto anchor_bol
    if subtype == 'eol' goto anchor_eol

    self.'panic'('Unrecognized subtype "', subtype, '" in PAST::Regex anchor node')

  anchor_fail:
    ops.'push_pirop'('goto', fail)
    goto done

  anchor_bos:
    ops.'push_pirop'('ne', pos, 0, fail)
    goto done

  anchor_eos:
    ops.'push_pirop'('ne', pos, eos, fail)
    goto done

  anchor_bol:
    ops.'push_pirop'('eq', pos, 0, donelabel)
    ops.'push_pirop'('ge', pos, eos, fail)
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('dec', '$I10')
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_NEWLINE, tgt, '$I10')
    ops.'push_pirop'('unless', '$I11', fail)
    ops.'push'(donelabel)
    goto done

  anchor_eol:
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_NEWLINE, tgt, '$I10')
    ops.'push_pirop'('if', '$I11', donelabel)
    ops.'push_pirop'('ne', pos, eos, fail)
    ops.'push_pirop'('eq', pos, 0, donelabel)
    ops.'push_pirop'('dec', '$I10')
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_NEWLINE, tgt, '$I10')
    ops.'push_pirop'('if', '$I11', fail)
    ops.'push'(donelabel)
    goto done

  anchor_lwb:
    ops.'push_pirop'('ge', pos, eos, fail)
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_WORD, tgt, '$I10')
    ops.'push_pirop'('unless', '$I11', fail)
    ops.'push_pirop'('dec', '$I10')
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_WORD, tgt, '$I10')
    ops.'push_pirop'('if', '$I11', fail)
    goto done

  anchor_rwb:
    ops.'push_pirop'('le', pos, 0, fail)
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_WORD, tgt, '$I10')
    ops.'push_pirop'('if', '$I11', fail)
    ops.'push_pirop'('dec', '$I10')
    ops.'push_pirop'('is_cclass', '$I11', .CCLASS_WORD, tgt, '$I10')
    ops.'push_pirop'('unless', '$I11', fail)
    goto done

  done:
    .return (ops)
.end


=item charclass(PAST::Regex node)

Match something in a character class, such as \w, \d, \s, dot, etc.

=cut

.sub 'charclass' :method
    .param pmc node

    .local string subtype
    .local int cclass, negate
    (subtype, cclass, negate) = self.'!charclass_init'(node)

    .local pmc cur, tgt, pos, off, eos, fail, ops
    (cur, tgt, pos, off, eos, fail) = self.'!rxregs'('cur tgt pos off eos fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    ops.'push_pirop'('inline', subtype, 'inline'=>'  # rx charclass %0')
    ops.'push_pirop'('ge', pos, eos, fail)
    if cclass == .CCLASS_ANY goto charclass_done

    .local pmc cctest
    cctest = self.'??!!'(negate, 'if', 'unless')

    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('is_cclass', '$I11', cclass, tgt, '$I10')
    ops.'push_pirop'(cctest, '$I11', fail)
    unless subtype == 'nl' goto charclass_done
    # handle logical newline here
    ops.'push_pirop'('substr', '$S10', tgt, '$I10', 2)
    ops.'push_pirop'('iseq', '$I11', '$S10', '"\r\n"')
    ops.'push_pirop'('add', pos, '$I11')

  charclass_done:
    ops.'push_pirop'('inc', pos)

    .return (ops)
.end


=item !charclass_init(PAST::Regex node)

Return the subtype, cclass value, and negation for a
charclass C<node>.

=cut

.sub '!charclass_init' :method
    .param pmc node

    .local string subtype
    .local int negate
    subtype = node.'subtype'()
    $S0 = downcase subtype
    negate = isne subtype, $S0

    $I0 = node.'negate'()
    negate = xor negate, $I0

    if $S0 == '.' goto cclass_dot
    if $S0 == 'd' goto cclass_digit
    if $S0 == 's' goto cclass_space
    if $S0 == 'w' goto cclass_word
    if $S0 == 'n' goto cclass_newline
    if $S0 == 'nl' goto cclass_newline
    self.'panic'('Unrecognized subtype "', subtype, '" in PAST::Regex charclass node')
  cclass_dot:
    .local int cclass
    cclass = .CCLASS_ANY
    goto cclass_done
  cclass_digit:
    cclass = .CCLASS_NUMERIC
    goto cclass_done
  cclass_space:
    cclass = .CCLASS_WHITESPACE
    goto cclass_done
  cclass_word:
    cclass = .CCLASS_WORD
    goto cclass_done
  cclass_newline:
    cclass = .CCLASS_NEWLINE
  cclass_done:
    .return (subtype, cclass, negate)
.end


=item charclass_q(PAST::Regex node)

Optimize certain quantified character class shortcuts, if it
makes sense to do so.  If not, return a null PMC and the
standard quantifier code will handle it.

=cut

.sub 'charclass_q' :method :multi(_, ['PAST';'Regex'])
    .param pmc node
    .param string backtrack
    .param int min
    .param int max

    if backtrack != 'r' goto pessimistic

    .local string subtype
    .local int cclass, negate
    (subtype, cclass, negate) = self.'!charclass_init'(node)

    # positive logical newline matching is special, don't try to optimize it
    if negate goto nl_done
    if subtype == 'nl' goto pessimistic
  nl_done:

    .local pmc findop
    findop = self.'??!!'(negate, 'find_cclass', 'find_not_cclass')

  quant_r:
    .local pmc cur, tgt, pos, off, eos, fail, ops
    (cur, tgt, pos, off, eos, fail) = self.'!rxregs'('cur tgt pos off eos fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    ops.'push_pirop'('inline', subtype, backtrack, min, max, 'inline'=>'  # rx charclass_q %0 %1 %2..%3')
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'(findop, '$I11', cclass, tgt, '$I10', eos)
    unless min > 0 goto min_done
    ops.'push_pirop'('add', '$I12', '$I10', min)
    ops.'push_pirop'('lt', '$I11', '$I12', fail)
  min_done:
    unless max > 0 goto max_done
    .local pmc maxlabel
    maxlabel = self.'post_new'('Label', 'name'=>'rx_charclass_')
    ops.'push_pirop'('add', '$I12', '$I10', max)
    ops.'push_pirop'('le', '$I11', '$I12', maxlabel)
    ops.'push_pirop'('set', '$I11', '$I12')
    ops.'push'(maxlabel)
  max_done:
    ops.'push_pirop'('add', pos, off, '$I11')
    .return (ops)

  pessimistic:
    null ops
    .return (ops)
.end
    

=item concat(PAST::Regex node)

Handle a concatenation of regexes.

=cut

.sub 'concat' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, ops, iter
    (cur) = self.'!rxregs'('cur')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
    iter = node.'iterator'()

  iter_loop:
    unless iter goto iter_done
    .local pmc cpast, cpost
    cpast = shift iter
    cpost = self.'post_regex'(cpast, cur)
    ops.'push'(cpost)
    goto iter_loop
  iter_done:

    .return (ops)
.end


=item cut(PAST::Regex node)

Generate POST for the cut-group and cut-rule operators.

=cut

.sub 'cut' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, fail, ops
    (cur, fail) = self.'!rxregs'('cur fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
    ops.'push_pirop'('set_addr', '$I10', fail)
    self.'!cursorop'(ops, '!mark_commit', 0, '$I10')
    .return (ops)
.end


=item enumcharlist(PAST::Regex node)

Generate POST for matching a character from an enumerated
character list.

=cut

.sub 'enumcharlist' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, tgt, pos, off, eos, fail, ops
    (cur, tgt, pos, off, eos, fail) = self.'!rxregs'('cur tgt pos off eos fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local string charlist
    charlist = node[0]
    charlist = self.'escape'(charlist)
    .local pmc  negate, testop
    negate = node.'negate'()
    testop = self.'??!!'(negate, 'ge', 'lt')
    .local string subtype
    .local int zerowidth
    subtype = node.'subtype'()
    zerowidth = iseq subtype, 'zerowidth'

    ops.'push_pirop'('inline', negate, subtype, 'inline'=>'  # rx enumcharlist negate=%0 %1')
   
    ops.'push_pirop'('ge', pos, eos, fail)
    ops.'push_pirop'('sub', '$I10', pos, off)
    ops.'push_pirop'('substr', '$S10', tgt, '$I10', 1)
    ops.'push_pirop'('index', '$I11', charlist, '$S10')
    ops.'push_pirop'(testop, '$I11', 0, fail)
    if zerowidth goto skip_zero_2
    ops.'push_pirop'('inc', pos)
  skip_zero_2:
    .return (ops)
.end
    

=item literal(PAST::Regex node)

Generate POST for matching a literal string provided as the
second child of this node.

=cut

.sub 'literal' :method :multi(_,['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, eos, tgt, fail, off
    (cur, pos, eos, tgt, fail, off) = self.'!rxregs'('cur pos eos tgt fail off')
    .local pmc ops, cpast, cpost, lpast, lpost
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local string subtype
    .local int ignorecase
    subtype = node.'subtype'()
    ignorecase = iseq subtype, 'ignorecase'

    # literal to be matched is our first child
    .local int litconst
    lpast = node[0]
    litconst = isa lpast, ['String']
    unless litconst goto lpast_done
    unless ignorecase goto lpast_done
    $S0 = lpast
    $S0 = downcase $S0
    lpast = box $S0
  lpast_done:
    lpost = self.'as_post'(lpast, 'rtype'=>'~')

    $S0 = lpost.'result'()
    ops.'push_pirop'('inline', subtype, $S0, 'inline'=>'  # rx literal %0 %1')
    ops.'push'(lpost)

    # compute constant literal length at compile time
    .local string litlen
    $I0 = isa lpast, ['String']
    if $I0 goto literal_string
    litlen = '$I10'
    ops.'push_pirop'('length', '$I10', lpost)
    goto have_litlen
  literal_string:
    $S0 = lpast
    $I0 = length $S0
    litlen = $I0
    if $I0 > 0 goto have_litlen
    .return (cpost)
  have_litlen:

    # fail if there aren't enough characters left in string
    ops.'push_pirop'('add', '$I11', pos, litlen)
    ops.'push_pirop'('gt', '$I11', eos, fail)

    # compute string to be matched and fail if mismatch
    ops.'push_pirop'('sub', '$I11', pos, off)
    ops.'push_pirop'('substr', '$S10', tgt, '$I11', litlen)
    unless ignorecase goto literal_test
    ops.'push_pirop'('downcase', '$S10', '$S10')
  literal_test:
    ops.'push_pirop'('ne', '$S10', lpost, fail)

    # increase position by literal length and move on
    ops.'push_pirop'('add', pos, litlen)
    .return (ops)
.end


=item pass(PAST::Regex node)

=cut

.sub 'pass' :method :multi(_,['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, ops
    (cur, pos) = self.'!rxregs'('cur pos')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local string regexname
    $P0 = find_dynamic_lex '$*REGEXNAME'
    regexname = self.'escape'($P0)

    ops.'push_pirop'('inline', 'inline'=>'  # rx pass')
    self.'!cursorop'(ops, '!cursor_pass', 0, pos, regexname)
    ops.'push_pirop'('return', cur)
    .return (ops)
.end


=item reduce

=cut

.sub 'reduce' :method :multi(_,['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, ops
    (cur, pos) = self.'!rxregs'('cur pos')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local pmc cpost, posargs, namedargs
    (cpost, posargs, namedargs) = self.'post_children'(node, 'signature'=>'v:')

    .local string regexname, key
    $P0 = find_dynamic_lex '$*REGEXNAME'
    regexname = self.'escape'($P0)
    key = posargs[0]

    ops.'push_pirop'('inline', regexname, key, 'inline'=>'  # rx reduce name=%0 key=%1')
    ops.'push'(cpost)
    self.'!cursorop'(ops, '!cursor_pos', 0, pos)
    self.'!cursorop'(ops, '!reduce', 0, regexname, posargs :flat, namedargs :flat)
    .return (ops)
.end


=item quant(PAST::Regex node)

=cut

.sub 'quant' :method :multi(_,['PAST';'Regex'])
    .param pmc node

    .local string backtrack
    backtrack = node.'backtrack'()
    if backtrack goto have_backtrack
    backtrack = 'g'
  have_backtrack:

     .local int min, max
     min = node.'min'()
     $P0 = node.'max'()
     max = $P0
     $I0 = defined $P0
     if $I0 goto have_max
     max = -1                          # -1 represents Inf
   have_max:

   optimize:
     $I0 = node.'list'()
     if $I0 != 1 goto optimize_done
     .local pmc cpast
     cpast = node[0]
     $S0 = cpast.'pasttype'()
     $S0 = concat $S0, '_q'
     $I0 = can self, $S0
     unless $I0 goto optimize_done
     $P0 = self.$S0(cpast, backtrack, min, max)
     if null $P0 goto optimize_done
     .return ($P0)
  optimize_done:

    .local pmc cur, pos, rep, fail
    (cur, pos, rep, fail) = self.'!rxregs'('cur pos rep fail')

    .local string qname
    .local pmc ops, q1label, q2label, btreg, cpost
    $S0 = concat 'rxquant', backtrack
    qname = self.'unique'($S0)
    ops = self.'post_new'('Ops', 'node'=>node)
    $S0 = concat qname, '_loop'
    q1label = self.'post_new'('Label', 'result'=>$S0)
    $S0 = concat qname, '_done'
    q2label = self.'post_new'('Label', 'result'=>$S0)
    cpost = self.'concat'(node)

    .local pmc seppast, seppost
    null seppost
    seppast = node.'sep'()
    unless seppast goto have_seppost
    seppost = self.'post_regex'(seppast)
  have_seppost:

    $S0 = max
    .local int needrep
    $I0 = isgt min, 1
    $I1 = isgt max, 1
    needrep = or $I0, $I1

    unless max < 0 goto have_s0
    $S0 = '*'
  have_s0:
    ops.'push_pirop'('inline', qname, min, $S0, 'inline'=>'  # rx %0 ** %1..%2')

  if backtrack == 'f' goto frugal

  greedy:
    btreg = self.'uniquereg'('I')
    ops.'push_pirop'('set_addr', btreg, q2label)
    .local int needmark
    .local string peekcut
    needmark = needrep
    peekcut = '!mark_peek'
    if backtrack != 'r' goto greedy_1
    needmark = 1
    peekcut = '!mark_commit'
  greedy_1:
    if min == 0 goto greedy_2
    unless needmark goto greedy_loop
    self.'!cursorop'(ops, '!mark_push', 0, 0, CURSOR_FAIL, btreg)
    goto greedy_loop
  greedy_2:
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, btreg)
  greedy_loop:
    ops.'push'(q1label)
    ops.'push'(cpost)
    unless needmark goto greedy_3
    self.'!cursorop'(ops, peekcut, 1, rep, btreg)
    unless needrep goto greedy_3
    ops.'push_pirop'('inc', rep)
  greedy_3:
    unless max > 1 goto greedy_4
    ops.'push_pirop'('ge', rep, max, q2label)
  greedy_4:
    unless max != 1 goto greedy_5
    self.'!cursorop'(ops, '!mark_push', 0, rep, pos, btreg)
    if null seppost goto greedy_4a
    ops.'push'(seppost)
  greedy_4a:
    ops.'push_pirop'('goto', q1label)
  greedy_5:
    ops.'push'(q2label)
    unless min > 1 goto greedy_6
    ops.'push_pirop'('lt', rep, min, fail)
  greedy_6:
    .return (ops)

  frugal:
    .local pmc ireg
    ireg = self.'uniquereg'('I')
    if min == 0 goto frugal_1
    unless needrep goto frugal_0
    ops.'push_pirop'('set', rep, 0)
  frugal_0:
    if null seppost goto frugal_2
    .local pmc seplabel
    $S0 = concat qname, '_sep'
    seplabel = self.'post_new'('Label', 'result'=>$S0)
    ops.'push_pirop'('goto', seplabel)
    goto frugal_2
  frugal_1:
    ops.'push_pirop'('set_addr', '$I10', q1label)
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, '$I10')
    ops.'push_pirop'('goto', q2label)
  frugal_2:
    ops.'push'(q1label)
    if null seppost goto frugal_2a
    ops.'push'(seppost)
    ops.'push'(seplabel)
  frugal_2a:
    unless needrep goto frugal_3
    ops.'push_pirop'('set', ireg, rep)
  frugal_3:
    ops.'push'(cpost)
    unless needrep goto frugal_4
    ops.'push_pirop'('add', rep, ireg, 1)
  frugal_4:
    unless min > 1 goto frugal_5
    ops.'push_pirop'('lt', rep, min, q1label)
  frugal_5:
    unless max > 1 goto frugal_6
    ops.'push_pirop'('ge', rep, max, q2label)
  frugal_6:
    unless max != 1 goto frugal_7
    ops.'push_pirop'('set_addr', '$I10', q1label)
    self.'!cursorop'(ops, '!mark_push', 0, ireg, pos, '$I10')
  frugal_7:
    ops.'push'(q2label)
    .return (ops)
.end


=item scan(POST::Regex)

Code for initial regex scan.

=cut

.sub 'scan' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, eos, ops
    (cur, pos, eos) = self.'!rxregs'('cur pos eos')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
    .local pmc looplabel, donelabel
    $S0 = self.'unique'('rxscan')
    $S1 = concat $S0, '_loop'
    looplabel = self.'post_new'('Label', 'result'=>$S1)
    $S1 = concat $S0, '_done'
    donelabel = self.'post_new'('Label', 'result'=>$S1)

    ops.'push_pirop'('ge', pos, 0, donelabel)
    ops.'push'(looplabel)
    self.'!cursorop'(ops, 'from', 1, '$P10')
    ops.'push_pirop'('inc', '$P10')
    ops.'push_pirop'('set', pos, '$P10')
    ops.'push_pirop'('ge', pos, eos, donelabel)
    ops.'push_pirop'('set_addr', '$I10', looplabel)
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, '$I10')
    ops.'push'(donelabel)
    .return (ops)
.end


=item subcapture(PAST::Regex node)

Perform a subcapture (capture of a portion of a regex).

=cut

.sub 'subcapture' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, tgt, fail
    (cur, pos, tgt, fail) = self.'!rxregs'('cur pos tgt fail')
    .local pmc ops, cpast, cpost
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
    cpast = node[0]
    cpost = self.'post_regex'(cpast)

    .local pmc name
    $P0 = node.'name'()
    name = self.'as_post'($P0, 'rtype'=>'*')

    .local string rxname 
    rxname = self.'unique'('rxcap_')

    .local pmc caplabel, donelabel
    $S0 = concat rxname, '_fail'
    caplabel = self.'post_new'('Label', 'result'=>$S0)
    $S0 = concat rxname, '_done'
    donelabel = self.'post_new'('Label', 'result'=>$S0)

    ops.'push_pirop'('inline', name, 'inline'=>'  # rx subcapture %0')
    ops.'push_pirop'('set_addr', '$I10', caplabel)
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, '$I10')
    ops.'push'(cpost)
    ops.'push_pirop'('set_addr', '$I10', caplabel)
    self.'!cursorop'(ops, '!mark_peek', 2, '$I12', '$I11', '$I10')
    self.'!cursorop'(ops, '!cursor_pos', 0, '$I11')
    self.'!cursorop'(ops, '!cursor_start', 1, '$P10')
    ops.'push_pirop'('callmethod', '"!cursor_pass"', '$P10', pos, '""')
    ops.'push'(name)
    self.'!cursorop'(ops, '!mark_push', 0, 0, CURSOR_FAIL, 0, '$P10')
    ops.'push_pirop'('callmethod', '"!cursor_names"', '$P10', name)
    ops.'push_pirop'('goto', donelabel)
    ops.'push'(caplabel)
    ops.'push_pirop'('goto', fail)
    ops.'push'(donelabel)
    .return (ops)
.end


=item subrule(PAST::Regex node)

Perform a subrule call.

=cut

.sub 'subrule' :method :multi(_, ['PAST';'Regex'])
    .param pmc node

    .local pmc cur, pos, fail, ops
    (cur, pos, fail) = self.'!rxregs'('cur pos fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)

    .local pmc name
    $P0 = node.'name'()
    name = self.'as_post'($P0, 'rtype'=>'*')

    .local pmc cpost, posargs, namedargs, subpost
    (cpost, posargs, namedargs) = self.'post_children'(node, 'signature'=>'v:')
    subpost = shift posargs

    .local pmc negate
    .local string testop
    negate = node.'negate'()
    testop = self.'??!!'(negate, 'if', 'unless')

    .local pmc subtype
    subtype = node.'subtype'()

    ops.'push_pirop'('inline', subpost, subtype, negate, 'inline'=>"  # rx subrule %0 subtype=%1 negate=%2")

    self.'!cursorop'(ops, '!cursor_pos', 0, pos)
    ops.'push'(cpost)
    ops.'push_pirop'('callmethod', subpost, cur, posargs :flat, namedargs :flat, 'result'=>'$P10')
    ops.'push_pirop'(testop, '$P10', fail)
    if subtype == 'zerowidth' goto done
    if subtype == 'method' goto subrule_pos
    self.'!cursorop'(ops, '!mark_push', 0, 0, CURSOR_FAIL, 0, '$P10')
    ops.'push'(name)
    ops.'push_pirop'('callmethod', '"!cursor_names"', '$P10', name)
  subrule_pos:
    ops.'push_pirop'('callmethod', '"pos"', '$P10', 'result'=>pos)
  done:
    .return (ops)
.end


=item post_new(type, args :slurpy, options :slurpy :named)

Helper method to create a new POST node of C<type>.

=cut

.sub 'post_new' :method
    .param string type
    .param pmc args            :slurpy
    .param pmc options         :slurpy :named

    $P0 = get_hll_global ['POST'], type
    .tailcall $P0.'new'(args :flat, options :flat :named)
.end

=item ??!!(test, trueval, falseval)

Helper method to perform ternary operation -- returns C<trueval> 
if C<test> is true, C<falseval> otherwise.

=cut

.sub '??!!' :method
    .param pmc test
    .param pmc trueval
    .param pmc falseval

    if test goto true
    .return (falseval)
  true:
    .return (trueval)
.end
    

=back

=head1 AUTHOR

Patrick Michaud <pmichaud@pobox.com> is the author and maintainer.

=head1 COPYRIGHT

Copyright (C) 2009, Patrick R. Michaud.

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:

### .include 'src/Regex/Cursor.pir'
# Copyright (C) 2009, Patrick R. Michaud
# $Id$

=head1 NAME

Regex::Cursor - Regex Cursor nodes

=head1 DESCRIPTION

This file implements the Regex::Cursor class, used for managing regular
expression control flow.  Regex::Cursor is also a base class for
grammars.

=cut

.include 'cclass.pasm'
### .include 'src/Regex/constants.pir'
.const int CURSOR_FAIL = -1
.const int CURSOR_FAIL_GROUP = -2
.const int CURSOR_FAIL_RULE = -3
.const int CURSOR_FAIL_MATCH = -4

.namespace ['Regex';'Cursor']

.sub '' :anon :load :init
    load_bytecode 'P6object.pbc'
    .local pmc p6meta
    p6meta = new 'P6metaclass'
    $P0 = p6meta.'new_class'('Regex::Cursor', 'attr'=>'$!target $!from $!pos $!match $!action $!names @!bstack @!cstack @!caparray')
    $P0 = box 0
    set_global '$!generation', $P0
    $P0 = new ['Boolean']
    assign $P0, 0
    set_global '$!FALSE', $P0
    $P0 = new ['Boolean']
    assign $P0, 1
    set_global '$!TRUE', $P0
    .return ()
.end

=head2 Methods

=over 4

=item MATCH()

Return this cursor's current Match object, generating a new one
for the Cursor if one hasn't been created yet.

=cut

.sub 'MATCH' :method
    .local pmc match
    match = getattribute self, '$!match'
    if null match goto match_make
    $P0 = get_global '$!TRUE'
    $I0 = issame match, $P0
    unless $I0 goto match_done

    # First, create a Match object and bind it
  match_make:
    match = new ['Regex';'Match']
    setattribute self, '$!match', match
    .local pmc target, from, to
    target = getattribute self, '$!target'
    setattribute match, '$!target', target
    from = getattribute self, '$!from'
    setattribute match, '$!from', from
    to = getattribute self, '$!pos'
    setattribute match, '$!to', to

    # Create any arrayed subcaptures.
    .local pmc caparray, caparray_it, caphash
    caparray = getattribute self, '@!caparray'
    if null caparray goto caparray_done
    caparray_it = iter caparray
    caphash = new ['Hash']
  caparray_loop:
    unless caparray_it goto caparray_done
    .local string subname
    .local pmc arr
    .local int keyint
    subname = shift caparray_it
    arr = new ['ResizablePMCArray']
    caphash[subname] = arr
    keyint = is_cclass .CCLASS_NUMERIC, subname, 0
    if keyint goto caparray_int
    match[subname] = arr
    goto caparray_loop
  caparray_int:
    $I0 = subname
    match[$I0] = arr
  caparray_done:

    # If it's not a successful match, or if there are
    # no saved subcursors, we're done.
    if to < from goto match_done
    .local pmc cstack, cstack_it
    cstack = getattribute self, '@!cstack'
    if null cstack goto cstack_done
    unless cstack goto cstack_done
    cstack_it = iter cstack
  cstack_loop:
    unless cstack_it goto cstack_done
    .local pmc subcur, submatch, names
    subcur = shift cstack_it
    # If the subcursor isn't bound with a name, skip it
    names = getattribute subcur, '$!names'
    if null names goto cstack_loop
    $I0 = isa subcur, ['Regex';'Cursor']
    unless $I0 goto cstack_1
    submatch = subcur.'MATCH'()
    goto cstack_2
  cstack_1:
    submatch = subcur
  cstack_2:
    # See if we have multiple binds
    .local pmc names_it
    subname = names
    names_it = get_global '$!FALSE'
    $I0 = index subname, '='
    if $I0 < 0 goto cstack_subname
    names_it = split '=', subname
  cstack_subname_loop:
    subname = shift names_it
  cstack_subname:
    keyint = is_cclass .CCLASS_NUMERIC, subname, 0
    if null caparray goto cstack_bind
    $I0 = exists caphash[subname]
    unless $I0 goto cstack_bind
    if keyint goto cstack_array_int
    $P0 = match[subname]
    push $P0, submatch
    goto cstack_bind_done
  cstack_array_int:
    $I0 = subname
    $P0 = match[$I0]
    push $P0, submatch
    goto cstack_bind_done
  cstack_bind:
    if keyint goto cstack_bind_int
    match[subname] = submatch
    goto cstack_bind_done
  cstack_bind_int:
    $I0 = subname
    match[$I0] = submatch
  cstack_bind_done:
    if names_it goto cstack_subname_loop
    goto cstack_loop
  cstack_done:

  match_done:
    .return (match)
.end


=item parse(target [, regex])

Parse C<target> in the current grammar starting with C<regex>.
If C<regex> is omitted, then use the C<TOP> rule for the grammar.

=cut

.sub 'parse' :method
    .param pmc target
    .param pmc regex           :optional
    .param int has_regex       :opt_flag
    .param pmc options         :slurpy :named

    if has_regex goto regex_done
    regex = find_method self, 'TOP'
  regex_done:

    .local pmc cur, match
    cur = self.'!cursor_init'(target, options :flat :named)
    cur = cur.regex()
    match = cur.'MATCH'()
    .return (match)
.end


=item pos()

Return the cursor's current position.

=cut

.sub 'pos' :method
    $P0 = getattribute self, '$!pos'
    .return ($P0)
.end


=item from()

Return the cursor's from position.

=cut

.sub 'from' :method
    $P0 = getattribute self, '$!from'
    .return ($P0)
.end


=head2 Private methods

=over 4

=item !cursor_init(target)

Create a new cursor for matching C<target>.

=cut

.sub '!cursor_init' :method
    .param string target
    .param int from            :named('from') :optional
    .param pmc action          :named('action') :optional

    .local pmc parrotclass, cur
    $P0 = self.'HOW'()
    parrotclass = getattribute $P0, 'parrotclass'
    cur = new parrotclass

    $P0 = new ['CodeString']
    $P0 = target
    setattribute cur, '$!target', $P0

    $P0 = box from
    setattribute cur, '$!from', $P0
    $P0 = box from
    setattribute cur, '$!pos', $P0

    setattribute cur, '$!action', action
    .return (cur)
.end

=item !cursor_start([lang])

Create and initialize a new cursor from C<self>.  If C<lang> is
provided, then the new cursor has the same type as lang.

=cut

.sub '!cursor_start' :method
    .param pmc lang            :optional
    .param int has_lang        :opt_flag

    if has_lang goto have_lang
    lang = self
  have_lang:

    .local pmc parrotclass, cur
    $P0 = lang.'HOW'()
    parrotclass = getattribute $P0, 'parrotclass'
    cur = new parrotclass

    .local pmc from, pos, target, action
    from = getattribute self, '$!pos'
    setattribute cur, '$!from', from
    setattribute cur, '$!pos', from

    target = getattribute self, '$!target'
    setattribute cur, '$!target', target
    action = getattribute self, '$!action'
    setattribute cur, '$!action', action

    .return (cur, from, target, from)
.end


=item !cursor_fail(pos)

Permanently fail this cursor.

=cut

.sub '!cursor_fail' :method
    .local pmc pos
    pos = box CURSOR_FAIL_RULE
    setattribute self, '$!pos', pos
    null $P0
    setattribute self, '$!match', $P0
    setattribute self, '@!bstack', $P0
    setattribute self, '@!cstack', $P0
.end


=item !cursor_pass(pos, name)

Set the Cursor as passing at C<pos>; calling any reduction action
C<name> associated with the cursor.  This method simply sets
C<$!match> to a boolean true value to indicate the regex was
successful; the C<MATCH> method above replaces this boolean true
with a "real" Match object when requested.

=cut

.sub '!cursor_pass' :method
    .param pmc pos
    .param string name

    setattribute self, '$!pos', pos
    .local pmc match
    match = get_global '$!TRUE'
    setattribute self, '$!match', match
    unless name goto done
    self.'!reduce'(name)
  done:
    .return (self)
.end


=item !cursor_caparray(caparray :slurpy)

Set the list of subcaptures that produce arrays to C<caparray>.

=cut

.sub '!cursor_caparray' :method
    .param pmc caparray        :slurpy
    setattribute self, '@!caparray', caparray
.end


=item !cursor_names(names)

Set the Cursor's name (for binding) to C<names>.

=cut

.sub '!cursor_names' :method
    .param pmc names
    setattribute self, '$!names', names
.end


=item !cursor_pos(pos)

Set the cursor's position to C<pos>.

=cut

.sub '!cursor_pos' :method
    .param pmc pos
    setattribute self, '$!pos', pos
.end


=item !mark_push(rep, pos, mark)

Push a new backtracking point onto the cursor with the given
C<rep>, C<pos>, and backtracking C<mark>.  (The C<mark> is typically
the address of a label to branch to when backtracking occurs.)

=cut

.sub '!mark_push' :method
    .param int rep
    .param int pos
    .param int mark
    .param pmc subcur          :optional
    .param int has_subcur      :opt_flag

    # cptr contains the desired number of elements in the cstack
    .local int cptr
    cptr = 0

    # Initialize bstack if needed, and set cptr to be the cstack
    # size requested by the top frame.
    .local pmc bstack
    bstack = getattribute self, '@!bstack'
    if null bstack goto bstack_new
    unless bstack goto bstack_done
    $I0 = elements bstack
    dec $I0
    cptr = bstack[$I0]
    goto bstack_done
  bstack_new:
    bstack = new ['ResizableIntegerArray']
    setattribute self, '@!bstack', bstack
  bstack_done:

    # If a new subcursor is being pushed, then save it in cstack
    # and change cptr to include the new subcursor.
    unless has_subcur goto subcur_done
    .local pmc cstack
    cstack = getattribute self, '@!cstack'
    unless null cstack goto have_cstack
    cstack = new ['ResizablePMCArray']
    setattribute self, '@!cstack', cstack
  have_cstack:
    cstack[cptr] = subcur
    inc cptr
  subcur_done:

    # Save our mark frame information.
    push bstack, mark
    push bstack, pos
    push bstack, rep
    push bstack, cptr
.end


=item !mark_peek(mark)

Return information about the latest frame for C<mark>.
If C<mark> is zero, return information about the latest frame.

=cut

.sub '!mark_peek' :method
    .param int tomark

    .local pmc bstack
    bstack = getattribute self, '@!bstack'
    if null bstack goto no_mark
    unless bstack goto no_mark

    .local int bptr
    bptr = elements bstack

  bptr_loop:
    bptr = bptr - 4
    if bptr < 0 goto no_mark
    .local int rep, pos, mark, cptr
    mark = bstack[bptr]
    unless tomark goto bptr_done
    unless mark == tomark goto bptr_loop
  bptr_done:
    $I0  = bptr + 1
    pos  = bstack[$I0]
    inc $I0
    rep  = bstack[$I0]
    inc $I0
    cptr = bstack[$I0]
    .return (rep, pos, mark, bptr, bstack, cptr)

  no_mark:
    .return (0, CURSOR_FAIL_GROUP, 0, 0, bstack, 0)
.end


=item !mark_fail(tomark)

Remove the most recent C<mark> and backtrack the cursor to the
point given by that mark.  If C<mark> is zero, then
backtracks the most recent mark.  Returns the backtracked
values of repetition count, cursor position, and mark (address).

=cut

.sub '!mark_fail' :method
    .param int mark

    # Get the frame information for C<mark>.
    .local int rep, pos, mark, bptr, cptr
    .local pmc bstack
    (rep, pos, mark, bptr, bstack, cptr) = self.'!mark_peek'(mark)

    .local pmc subcur
    null subcur

    # If there's no bstack, there's nothing else to do.
    if null bstack goto done

    # If there's a subcursor associated with this mark, return it.
    unless cptr > 0 goto cstack_done
    .local pmc cstack
    cstack = getattribute self, '@!cstack'
    dec cptr
    subcur = cstack[cptr]
    # Set the cstack to the size requested by the soon-to-be-top mark frame.
    unless bptr > 0 goto cstack_zero
    $I0 = bptr - 1
    $I0 = bstack[$I0]
    assign cstack, $I0
    goto cstack_done
  cstack_zero:
    assign cstack, 0
  cstack_done:

    # Pop the current mark frame and all above it.
    assign bstack, bptr

  done:
    .return (rep, pos, mark, subcur)
.end


=item !mark_commit(mark)

Like C<!mark_fail> above this backtracks the cursor to C<mark>
(releasing any intermediate marks), but preserves the current 
capture states.

=cut

.sub '!mark_commit' :method
    .param int mark

    # find mark
    .local int rep, pos, mark, bptr, cptr
    .local pmc bstack
    (rep, pos, mark, bptr, bstack) = self.'!mark_peek'(mark)

    # get current cstack size into cptr
    if null bstack goto done
    unless bstack goto done
    $I0 = elements bstack
    dec $I0
    cptr = bstack[$I0]

    # Pop the mark frame and everything above it.
    assign bstack, bptr

    # If we don't need to hold any cstack information, we're done.
    unless cptr > 0 goto done

    # If the top frame is an auto-fail frame, (re)use it to hold
    # our needed cptr, otherwise create a new auto-fail frame to do it.
    unless bptr > 0 goto cstack_push
    $I0 = bptr - 3             # pos is at top-3
    $I1 = bstack[$I0]
    unless $I1 < 0 goto cstack_push
    $I0 = bptr - 1             # cptr is at top-1
    bstack[$I0] = cptr
    goto done
  cstack_push:
    push bstack, 0             # mark
    push bstack, CURSOR_FAIL   # pos
    push bstack, 0             # rep
    push bstack, cptr          # cptr

  done:
    .return (rep, pos, mark)
.end


=item !reduce(name [, key] [, match])

Perform any action associated with the current regex match.

=cut

.sub '!reduce' :method
    .param string name
    .param string key          :optional
    .param int has_key         :opt_flag
    .param pmc match           :optional
    .param int has_match       :opt_flag
    .local pmc action
    action = getattribute self, '$!action'
    if null action goto action_done
    $I0 = can action, name
    unless $I0 goto action_done
    if has_match goto match_done
    match = self.'MATCH'()
  match_done:
    if has_key goto action_key
    action.name(match)
    goto action_done
  action_key:
    .tailcall action.name(match, key)
  action_done:
    .return ()
.end


=item !BACKREF(name)

Match the backreference given by C<name>.

=cut

.sub '!BACKREF' :method
    .param string name
    .local pmc cur
    .local int pos, eos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()

    # search the cursor cstack for the latest occurrence of C<name>
    .local pmc cstack
    cstack = getattribute self, '@!cstack'
    if null cstack goto pass
    .local int cstack_it
    cstack_it = elements cstack
  cstack_loop:
    dec cstack_it
    unless cstack_it >= 0 goto pass
    .local pmc subcur
    subcur = cstack[cstack_it]
    $P0 = getattribute subcur, '$!names'
    if null $P0 goto cstack_loop
    $S0 = $P0
    if name != $S0 goto cstack_loop
    # we found a matching subcursor, get the literal it matched
  cstack_done:
    .local int litlen
    .local string litstr
    $I1 = subcur.'pos'()
    $I0 = subcur.'from'()
    litlen = $I1 - $I0
    litstr = substr tgt, $I0, litlen
    # now test the literal against our target
    $S0 = substr tgt, pos, litlen
    unless $S0 == litstr goto fail
    pos += litlen
  pass:
    cur.'!cursor_pass'(pos, '')
  fail:
    .return (cur)
.end


=back

=head2 Vtable functions

=over 4

=item get_bool

=cut

.sub '' :vtable('get_bool') :method
    .local pmc match
    match = getattribute self, '$!match'
    if null match goto false
    $I0 = istrue match
    .return ($I0)
  false:
    .return (0)
.end


=head1 AUTHORS

Patrick Michaud <pmichaud@pobox.com> is the author and maintainer.

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
### .include 'src/Regex/Cursor-builtins.pir'
# Copyright (C) 2009, Patrick R. Michaud
# $Id$

=head1 NAME

Regex::Cursor-builtins - builtin regexes for Cursor objects

=cut

.include 'cclass.pasm'

.namespace ['Regex';'Cursor']

.sub 'before' :method
    .param pmc regex           :optional
    .local pmc cur
    .local int pos
    (cur, pos) = self.'!cursor_start'()
    if null regex goto fail
    $P0 = cur.regex()
    unless $P0 goto fail
    cur.'!cursor_pass'(pos, 'before')
  fail:
    .return (cur)
.end


.sub 'ident' :method
    .local pmc cur
    .local int pos, eos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    eos = length tgt
    $S0 = substr tgt, pos, 1
    if $S0 == '_' goto ident_1
    $I0 = is_cclass .CCLASS_ALPHABETIC, tgt, pos
    unless $I0 goto fail
  ident_1:
    pos = find_not_cclass .CCLASS_WORD, tgt, pos, eos
    cur.'!cursor_pass'(pos, 'ident')
  fail:
    .return (cur)
.end

.sub 'wb' :method
    .local pmc cur
    .local int pos, eos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    if pos == 0 goto pass
    eos = length tgt
    if pos == eos goto pass
    $I0 = pos - 1
    $I1 = is_cclass .CCLASS_WORD, tgt, $I0
    $I2 = is_cclass .CCLASS_WORD, tgt, pos
    if $I1 == $I2 goto fail
  pass:
    cur.'!cursor_pass'(pos, 'wb')
  fail:
    .return (cur)
.end

.sub 'ww' :method
    .local pmc cur
    .local int pos, eos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    if pos == 0 goto fail
    eos = length tgt
    if pos == eos goto fail
    $I0 = is_cclass .CCLASS_WORD, tgt, pos
    unless $I0 goto fail
    $I1 = pos - 1
    $I0 = is_cclass .CCLASS_WORD, tgt, $I1
    unless $I0 goto fail
  pass:
    cur.'!cursor_pass'(pos, 'ww')
  fail:
    .return (cur)
.end

.sub 'ws' :method
    .local pmc cur
    .local int pos, eos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    eos = length tgt
    if pos >= eos goto pass
    if pos == 0 goto ws_scan
    $I0 = is_cclass .CCLASS_WORD, tgt, pos
    unless $I0 goto ws_scan
    $I1 = pos - 1
    $I0 = is_cclass .CCLASS_WORD, tgt, $I1
    if $I0 goto fail
  ws_scan:
    pos = find_not_cclass .CCLASS_WHITESPACE, tgt, pos, eos
  pass:
    cur.'!cursor_pass'(pos, 'ws')
  fail:
    .return (cur)
.end

.sub '!cclass' :anon
    .param pmc self
    .param string name
    .param int cclass
    .local pmc cur
    .local int pos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    $I0 = is_cclass cclass, tgt, pos
    unless $I0 goto fail
    inc pos
    cur.'!cursor_pass'(pos, name)
  fail:
    .return (cur)
.end

.sub 'alpha' :method
    .local pmc cur
    .local int pos
    .local string tgt
    (cur, pos, tgt) = self.'!cursor_start'()
    $I0 = is_cclass .CCLASS_ALPHABETIC, tgt, pos
    if $I0 goto pass
    $S0 = substr tgt, pos, 1
    if $S0 != '_' goto fail
  pass:
    inc pos
    cur.'!cursor_pass'(pos, 'alpha')
  fail:
    .return (cur)
.end

.sub 'upper' :method
    .tailcall '!cclass'(self, 'upper', .CCLASS_UPPERCASE)
.end
    
.sub 'lower' :method
    .tailcall '!cclass'(self, 'lower', .CCLASS_LOWERCASE)
.end
    
.sub 'digit' :method
    .tailcall '!cclass'(self, 'digit', .CCLASS_NUMERIC)
.end

.sub 'xdigit' :method
    .tailcall '!cclass'(self, 'xdigit', .CCLASS_HEXADECIMAL)
.end

.sub 'print' :method
    .tailcall '!cclass'(self, 'print', .CCLASS_PRINTING)
.end

.sub 'graph' :method
    .tailcall '!cclass'(self, 'graph', .CCLASS_GRAPHICAL)
.end

.sub 'cntrl' :method
    .tailcall '!cclass'(self, 'cntrl', .CCLASS_CONTROL)
.end
    
.sub 'punct' :method
    .tailcall '!cclass'(self, 'punct', .CCLASS_PUNCTUATION)
.end

.sub 'alnum' :method
    .tailcall '!cclass'(self, 'alnum', .CCLASS_ALPHANUMERIC)
.end

.sub 'space' :method
    .tailcall '!cclass'(self, 'space', .CCLASS_WHITESPACE)
.end

.sub 'blank' :method
    .tailcall '!cclass'(self, 'blank', .CCLASS_BLANK)
.end

    
=head1 AUTHORS

Patrick Michaud <pmichaud@pobox.com> is the author and maintainer.

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
### .include 'src/Regex/Match.pir'
# Copyright (C) 2009, Patrick R. Michaud
# $Id$

=head1 NAME

Regex::Match - Regex Match objects

=head1 DESCRIPTION

This file implements Match objects for the regex engine.

=cut

.namespace ['Regex';'Match']

.sub '' :anon :load :init
    load_bytecode 'P6object.pbc'
    .local pmc p6meta
    p6meta = new 'P6metaclass'
    $P0 = p6meta.'new_class'('Regex::Match', 'parent'=>'Capture', 'attr'=>'$!target $!from $!to $!ast')
    .return ()
.end

=head2 Methods

=over 4

=item from()

Returns the offset in the target string of the beginning of the match.

=cut

.sub 'from' :method
    $P0 = getattribute self, '$!from'
    .return ($P0)
.end


=item to()

Returns the offset in the target string of the end of the match.

=cut

.sub 'to' :method
    $P0 = getattribute self, '$!to'
    .return ($P0)
.end


=item chars()

Returns C<.to() - .from()>

=cut

.sub 'chars' :method
    $I0 = self.'to'()
    $I1 = self.'from'()
    $I2 = $I0 - $I1
    .return ($I2)
.end


=item orig()

Return the original item that was matched against.

=cut

.sub 'orig' :method
    $P0 = getattribute self, '$!target'
    .return ($P0)
.end


=item Str()

Returns the portion of the target corresponding to this match.

=cut

.sub 'Str' :method
    $S0 = self.'orig'()
    $I0 = self.'from'()
    $I1 = self.'to'()
    $I1 -= $I0
    $S1 = substr $S0, $I0, $I1
    .return ($S1)
.end


=item ast()

Returns the "abstract object" for the Match; if no abstract object
has been set then returns C<Str> above.

=cut

.sub 'ast' :method
    .local pmc ast
    ast = getattribute self, '$!ast'
    if null ast goto ret_null
    .return (ast)
  ret_null:
    .tailcall self.'Str'()
.end


=back

=head2 Vtable functions

=over 4

=item get_bool()

Returns 1 (true) if this is the result of a successful match,
otherwise returns 0 (false).

=cut

.sub '' :vtable('get_bool') :method
    $P0 = getattribute self, '$!from'
    $P1 = getattribute self, '$!to'
    $I0 = isge $P1, $P0
    .return ($I0)
.end


=item get_integer()

Returns the integer value of the matched text.

=cut

.sub '' :vtable('get_integer') :method
    $I0 = self.'Str'()
    .return ($I0)
.end


=item get_number()

Returns the numeric value of this match

=cut

.sub '' :vtable('get_number') :method
    $N0 = self.'Str'()
    .return ($N0)
.end


=item get_string()

Returns the string value of the match

=cut

.sub '' :vtable('get_string') :method
    $S0 = self.'Str'()
    .return ($S0)
.end
    

=item !make(obj)

Set the "ast object" for the invocant.

=cut

.sub '!make' :method
    .param pmc obj
    setattribute self, '$!ast', obj
    .return (obj)
.end
    

=back

=head1 AUTHORS

Patrick Michaud <pmichaud@pobox.com> is the author and maintainer.

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
### .include 'src/Regex/Dumper.pir'
# Copyright (C) 2005-2009, Parrot Foundation.
# $Id$

=head1 TITLE

Regex::Dumper - various methods for displaying Match structures

=head2 C<Regex::Match> Methods

=over 4

=item C<__dump(PMC dumper, STR label)>

This method enables Data::Dumper to work on Regex::Match objects.

=cut

.namespace ['Regex';'Match']

.sub "__dump" :method
    .param pmc dumper
    .param string label
    .local string indent, subindent
    .local pmc it, val
    .local string key
    .local pmc hash, array
    .local int hascapts

    (subindent, indent) = dumper."newIndent"()
    print "=> "
    $S0 = self
    dumper."genericString"("", $S0)
    print " @ "
    $I0 = self.'from'()
    print $I0
    hascapts = 0
    hash = self.'hash'()
    if_null hash, dump_array
    it = iter hash
  dump_hash_1:
    unless it goto dump_array
    if hascapts goto dump_hash_2
    print " {"
    hascapts = 1
  dump_hash_2:
    print "\n"
    print subindent
    key = shift it
    val = hash[key]
    print "<"
    print key
    print "> => "
    dumper."dump"(label, val)
    goto dump_hash_1
  dump_array:
    array = self.'list'()
    if_null array, dump_end
    $I1 = elements array
    $I0 = 0
  dump_array_1:
    if $I0 >= $I1 goto dump_end
    if hascapts goto dump_array_2
    print " {"
    hascapts = 1
  dump_array_2:
    print "\n"
    print subindent
    val = array[$I0]
    print "["
    print $I0
    print "] => "
    dumper."dump"(label, val)
    inc $I0
    goto dump_array_1
  dump_end:
    unless hascapts goto end
    print "\n"
    print indent
    print "}"
  end:
    dumper."deleteIndent"()
.end


=item C<dump_str()>

An alternate dump output for a Match object and all of its subcaptures.

=cut

.sub "dump_str" :method
    .param string prefix       :optional           # name of match variable
    .param int has_prefix      :opt_flag
    .param string b1           :optional           # bracket open
    .param int has_b1          :opt_flag
    .param string b2           :optional           # bracket close
    .param int has_b2          :opt_flag

    .local pmc capt
    .local int spi, spc
    .local pmc it
    .local string prefix1, prefix2
    .local pmc jmpstack
    jmpstack = new 'ResizableIntegerArray'

    if has_b2 goto start
    b2 = "]"
    if has_b1 goto start
    b1 = "["
  start:
    .local string out
    out = concat prefix, ':'
    unless self goto subpats
    out .= ' <'
    $S0 = self
    out .= $S0
    out .= ' @ '
    $S0 = self.'from'()
    out .= $S0
    out .= '> '

  subpats:
    $I0 = self
    $S0 = $I0
    out .= $S0
    out .= "\n"
    capt = self.'list'()
    if_null capt, subrules
    spi = 0
    spc = elements capt
  subpats_1:
    unless spi < spc goto subrules
    prefix1 = concat prefix, b1
    $S0 = spi
    concat prefix1, $S0
    concat prefix1, b2
    $I0 = defined capt[spi]
    unless $I0 goto subpats_2
    $P0 = capt[spi]
    local_branch jmpstack, dumper
  subpats_2:
    inc spi
    goto subpats_1

  subrules:
    capt = self.'hash'()
    if_null capt, end
    it = iter capt
  subrules_1:
    unless it goto end
    $S0 = shift it
    prefix1 = concat prefix, '<'
    concat prefix1, $S0
    concat prefix1, ">"
    $I0 = defined capt[$S0]
    unless $I0 goto subrules_1
    $P0 = capt[$S0]
    local_branch jmpstack, dumper
    goto subrules_1

  dumper:
    $I0 = isa $P0, ['Regex';'Match']
    unless $I0 goto dumper_0
    $S0 = $P0.'dump_str'(prefix1, b1, b2)
    out .= $S0
    local_return jmpstack
  dumper_0:
    $I0 = does $P0, 'array'
    unless $I0 goto dumper_3
    $I0 = 0
    $I1 = elements $P0
  dumper_1:
    if $I0 >= $I1 goto dumper_2
    $P1 = $P0[$I0]
    prefix2 = concat prefix1, b1
    $S0 = $I0
    concat prefix2, $S0
    concat prefix2, b2
    $S0 = $P1.'dump_str'(prefix2, b1, b2)
    out .= $S0
    inc $I0
    goto dumper_1
  dumper_2:
    local_return jmpstack
  dumper_3:
    out .= prefix1
    out .= ': '
    $S0 = $P0
    out .= $S0
    out .= "\n"
    local_return jmpstack

  end:
    .return (out)
.end


=back

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
### .include 'src/cheats/regex-cursor-protoregex.pir'
# Copyright (C) 2009, Patrick R. Michaud

=head1 NAME

regex-cursor-protoregex.pir - naive protoregex implementation

=head1 DESCRIPTION

=over 4

=item !protoregex()

This method adds rudimentary protoregex support to Regex::Cursor.  It doesn't
do longest token matching correctly; instead it tries regexes
in reverse order of longest regex name.

=cut

.namespace ['Regex';'Cursor']

.sub '!protoregex' :method
    .param string name

    .local pmc generation
    generation = get_global '$!generation'

    .local pmc parrotclass, prototable
    parrotclass = typeof self
    prototable = getprop '%!prototable', parrotclass
    if null prototable goto make_prototable
    $P0 = getprop '$!generation', prototable
    $I0 = issame $P0, generation
    if $I0 goto have_prototable
  make_prototable:
    prototable = self.'!protoregex_gen_table'(parrotclass)
  have_prototable:

    .local pmc tokrx, toklen
    $S0 = concat name, '.tokrx'
    tokrx = prototable[$S0]
    $S0 = concat name, '.toklen'
    toklen = prototable[$S0]
    unless null tokrx goto have_tokrx
    (tokrx, toklen) = self.'!protoregex_gen_tokrx'(prototable, name)
  have_tokrx:

    unless tokrx goto token_fail

    .local pmc tokrx_it
    tokrx_it = iter tokrx
  token_loop:
    unless tokrx_it goto token_done
    .local pmc rx, cur
    rx = shift tokrx_it
    cur = self.rx()
    if cur goto token_done
    goto token_loop
  token_done:
    .return (cur)

  token_fail:
    .return (0)
.end


=item !protoregex_generation()

Set the C<$!generation> flag to indicate that protoregexes need to
be recalculated.

=cut

.sub '!protoregex_generation' :method
    $P0 = get_global '$!generation'
    # don't change this to 'inc' -- we want to ensure new PMC
    $P1 = add $P0, 1
    set_global '$!generation', $P1
    .return ($P1)
.end

=item !protoregex_gen_table(parrotclass)

Generate a new protoregex table for C<parrotclass>.  This involves
creating a hash keyed with method names containing ':sym<' from
C<parrotclass> and all of its superclasses.  This new hash is
then given the current C<$!generate> property so we can avoid
recreating it.

The categorization of the protoregex candidate lists
for individual protoregexes is handled (lazily) by
C<!protoregex_gen_tokrx> below.

=cut

.sub '!protoregex_gen_table' :method
    .param pmc parrotclass

    .local pmc prototable
    prototable = new ['Hash']
    .local pmc class_it, method_it
    $P0 = parrotclass.'inspect'('all_parents')
    class_it = iter $P0
  class_loop:
    unless class_it goto class_done
    $P0 = shift class_it
    $P0 = $P0.'methods'()
    method_it = iter $P0
  method_loop:
    unless method_it goto class_loop
    $S0 = shift method_it
    $I0 = index $S0, ':sym<'
    if $I0 < 0 goto method_loop
    prototable[$S0] = prototable
    goto method_loop
  class_done:
    $P0 = get_global '$!generation'
    setprop prototable, '$!generation', $P0
    setprop parrotclass, '%!prototable', prototable
    .return (prototable)
.end

=item !protoregex_gen_tokrx(prototable, name)

Generate this class' token list in prototable for the protoregex
called C<name>.

=cut

.sub '!protoregex_gen_tokrx' :method
    .param pmc prototable
    .param string name

    .local pmc toklen, tokrx
    null toklen
    tokrx  = new ['ResizablePMCArray']

    # The prototable has already collected all of the names of
    # protoregex methods into C<prototable>.  We set up a loop
    # to find all of the method names that begin with "name:sym<".
    .local string mprefix
    .local int mlen
    mprefix = concat name, ':sym<'
    mlen   = length mprefix

    .local pmc method_it, method
    .local string method_name
    method_it = iter prototable
  method_loop:
    unless method_it goto method_done
    method_name = shift method_it
    $S0 = substr method_name, 0, mlen
    if $S0 != mprefix goto method_loop

    # Okay, we've found a method name intended for this protoregex,
    # add it to our list.
    .local pmc rx
    rx = find_method self, method_name
    push tokrx, rx
    goto method_loop
  method_done:


    # Now sort the methods by name, longest first.
    .const 'Sub' $P99 = '!protoregex_cmp'
    tokrx.'sort'($P99)

    # say name
    # $P0 = iter tokrx
  # say_loop:
    # unless $P0 goto say_done
    # $P1 = shift $P0
    # say $P1
    # goto say_loop
  # say_done:

    # It's built!  Now store the tokrx table where we can find it
    # again later without having to rebuild it.
    $S0 = concat name, '.tokrx'
    prototable[$S0] = tokrx
    .return (tokrx, toklen)
.end


.sub '!protoregex_cmp' :anon
    .param pmc a
    .param pmc b
    $S0 = a
    $I0 = length $S0
    $S1 = b
    $I1 = length $S1
    $I2 = cmp $I1, $I0
    .return ($I2)
.end

=back

=cut

### .include 'src/gen/p6regex-grammar.pir'

.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block11"  :subid("10_1256021810.94784")
.annotate "line", 0
    .const 'Sub' $P308 = "84_1256021810.94784" 
    capture_lex $P308
    .const 'Sub' $P303 = "83_1256021810.94784" 
    capture_lex $P303
    .const 'Sub' $P298 = "82_1256021810.94784" 
    capture_lex $P298
    .const 'Sub' $P283 = "79_1256021810.94784" 
    capture_lex $P283
    .const 'Sub' $P251 = "74_1256021810.94784" 
    capture_lex $P251
    .const 'Sub' $P242 = "72_1256021810.94784" 
    capture_lex $P242
    .const 'Sub' $P232 = "70_1256021810.94784" 
    capture_lex $P232
    .const 'Sub' $P230 = "69_1256021810.94784" 
    capture_lex $P230
    .const 'Sub' $P223 = "67_1256021810.94784" 
    capture_lex $P223
    .const 'Sub' $P216 = "65_1256021810.94784" 
    capture_lex $P216
    .const 'Sub' $P212 = "63_1256021810.94784" 
    capture_lex $P212
    .const 'Sub' $P210 = "62_1256021810.94784" 
    capture_lex $P210
    .const 'Sub' $P208 = "61_1256021810.94784" 
    capture_lex $P208
    .const 'Sub' $P206 = "60_1256021810.94784" 
    capture_lex $P206
    .const 'Sub' $P204 = "59_1256021810.94784" 
    capture_lex $P204
    .const 'Sub' $P201 = "58_1256021810.94784" 
    capture_lex $P201
    .const 'Sub' $P198 = "57_1256021810.94784" 
    capture_lex $P198
    .const 'Sub' $P195 = "56_1256021810.94784" 
    capture_lex $P195
    .const 'Sub' $P192 = "55_1256021810.94784" 
    capture_lex $P192
    .const 'Sub' $P189 = "54_1256021810.94784" 
    capture_lex $P189
    .const 'Sub' $P186 = "53_1256021810.94784" 
    capture_lex $P186
    .const 'Sub' $P183 = "52_1256021810.94784" 
    capture_lex $P183
    .const 'Sub' $P180 = "51_1256021810.94784" 
    capture_lex $P180
    .const 'Sub' $P169 = "49_1256021810.94784" 
    capture_lex $P169
    .const 'Sub' $P166 = "48_1256021810.94784" 
    capture_lex $P166
    .const 'Sub' $P152 = "47_1256021810.94784" 
    capture_lex $P152
    .const 'Sub' $P150 = "46_1256021810.94784" 
    capture_lex $P150
    .const 'Sub' $P148 = "45_1256021810.94784" 
    capture_lex $P148
    .const 'Sub' $P144 = "44_1256021810.94784" 
    capture_lex $P144
    .const 'Sub' $P140 = "43_1256021810.94784" 
    capture_lex $P140
    .const 'Sub' $P137 = "42_1256021810.94784" 
    capture_lex $P137
    .const 'Sub' $P134 = "41_1256021810.94784" 
    capture_lex $P134
    .const 'Sub' $P131 = "40_1256021810.94784" 
    capture_lex $P131
    .const 'Sub' $P128 = "39_1256021810.94784" 
    capture_lex $P128
    .const 'Sub' $P125 = "38_1256021810.94784" 
    capture_lex $P125
    .const 'Sub' $P122 = "37_1256021810.94784" 
    capture_lex $P122
    .const 'Sub' $P119 = "36_1256021810.94784" 
    capture_lex $P119
    .const 'Sub' $P117 = "35_1256021810.94784" 
    capture_lex $P117
    .const 'Sub' $P115 = "34_1256021810.94784" 
    capture_lex $P115
    .const 'Sub' $P113 = "33_1256021810.94784" 
    capture_lex $P113
    .const 'Sub' $P111 = "32_1256021810.94784" 
    capture_lex $P111
    .const 'Sub' $P100 = "29_1256021810.94784" 
    capture_lex $P100
    .const 'Sub' $P91 = "28_1256021810.94784" 
    capture_lex $P91
    .const 'Sub' $P88 = "27_1256021810.94784" 
    capture_lex $P88
    .const 'Sub' $P85 = "26_1256021810.94784" 
    capture_lex $P85
    .const 'Sub' $P82 = "25_1256021810.94784" 
    capture_lex $P82
    .const 'Sub' $P69 = "22_1256021810.94784" 
    capture_lex $P69
    .const 'Sub' $P60 = "20_1256021810.94784" 
    capture_lex $P60
    .const 'Sub' $P56 = "19_1256021810.94784" 
    capture_lex $P56
    .const 'Sub' $P47 = "18_1256021810.94784" 
    capture_lex $P47
    .const 'Sub' $P44 = "17_1256021810.94784" 
    capture_lex $P44
    .const 'Sub' $P34 = "16_1256021810.94784" 
    capture_lex $P34
    .const 'Sub' $P30 = "15_1256021810.94784" 
    capture_lex $P30
    .const 'Sub' $P25 = "14_1256021810.94784" 
    capture_lex $P25
    .const 'Sub' $P18 = "12_1256021810.94784" 
    capture_lex $P18
    .const 'Sub' $P13 = "11_1256021810.94784" 
    capture_lex $P13
.annotate "line", 158
    .const 'Sub' $P308 = "84_1256021810.94784" 
    capture_lex $P308
.annotate "line", 1
    .return ($P308)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "" :load :init :subid("post85") :outer("10_1256021810.94784")
.annotate "line", 0
    get_hll_global $P12, ["Regex";"P6Regex";"Grammar"], "_block11" 
    .local pmc block
    set block, $P12
.annotate "line", 1
    get_hll_global $P313, "P6metaclass"
    $P313."new_class"("Regex::P6Regex::Grammar", "Regex::Cursor" :named("parent"))
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "ws"  :subid("11_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 3
    .local string rx14_tgt
    .local int rx14_pos
    .local int rx14_off
    .local int rx14_eos
    .local int rx14_rep
    .local pmc rx14_cur
    (rx14_cur, rx14_pos, rx14_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx14_cur
    length rx14_eos, rx14_tgt
    set rx14_off, 0
    lt $I10, 2, rx14_start
    sub rx14_off, $I10, 1
    substr rx14_tgt, rx14_tgt, rx14_off
  rx14_start:
  # rx rxquantr15 ** 0..*
    set_addr $I17, rxquantr15_done
    rx14_cur."!mark_push"(0, rx14_pos, $I17)
  rxquantr15_loop:
  alt16_0:
    set_addr $I10, alt16_1
    rx14_cur."!mark_push"(0, rx14_pos, $I10)
  # rx charclass_q s r 1..-1
    sub $I10, rx14_pos, rx14_off
    find_not_cclass $I11, 32, rx14_tgt, $I10, rx14_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx14_fail
    add rx14_pos, rx14_off, $I11
    goto alt16_end
  alt16_1:
  # rx literal  "#"
    add $I11, rx14_pos, 1
    gt $I11, rx14_eos, rx14_fail
    sub $I11, rx14_pos, rx14_off
    substr $S10, rx14_tgt, $I11, 1
    ne $S10, "#", rx14_fail
    add rx14_pos, 1
  # rx charclass_q N r 0..-1
    sub $I10, rx14_pos, rx14_off
    find_cclass $I11, 4096, rx14_tgt, $I10, rx14_eos
    add rx14_pos, rx14_off, $I11
  alt16_end:
    (rx14_rep) = rx14_cur."!mark_commit"($I17)
    rx14_cur."!mark_push"(rx14_rep, rx14_pos, $I17)
    goto rxquantr15_loop
  rxquantr15_done:
  # rx pass
    rx14_cur."!cursor_pass"(rx14_pos, "ws")
    .return (rx14_cur)
  rx14_fail:
    (rx14_rep, rx14_pos, $I10, $P10) = rx14_cur."!mark_fail"(0)
    lt rx14_pos, -1, rx14_done
    eq rx14_pos, -1, rx14_fail
    jump $I10
  rx14_done:
    rx14_cur."!cursor_fail"()
    .return (rx14_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "normspace"  :subid("12_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 5
    .const 'Sub' $P21 = "13_1256021810.94784" 
    capture_lex $P21
    .local string rx19_tgt
    .local int rx19_pos
    .local int rx19_off
    .local int rx19_eos
    .local int rx19_rep
    .local pmc rx19_cur
    (rx19_cur, rx19_pos, rx19_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx19_cur
    length rx19_eos, rx19_tgt
    set rx19_off, 0
    lt $I10, 2, rx19_start
    sub rx19_off, $I10, 1
    substr rx19_tgt, rx19_tgt, rx19_off
  rx19_start:
  # rx subrule "before" subtype=zerowidth negate=
    rx19_cur."!cursor_pos"(rx19_pos)
    .const 'Sub' $P21 = "13_1256021810.94784" 
    capture_lex $P21
    $P10 = rx19_cur."before"($P21)
    unless $P10, rx19_fail
  # rx subrule "ws" subtype=method negate=
    rx19_cur."!cursor_pos"(rx19_pos)
    $P10 = rx19_cur."ws"()
    unless $P10, rx19_fail
    rx19_pos = $P10."pos"()
  # rx pass
    rx19_cur."!cursor_pass"(rx19_pos, "normspace")
    .return (rx19_cur)
  rx19_fail:
    (rx19_rep, rx19_pos, $I10, $P10) = rx19_cur."!mark_fail"(0)
    lt rx19_pos, -1, rx19_done
    eq rx19_pos, -1, rx19_fail
    jump $I10
  rx19_done:
    rx19_cur."!cursor_fail"()
    .return (rx19_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block20"  :anon :subid("13_1256021810.94784") :method :outer("12_1256021810.94784")
.annotate "line", 5
    .local string rx22_tgt
    .local int rx22_pos
    .local int rx22_off
    .local int rx22_eos
    .local int rx22_rep
    .local pmc rx22_cur
    (rx22_cur, rx22_pos, rx22_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx22_cur
    length rx22_eos, rx22_tgt
    set rx22_off, 0
    lt $I10, 2, rx22_start
    sub rx22_off, $I10, 1
    substr rx22_tgt, rx22_tgt, rx22_off
  rx22_start:
    ge rx22_pos, 0, rxscan23_done
  rxscan23_loop:
    ($P10) = rx22_cur."from"()
    inc $P10
    set rx22_pos, $P10
    ge rx22_pos, rx22_eos, rxscan23_done
    set_addr $I10, rxscan23_loop
    rx22_cur."!mark_push"(0, rx22_pos, $I10)
  rxscan23_done:
  alt24_0:
    set_addr $I10, alt24_1
    rx22_cur."!mark_push"(0, rx22_pos, $I10)
  # rx charclass s
    ge rx22_pos, rx22_eos, rx22_fail
    sub $I10, rx22_pos, rx22_off
    is_cclass $I11, 32, rx22_tgt, $I10
    unless $I11, rx22_fail
    inc rx22_pos
    goto alt24_end
  alt24_1:
  # rx literal  "#"
    add $I11, rx22_pos, 1
    gt $I11, rx22_eos, rx22_fail
    sub $I11, rx22_pos, rx22_off
    substr $S10, rx22_tgt, $I11, 1
    ne $S10, "#", rx22_fail
    add rx22_pos, 1
  alt24_end:
  # rx pass
    rx22_cur."!cursor_pass"(rx22_pos, "")
    .return (rx22_cur)
  rx22_fail:
    (rx22_rep, rx22_pos, $I10, $P10) = rx22_cur."!mark_fail"(0)
    lt rx22_pos, -1, rx22_done
    eq rx22_pos, -1, rx22_fail
    jump $I10
  rx22_done:
    rx22_cur."!cursor_fail"()
    .return (rx22_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quote"  :subid("14_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 7
    .local string rx26_tgt
    .local int rx26_pos
    .local int rx26_off
    .local int rx26_eos
    .local int rx26_rep
    .local pmc rx26_cur
    (rx26_cur, rx26_pos, rx26_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx26_cur
    length rx26_eos, rx26_tgt
    set rx26_off, 0
    lt $I10, 2, rx26_start
    sub rx26_off, $I10, 1
    substr rx26_tgt, rx26_tgt, rx26_off
  rx26_start:
  # rx literal  "'"
    add $I11, rx26_pos, 1
    gt $I11, rx26_eos, rx26_fail
    sub $I11, rx26_pos, rx26_off
    substr $S10, rx26_tgt, $I11, 1
    ne $S10, "'", rx26_fail
    add rx26_pos, 1
  # rx subcapture "val"
    set_addr $I10, rxcap_29_fail
    rx26_cur."!mark_push"(0, rx26_pos, $I10)
  # rx rxquantr27 ** 0..*
    set_addr $I28, rxquantr27_done
    rx26_cur."!mark_push"(0, rx26_pos, $I28)
  rxquantr27_loop:
  # rx enumcharlist negate=1 
    ge rx26_pos, rx26_eos, rx26_fail
    sub $I10, rx26_pos, rx26_off
    substr $S10, rx26_tgt, $I10, 1
    index $I11, "'", $S10
    ge $I11, 0, rx26_fail
    inc rx26_pos
    (rx26_rep) = rx26_cur."!mark_commit"($I28)
    rx26_cur."!mark_push"(rx26_rep, rx26_pos, $I28)
    goto rxquantr27_loop
  rxquantr27_done:
    set_addr $I10, rxcap_29_fail
    ($I12, $I11) = rx26_cur."!mark_peek"($I10)
    rx26_cur."!cursor_pos"($I11)
    ($P10) = rx26_cur."!cursor_start"()
    $P10."!cursor_pass"(rx26_pos, "")
    rx26_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("val")
    goto rxcap_29_done
  rxcap_29_fail:
    goto rx26_fail
  rxcap_29_done:
  # rx literal  "'"
    add $I11, rx26_pos, 1
    gt $I11, rx26_eos, rx26_fail
    sub $I11, rx26_pos, rx26_off
    substr $S10, rx26_tgt, $I11, 1
    ne $S10, "'", rx26_fail
    add rx26_pos, 1
  # rx pass
    rx26_cur."!cursor_pass"(rx26_pos, "quote")
    .return (rx26_cur)
  rx26_fail:
    (rx26_rep, rx26_pos, $I10, $P10) = rx26_cur."!mark_fail"(0)
    lt rx26_pos, -1, rx26_done
    eq rx26_pos, -1, rx26_fail
    jump $I10
  rx26_done:
    rx26_cur."!cursor_fail"()
    .return (rx26_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "arg"  :subid("15_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 9
    .local string rx31_tgt
    .local int rx31_pos
    .local int rx31_off
    .local int rx31_eos
    .local int rx31_rep
    .local pmc rx31_cur
    (rx31_cur, rx31_pos, rx31_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx31_cur
    length rx31_eos, rx31_tgt
    set rx31_off, 0
    lt $I10, 2, rx31_start
    sub rx31_off, $I10, 1
    substr rx31_tgt, rx31_tgt, rx31_off
  rx31_start:
  alt32_0:
.annotate "line", 10
    set_addr $I10, alt32_1
    rx31_cur."!mark_push"(0, rx31_pos, $I10)
.annotate "line", 11
  # rx subrule "quote" subtype=capture negate=
    rx31_cur."!cursor_pos"(rx31_pos)
    $P10 = rx31_cur."quote"()
    unless $P10, rx31_fail
    rx31_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("quote")
    rx31_pos = $P10."pos"()
    goto alt32_end
  alt32_1:
.annotate "line", 12
  # rx subcapture "value"
    set_addr $I10, rxcap_33_fail
    rx31_cur."!mark_push"(0, rx31_pos, $I10)
  # rx charclass_q d r 1..-1
    sub $I10, rx31_pos, rx31_off
    find_not_cclass $I11, 8, rx31_tgt, $I10, rx31_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx31_fail
    add rx31_pos, rx31_off, $I11
    set_addr $I10, rxcap_33_fail
    ($I12, $I11) = rx31_cur."!mark_peek"($I10)
    rx31_cur."!cursor_pos"($I11)
    ($P10) = rx31_cur."!cursor_start"()
    $P10."!cursor_pass"(rx31_pos, "")
    rx31_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("value")
    goto rxcap_33_done
  rxcap_33_fail:
    goto rx31_fail
  rxcap_33_done:
  alt32_end:
.annotate "line", 9
  # rx pass
    rx31_cur."!cursor_pass"(rx31_pos, "arg")
    .return (rx31_cur)
  rx31_fail:
    (rx31_rep, rx31_pos, $I10, $P10) = rx31_cur."!mark_fail"(0)
    lt rx31_pos, -1, rx31_done
    eq rx31_pos, -1, rx31_fail
    jump $I10
  rx31_done:
    rx31_cur."!cursor_fail"()
    .return (rx31_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "arglist"  :subid("16_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 16
    .local string rx35_tgt
    .local int rx35_pos
    .local int rx35_off
    .local int rx35_eos
    .local int rx35_rep
    .local pmc rx35_cur
    (rx35_cur, rx35_pos, rx35_tgt, $I10) = self."!cursor_start"()
    rx35_cur."!cursor_caparray"("arg")
    .lex unicode:"$\x{a2}", rx35_cur
    length rx35_eos, rx35_tgt
    set rx35_off, 0
    lt $I10, 2, rx35_start
    sub rx35_off, $I10, 1
    substr rx35_tgt, rx35_tgt, rx35_off
  rx35_start:
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
  # rx subrule "arg" subtype=capture negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."arg"()
    unless $P10, rx35_fail
    rx35_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("arg")
    rx35_pos = $P10."pos"()
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
  # rx rxquantr38 ** 0..*
    set_addr $I42, rxquantr38_done
    rx35_cur."!mark_push"(0, rx35_pos, $I42)
  rxquantr38_loop:
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
  # rx literal  ","
    add $I11, rx35_pos, 1
    gt $I11, rx35_eos, rx35_fail
    sub $I11, rx35_pos, rx35_off
    substr $S10, rx35_tgt, $I11, 1
    ne $S10, ",", rx35_fail
    add rx35_pos, 1
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
  # rx subrule "arg" subtype=capture negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."arg"()
    unless $P10, rx35_fail
    rx35_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("arg")
    rx35_pos = $P10."pos"()
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
    (rx35_rep) = rx35_cur."!mark_commit"($I42)
    rx35_cur."!mark_push"(rx35_rep, rx35_pos, $I42)
    goto rxquantr38_loop
  rxquantr38_done:
  # rx subrule "ws" subtype=method negate=
    rx35_cur."!cursor_pos"(rx35_pos)
    $P10 = rx35_cur."ws"()
    unless $P10, rx35_fail
    rx35_pos = $P10."pos"()
  # rx pass
    rx35_cur."!cursor_pass"(rx35_pos, "arglist")
    .return (rx35_cur)
  rx35_fail:
    (rx35_rep, rx35_pos, $I10, $P10) = rx35_cur."!mark_fail"(0)
    lt rx35_pos, -1, rx35_done
    eq rx35_pos, -1, rx35_fail
    jump $I10
  rx35_done:
    rx35_cur."!cursor_fail"()
    .return (rx35_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "TOP"  :subid("17_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 18
    .local string rx45_tgt
    .local int rx45_pos
    .local int rx45_off
    .local int rx45_eos
    .local int rx45_rep
    .local pmc rx45_cur
    (rx45_cur, rx45_pos, rx45_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx45_cur
    length rx45_eos, rx45_tgt
    set rx45_off, 0
    lt $I10, 2, rx45_start
    sub rx45_off, $I10, 1
    substr rx45_tgt, rx45_tgt, rx45_off
  rx45_start:
.annotate "line", 19
  # rx subrule "nibbler" subtype=capture negate=
    rx45_cur."!cursor_pos"(rx45_pos)
    $P10 = rx45_cur."nibbler"()
    unless $P10, rx45_fail
    rx45_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("nibbler")
    rx45_pos = $P10."pos"()
  alt46_0:
.annotate "line", 20
    set_addr $I10, alt46_1
    rx45_cur."!mark_push"(0, rx45_pos, $I10)
  # rxanchor eos
    ne rx45_pos, rx45_eos, rx45_fail
    goto alt46_end
  alt46_1:
  # rx subrule "panic" subtype=method negate=
    rx45_cur."!cursor_pos"(rx45_pos)
    $P10 = rx45_cur."panic"("Confused")
    unless $P10, rx45_fail
    rx45_pos = $P10."pos"()
  alt46_end:
.annotate "line", 18
  # rx pass
    rx45_cur."!cursor_pass"(rx45_pos, "TOP")
    .return (rx45_cur)
  rx45_fail:
    (rx45_rep, rx45_pos, $I10, $P10) = rx45_cur."!mark_fail"(0)
    lt rx45_pos, -1, rx45_done
    eq rx45_pos, -1, rx45_fail
    jump $I10
  rx45_done:
    rx45_cur."!cursor_fail"()
    .return (rx45_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "nibbler"  :subid("18_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 23
    .local string rx48_tgt
    .local int rx48_pos
    .local int rx48_off
    .local int rx48_eos
    .local int rx48_rep
    .local pmc rx48_cur
    (rx48_cur, rx48_pos, rx48_tgt, $I10) = self."!cursor_start"()
    rx48_cur."!cursor_caparray"("termish")
    .lex unicode:"$\x{a2}", rx48_cur
    length rx48_eos, rx48_tgt
    set rx48_off, 0
    lt $I10, 2, rx48_start
    sub rx48_off, $I10, 1
    substr rx48_tgt, rx48_tgt, rx48_off
  rx48_start:
.annotate "line", 24
  # rx reduce name="nibbler" key="open"
    rx48_cur."!cursor_pos"(rx48_pos)
    rx48_cur."!reduce"("nibbler", "open")
.annotate "line", 25
  # rx rxquantr49 ** 0..1
    set_addr $I51, rxquantr49_done
    rx48_cur."!mark_push"(0, rx48_pos, $I51)
  rxquantr49_loop:
  # rx subrule "ws" subtype=method negate=
    rx48_cur."!cursor_pos"(rx48_pos)
    $P10 = rx48_cur."ws"()
    unless $P10, rx48_fail
    rx48_pos = $P10."pos"()
  alt50_0:
    set_addr $I10, alt50_1
    rx48_cur."!mark_push"(0, rx48_pos, $I10)
  # rx literal  "||"
    add $I11, rx48_pos, 2
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 2
    ne $S10, "||", rx48_fail
    add rx48_pos, 2
    goto alt50_end
  alt50_1:
    set_addr $I10, alt50_2
    rx48_cur."!mark_push"(0, rx48_pos, $I10)
  # rx literal  "|"
    add $I11, rx48_pos, 1
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 1
    ne $S10, "|", rx48_fail
    add rx48_pos, 1
    goto alt50_end
  alt50_2:
    set_addr $I10, alt50_3
    rx48_cur."!mark_push"(0, rx48_pos, $I10)
  # rx literal  "&&"
    add $I11, rx48_pos, 2
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 2
    ne $S10, "&&", rx48_fail
    add rx48_pos, 2
    goto alt50_end
  alt50_3:
  # rx literal  "&"
    add $I11, rx48_pos, 1
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 1
    ne $S10, "&", rx48_fail
    add rx48_pos, 1
  alt50_end:
    (rx48_rep) = rx48_cur."!mark_commit"($I51)
  rxquantr49_done:
.annotate "line", 26
  # rx subrule "termish" subtype=capture negate=
    rx48_cur."!cursor_pos"(rx48_pos)
    $P10 = rx48_cur."termish"()
    unless $P10, rx48_fail
    rx48_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("termish")
    rx48_pos = $P10."pos"()
.annotate "line", 29
  # rx rxquantr52 ** 0..*
    set_addr $I55, rxquantr52_done
    rx48_cur."!mark_push"(0, rx48_pos, $I55)
  rxquantr52_loop:
  alt53_0:
.annotate "line", 27
    set_addr $I10, alt53_1
    rx48_cur."!mark_push"(0, rx48_pos, $I10)
  # rx literal  "||"
    add $I11, rx48_pos, 2
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 2
    ne $S10, "||", rx48_fail
    add rx48_pos, 2
    goto alt53_end
  alt53_1:
  # rx literal  "|"
    add $I11, rx48_pos, 1
    gt $I11, rx48_eos, rx48_fail
    sub $I11, rx48_pos, rx48_off
    substr $S10, rx48_tgt, $I11, 1
    ne $S10, "|", rx48_fail
    add rx48_pos, 1
  alt53_end:
  alt54_0:
.annotate "line", 28
    set_addr $I10, alt54_1
    rx48_cur."!mark_push"(0, rx48_pos, $I10)
  # rx subrule "termish" subtype=capture negate=
    rx48_cur."!cursor_pos"(rx48_pos)
    $P10 = rx48_cur."termish"()
    unless $P10, rx48_fail
    rx48_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("termish")
    rx48_pos = $P10."pos"()
    goto alt54_end
  alt54_1:
  # rx subrule "panic" subtype=method negate=
    rx48_cur."!cursor_pos"(rx48_pos)
    $P10 = rx48_cur."panic"("Null pattern not allowed")
    unless $P10, rx48_fail
    rx48_pos = $P10."pos"()
  alt54_end:
.annotate "line", 29
    (rx48_rep) = rx48_cur."!mark_commit"($I55)
    rx48_cur."!mark_push"(rx48_rep, rx48_pos, $I55)
    goto rxquantr52_loop
  rxquantr52_done:
.annotate "line", 23
  # rx pass
    rx48_cur."!cursor_pass"(rx48_pos, "nibbler")
    .return (rx48_cur)
  rx48_fail:
    (rx48_rep, rx48_pos, $I10, $P10) = rx48_cur."!mark_fail"(0)
    lt rx48_pos, -1, rx48_done
    eq rx48_pos, -1, rx48_fail
    jump $I10
  rx48_done:
    rx48_cur."!cursor_fail"()
    .return (rx48_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "termish"  :subid("19_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 32
    .local string rx57_tgt
    .local int rx57_pos
    .local int rx57_off
    .local int rx57_eos
    .local int rx57_rep
    .local pmc rx57_cur
    (rx57_cur, rx57_pos, rx57_tgt, $I10) = self."!cursor_start"()
    rx57_cur."!cursor_caparray"("noun")
    .lex unicode:"$\x{a2}", rx57_cur
    length rx57_eos, rx57_tgt
    set rx57_off, 0
    lt $I10, 2, rx57_start
    sub rx57_off, $I10, 1
    substr rx57_tgt, rx57_tgt, rx57_off
  rx57_start:
.annotate "line", 33
  # rx rxquantr58 ** 1..*
    set_addr $I59, rxquantr58_done
    rx57_cur."!mark_push"(0, -1, $I59)
  rxquantr58_loop:
  # rx subrule "quantified_atom" subtype=capture negate=
    rx57_cur."!cursor_pos"(rx57_pos)
    $P10 = rx57_cur."quantified_atom"()
    unless $P10, rx57_fail
    rx57_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("noun")
    rx57_pos = $P10."pos"()
    (rx57_rep) = rx57_cur."!mark_commit"($I59)
    rx57_cur."!mark_push"(rx57_rep, rx57_pos, $I59)
    goto rxquantr58_loop
  rxquantr58_done:
.annotate "line", 32
  # rx pass
    rx57_cur."!cursor_pass"(rx57_pos, "termish")
    .return (rx57_cur)
  rx57_fail:
    (rx57_rep, rx57_pos, $I10, $P10) = rx57_cur."!mark_fail"(0)
    lt rx57_pos, -1, rx57_done
    eq rx57_pos, -1, rx57_fail
    jump $I10
  rx57_done:
    rx57_cur."!cursor_fail"()
    .return (rx57_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantified_atom"  :subid("20_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 36
    .const 'Sub' $P65 = "21_1256021810.94784" 
    capture_lex $P65
    .local string rx61_tgt
    .local int rx61_pos
    .local int rx61_off
    .local int rx61_eos
    .local int rx61_rep
    .local pmc rx61_cur
    (rx61_cur, rx61_pos, rx61_tgt, $I10) = self."!cursor_start"()
    rx61_cur."!cursor_caparray"("quantifier", "backmod")
    .lex unicode:"$\x{a2}", rx61_cur
    length rx61_eos, rx61_tgt
    set rx61_off, 0
    lt $I10, 2, rx61_start
    sub rx61_off, $I10, 1
    substr rx61_tgt, rx61_tgt, rx61_off
  rx61_start:
.annotate "line", 37
  # rx subrule "atom" subtype=capture negate=
    rx61_cur."!cursor_pos"(rx61_pos)
    $P10 = rx61_cur."atom"()
    unless $P10, rx61_fail
    rx61_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("atom")
    rx61_pos = $P10."pos"()
  # rx rxquantr62 ** 0..1
    set_addr $I68, rxquantr62_done
    rx61_cur."!mark_push"(0, rx61_pos, $I68)
  rxquantr62_loop:
  # rx subrule "ws" subtype=method negate=
    rx61_cur."!cursor_pos"(rx61_pos)
    $P10 = rx61_cur."ws"()
    unless $P10, rx61_fail
    rx61_pos = $P10."pos"()
  alt63_0:
    set_addr $I10, alt63_1
    rx61_cur."!mark_push"(0, rx61_pos, $I10)
  # rx subrule "quantifier" subtype=capture negate=
    rx61_cur."!cursor_pos"(rx61_pos)
    $P10 = rx61_cur."quantifier"()
    unless $P10, rx61_fail
    rx61_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("quantifier")
    rx61_pos = $P10."pos"()
    goto alt63_end
  alt63_1:
  # rx subrule "before" subtype=zerowidth negate=
    rx61_cur."!cursor_pos"(rx61_pos)
    .const 'Sub' $P65 = "21_1256021810.94784" 
    capture_lex $P65
    $P10 = rx61_cur."before"($P65)
    unless $P10, rx61_fail
  # rx subrule "backmod" subtype=capture negate=
    rx61_cur."!cursor_pos"(rx61_pos)
    $P10 = rx61_cur."backmod"()
    unless $P10, rx61_fail
    rx61_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backmod")
    rx61_pos = $P10."pos"()
  # rx subrule "alpha" subtype=zerowidth negate=1
    rx61_cur."!cursor_pos"(rx61_pos)
    $P10 = rx61_cur."alpha"()
    if $P10, rx61_fail
  alt63_end:
    (rx61_rep) = rx61_cur."!mark_commit"($I68)
  rxquantr62_done:
.annotate "line", 36
  # rx pass
    rx61_cur."!cursor_pass"(rx61_pos, "quantified_atom")
    .return (rx61_cur)
  rx61_fail:
    (rx61_rep, rx61_pos, $I10, $P10) = rx61_cur."!mark_fail"(0)
    lt rx61_pos, -1, rx61_done
    eq rx61_pos, -1, rx61_fail
    jump $I10
  rx61_done:
    rx61_cur."!cursor_fail"()
    .return (rx61_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block64"  :anon :subid("21_1256021810.94784") :method :outer("20_1256021810.94784")
.annotate "line", 37
    .local string rx66_tgt
    .local int rx66_pos
    .local int rx66_off
    .local int rx66_eos
    .local int rx66_rep
    .local pmc rx66_cur
    (rx66_cur, rx66_pos, rx66_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx66_cur
    length rx66_eos, rx66_tgt
    set rx66_off, 0
    lt $I10, 2, rx66_start
    sub rx66_off, $I10, 1
    substr rx66_tgt, rx66_tgt, rx66_off
  rx66_start:
    ge rx66_pos, 0, rxscan67_done
  rxscan67_loop:
    ($P10) = rx66_cur."from"()
    inc $P10
    set rx66_pos, $P10
    ge rx66_pos, rx66_eos, rxscan67_done
    set_addr $I10, rxscan67_loop
    rx66_cur."!mark_push"(0, rx66_pos, $I10)
  rxscan67_done:
  # rx literal  ":"
    add $I11, rx66_pos, 1
    gt $I11, rx66_eos, rx66_fail
    sub $I11, rx66_pos, rx66_off
    substr $S10, rx66_tgt, $I11, 1
    ne $S10, ":", rx66_fail
    add rx66_pos, 1
  # rx pass
    rx66_cur."!cursor_pass"(rx66_pos, "")
    .return (rx66_cur)
  rx66_fail:
    (rx66_rep, rx66_pos, $I10, $P10) = rx66_cur."!mark_fail"(0)
    lt rx66_pos, -1, rx66_done
    eq rx66_pos, -1, rx66_fail
    jump $I10
  rx66_done:
    rx66_cur."!cursor_fail"()
    .return (rx66_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "atom"  :subid("22_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 40
    .const 'Sub' $P76 = "23_1256021810.94784" 
    capture_lex $P76
    .local string rx70_tgt
    .local int rx70_pos
    .local int rx70_off
    .local int rx70_eos
    .local int rx70_rep
    .local pmc rx70_cur
    (rx70_cur, rx70_pos, rx70_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx70_cur
    length rx70_eos, rx70_tgt
    set rx70_off, 0
    lt $I10, 2, rx70_start
    sub rx70_off, $I10, 1
    substr rx70_tgt, rx70_tgt, rx70_off
  rx70_start:
  alt71_0:
.annotate "line", 42
    set_addr $I10, alt71_1
    rx70_cur."!mark_push"(0, rx70_pos, $I10)
.annotate "line", 43
  # rx charclass w
    ge rx70_pos, rx70_eos, rx70_fail
    sub $I10, rx70_pos, rx70_off
    is_cclass $I11, 8192, rx70_tgt, $I10
    unless $I11, rx70_fail
    inc rx70_pos
  # rx rxquantr72 ** 0..1
    set_addr $I79, rxquantr72_done
    rx70_cur."!mark_push"(0, rx70_pos, $I79)
  rxquantr72_loop:
  # rx rxquantg73 ** 1..*
    set_addr $I74, rxquantg73_done
  rxquantg73_loop:
  # rx charclass w
    ge rx70_pos, rx70_eos, rx70_fail
    sub $I10, rx70_pos, rx70_off
    is_cclass $I11, 8192, rx70_tgt, $I10
    unless $I11, rx70_fail
    inc rx70_pos
    rx70_cur."!mark_push"(rx70_rep, rx70_pos, $I74)
    goto rxquantg73_loop
  rxquantg73_done:
  # rx subrule "before" subtype=zerowidth negate=
    rx70_cur."!cursor_pos"(rx70_pos)
    .const 'Sub' $P76 = "23_1256021810.94784" 
    capture_lex $P76
    $P10 = rx70_cur."before"($P76)
    unless $P10, rx70_fail
    (rx70_rep) = rx70_cur."!mark_commit"($I79)
  rxquantr72_done:
    goto alt71_end
  alt71_1:
.annotate "line", 44
  # rx subrule "metachar" subtype=capture negate=
    rx70_cur."!cursor_pos"(rx70_pos)
    $P10 = rx70_cur."metachar"()
    unless $P10, rx70_fail
    rx70_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("metachar")
    rx70_pos = $P10."pos"()
  alt71_end:
.annotate "line", 40
  # rx pass
    rx70_cur."!cursor_pass"(rx70_pos, "atom")
    .return (rx70_cur)
  rx70_fail:
    (rx70_rep, rx70_pos, $I10, $P10) = rx70_cur."!mark_fail"(0)
    lt rx70_pos, -1, rx70_done
    eq rx70_pos, -1, rx70_fail
    jump $I10
  rx70_done:
    rx70_cur."!cursor_fail"()
    .return (rx70_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block75"  :anon :subid("23_1256021810.94784") :method :outer("22_1256021810.94784")
.annotate "line", 43
    .local string rx77_tgt
    .local int rx77_pos
    .local int rx77_off
    .local int rx77_eos
    .local int rx77_rep
    .local pmc rx77_cur
    (rx77_cur, rx77_pos, rx77_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx77_cur
    length rx77_eos, rx77_tgt
    set rx77_off, 0
    lt $I10, 2, rx77_start
    sub rx77_off, $I10, 1
    substr rx77_tgt, rx77_tgt, rx77_off
  rx77_start:
    ge rx77_pos, 0, rxscan78_done
  rxscan78_loop:
    ($P10) = rx77_cur."from"()
    inc $P10
    set rx77_pos, $P10
    ge rx77_pos, rx77_eos, rxscan78_done
    set_addr $I10, rxscan78_loop
    rx77_cur."!mark_push"(0, rx77_pos, $I10)
  rxscan78_done:
  # rx charclass w
    ge rx77_pos, rx77_eos, rx77_fail
    sub $I10, rx77_pos, rx77_off
    is_cclass $I11, 8192, rx77_tgt, $I10
    unless $I11, rx77_fail
    inc rx77_pos
  # rx pass
    rx77_cur."!cursor_pass"(rx77_pos, "")
    .return (rx77_cur)
  rx77_fail:
    (rx77_rep, rx77_pos, $I10, $P10) = rx77_cur."!mark_fail"(0)
    lt rx77_pos, -1, rx77_done
    eq rx77_pos, -1, rx77_fail
    jump $I10
  rx77_done:
    rx77_cur."!cursor_fail"()
    .return (rx77_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantifier"  :subid("24_1256021810.94784") :method
.annotate "line", 48
    $P81 = self."!protoregex"("quantifier")
    .return ($P81)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantifier:sym<*>"  :subid("25_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 49
    .local string rx83_tgt
    .local int rx83_pos
    .local int rx83_off
    .local int rx83_eos
    .local int rx83_rep
    .local pmc rx83_cur
    (rx83_cur, rx83_pos, rx83_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx83_cur
    length rx83_eos, rx83_tgt
    set rx83_off, 0
    lt $I10, 2, rx83_start
    sub rx83_off, $I10, 1
    substr rx83_tgt, rx83_tgt, rx83_off
  rx83_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_84_fail
    rx83_cur."!mark_push"(0, rx83_pos, $I10)
  # rx literal  "*"
    add $I11, rx83_pos, 1
    gt $I11, rx83_eos, rx83_fail
    sub $I11, rx83_pos, rx83_off
    substr $S10, rx83_tgt, $I11, 1
    ne $S10, "*", rx83_fail
    add rx83_pos, 1
    set_addr $I10, rxcap_84_fail
    ($I12, $I11) = rx83_cur."!mark_peek"($I10)
    rx83_cur."!cursor_pos"($I11)
    ($P10) = rx83_cur."!cursor_start"()
    $P10."!cursor_pass"(rx83_pos, "")
    rx83_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_84_done
  rxcap_84_fail:
    goto rx83_fail
  rxcap_84_done:
  # rx subrule "backmod" subtype=capture negate=
    rx83_cur."!cursor_pos"(rx83_pos)
    $P10 = rx83_cur."backmod"()
    unless $P10, rx83_fail
    rx83_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backmod")
    rx83_pos = $P10."pos"()
  # rx pass
    rx83_cur."!cursor_pass"(rx83_pos, "quantifier:sym<*>")
    .return (rx83_cur)
  rx83_fail:
    (rx83_rep, rx83_pos, $I10, $P10) = rx83_cur."!mark_fail"(0)
    lt rx83_pos, -1, rx83_done
    eq rx83_pos, -1, rx83_fail
    jump $I10
  rx83_done:
    rx83_cur."!cursor_fail"()
    .return (rx83_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantifier:sym<+>"  :subid("26_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 50
    .local string rx86_tgt
    .local int rx86_pos
    .local int rx86_off
    .local int rx86_eos
    .local int rx86_rep
    .local pmc rx86_cur
    (rx86_cur, rx86_pos, rx86_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx86_cur
    length rx86_eos, rx86_tgt
    set rx86_off, 0
    lt $I10, 2, rx86_start
    sub rx86_off, $I10, 1
    substr rx86_tgt, rx86_tgt, rx86_off
  rx86_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_87_fail
    rx86_cur."!mark_push"(0, rx86_pos, $I10)
  # rx literal  "+"
    add $I11, rx86_pos, 1
    gt $I11, rx86_eos, rx86_fail
    sub $I11, rx86_pos, rx86_off
    substr $S10, rx86_tgt, $I11, 1
    ne $S10, "+", rx86_fail
    add rx86_pos, 1
    set_addr $I10, rxcap_87_fail
    ($I12, $I11) = rx86_cur."!mark_peek"($I10)
    rx86_cur."!cursor_pos"($I11)
    ($P10) = rx86_cur."!cursor_start"()
    $P10."!cursor_pass"(rx86_pos, "")
    rx86_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_87_done
  rxcap_87_fail:
    goto rx86_fail
  rxcap_87_done:
  # rx subrule "backmod" subtype=capture negate=
    rx86_cur."!cursor_pos"(rx86_pos)
    $P10 = rx86_cur."backmod"()
    unless $P10, rx86_fail
    rx86_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backmod")
    rx86_pos = $P10."pos"()
  # rx pass
    rx86_cur."!cursor_pass"(rx86_pos, "quantifier:sym<+>")
    .return (rx86_cur)
  rx86_fail:
    (rx86_rep, rx86_pos, $I10, $P10) = rx86_cur."!mark_fail"(0)
    lt rx86_pos, -1, rx86_done
    eq rx86_pos, -1, rx86_fail
    jump $I10
  rx86_done:
    rx86_cur."!cursor_fail"()
    .return (rx86_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantifier:sym<?>"  :subid("27_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 51
    .local string rx89_tgt
    .local int rx89_pos
    .local int rx89_off
    .local int rx89_eos
    .local int rx89_rep
    .local pmc rx89_cur
    (rx89_cur, rx89_pos, rx89_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx89_cur
    length rx89_eos, rx89_tgt
    set rx89_off, 0
    lt $I10, 2, rx89_start
    sub rx89_off, $I10, 1
    substr rx89_tgt, rx89_tgt, rx89_off
  rx89_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_90_fail
    rx89_cur."!mark_push"(0, rx89_pos, $I10)
  # rx literal  "?"
    add $I11, rx89_pos, 1
    gt $I11, rx89_eos, rx89_fail
    sub $I11, rx89_pos, rx89_off
    substr $S10, rx89_tgt, $I11, 1
    ne $S10, "?", rx89_fail
    add rx89_pos, 1
    set_addr $I10, rxcap_90_fail
    ($I12, $I11) = rx89_cur."!mark_peek"($I10)
    rx89_cur."!cursor_pos"($I11)
    ($P10) = rx89_cur."!cursor_start"()
    $P10."!cursor_pass"(rx89_pos, "")
    rx89_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_90_done
  rxcap_90_fail:
    goto rx89_fail
  rxcap_90_done:
  # rx subrule "backmod" subtype=capture negate=
    rx89_cur."!cursor_pos"(rx89_pos)
    $P10 = rx89_cur."backmod"()
    unless $P10, rx89_fail
    rx89_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backmod")
    rx89_pos = $P10."pos"()
  # rx pass
    rx89_cur."!cursor_pass"(rx89_pos, "quantifier:sym<?>")
    .return (rx89_cur)
  rx89_fail:
    (rx89_rep, rx89_pos, $I10, $P10) = rx89_cur."!mark_fail"(0)
    lt rx89_pos, -1, rx89_done
    eq rx89_pos, -1, rx89_fail
    jump $I10
  rx89_done:
    rx89_cur."!cursor_fail"()
    .return (rx89_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "quantifier:sym<**>"  :subid("28_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 52
    .local string rx92_tgt
    .local int rx92_pos
    .local int rx92_off
    .local int rx92_eos
    .local int rx92_rep
    .local pmc rx92_cur
    (rx92_cur, rx92_pos, rx92_tgt, $I10) = self."!cursor_start"()
    rx92_cur."!cursor_caparray"("max")
    .lex unicode:"$\x{a2}", rx92_cur
    length rx92_eos, rx92_tgt
    set rx92_off, 0
    lt $I10, 2, rx92_start
    sub rx92_off, $I10, 1
    substr rx92_tgt, rx92_tgt, rx92_off
  rx92_start:
.annotate "line", 53
  # rx subcapture "sym"
    set_addr $I10, rxcap_93_fail
    rx92_cur."!mark_push"(0, rx92_pos, $I10)
  # rx literal  "**"
    add $I11, rx92_pos, 2
    gt $I11, rx92_eos, rx92_fail
    sub $I11, rx92_pos, rx92_off
    substr $S10, rx92_tgt, $I11, 2
    ne $S10, "**", rx92_fail
    add rx92_pos, 2
    set_addr $I10, rxcap_93_fail
    ($I12, $I11) = rx92_cur."!mark_peek"($I10)
    rx92_cur."!cursor_pos"($I11)
    ($P10) = rx92_cur."!cursor_start"()
    $P10."!cursor_pass"(rx92_pos, "")
    rx92_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_93_done
  rxcap_93_fail:
    goto rx92_fail
  rxcap_93_done:
  # rx charclass_q s r 0..-1
    sub $I10, rx92_pos, rx92_off
    find_not_cclass $I11, 32, rx92_tgt, $I10, rx92_eos
    add rx92_pos, rx92_off, $I11
  # rx subrule "backmod" subtype=capture negate=
    rx92_cur."!cursor_pos"(rx92_pos)
    $P10 = rx92_cur."backmod"()
    unless $P10, rx92_fail
    rx92_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backmod")
    rx92_pos = $P10."pos"()
  # rx charclass_q s r 0..-1
    sub $I10, rx92_pos, rx92_off
    find_not_cclass $I11, 32, rx92_tgt, $I10, rx92_eos
    add rx92_pos, rx92_off, $I11
  alt94_0:
.annotate "line", 54
    set_addr $I10, alt94_1
    rx92_cur."!mark_push"(0, rx92_pos, $I10)
.annotate "line", 55
  # rx subcapture "min"
    set_addr $I10, rxcap_95_fail
    rx92_cur."!mark_push"(0, rx92_pos, $I10)
  # rx charclass_q d r 1..-1
    sub $I10, rx92_pos, rx92_off
    find_not_cclass $I11, 8, rx92_tgt, $I10, rx92_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx92_fail
    add rx92_pos, rx92_off, $I11
    set_addr $I10, rxcap_95_fail
    ($I12, $I11) = rx92_cur."!mark_peek"($I10)
    rx92_cur."!cursor_pos"($I11)
    ($P10) = rx92_cur."!cursor_start"()
    $P10."!cursor_pass"(rx92_pos, "")
    rx92_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("min")
    goto rxcap_95_done
  rxcap_95_fail:
    goto rx92_fail
  rxcap_95_done:
  # rx rxquantr96 ** 0..1
    set_addr $I99, rxquantr96_done
    rx92_cur."!mark_push"(0, rx92_pos, $I99)
  rxquantr96_loop:
  # rx literal  ".."
    add $I11, rx92_pos, 2
    gt $I11, rx92_eos, rx92_fail
    sub $I11, rx92_pos, rx92_off
    substr $S10, rx92_tgt, $I11, 2
    ne $S10, "..", rx92_fail
    add rx92_pos, 2
  # rx subcapture "max"
    set_addr $I10, rxcap_98_fail
    rx92_cur."!mark_push"(0, rx92_pos, $I10)
  alt97_0:
    set_addr $I10, alt97_1
    rx92_cur."!mark_push"(0, rx92_pos, $I10)
  # rx charclass_q d r 1..-1
    sub $I10, rx92_pos, rx92_off
    find_not_cclass $I11, 8, rx92_tgt, $I10, rx92_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx92_fail
    add rx92_pos, rx92_off, $I11
    goto alt97_end
  alt97_1:
  # rx literal  "*"
    add $I11, rx92_pos, 1
    gt $I11, rx92_eos, rx92_fail
    sub $I11, rx92_pos, rx92_off
    substr $S10, rx92_tgt, $I11, 1
    ne $S10, "*", rx92_fail
    add rx92_pos, 1
  alt97_end:
    set_addr $I10, rxcap_98_fail
    ($I12, $I11) = rx92_cur."!mark_peek"($I10)
    rx92_cur."!cursor_pos"($I11)
    ($P10) = rx92_cur."!cursor_start"()
    $P10."!cursor_pass"(rx92_pos, "")
    rx92_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("max")
    goto rxcap_98_done
  rxcap_98_fail:
    goto rx92_fail
  rxcap_98_done:
    (rx92_rep) = rx92_cur."!mark_commit"($I99)
  rxquantr96_done:
    goto alt94_end
  alt94_1:
.annotate "line", 56
  # rx subrule "quantified_atom" subtype=capture negate=
    rx92_cur."!cursor_pos"(rx92_pos)
    $P10 = rx92_cur."quantified_atom"()
    unless $P10, rx92_fail
    rx92_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("quantified_atom")
    rx92_pos = $P10."pos"()
  alt94_end:
.annotate "line", 52
  # rx pass
    rx92_cur."!cursor_pass"(rx92_pos, "quantifier:sym<**>")
    .return (rx92_cur)
  rx92_fail:
    (rx92_rep, rx92_pos, $I10, $P10) = rx92_cur."!mark_fail"(0)
    lt rx92_pos, -1, rx92_done
    eq rx92_pos, -1, rx92_fail
    jump $I10
  rx92_done:
    rx92_cur."!cursor_fail"()
    .return (rx92_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backmod"  :subid("29_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 60
    .const 'Sub' $P106 = "30_1256021810.94784" 
    capture_lex $P106
    .local string rx101_tgt
    .local int rx101_pos
    .local int rx101_off
    .local int rx101_eos
    .local int rx101_rep
    .local pmc rx101_cur
    (rx101_cur, rx101_pos, rx101_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx101_cur
    length rx101_eos, rx101_tgt
    set rx101_off, 0
    lt $I10, 2, rx101_start
    sub rx101_off, $I10, 1
    substr rx101_tgt, rx101_tgt, rx101_off
  rx101_start:
  # rx rxquantr102 ** 0..1
    set_addr $I103, rxquantr102_done
    rx101_cur."!mark_push"(0, rx101_pos, $I103)
  rxquantr102_loop:
  # rx literal  ":"
    add $I11, rx101_pos, 1
    gt $I11, rx101_eos, rx101_fail
    sub $I11, rx101_pos, rx101_off
    substr $S10, rx101_tgt, $I11, 1
    ne $S10, ":", rx101_fail
    add rx101_pos, 1
    (rx101_rep) = rx101_cur."!mark_commit"($I103)
  rxquantr102_done:
  alt104_0:
    set_addr $I10, alt104_1
    rx101_cur."!mark_push"(0, rx101_pos, $I10)
  # rx literal  "?"
    add $I11, rx101_pos, 1
    gt $I11, rx101_eos, rx101_fail
    sub $I11, rx101_pos, rx101_off
    substr $S10, rx101_tgt, $I11, 1
    ne $S10, "?", rx101_fail
    add rx101_pos, 1
    goto alt104_end
  alt104_1:
    set_addr $I10, alt104_2
    rx101_cur."!mark_push"(0, rx101_pos, $I10)
  # rx literal  "!"
    add $I11, rx101_pos, 1
    gt $I11, rx101_eos, rx101_fail
    sub $I11, rx101_pos, rx101_off
    substr $S10, rx101_tgt, $I11, 1
    ne $S10, "!", rx101_fail
    add rx101_pos, 1
    goto alt104_end
  alt104_2:
  # rx subrule "before" subtype=zerowidth negate=1
    rx101_cur."!cursor_pos"(rx101_pos)
    .const 'Sub' $P106 = "30_1256021810.94784" 
    capture_lex $P106
    $P10 = rx101_cur."before"($P106)
    if $P10, rx101_fail
  alt104_end:
  # rx pass
    rx101_cur."!cursor_pass"(rx101_pos, "backmod")
    .return (rx101_cur)
  rx101_fail:
    (rx101_rep, rx101_pos, $I10, $P10) = rx101_cur."!mark_fail"(0)
    lt rx101_pos, -1, rx101_done
    eq rx101_pos, -1, rx101_fail
    jump $I10
  rx101_done:
    rx101_cur."!cursor_fail"()
    .return (rx101_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block105"  :anon :subid("30_1256021810.94784") :method :outer("29_1256021810.94784")
.annotate "line", 60
    .local string rx107_tgt
    .local int rx107_pos
    .local int rx107_off
    .local int rx107_eos
    .local int rx107_rep
    .local pmc rx107_cur
    (rx107_cur, rx107_pos, rx107_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx107_cur
    length rx107_eos, rx107_tgt
    set rx107_off, 0
    lt $I10, 2, rx107_start
    sub rx107_off, $I10, 1
    substr rx107_tgt, rx107_tgt, rx107_off
  rx107_start:
    ge rx107_pos, 0, rxscan108_done
  rxscan108_loop:
    ($P10) = rx107_cur."from"()
    inc $P10
    set rx107_pos, $P10
    ge rx107_pos, rx107_eos, rxscan108_done
    set_addr $I10, rxscan108_loop
    rx107_cur."!mark_push"(0, rx107_pos, $I10)
  rxscan108_done:
  # rx literal  ":"
    add $I11, rx107_pos, 1
    gt $I11, rx107_eos, rx107_fail
    sub $I11, rx107_pos, rx107_off
    substr $S10, rx107_tgt, $I11, 1
    ne $S10, ":", rx107_fail
    add rx107_pos, 1
  # rx pass
    rx107_cur."!cursor_pass"(rx107_pos, "")
    .return (rx107_cur)
  rx107_fail:
    (rx107_rep, rx107_pos, $I10, $P10) = rx107_cur."!mark_fail"(0)
    lt rx107_pos, -1, rx107_done
    eq rx107_pos, -1, rx107_fail
    jump $I10
  rx107_done:
    rx107_cur."!cursor_fail"()
    .return (rx107_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar"  :subid("31_1256021810.94784") :method
.annotate "line", 62
    $P110 = self."!protoregex"("metachar")
    .return ($P110)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<ws>"  :subid("32_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 63
    .local string rx112_tgt
    .local int rx112_pos
    .local int rx112_off
    .local int rx112_eos
    .local int rx112_rep
    .local pmc rx112_cur
    (rx112_cur, rx112_pos, rx112_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx112_cur
    length rx112_eos, rx112_tgt
    set rx112_off, 0
    lt $I10, 2, rx112_start
    sub rx112_off, $I10, 1
    substr rx112_tgt, rx112_tgt, rx112_off
  rx112_start:
  # rx subrule "normspace" subtype=method negate=
    rx112_cur."!cursor_pos"(rx112_pos)
    $P10 = rx112_cur."normspace"()
    unless $P10, rx112_fail
    rx112_pos = $P10."pos"()
  # rx pass
    rx112_cur."!cursor_pass"(rx112_pos, "metachar:sym<ws>")
    .return (rx112_cur)
  rx112_fail:
    (rx112_rep, rx112_pos, $I10, $P10) = rx112_cur."!mark_fail"(0)
    lt rx112_pos, -1, rx112_done
    eq rx112_pos, -1, rx112_fail
    jump $I10
  rx112_done:
    rx112_cur."!cursor_fail"()
    .return (rx112_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<[ ]>"  :subid("33_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 64
    .local string rx114_tgt
    .local int rx114_pos
    .local int rx114_off
    .local int rx114_eos
    .local int rx114_rep
    .local pmc rx114_cur
    (rx114_cur, rx114_pos, rx114_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx114_cur
    length rx114_eos, rx114_tgt
    set rx114_off, 0
    lt $I10, 2, rx114_start
    sub rx114_off, $I10, 1
    substr rx114_tgt, rx114_tgt, rx114_off
  rx114_start:
  # rx literal  "["
    add $I11, rx114_pos, 1
    gt $I11, rx114_eos, rx114_fail
    sub $I11, rx114_pos, rx114_off
    substr $S10, rx114_tgt, $I11, 1
    ne $S10, "[", rx114_fail
    add rx114_pos, 1
  # rx subrule "nibbler" subtype=capture negate=
    rx114_cur."!cursor_pos"(rx114_pos)
    $P10 = rx114_cur."nibbler"()
    unless $P10, rx114_fail
    rx114_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("nibbler")
    rx114_pos = $P10."pos"()
  # rx literal  "]"
    add $I11, rx114_pos, 1
    gt $I11, rx114_eos, rx114_fail
    sub $I11, rx114_pos, rx114_off
    substr $S10, rx114_tgt, $I11, 1
    ne $S10, "]", rx114_fail
    add rx114_pos, 1
  # rx pass
    rx114_cur."!cursor_pass"(rx114_pos, "metachar:sym<[ ]>")
    .return (rx114_cur)
  rx114_fail:
    (rx114_rep, rx114_pos, $I10, $P10) = rx114_cur."!mark_fail"(0)
    lt rx114_pos, -1, rx114_done
    eq rx114_pos, -1, rx114_fail
    jump $I10
  rx114_done:
    rx114_cur."!cursor_fail"()
    .return (rx114_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<( )>"  :subid("34_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 65
    .local string rx116_tgt
    .local int rx116_pos
    .local int rx116_off
    .local int rx116_eos
    .local int rx116_rep
    .local pmc rx116_cur
    (rx116_cur, rx116_pos, rx116_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx116_cur
    length rx116_eos, rx116_tgt
    set rx116_off, 0
    lt $I10, 2, rx116_start
    sub rx116_off, $I10, 1
    substr rx116_tgt, rx116_tgt, rx116_off
  rx116_start:
  # rx literal  "("
    add $I11, rx116_pos, 1
    gt $I11, rx116_eos, rx116_fail
    sub $I11, rx116_pos, rx116_off
    substr $S10, rx116_tgt, $I11, 1
    ne $S10, "(", rx116_fail
    add rx116_pos, 1
  # rx subrule "nibbler" subtype=capture negate=
    rx116_cur."!cursor_pos"(rx116_pos)
    $P10 = rx116_cur."nibbler"()
    unless $P10, rx116_fail
    rx116_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("nibbler")
    rx116_pos = $P10."pos"()
  # rx literal  ")"
    add $I11, rx116_pos, 1
    gt $I11, rx116_eos, rx116_fail
    sub $I11, rx116_pos, rx116_off
    substr $S10, rx116_tgt, $I11, 1
    ne $S10, ")", rx116_fail
    add rx116_pos, 1
  # rx pass
    rx116_cur."!cursor_pass"(rx116_pos, "metachar:sym<( )>")
    .return (rx116_cur)
  rx116_fail:
    (rx116_rep, rx116_pos, $I10, $P10) = rx116_cur."!mark_fail"(0)
    lt rx116_pos, -1, rx116_done
    eq rx116_pos, -1, rx116_fail
    jump $I10
  rx116_done:
    rx116_cur."!cursor_fail"()
    .return (rx116_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<'>"  :subid("35_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 66
    .local string rx118_tgt
    .local int rx118_pos
    .local int rx118_off
    .local int rx118_eos
    .local int rx118_rep
    .local pmc rx118_cur
    (rx118_cur, rx118_pos, rx118_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx118_cur
    length rx118_eos, rx118_tgt
    set rx118_off, 0
    lt $I10, 2, rx118_start
    sub rx118_off, $I10, 1
    substr rx118_tgt, rx118_tgt, rx118_off
  rx118_start:
  # rx subrule "quote" subtype=capture negate=
    rx118_cur."!cursor_pos"(rx118_pos)
    $P10 = rx118_cur."quote"()
    unless $P10, rx118_fail
    rx118_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("quote")
    rx118_pos = $P10."pos"()
  # rx pass
    rx118_cur."!cursor_pass"(rx118_pos, "metachar:sym<'>")
    .return (rx118_cur)
  rx118_fail:
    (rx118_rep, rx118_pos, $I10, $P10) = rx118_cur."!mark_fail"(0)
    lt rx118_pos, -1, rx118_done
    eq rx118_pos, -1, rx118_fail
    jump $I10
  rx118_done:
    rx118_cur."!cursor_fail"()
    .return (rx118_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<.>"  :subid("36_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 67
    .local string rx120_tgt
    .local int rx120_pos
    .local int rx120_off
    .local int rx120_eos
    .local int rx120_rep
    .local pmc rx120_cur
    (rx120_cur, rx120_pos, rx120_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx120_cur
    length rx120_eos, rx120_tgt
    set rx120_off, 0
    lt $I10, 2, rx120_start
    sub rx120_off, $I10, 1
    substr rx120_tgt, rx120_tgt, rx120_off
  rx120_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_121_fail
    rx120_cur."!mark_push"(0, rx120_pos, $I10)
  # rx literal  "."
    add $I11, rx120_pos, 1
    gt $I11, rx120_eos, rx120_fail
    sub $I11, rx120_pos, rx120_off
    substr $S10, rx120_tgt, $I11, 1
    ne $S10, ".", rx120_fail
    add rx120_pos, 1
    set_addr $I10, rxcap_121_fail
    ($I12, $I11) = rx120_cur."!mark_peek"($I10)
    rx120_cur."!cursor_pos"($I11)
    ($P10) = rx120_cur."!cursor_start"()
    $P10."!cursor_pass"(rx120_pos, "")
    rx120_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_121_done
  rxcap_121_fail:
    goto rx120_fail
  rxcap_121_done:
  # rx pass
    rx120_cur."!cursor_pass"(rx120_pos, "metachar:sym<.>")
    .return (rx120_cur)
  rx120_fail:
    (rx120_rep, rx120_pos, $I10, $P10) = rx120_cur."!mark_fail"(0)
    lt rx120_pos, -1, rx120_done
    eq rx120_pos, -1, rx120_fail
    jump $I10
  rx120_done:
    rx120_cur."!cursor_fail"()
    .return (rx120_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<^>"  :subid("37_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 68
    .local string rx123_tgt
    .local int rx123_pos
    .local int rx123_off
    .local int rx123_eos
    .local int rx123_rep
    .local pmc rx123_cur
    (rx123_cur, rx123_pos, rx123_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx123_cur
    length rx123_eos, rx123_tgt
    set rx123_off, 0
    lt $I10, 2, rx123_start
    sub rx123_off, $I10, 1
    substr rx123_tgt, rx123_tgt, rx123_off
  rx123_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_124_fail
    rx123_cur."!mark_push"(0, rx123_pos, $I10)
  # rx literal  "^"
    add $I11, rx123_pos, 1
    gt $I11, rx123_eos, rx123_fail
    sub $I11, rx123_pos, rx123_off
    substr $S10, rx123_tgt, $I11, 1
    ne $S10, "^", rx123_fail
    add rx123_pos, 1
    set_addr $I10, rxcap_124_fail
    ($I12, $I11) = rx123_cur."!mark_peek"($I10)
    rx123_cur."!cursor_pos"($I11)
    ($P10) = rx123_cur."!cursor_start"()
    $P10."!cursor_pass"(rx123_pos, "")
    rx123_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_124_done
  rxcap_124_fail:
    goto rx123_fail
  rxcap_124_done:
  # rx pass
    rx123_cur."!cursor_pass"(rx123_pos, "metachar:sym<^>")
    .return (rx123_cur)
  rx123_fail:
    (rx123_rep, rx123_pos, $I10, $P10) = rx123_cur."!mark_fail"(0)
    lt rx123_pos, -1, rx123_done
    eq rx123_pos, -1, rx123_fail
    jump $I10
  rx123_done:
    rx123_cur."!cursor_fail"()
    .return (rx123_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<^^>"  :subid("38_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 69
    .local string rx126_tgt
    .local int rx126_pos
    .local int rx126_off
    .local int rx126_eos
    .local int rx126_rep
    .local pmc rx126_cur
    (rx126_cur, rx126_pos, rx126_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx126_cur
    length rx126_eos, rx126_tgt
    set rx126_off, 0
    lt $I10, 2, rx126_start
    sub rx126_off, $I10, 1
    substr rx126_tgt, rx126_tgt, rx126_off
  rx126_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_127_fail
    rx126_cur."!mark_push"(0, rx126_pos, $I10)
  # rx literal  "^^"
    add $I11, rx126_pos, 2
    gt $I11, rx126_eos, rx126_fail
    sub $I11, rx126_pos, rx126_off
    substr $S10, rx126_tgt, $I11, 2
    ne $S10, "^^", rx126_fail
    add rx126_pos, 2
    set_addr $I10, rxcap_127_fail
    ($I12, $I11) = rx126_cur."!mark_peek"($I10)
    rx126_cur."!cursor_pos"($I11)
    ($P10) = rx126_cur."!cursor_start"()
    $P10."!cursor_pass"(rx126_pos, "")
    rx126_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_127_done
  rxcap_127_fail:
    goto rx126_fail
  rxcap_127_done:
  # rx pass
    rx126_cur."!cursor_pass"(rx126_pos, "metachar:sym<^^>")
    .return (rx126_cur)
  rx126_fail:
    (rx126_rep, rx126_pos, $I10, $P10) = rx126_cur."!mark_fail"(0)
    lt rx126_pos, -1, rx126_done
    eq rx126_pos, -1, rx126_fail
    jump $I10
  rx126_done:
    rx126_cur."!cursor_fail"()
    .return (rx126_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<$>"  :subid("39_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 70
    .local string rx129_tgt
    .local int rx129_pos
    .local int rx129_off
    .local int rx129_eos
    .local int rx129_rep
    .local pmc rx129_cur
    (rx129_cur, rx129_pos, rx129_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx129_cur
    length rx129_eos, rx129_tgt
    set rx129_off, 0
    lt $I10, 2, rx129_start
    sub rx129_off, $I10, 1
    substr rx129_tgt, rx129_tgt, rx129_off
  rx129_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_130_fail
    rx129_cur."!mark_push"(0, rx129_pos, $I10)
  # rx literal  "$"
    add $I11, rx129_pos, 1
    gt $I11, rx129_eos, rx129_fail
    sub $I11, rx129_pos, rx129_off
    substr $S10, rx129_tgt, $I11, 1
    ne $S10, "$", rx129_fail
    add rx129_pos, 1
    set_addr $I10, rxcap_130_fail
    ($I12, $I11) = rx129_cur."!mark_peek"($I10)
    rx129_cur."!cursor_pos"($I11)
    ($P10) = rx129_cur."!cursor_start"()
    $P10."!cursor_pass"(rx129_pos, "")
    rx129_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_130_done
  rxcap_130_fail:
    goto rx129_fail
  rxcap_130_done:
  # rx pass
    rx129_cur."!cursor_pass"(rx129_pos, "metachar:sym<$>")
    .return (rx129_cur)
  rx129_fail:
    (rx129_rep, rx129_pos, $I10, $P10) = rx129_cur."!mark_fail"(0)
    lt rx129_pos, -1, rx129_done
    eq rx129_pos, -1, rx129_fail
    jump $I10
  rx129_done:
    rx129_cur."!cursor_fail"()
    .return (rx129_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<$$>"  :subid("40_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 71
    .local string rx132_tgt
    .local int rx132_pos
    .local int rx132_off
    .local int rx132_eos
    .local int rx132_rep
    .local pmc rx132_cur
    (rx132_cur, rx132_pos, rx132_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx132_cur
    length rx132_eos, rx132_tgt
    set rx132_off, 0
    lt $I10, 2, rx132_start
    sub rx132_off, $I10, 1
    substr rx132_tgt, rx132_tgt, rx132_off
  rx132_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_133_fail
    rx132_cur."!mark_push"(0, rx132_pos, $I10)
  # rx literal  "$$"
    add $I11, rx132_pos, 2
    gt $I11, rx132_eos, rx132_fail
    sub $I11, rx132_pos, rx132_off
    substr $S10, rx132_tgt, $I11, 2
    ne $S10, "$$", rx132_fail
    add rx132_pos, 2
    set_addr $I10, rxcap_133_fail
    ($I12, $I11) = rx132_cur."!mark_peek"($I10)
    rx132_cur."!cursor_pos"($I11)
    ($P10) = rx132_cur."!cursor_start"()
    $P10."!cursor_pass"(rx132_pos, "")
    rx132_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_133_done
  rxcap_133_fail:
    goto rx132_fail
  rxcap_133_done:
  # rx pass
    rx132_cur."!cursor_pass"(rx132_pos, "metachar:sym<$$>")
    .return (rx132_cur)
  rx132_fail:
    (rx132_rep, rx132_pos, $I10, $P10) = rx132_cur."!mark_fail"(0)
    lt rx132_pos, -1, rx132_done
    eq rx132_pos, -1, rx132_fail
    jump $I10
  rx132_done:
    rx132_cur."!cursor_fail"()
    .return (rx132_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<:::>"  :subid("41_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 72
    .local string rx135_tgt
    .local int rx135_pos
    .local int rx135_off
    .local int rx135_eos
    .local int rx135_rep
    .local pmc rx135_cur
    (rx135_cur, rx135_pos, rx135_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx135_cur
    length rx135_eos, rx135_tgt
    set rx135_off, 0
    lt $I10, 2, rx135_start
    sub rx135_off, $I10, 1
    substr rx135_tgt, rx135_tgt, rx135_off
  rx135_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_136_fail
    rx135_cur."!mark_push"(0, rx135_pos, $I10)
  # rx literal  ":::"
    add $I11, rx135_pos, 3
    gt $I11, rx135_eos, rx135_fail
    sub $I11, rx135_pos, rx135_off
    substr $S10, rx135_tgt, $I11, 3
    ne $S10, ":::", rx135_fail
    add rx135_pos, 3
    set_addr $I10, rxcap_136_fail
    ($I12, $I11) = rx135_cur."!mark_peek"($I10)
    rx135_cur."!cursor_pos"($I11)
    ($P10) = rx135_cur."!cursor_start"()
    $P10."!cursor_pass"(rx135_pos, "")
    rx135_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_136_done
  rxcap_136_fail:
    goto rx135_fail
  rxcap_136_done:
  # rx pass
    rx135_cur."!cursor_pass"(rx135_pos, "metachar:sym<:::>")
    .return (rx135_cur)
  rx135_fail:
    (rx135_rep, rx135_pos, $I10, $P10) = rx135_cur."!mark_fail"(0)
    lt rx135_pos, -1, rx135_done
    eq rx135_pos, -1, rx135_fail
    jump $I10
  rx135_done:
    rx135_cur."!cursor_fail"()
    .return (rx135_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<::>"  :subid("42_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 73
    .local string rx138_tgt
    .local int rx138_pos
    .local int rx138_off
    .local int rx138_eos
    .local int rx138_rep
    .local pmc rx138_cur
    (rx138_cur, rx138_pos, rx138_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx138_cur
    length rx138_eos, rx138_tgt
    set rx138_off, 0
    lt $I10, 2, rx138_start
    sub rx138_off, $I10, 1
    substr rx138_tgt, rx138_tgt, rx138_off
  rx138_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_139_fail
    rx138_cur."!mark_push"(0, rx138_pos, $I10)
  # rx literal  "::"
    add $I11, rx138_pos, 2
    gt $I11, rx138_eos, rx138_fail
    sub $I11, rx138_pos, rx138_off
    substr $S10, rx138_tgt, $I11, 2
    ne $S10, "::", rx138_fail
    add rx138_pos, 2
    set_addr $I10, rxcap_139_fail
    ($I12, $I11) = rx138_cur."!mark_peek"($I10)
    rx138_cur."!cursor_pos"($I11)
    ($P10) = rx138_cur."!cursor_start"()
    $P10."!cursor_pass"(rx138_pos, "")
    rx138_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_139_done
  rxcap_139_fail:
    goto rx138_fail
  rxcap_139_done:
  # rx pass
    rx138_cur."!cursor_pass"(rx138_pos, "metachar:sym<::>")
    .return (rx138_cur)
  rx138_fail:
    (rx138_rep, rx138_pos, $I10, $P10) = rx138_cur."!mark_fail"(0)
    lt rx138_pos, -1, rx138_done
    eq rx138_pos, -1, rx138_fail
    jump $I10
  rx138_done:
    rx138_cur."!cursor_fail"()
    .return (rx138_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<lwb>"  :subid("43_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 74
    .local string rx141_tgt
    .local int rx141_pos
    .local int rx141_off
    .local int rx141_eos
    .local int rx141_rep
    .local pmc rx141_cur
    (rx141_cur, rx141_pos, rx141_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx141_cur
    length rx141_eos, rx141_tgt
    set rx141_off, 0
    lt $I10, 2, rx141_start
    sub rx141_off, $I10, 1
    substr rx141_tgt, rx141_tgt, rx141_off
  rx141_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_143_fail
    rx141_cur."!mark_push"(0, rx141_pos, $I10)
  alt142_0:
    set_addr $I10, alt142_1
    rx141_cur."!mark_push"(0, rx141_pos, $I10)
  # rx literal  "<<"
    add $I11, rx141_pos, 2
    gt $I11, rx141_eos, rx141_fail
    sub $I11, rx141_pos, rx141_off
    substr $S10, rx141_tgt, $I11, 2
    ne $S10, "<<", rx141_fail
    add rx141_pos, 2
    goto alt142_end
  alt142_1:
  # rx literal  unicode:"\x{ab}"
    add $I11, rx141_pos, 1
    gt $I11, rx141_eos, rx141_fail
    sub $I11, rx141_pos, rx141_off
    substr $S10, rx141_tgt, $I11, 1
    ne $S10, unicode:"\x{ab}", rx141_fail
    add rx141_pos, 1
  alt142_end:
    set_addr $I10, rxcap_143_fail
    ($I12, $I11) = rx141_cur."!mark_peek"($I10)
    rx141_cur."!cursor_pos"($I11)
    ($P10) = rx141_cur."!cursor_start"()
    $P10."!cursor_pass"(rx141_pos, "")
    rx141_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_143_done
  rxcap_143_fail:
    goto rx141_fail
  rxcap_143_done:
  # rx pass
    rx141_cur."!cursor_pass"(rx141_pos, "metachar:sym<lwb>")
    .return (rx141_cur)
  rx141_fail:
    (rx141_rep, rx141_pos, $I10, $P10) = rx141_cur."!mark_fail"(0)
    lt rx141_pos, -1, rx141_done
    eq rx141_pos, -1, rx141_fail
    jump $I10
  rx141_done:
    rx141_cur."!cursor_fail"()
    .return (rx141_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<rwb>"  :subid("44_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 75
    .local string rx145_tgt
    .local int rx145_pos
    .local int rx145_off
    .local int rx145_eos
    .local int rx145_rep
    .local pmc rx145_cur
    (rx145_cur, rx145_pos, rx145_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx145_cur
    length rx145_eos, rx145_tgt
    set rx145_off, 0
    lt $I10, 2, rx145_start
    sub rx145_off, $I10, 1
    substr rx145_tgt, rx145_tgt, rx145_off
  rx145_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_147_fail
    rx145_cur."!mark_push"(0, rx145_pos, $I10)
  alt146_0:
    set_addr $I10, alt146_1
    rx145_cur."!mark_push"(0, rx145_pos, $I10)
  # rx literal  ">>"
    add $I11, rx145_pos, 2
    gt $I11, rx145_eos, rx145_fail
    sub $I11, rx145_pos, rx145_off
    substr $S10, rx145_tgt, $I11, 2
    ne $S10, ">>", rx145_fail
    add rx145_pos, 2
    goto alt146_end
  alt146_1:
  # rx literal  unicode:"\x{bb}"
    add $I11, rx145_pos, 1
    gt $I11, rx145_eos, rx145_fail
    sub $I11, rx145_pos, rx145_off
    substr $S10, rx145_tgt, $I11, 1
    ne $S10, unicode:"\x{bb}", rx145_fail
    add rx145_pos, 1
  alt146_end:
    set_addr $I10, rxcap_147_fail
    ($I12, $I11) = rx145_cur."!mark_peek"($I10)
    rx145_cur."!cursor_pos"($I11)
    ($P10) = rx145_cur."!cursor_start"()
    $P10."!cursor_pass"(rx145_pos, "")
    rx145_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_147_done
  rxcap_147_fail:
    goto rx145_fail
  rxcap_147_done:
  # rx pass
    rx145_cur."!cursor_pass"(rx145_pos, "metachar:sym<rwb>")
    .return (rx145_cur)
  rx145_fail:
    (rx145_rep, rx145_pos, $I10, $P10) = rx145_cur."!mark_fail"(0)
    lt rx145_pos, -1, rx145_done
    eq rx145_pos, -1, rx145_fail
    jump $I10
  rx145_done:
    rx145_cur."!cursor_fail"()
    .return (rx145_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<bs>"  :subid("45_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 76
    .local string rx149_tgt
    .local int rx149_pos
    .local int rx149_off
    .local int rx149_eos
    .local int rx149_rep
    .local pmc rx149_cur
    (rx149_cur, rx149_pos, rx149_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx149_cur
    length rx149_eos, rx149_tgt
    set rx149_off, 0
    lt $I10, 2, rx149_start
    sub rx149_off, $I10, 1
    substr rx149_tgt, rx149_tgt, rx149_off
  rx149_start:
  # rx literal  "\\"
    add $I11, rx149_pos, 1
    gt $I11, rx149_eos, rx149_fail
    sub $I11, rx149_pos, rx149_off
    substr $S10, rx149_tgt, $I11, 1
    ne $S10, "\\", rx149_fail
    add rx149_pos, 1
  # rx subrule "backslash" subtype=capture negate=
    rx149_cur."!cursor_pos"(rx149_pos)
    $P10 = rx149_cur."backslash"()
    unless $P10, rx149_fail
    rx149_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("backslash")
    rx149_pos = $P10."pos"()
  # rx pass
    rx149_cur."!cursor_pass"(rx149_pos, "metachar:sym<bs>")
    .return (rx149_cur)
  rx149_fail:
    (rx149_rep, rx149_pos, $I10, $P10) = rx149_cur."!mark_fail"(0)
    lt rx149_pos, -1, rx149_done
    eq rx149_pos, -1, rx149_fail
    jump $I10
  rx149_done:
    rx149_cur."!cursor_fail"()
    .return (rx149_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<mod>"  :subid("46_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 77
    .local string rx151_tgt
    .local int rx151_pos
    .local int rx151_off
    .local int rx151_eos
    .local int rx151_rep
    .local pmc rx151_cur
    (rx151_cur, rx151_pos, rx151_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx151_cur
    length rx151_eos, rx151_tgt
    set rx151_off, 0
    lt $I10, 2, rx151_start
    sub rx151_off, $I10, 1
    substr rx151_tgt, rx151_tgt, rx151_off
  rx151_start:
  # rx subrule "mod_internal" subtype=capture negate=
    rx151_cur."!cursor_pos"(rx151_pos)
    $P10 = rx151_cur."mod_internal"()
    unless $P10, rx151_fail
    rx151_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("mod_internal")
    rx151_pos = $P10."pos"()
  # rx pass
    rx151_cur."!cursor_pass"(rx151_pos, "metachar:sym<mod>")
    .return (rx151_cur)
  rx151_fail:
    (rx151_rep, rx151_pos, $I10, $P10) = rx151_cur."!mark_fail"(0)
    lt rx151_pos, -1, rx151_done
    eq rx151_pos, -1, rx151_fail
    jump $I10
  rx151_done:
    rx151_cur."!cursor_fail"()
    .return (rx151_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<{*}>"  :subid("47_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 79
    .local string rx153_tgt
    .local int rx153_pos
    .local int rx153_off
    .local int rx153_eos
    .local int rx153_rep
    .local pmc rx153_cur
    (rx153_cur, rx153_pos, rx153_tgt, $I10) = self."!cursor_start"()
    rx153_cur."!cursor_caparray"("key")
    .lex unicode:"$\x{a2}", rx153_cur
    length rx153_eos, rx153_tgt
    set rx153_off, 0
    lt $I10, 2, rx153_start
    sub rx153_off, $I10, 1
    substr rx153_tgt, rx153_tgt, rx153_off
  rx153_start:
.annotate "line", 80
  # rx subcapture "sym"
    set_addr $I10, rxcap_154_fail
    rx153_cur."!mark_push"(0, rx153_pos, $I10)
  # rx literal  "{*}"
    add $I11, rx153_pos, 3
    gt $I11, rx153_eos, rx153_fail
    sub $I11, rx153_pos, rx153_off
    substr $S10, rx153_tgt, $I11, 3
    ne $S10, "{*}", rx153_fail
    add rx153_pos, 3
    set_addr $I10, rxcap_154_fail
    ($I12, $I11) = rx153_cur."!mark_peek"($I10)
    rx153_cur."!cursor_pos"($I11)
    ($P10) = rx153_cur."!cursor_start"()
    $P10."!cursor_pass"(rx153_pos, "")
    rx153_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_154_done
  rxcap_154_fail:
    goto rx153_fail
  rxcap_154_done:
.annotate "line", 81
  # rx rxquantr155 ** 0..1
    set_addr $I165, rxquantr155_done
    rx153_cur."!mark_push"(0, rx153_pos, $I165)
  rxquantr155_loop:
  # rx rxquantr156 ** 0..*
    set_addr $I157, rxquantr156_done
    rx153_cur."!mark_push"(0, rx153_pos, $I157)
  rxquantr156_loop:
  # rx enumcharlist negate=0 
    ge rx153_pos, rx153_eos, rx153_fail
    sub $I10, rx153_pos, rx153_off
    substr $S10, rx153_tgt, $I10, 1
    index $I11, unicode:"\t \x{a0}\u1680\u180e\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u202f\u205f\u3000", $S10
    lt $I11, 0, rx153_fail
    inc rx153_pos
    (rx153_rep) = rx153_cur."!mark_commit"($I157)
    rx153_cur."!mark_push"(rx153_rep, rx153_pos, $I157)
    goto rxquantr156_loop
  rxquantr156_done:
  # rx literal  "#= "
    add $I11, rx153_pos, 3
    gt $I11, rx153_eos, rx153_fail
    sub $I11, rx153_pos, rx153_off
    substr $S10, rx153_tgt, $I11, 3
    ne $S10, "#= ", rx153_fail
    add rx153_pos, 3
  # rx rxquantr158 ** 0..*
    set_addr $I159, rxquantr158_done
    rx153_cur."!mark_push"(0, rx153_pos, $I159)
  rxquantr158_loop:
  # rx enumcharlist negate=0 
    ge rx153_pos, rx153_eos, rx153_fail
    sub $I10, rx153_pos, rx153_off
    substr $S10, rx153_tgt, $I10, 1
    index $I11, unicode:"\t \x{a0}\u1680\u180e\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u202f\u205f\u3000", $S10
    lt $I11, 0, rx153_fail
    inc rx153_pos
    (rx153_rep) = rx153_cur."!mark_commit"($I159)
    rx153_cur."!mark_push"(rx153_rep, rx153_pos, $I159)
    goto rxquantr158_loop
  rxquantr158_done:
  # rx subcapture "key"
    set_addr $I10, rxcap_164_fail
    rx153_cur."!mark_push"(0, rx153_pos, $I10)
  # rx charclass_q S r 1..-1
    sub $I10, rx153_pos, rx153_off
    find_cclass $I11, 32, rx153_tgt, $I10, rx153_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx153_fail
    add rx153_pos, rx153_off, $I11
  # rx rxquantr160 ** 0..*
    set_addr $I163, rxquantr160_done
    rx153_cur."!mark_push"(0, rx153_pos, $I163)
  rxquantr160_loop:
  # rx rxquantr161 ** 1..*
    set_addr $I162, rxquantr161_done
    rx153_cur."!mark_push"(0, -1, $I162)
  rxquantr161_loop:
  # rx enumcharlist negate=0 
    ge rx153_pos, rx153_eos, rx153_fail
    sub $I10, rx153_pos, rx153_off
    substr $S10, rx153_tgt, $I10, 1
    index $I11, unicode:"\t \x{a0}\u1680\u180e\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u202f\u205f\u3000", $S10
    lt $I11, 0, rx153_fail
    inc rx153_pos
    (rx153_rep) = rx153_cur."!mark_commit"($I162)
    rx153_cur."!mark_push"(rx153_rep, rx153_pos, $I162)
    goto rxquantr161_loop
  rxquantr161_done:
  # rx charclass_q S r 1..-1
    sub $I10, rx153_pos, rx153_off
    find_cclass $I11, 32, rx153_tgt, $I10, rx153_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx153_fail
    add rx153_pos, rx153_off, $I11
    (rx153_rep) = rx153_cur."!mark_commit"($I163)
    rx153_cur."!mark_push"(rx153_rep, rx153_pos, $I163)
    goto rxquantr160_loop
  rxquantr160_done:
    set_addr $I10, rxcap_164_fail
    ($I12, $I11) = rx153_cur."!mark_peek"($I10)
    rx153_cur."!cursor_pos"($I11)
    ($P10) = rx153_cur."!cursor_start"()
    $P10."!cursor_pass"(rx153_pos, "")
    rx153_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("key")
    goto rxcap_164_done
  rxcap_164_fail:
    goto rx153_fail
  rxcap_164_done:
    (rx153_rep) = rx153_cur."!mark_commit"($I165)
  rxquantr155_done:
.annotate "line", 79
  # rx pass
    rx153_cur."!cursor_pass"(rx153_pos, "metachar:sym<{*}>")
    .return (rx153_cur)
  rx153_fail:
    (rx153_rep, rx153_pos, $I10, $P10) = rx153_cur."!mark_fail"(0)
    lt rx153_pos, -1, rx153_done
    eq rx153_pos, -1, rx153_fail
    jump $I10
  rx153_done:
    rx153_cur."!cursor_fail"()
    .return (rx153_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<assert>"  :subid("48_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 83
    .local string rx167_tgt
    .local int rx167_pos
    .local int rx167_off
    .local int rx167_eos
    .local int rx167_rep
    .local pmc rx167_cur
    (rx167_cur, rx167_pos, rx167_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx167_cur
    length rx167_eos, rx167_tgt
    set rx167_off, 0
    lt $I10, 2, rx167_start
    sub rx167_off, $I10, 1
    substr rx167_tgt, rx167_tgt, rx167_off
  rx167_start:
.annotate "line", 84
  # rx literal  "<"
    add $I11, rx167_pos, 1
    gt $I11, rx167_eos, rx167_fail
    sub $I11, rx167_pos, rx167_off
    substr $S10, rx167_tgt, $I11, 1
    ne $S10, "<", rx167_fail
    add rx167_pos, 1
  # rx subrule "assertion" subtype=capture negate=
    rx167_cur."!cursor_pos"(rx167_pos)
    $P10 = rx167_cur."assertion"()
    unless $P10, rx167_fail
    rx167_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("assertion")
    rx167_pos = $P10."pos"()
  alt168_0:
.annotate "line", 85
    set_addr $I10, alt168_1
    rx167_cur."!mark_push"(0, rx167_pos, $I10)
  # rx literal  ">"
    add $I11, rx167_pos, 1
    gt $I11, rx167_eos, rx167_fail
    sub $I11, rx167_pos, rx167_off
    substr $S10, rx167_tgt, $I11, 1
    ne $S10, ">", rx167_fail
    add rx167_pos, 1
    goto alt168_end
  alt168_1:
  # rx subrule "panic" subtype=method negate=
    rx167_cur."!cursor_pos"(rx167_pos)
    $P10 = rx167_cur."panic"("regex assertion not terminated by angle bracket")
    unless $P10, rx167_fail
    rx167_pos = $P10."pos"()
  alt168_end:
.annotate "line", 83
  # rx pass
    rx167_cur."!cursor_pass"(rx167_pos, "metachar:sym<assert>")
    .return (rx167_cur)
  rx167_fail:
    (rx167_rep, rx167_pos, $I10, $P10) = rx167_cur."!mark_fail"(0)
    lt rx167_pos, -1, rx167_done
    eq rx167_pos, -1, rx167_fail
    jump $I10
  rx167_done:
    rx167_cur."!cursor_fail"()
    .return (rx167_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "metachar:sym<var>"  :subid("49_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 88
    .local string rx170_tgt
    .local int rx170_pos
    .local int rx170_off
    .local int rx170_eos
    .local int rx170_rep
    .local pmc rx170_cur
    (rx170_cur, rx170_pos, rx170_tgt, $I10) = self."!cursor_start"()
    rx170_cur."!cursor_caparray"("quantified_atom")
    .lex unicode:"$\x{a2}", rx170_cur
    length rx170_eos, rx170_tgt
    set rx170_off, 0
    lt $I10, 2, rx170_start
    sub rx170_off, $I10, 1
    substr rx170_tgt, rx170_tgt, rx170_off
  rx170_start:
  alt171_0:
.annotate "line", 89
    set_addr $I10, alt171_1
    rx170_cur."!mark_push"(0, rx170_pos, $I10)
.annotate "line", 90
  # rx literal  "$<"
    add $I11, rx170_pos, 2
    gt $I11, rx170_eos, rx170_fail
    sub $I11, rx170_pos, rx170_off
    substr $S10, rx170_tgt, $I11, 2
    ne $S10, "$<", rx170_fail
    add rx170_pos, 2
  # rx subcapture "name"
    set_addr $I10, rxcap_174_fail
    rx170_cur."!mark_push"(0, rx170_pos, $I10)
  # rx rxquantr172 ** 1..*
    set_addr $I173, rxquantr172_done
    rx170_cur."!mark_push"(0, -1, $I173)
  rxquantr172_loop:
  # rx enumcharlist negate=1 
    ge rx170_pos, rx170_eos, rx170_fail
    sub $I10, rx170_pos, rx170_off
    substr $S10, rx170_tgt, $I10, 1
    index $I11, ">", $S10
    ge $I11, 0, rx170_fail
    inc rx170_pos
    (rx170_rep) = rx170_cur."!mark_commit"($I173)
    rx170_cur."!mark_push"(rx170_rep, rx170_pos, $I173)
    goto rxquantr172_loop
  rxquantr172_done:
    set_addr $I10, rxcap_174_fail
    ($I12, $I11) = rx170_cur."!mark_peek"($I10)
    rx170_cur."!cursor_pos"($I11)
    ($P10) = rx170_cur."!cursor_start"()
    $P10."!cursor_pass"(rx170_pos, "")
    rx170_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("name")
    goto rxcap_174_done
  rxcap_174_fail:
    goto rx170_fail
  rxcap_174_done:
  # rx literal  ">"
    add $I11, rx170_pos, 1
    gt $I11, rx170_eos, rx170_fail
    sub $I11, rx170_pos, rx170_off
    substr $S10, rx170_tgt, $I11, 1
    ne $S10, ">", rx170_fail
    add rx170_pos, 1
    goto alt171_end
  alt171_1:
.annotate "line", 91
  # rx literal  "$"
    add $I11, rx170_pos, 1
    gt $I11, rx170_eos, rx170_fail
    sub $I11, rx170_pos, rx170_off
    substr $S10, rx170_tgt, $I11, 1
    ne $S10, "$", rx170_fail
    add rx170_pos, 1
  # rx subcapture "pos"
    set_addr $I10, rxcap_175_fail
    rx170_cur."!mark_push"(0, rx170_pos, $I10)
  # rx charclass_q d r 1..-1
    sub $I10, rx170_pos, rx170_off
    find_not_cclass $I11, 8, rx170_tgt, $I10, rx170_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx170_fail
    add rx170_pos, rx170_off, $I11
    set_addr $I10, rxcap_175_fail
    ($I12, $I11) = rx170_cur."!mark_peek"($I10)
    rx170_cur."!cursor_pos"($I11)
    ($P10) = rx170_cur."!cursor_start"()
    $P10."!cursor_pass"(rx170_pos, "")
    rx170_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("pos")
    goto rxcap_175_done
  rxcap_175_fail:
    goto rx170_fail
  rxcap_175_done:
  alt171_end:
.annotate "line", 94
  # rx rxquantr176 ** 0..1
    set_addr $I177, rxquantr176_done
    rx170_cur."!mark_push"(0, rx170_pos, $I177)
  rxquantr176_loop:
  # rx subrule "ws" subtype=method negate=
    rx170_cur."!cursor_pos"(rx170_pos)
    $P10 = rx170_cur."ws"()
    unless $P10, rx170_fail
    rx170_pos = $P10."pos"()
  # rx literal  "="
    add $I11, rx170_pos, 1
    gt $I11, rx170_eos, rx170_fail
    sub $I11, rx170_pos, rx170_off
    substr $S10, rx170_tgt, $I11, 1
    ne $S10, "=", rx170_fail
    add rx170_pos, 1
  # rx subrule "ws" subtype=method negate=
    rx170_cur."!cursor_pos"(rx170_pos)
    $P10 = rx170_cur."ws"()
    unless $P10, rx170_fail
    rx170_pos = $P10."pos"()
  # rx subrule "quantified_atom" subtype=capture negate=
    rx170_cur."!cursor_pos"(rx170_pos)
    $P10 = rx170_cur."quantified_atom"()
    unless $P10, rx170_fail
    rx170_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("quantified_atom")
    rx170_pos = $P10."pos"()
    (rx170_rep) = rx170_cur."!mark_commit"($I177)
  rxquantr176_done:
.annotate "line", 88
  # rx pass
    rx170_cur."!cursor_pass"(rx170_pos, "metachar:sym<var>")
    .return (rx170_cur)
  rx170_fail:
    (rx170_rep, rx170_pos, $I10, $P10) = rx170_cur."!mark_fail"(0)
    lt rx170_pos, -1, rx170_done
    eq rx170_pos, -1, rx170_fail
    jump $I10
  rx170_done:
    rx170_cur."!cursor_fail"()
    .return (rx170_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash"  :subid("50_1256021810.94784") :method
.annotate "line", 97
    $P179 = self."!protoregex"("backslash")
    .return ($P179)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<w>"  :subid("51_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 98
    .local string rx181_tgt
    .local int rx181_pos
    .local int rx181_off
    .local int rx181_eos
    .local int rx181_rep
    .local pmc rx181_cur
    (rx181_cur, rx181_pos, rx181_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx181_cur
    length rx181_eos, rx181_tgt
    set rx181_off, 0
    lt $I10, 2, rx181_start
    sub rx181_off, $I10, 1
    substr rx181_tgt, rx181_tgt, rx181_off
  rx181_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_182_fail
    rx181_cur."!mark_push"(0, rx181_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx181_pos, rx181_eos, rx181_fail
    sub $I10, rx181_pos, rx181_off
    substr $S10, rx181_tgt, $I10, 1
    index $I11, "dswnDSWN", $S10
    lt $I11, 0, rx181_fail
    inc rx181_pos
    set_addr $I10, rxcap_182_fail
    ($I12, $I11) = rx181_cur."!mark_peek"($I10)
    rx181_cur."!cursor_pos"($I11)
    ($P10) = rx181_cur."!cursor_start"()
    $P10."!cursor_pass"(rx181_pos, "")
    rx181_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_182_done
  rxcap_182_fail:
    goto rx181_fail
  rxcap_182_done:
  # rx pass
    rx181_cur."!cursor_pass"(rx181_pos, "backslash:sym<w>")
    .return (rx181_cur)
  rx181_fail:
    (rx181_rep, rx181_pos, $I10, $P10) = rx181_cur."!mark_fail"(0)
    lt rx181_pos, -1, rx181_done
    eq rx181_pos, -1, rx181_fail
    jump $I10
  rx181_done:
    rx181_cur."!cursor_fail"()
    .return (rx181_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<b>"  :subid("52_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 99
    .local string rx184_tgt
    .local int rx184_pos
    .local int rx184_off
    .local int rx184_eos
    .local int rx184_rep
    .local pmc rx184_cur
    (rx184_cur, rx184_pos, rx184_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx184_cur
    length rx184_eos, rx184_tgt
    set rx184_off, 0
    lt $I10, 2, rx184_start
    sub rx184_off, $I10, 1
    substr rx184_tgt, rx184_tgt, rx184_off
  rx184_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_185_fail
    rx184_cur."!mark_push"(0, rx184_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx184_pos, rx184_eos, rx184_fail
    sub $I10, rx184_pos, rx184_off
    substr $S10, rx184_tgt, $I10, 1
    index $I11, "bB", $S10
    lt $I11, 0, rx184_fail
    inc rx184_pos
    set_addr $I10, rxcap_185_fail
    ($I12, $I11) = rx184_cur."!mark_peek"($I10)
    rx184_cur."!cursor_pos"($I11)
    ($P10) = rx184_cur."!cursor_start"()
    $P10."!cursor_pass"(rx184_pos, "")
    rx184_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_185_done
  rxcap_185_fail:
    goto rx184_fail
  rxcap_185_done:
  # rx pass
    rx184_cur."!cursor_pass"(rx184_pos, "backslash:sym<b>")
    .return (rx184_cur)
  rx184_fail:
    (rx184_rep, rx184_pos, $I10, $P10) = rx184_cur."!mark_fail"(0)
    lt rx184_pos, -1, rx184_done
    eq rx184_pos, -1, rx184_fail
    jump $I10
  rx184_done:
    rx184_cur."!cursor_fail"()
    .return (rx184_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<e>"  :subid("53_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 100
    .local string rx187_tgt
    .local int rx187_pos
    .local int rx187_off
    .local int rx187_eos
    .local int rx187_rep
    .local pmc rx187_cur
    (rx187_cur, rx187_pos, rx187_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx187_cur
    length rx187_eos, rx187_tgt
    set rx187_off, 0
    lt $I10, 2, rx187_start
    sub rx187_off, $I10, 1
    substr rx187_tgt, rx187_tgt, rx187_off
  rx187_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_188_fail
    rx187_cur."!mark_push"(0, rx187_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx187_pos, rx187_eos, rx187_fail
    sub $I10, rx187_pos, rx187_off
    substr $S10, rx187_tgt, $I10, 1
    index $I11, "eE", $S10
    lt $I11, 0, rx187_fail
    inc rx187_pos
    set_addr $I10, rxcap_188_fail
    ($I12, $I11) = rx187_cur."!mark_peek"($I10)
    rx187_cur."!cursor_pos"($I11)
    ($P10) = rx187_cur."!cursor_start"()
    $P10."!cursor_pass"(rx187_pos, "")
    rx187_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_188_done
  rxcap_188_fail:
    goto rx187_fail
  rxcap_188_done:
  # rx pass
    rx187_cur."!cursor_pass"(rx187_pos, "backslash:sym<e>")
    .return (rx187_cur)
  rx187_fail:
    (rx187_rep, rx187_pos, $I10, $P10) = rx187_cur."!mark_fail"(0)
    lt rx187_pos, -1, rx187_done
    eq rx187_pos, -1, rx187_fail
    jump $I10
  rx187_done:
    rx187_cur."!cursor_fail"()
    .return (rx187_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<f>"  :subid("54_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 101
    .local string rx190_tgt
    .local int rx190_pos
    .local int rx190_off
    .local int rx190_eos
    .local int rx190_rep
    .local pmc rx190_cur
    (rx190_cur, rx190_pos, rx190_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx190_cur
    length rx190_eos, rx190_tgt
    set rx190_off, 0
    lt $I10, 2, rx190_start
    sub rx190_off, $I10, 1
    substr rx190_tgt, rx190_tgt, rx190_off
  rx190_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_191_fail
    rx190_cur."!mark_push"(0, rx190_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx190_pos, rx190_eos, rx190_fail
    sub $I10, rx190_pos, rx190_off
    substr $S10, rx190_tgt, $I10, 1
    index $I11, "fF", $S10
    lt $I11, 0, rx190_fail
    inc rx190_pos
    set_addr $I10, rxcap_191_fail
    ($I12, $I11) = rx190_cur."!mark_peek"($I10)
    rx190_cur."!cursor_pos"($I11)
    ($P10) = rx190_cur."!cursor_start"()
    $P10."!cursor_pass"(rx190_pos, "")
    rx190_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_191_done
  rxcap_191_fail:
    goto rx190_fail
  rxcap_191_done:
  # rx pass
    rx190_cur."!cursor_pass"(rx190_pos, "backslash:sym<f>")
    .return (rx190_cur)
  rx190_fail:
    (rx190_rep, rx190_pos, $I10, $P10) = rx190_cur."!mark_fail"(0)
    lt rx190_pos, -1, rx190_done
    eq rx190_pos, -1, rx190_fail
    jump $I10
  rx190_done:
    rx190_cur."!cursor_fail"()
    .return (rx190_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<h>"  :subid("55_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 102
    .local string rx193_tgt
    .local int rx193_pos
    .local int rx193_off
    .local int rx193_eos
    .local int rx193_rep
    .local pmc rx193_cur
    (rx193_cur, rx193_pos, rx193_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx193_cur
    length rx193_eos, rx193_tgt
    set rx193_off, 0
    lt $I10, 2, rx193_start
    sub rx193_off, $I10, 1
    substr rx193_tgt, rx193_tgt, rx193_off
  rx193_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_194_fail
    rx193_cur."!mark_push"(0, rx193_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx193_pos, rx193_eos, rx193_fail
    sub $I10, rx193_pos, rx193_off
    substr $S10, rx193_tgt, $I10, 1
    index $I11, "hH", $S10
    lt $I11, 0, rx193_fail
    inc rx193_pos
    set_addr $I10, rxcap_194_fail
    ($I12, $I11) = rx193_cur."!mark_peek"($I10)
    rx193_cur."!cursor_pos"($I11)
    ($P10) = rx193_cur."!cursor_start"()
    $P10."!cursor_pass"(rx193_pos, "")
    rx193_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_194_done
  rxcap_194_fail:
    goto rx193_fail
  rxcap_194_done:
  # rx pass
    rx193_cur."!cursor_pass"(rx193_pos, "backslash:sym<h>")
    .return (rx193_cur)
  rx193_fail:
    (rx193_rep, rx193_pos, $I10, $P10) = rx193_cur."!mark_fail"(0)
    lt rx193_pos, -1, rx193_done
    eq rx193_pos, -1, rx193_fail
    jump $I10
  rx193_done:
    rx193_cur."!cursor_fail"()
    .return (rx193_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<r>"  :subid("56_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 103
    .local string rx196_tgt
    .local int rx196_pos
    .local int rx196_off
    .local int rx196_eos
    .local int rx196_rep
    .local pmc rx196_cur
    (rx196_cur, rx196_pos, rx196_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx196_cur
    length rx196_eos, rx196_tgt
    set rx196_off, 0
    lt $I10, 2, rx196_start
    sub rx196_off, $I10, 1
    substr rx196_tgt, rx196_tgt, rx196_off
  rx196_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_197_fail
    rx196_cur."!mark_push"(0, rx196_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx196_pos, rx196_eos, rx196_fail
    sub $I10, rx196_pos, rx196_off
    substr $S10, rx196_tgt, $I10, 1
    index $I11, "rR", $S10
    lt $I11, 0, rx196_fail
    inc rx196_pos
    set_addr $I10, rxcap_197_fail
    ($I12, $I11) = rx196_cur."!mark_peek"($I10)
    rx196_cur."!cursor_pos"($I11)
    ($P10) = rx196_cur."!cursor_start"()
    $P10."!cursor_pass"(rx196_pos, "")
    rx196_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_197_done
  rxcap_197_fail:
    goto rx196_fail
  rxcap_197_done:
  # rx pass
    rx196_cur."!cursor_pass"(rx196_pos, "backslash:sym<r>")
    .return (rx196_cur)
  rx196_fail:
    (rx196_rep, rx196_pos, $I10, $P10) = rx196_cur."!mark_fail"(0)
    lt rx196_pos, -1, rx196_done
    eq rx196_pos, -1, rx196_fail
    jump $I10
  rx196_done:
    rx196_cur."!cursor_fail"()
    .return (rx196_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<t>"  :subid("57_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 104
    .local string rx199_tgt
    .local int rx199_pos
    .local int rx199_off
    .local int rx199_eos
    .local int rx199_rep
    .local pmc rx199_cur
    (rx199_cur, rx199_pos, rx199_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx199_cur
    length rx199_eos, rx199_tgt
    set rx199_off, 0
    lt $I10, 2, rx199_start
    sub rx199_off, $I10, 1
    substr rx199_tgt, rx199_tgt, rx199_off
  rx199_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_200_fail
    rx199_cur."!mark_push"(0, rx199_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx199_pos, rx199_eos, rx199_fail
    sub $I10, rx199_pos, rx199_off
    substr $S10, rx199_tgt, $I10, 1
    index $I11, "tT", $S10
    lt $I11, 0, rx199_fail
    inc rx199_pos
    set_addr $I10, rxcap_200_fail
    ($I12, $I11) = rx199_cur."!mark_peek"($I10)
    rx199_cur."!cursor_pos"($I11)
    ($P10) = rx199_cur."!cursor_start"()
    $P10."!cursor_pass"(rx199_pos, "")
    rx199_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_200_done
  rxcap_200_fail:
    goto rx199_fail
  rxcap_200_done:
  # rx pass
    rx199_cur."!cursor_pass"(rx199_pos, "backslash:sym<t>")
    .return (rx199_cur)
  rx199_fail:
    (rx199_rep, rx199_pos, $I10, $P10) = rx199_cur."!mark_fail"(0)
    lt rx199_pos, -1, rx199_done
    eq rx199_pos, -1, rx199_fail
    jump $I10
  rx199_done:
    rx199_cur."!cursor_fail"()
    .return (rx199_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<v>"  :subid("58_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 105
    .local string rx202_tgt
    .local int rx202_pos
    .local int rx202_off
    .local int rx202_eos
    .local int rx202_rep
    .local pmc rx202_cur
    (rx202_cur, rx202_pos, rx202_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx202_cur
    length rx202_eos, rx202_tgt
    set rx202_off, 0
    lt $I10, 2, rx202_start
    sub rx202_off, $I10, 1
    substr rx202_tgt, rx202_tgt, rx202_off
  rx202_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_203_fail
    rx202_cur."!mark_push"(0, rx202_pos, $I10)
  # rx enumcharlist negate=0 
    ge rx202_pos, rx202_eos, rx202_fail
    sub $I10, rx202_pos, rx202_off
    substr $S10, rx202_tgt, $I10, 1
    index $I11, "vV", $S10
    lt $I11, 0, rx202_fail
    inc rx202_pos
    set_addr $I10, rxcap_203_fail
    ($I12, $I11) = rx202_cur."!mark_peek"($I10)
    rx202_cur."!cursor_pos"($I11)
    ($P10) = rx202_cur."!cursor_start"()
    $P10."!cursor_pass"(rx202_pos, "")
    rx202_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_203_done
  rxcap_203_fail:
    goto rx202_fail
  rxcap_203_done:
  # rx pass
    rx202_cur."!cursor_pass"(rx202_pos, "backslash:sym<v>")
    .return (rx202_cur)
  rx202_fail:
    (rx202_rep, rx202_pos, $I10, $P10) = rx202_cur."!mark_fail"(0)
    lt rx202_pos, -1, rx202_done
    eq rx202_pos, -1, rx202_fail
    jump $I10
  rx202_done:
    rx202_cur."!cursor_fail"()
    .return (rx202_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<A>"  :subid("59_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 106
    .local string rx205_tgt
    .local int rx205_pos
    .local int rx205_off
    .local int rx205_eos
    .local int rx205_rep
    .local pmc rx205_cur
    (rx205_cur, rx205_pos, rx205_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx205_cur
    length rx205_eos, rx205_tgt
    set rx205_off, 0
    lt $I10, 2, rx205_start
    sub rx205_off, $I10, 1
    substr rx205_tgt, rx205_tgt, rx205_off
  rx205_start:
  # rx literal  "A"
    add $I11, rx205_pos, 1
    gt $I11, rx205_eos, rx205_fail
    sub $I11, rx205_pos, rx205_off
    substr $S10, rx205_tgt, $I11, 1
    ne $S10, "A", rx205_fail
    add rx205_pos, 1
  # rx subrule "obs" subtype=method negate=
    rx205_cur."!cursor_pos"(rx205_pos)
    $P10 = rx205_cur."obs"("\\\\A as beginning-of-string matcher;^")
    unless $P10, rx205_fail
    rx205_pos = $P10."pos"()
  # rx pass
    rx205_cur."!cursor_pass"(rx205_pos, "backslash:sym<A>")
    .return (rx205_cur)
  rx205_fail:
    (rx205_rep, rx205_pos, $I10, $P10) = rx205_cur."!mark_fail"(0)
    lt rx205_pos, -1, rx205_done
    eq rx205_pos, -1, rx205_fail
    jump $I10
  rx205_done:
    rx205_cur."!cursor_fail"()
    .return (rx205_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<z>"  :subid("60_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 107
    .local string rx207_tgt
    .local int rx207_pos
    .local int rx207_off
    .local int rx207_eos
    .local int rx207_rep
    .local pmc rx207_cur
    (rx207_cur, rx207_pos, rx207_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx207_cur
    length rx207_eos, rx207_tgt
    set rx207_off, 0
    lt $I10, 2, rx207_start
    sub rx207_off, $I10, 1
    substr rx207_tgt, rx207_tgt, rx207_off
  rx207_start:
  # rx literal  "z"
    add $I11, rx207_pos, 1
    gt $I11, rx207_eos, rx207_fail
    sub $I11, rx207_pos, rx207_off
    substr $S10, rx207_tgt, $I11, 1
    ne $S10, "z", rx207_fail
    add rx207_pos, 1
  # rx subrule "obs" subtype=method negate=
    rx207_cur."!cursor_pos"(rx207_pos)
    $P10 = rx207_cur."obs"("\\\\z as end-of-string matcher;$")
    unless $P10, rx207_fail
    rx207_pos = $P10."pos"()
  # rx pass
    rx207_cur."!cursor_pass"(rx207_pos, "backslash:sym<z>")
    .return (rx207_cur)
  rx207_fail:
    (rx207_rep, rx207_pos, $I10, $P10) = rx207_cur."!mark_fail"(0)
    lt rx207_pos, -1, rx207_done
    eq rx207_pos, -1, rx207_fail
    jump $I10
  rx207_done:
    rx207_cur."!cursor_fail"()
    .return (rx207_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<Z>"  :subid("61_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 108
    .local string rx209_tgt
    .local int rx209_pos
    .local int rx209_off
    .local int rx209_eos
    .local int rx209_rep
    .local pmc rx209_cur
    (rx209_cur, rx209_pos, rx209_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx209_cur
    length rx209_eos, rx209_tgt
    set rx209_off, 0
    lt $I10, 2, rx209_start
    sub rx209_off, $I10, 1
    substr rx209_tgt, rx209_tgt, rx209_off
  rx209_start:
  # rx literal  "Z"
    add $I11, rx209_pos, 1
    gt $I11, rx209_eos, rx209_fail
    sub $I11, rx209_pos, rx209_off
    substr $S10, rx209_tgt, $I11, 1
    ne $S10, "Z", rx209_fail
    add rx209_pos, 1
  # rx subrule "obs" subtype=method negate=
    rx209_cur."!cursor_pos"(rx209_pos)
    $P10 = rx209_cur."obs"("\\\\Z as end-of-string matcher;\\\\n?$")
    unless $P10, rx209_fail
    rx209_pos = $P10."pos"()
  # rx pass
    rx209_cur."!cursor_pass"(rx209_pos, "backslash:sym<Z>")
    .return (rx209_cur)
  rx209_fail:
    (rx209_rep, rx209_pos, $I10, $P10) = rx209_cur."!mark_fail"(0)
    lt rx209_pos, -1, rx209_done
    eq rx209_pos, -1, rx209_fail
    jump $I10
  rx209_done:
    rx209_cur."!cursor_fail"()
    .return (rx209_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<Q>"  :subid("62_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 109
    .local string rx211_tgt
    .local int rx211_pos
    .local int rx211_off
    .local int rx211_eos
    .local int rx211_rep
    .local pmc rx211_cur
    (rx211_cur, rx211_pos, rx211_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx211_cur
    length rx211_eos, rx211_tgt
    set rx211_off, 0
    lt $I10, 2, rx211_start
    sub rx211_off, $I10, 1
    substr rx211_tgt, rx211_tgt, rx211_off
  rx211_start:
  # rx literal  "Q"
    add $I11, rx211_pos, 1
    gt $I11, rx211_eos, rx211_fail
    sub $I11, rx211_pos, rx211_off
    substr $S10, rx211_tgt, $I11, 1
    ne $S10, "Q", rx211_fail
    add rx211_pos, 1
  # rx subrule "obs" subtype=method negate=
    rx211_cur."!cursor_pos"(rx211_pos)
    $P10 = rx211_cur."obs"("\\\\Q as quotemeta;quotes or literal variable match")
    unless $P10, rx211_fail
    rx211_pos = $P10."pos"()
  # rx pass
    rx211_cur."!cursor_pass"(rx211_pos, "backslash:sym<Q>")
    .return (rx211_cur)
  rx211_fail:
    (rx211_rep, rx211_pos, $I10, $P10) = rx211_cur."!mark_fail"(0)
    lt rx211_pos, -1, rx211_done
    eq rx211_pos, -1, rx211_fail
    jump $I10
  rx211_done:
    rx211_cur."!cursor_fail"()
    .return (rx211_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "backslash:sym<misc>"  :subid("63_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 110
    .local string rx213_tgt
    .local int rx213_pos
    .local int rx213_off
    .local int rx213_eos
    .local int rx213_rep
    .local pmc rx213_cur
    (rx213_cur, rx213_pos, rx213_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx213_cur
    length rx213_eos, rx213_tgt
    set rx213_off, 0
    lt $I10, 2, rx213_start
    sub rx213_off, $I10, 1
    substr rx213_tgt, rx213_tgt, rx213_off
  rx213_start:
  # rx charclass W
    ge rx213_pos, rx213_eos, rx213_fail
    sub $I10, rx213_pos, rx213_off
    is_cclass $I11, 8192, rx213_tgt, $I10
    if $I11, rx213_fail
    inc rx213_pos
  # rx pass
    rx213_cur."!cursor_pass"(rx213_pos, "backslash:sym<misc>")
    .return (rx213_cur)
  rx213_fail:
    (rx213_rep, rx213_pos, $I10, $P10) = rx213_cur."!mark_fail"(0)
    lt rx213_pos, -1, rx213_done
    eq rx213_pos, -1, rx213_fail
    jump $I10
  rx213_done:
    rx213_cur."!cursor_fail"()
    .return (rx213_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion"  :subid("64_1256021810.94784") :method
.annotate "line", 112
    $P215 = self."!protoregex"("assertion")
    .return ($P215)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion:sym<?>"  :subid("65_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 114
    .const 'Sub' $P220 = "66_1256021810.94784" 
    capture_lex $P220
    .local string rx217_tgt
    .local int rx217_pos
    .local int rx217_off
    .local int rx217_eos
    .local int rx217_rep
    .local pmc rx217_cur
    (rx217_cur, rx217_pos, rx217_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx217_cur
    length rx217_eos, rx217_tgt
    set rx217_off, 0
    lt $I10, 2, rx217_start
    sub rx217_off, $I10, 1
    substr rx217_tgt, rx217_tgt, rx217_off
  rx217_start:
  # rx literal  "?"
    add $I11, rx217_pos, 1
    gt $I11, rx217_eos, rx217_fail
    sub $I11, rx217_pos, rx217_off
    substr $S10, rx217_tgt, $I11, 1
    ne $S10, "?", rx217_fail
    add rx217_pos, 1
  alt218_0:
    set_addr $I10, alt218_1
    rx217_cur."!mark_push"(0, rx217_pos, $I10)
  # rx subrule "before" subtype=zerowidth negate=
    rx217_cur."!cursor_pos"(rx217_pos)
    .const 'Sub' $P220 = "66_1256021810.94784" 
    capture_lex $P220
    $P10 = rx217_cur."before"($P220)
    unless $P10, rx217_fail
    goto alt218_end
  alt218_1:
  # rx subrule "assertion" subtype=capture negate=
    rx217_cur."!cursor_pos"(rx217_pos)
    $P10 = rx217_cur."assertion"()
    unless $P10, rx217_fail
    rx217_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("assertion")
    rx217_pos = $P10."pos"()
  alt218_end:
  # rx pass
    rx217_cur."!cursor_pass"(rx217_pos, "assertion:sym<?>")
    .return (rx217_cur)
  rx217_fail:
    (rx217_rep, rx217_pos, $I10, $P10) = rx217_cur."!mark_fail"(0)
    lt rx217_pos, -1, rx217_done
    eq rx217_pos, -1, rx217_fail
    jump $I10
  rx217_done:
    rx217_cur."!cursor_fail"()
    .return (rx217_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block219"  :anon :subid("66_1256021810.94784") :method :outer("65_1256021810.94784")
.annotate "line", 114
    .local string rx221_tgt
    .local int rx221_pos
    .local int rx221_off
    .local int rx221_eos
    .local int rx221_rep
    .local pmc rx221_cur
    (rx221_cur, rx221_pos, rx221_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx221_cur
    length rx221_eos, rx221_tgt
    set rx221_off, 0
    lt $I10, 2, rx221_start
    sub rx221_off, $I10, 1
    substr rx221_tgt, rx221_tgt, rx221_off
  rx221_start:
    ge rx221_pos, 0, rxscan222_done
  rxscan222_loop:
    ($P10) = rx221_cur."from"()
    inc $P10
    set rx221_pos, $P10
    ge rx221_pos, rx221_eos, rxscan222_done
    set_addr $I10, rxscan222_loop
    rx221_cur."!mark_push"(0, rx221_pos, $I10)
  rxscan222_done:
  # rx literal  ">"
    add $I11, rx221_pos, 1
    gt $I11, rx221_eos, rx221_fail
    sub $I11, rx221_pos, rx221_off
    substr $S10, rx221_tgt, $I11, 1
    ne $S10, ">", rx221_fail
    add rx221_pos, 1
  # rx pass
    rx221_cur."!cursor_pass"(rx221_pos, "")
    .return (rx221_cur)
  rx221_fail:
    (rx221_rep, rx221_pos, $I10, $P10) = rx221_cur."!mark_fail"(0)
    lt rx221_pos, -1, rx221_done
    eq rx221_pos, -1, rx221_fail
    jump $I10
  rx221_done:
    rx221_cur."!cursor_fail"()
    .return (rx221_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion:sym<!>"  :subid("67_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 115
    .const 'Sub' $P227 = "68_1256021810.94784" 
    capture_lex $P227
    .local string rx224_tgt
    .local int rx224_pos
    .local int rx224_off
    .local int rx224_eos
    .local int rx224_rep
    .local pmc rx224_cur
    (rx224_cur, rx224_pos, rx224_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx224_cur
    length rx224_eos, rx224_tgt
    set rx224_off, 0
    lt $I10, 2, rx224_start
    sub rx224_off, $I10, 1
    substr rx224_tgt, rx224_tgt, rx224_off
  rx224_start:
  # rx literal  "!"
    add $I11, rx224_pos, 1
    gt $I11, rx224_eos, rx224_fail
    sub $I11, rx224_pos, rx224_off
    substr $S10, rx224_tgt, $I11, 1
    ne $S10, "!", rx224_fail
    add rx224_pos, 1
  alt225_0:
    set_addr $I10, alt225_1
    rx224_cur."!mark_push"(0, rx224_pos, $I10)
  # rx subrule "before" subtype=zerowidth negate=
    rx224_cur."!cursor_pos"(rx224_pos)
    .const 'Sub' $P227 = "68_1256021810.94784" 
    capture_lex $P227
    $P10 = rx224_cur."before"($P227)
    unless $P10, rx224_fail
    goto alt225_end
  alt225_1:
  # rx subrule "assertion" subtype=capture negate=
    rx224_cur."!cursor_pos"(rx224_pos)
    $P10 = rx224_cur."assertion"()
    unless $P10, rx224_fail
    rx224_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("assertion")
    rx224_pos = $P10."pos"()
  alt225_end:
  # rx pass
    rx224_cur."!cursor_pass"(rx224_pos, "assertion:sym<!>")
    .return (rx224_cur)
  rx224_fail:
    (rx224_rep, rx224_pos, $I10, $P10) = rx224_cur."!mark_fail"(0)
    lt rx224_pos, -1, rx224_done
    eq rx224_pos, -1, rx224_fail
    jump $I10
  rx224_done:
    rx224_cur."!cursor_fail"()
    .return (rx224_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block226"  :anon :subid("68_1256021810.94784") :method :outer("67_1256021810.94784")
.annotate "line", 115
    .local string rx228_tgt
    .local int rx228_pos
    .local int rx228_off
    .local int rx228_eos
    .local int rx228_rep
    .local pmc rx228_cur
    (rx228_cur, rx228_pos, rx228_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx228_cur
    length rx228_eos, rx228_tgt
    set rx228_off, 0
    lt $I10, 2, rx228_start
    sub rx228_off, $I10, 1
    substr rx228_tgt, rx228_tgt, rx228_off
  rx228_start:
    ge rx228_pos, 0, rxscan229_done
  rxscan229_loop:
    ($P10) = rx228_cur."from"()
    inc $P10
    set rx228_pos, $P10
    ge rx228_pos, rx228_eos, rxscan229_done
    set_addr $I10, rxscan229_loop
    rx228_cur."!mark_push"(0, rx228_pos, $I10)
  rxscan229_done:
  # rx literal  ">"
    add $I11, rx228_pos, 1
    gt $I11, rx228_eos, rx228_fail
    sub $I11, rx228_pos, rx228_off
    substr $S10, rx228_tgt, $I11, 1
    ne $S10, ">", rx228_fail
    add rx228_pos, 1
  # rx pass
    rx228_cur."!cursor_pass"(rx228_pos, "")
    .return (rx228_cur)
  rx228_fail:
    (rx228_rep, rx228_pos, $I10, $P10) = rx228_cur."!mark_fail"(0)
    lt rx228_pos, -1, rx228_done
    eq rx228_pos, -1, rx228_fail
    jump $I10
  rx228_done:
    rx228_cur."!cursor_fail"()
    .return (rx228_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion:sym<method>"  :subid("69_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 117
    .local string rx231_tgt
    .local int rx231_pos
    .local int rx231_off
    .local int rx231_eos
    .local int rx231_rep
    .local pmc rx231_cur
    (rx231_cur, rx231_pos, rx231_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx231_cur
    length rx231_eos, rx231_tgt
    set rx231_off, 0
    lt $I10, 2, rx231_start
    sub rx231_off, $I10, 1
    substr rx231_tgt, rx231_tgt, rx231_off
  rx231_start:
.annotate "line", 118
  # rx literal  "."
    add $I11, rx231_pos, 1
    gt $I11, rx231_eos, rx231_fail
    sub $I11, rx231_pos, rx231_off
    substr $S10, rx231_tgt, $I11, 1
    ne $S10, ".", rx231_fail
    add rx231_pos, 1
  # rx subrule "assertion" subtype=capture negate=
    rx231_cur."!cursor_pos"(rx231_pos)
    $P10 = rx231_cur."assertion"()
    unless $P10, rx231_fail
    rx231_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("assertion")
    rx231_pos = $P10."pos"()
.annotate "line", 117
  # rx pass
    rx231_cur."!cursor_pass"(rx231_pos, "assertion:sym<method>")
    .return (rx231_cur)
  rx231_fail:
    (rx231_rep, rx231_pos, $I10, $P10) = rx231_cur."!mark_fail"(0)
    lt rx231_pos, -1, rx231_done
    eq rx231_pos, -1, rx231_fail
    jump $I10
  rx231_done:
    rx231_cur."!cursor_fail"()
    .return (rx231_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion:sym<name>"  :subid("70_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 121
    .const 'Sub' $P238 = "71_1256021810.94784" 
    capture_lex $P238
    .local string rx233_tgt
    .local int rx233_pos
    .local int rx233_off
    .local int rx233_eos
    .local int rx233_rep
    .local pmc rx233_cur
    (rx233_cur, rx233_pos, rx233_tgt, $I10) = self."!cursor_start"()
    rx233_cur."!cursor_caparray"("nibbler", "arglist", "assertion")
    .lex unicode:"$\x{a2}", rx233_cur
    length rx233_eos, rx233_tgt
    set rx233_off, 0
    lt $I10, 2, rx233_start
    sub rx233_off, $I10, 1
    substr rx233_tgt, rx233_tgt, rx233_off
  rx233_start:
.annotate "line", 122
  # rx subcapture "longname"
    set_addr $I10, rxcap_234_fail
    rx233_cur."!mark_push"(0, rx233_pos, $I10)
  # rx charclass_q w r 1..-1
    sub $I10, rx233_pos, rx233_off
    find_not_cclass $I11, 8192, rx233_tgt, $I10, rx233_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx233_fail
    add rx233_pos, rx233_off, $I11
    set_addr $I10, rxcap_234_fail
    ($I12, $I11) = rx233_cur."!mark_peek"($I10)
    rx233_cur."!cursor_pos"($I11)
    ($P10) = rx233_cur."!cursor_start"()
    $P10."!cursor_pass"(rx233_pos, "")
    rx233_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("longname")
    goto rxcap_234_done
  rxcap_234_fail:
    goto rx233_fail
  rxcap_234_done:
.annotate "line", 129
  # rx rxquantr235 ** 0..1
    set_addr $I241, rxquantr235_done
    rx233_cur."!mark_push"(0, rx233_pos, $I241)
  rxquantr235_loop:
  alt236_0:
.annotate "line", 123
    set_addr $I10, alt236_1
    rx233_cur."!mark_push"(0, rx233_pos, $I10)
.annotate "line", 124
  # rx subrule "before" subtype=zerowidth negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    .const 'Sub' $P238 = "71_1256021810.94784" 
    capture_lex $P238
    $P10 = rx233_cur."before"($P238)
    unless $P10, rx233_fail
    goto alt236_end
  alt236_1:
    set_addr $I10, alt236_2
    rx233_cur."!mark_push"(0, rx233_pos, $I10)
.annotate "line", 125
  # rx literal  "="
    add $I11, rx233_pos, 1
    gt $I11, rx233_eos, rx233_fail
    sub $I11, rx233_pos, rx233_off
    substr $S10, rx233_tgt, $I11, 1
    ne $S10, "=", rx233_fail
    add rx233_pos, 1
  # rx subrule "assertion" subtype=capture negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    $P10 = rx233_cur."assertion"()
    unless $P10, rx233_fail
    rx233_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("assertion")
    rx233_pos = $P10."pos"()
    goto alt236_end
  alt236_2:
    set_addr $I10, alt236_3
    rx233_cur."!mark_push"(0, rx233_pos, $I10)
.annotate "line", 126
  # rx literal  ":"
    add $I11, rx233_pos, 1
    gt $I11, rx233_eos, rx233_fail
    sub $I11, rx233_pos, rx233_off
    substr $S10, rx233_tgt, $I11, 1
    ne $S10, ":", rx233_fail
    add rx233_pos, 1
  # rx subrule "arglist" subtype=capture negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    $P10 = rx233_cur."arglist"()
    unless $P10, rx233_fail
    rx233_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("arglist")
    rx233_pos = $P10."pos"()
    goto alt236_end
  alt236_3:
    set_addr $I10, alt236_4
    rx233_cur."!mark_push"(0, rx233_pos, $I10)
.annotate "line", 127
  # rx literal  "("
    add $I11, rx233_pos, 1
    gt $I11, rx233_eos, rx233_fail
    sub $I11, rx233_pos, rx233_off
    substr $S10, rx233_tgt, $I11, 1
    ne $S10, "(", rx233_fail
    add rx233_pos, 1
  # rx subrule "arglist" subtype=capture negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    $P10 = rx233_cur."arglist"()
    unless $P10, rx233_fail
    rx233_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("arglist")
    rx233_pos = $P10."pos"()
  # rx literal  ")"
    add $I11, rx233_pos, 1
    gt $I11, rx233_eos, rx233_fail
    sub $I11, rx233_pos, rx233_off
    substr $S10, rx233_tgt, $I11, 1
    ne $S10, ")", rx233_fail
    add rx233_pos, 1
    goto alt236_end
  alt236_4:
.annotate "line", 128
  # rx subrule "normspace" subtype=method negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    $P10 = rx233_cur."normspace"()
    unless $P10, rx233_fail
    rx233_pos = $P10."pos"()
  # rx subrule "nibbler" subtype=capture negate=
    rx233_cur."!cursor_pos"(rx233_pos)
    $P10 = rx233_cur."nibbler"()
    unless $P10, rx233_fail
    rx233_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("nibbler")
    rx233_pos = $P10."pos"()
  alt236_end:
.annotate "line", 129
    (rx233_rep) = rx233_cur."!mark_commit"($I241)
  rxquantr235_done:
.annotate "line", 121
  # rx pass
    rx233_cur."!cursor_pass"(rx233_pos, "assertion:sym<name>")
    .return (rx233_cur)
  rx233_fail:
    (rx233_rep, rx233_pos, $I10, $P10) = rx233_cur."!mark_fail"(0)
    lt rx233_pos, -1, rx233_done
    eq rx233_pos, -1, rx233_fail
    jump $I10
  rx233_done:
    rx233_cur."!cursor_fail"()
    .return (rx233_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block237"  :anon :subid("71_1256021810.94784") :method :outer("70_1256021810.94784")
.annotate "line", 124
    .local string rx239_tgt
    .local int rx239_pos
    .local int rx239_off
    .local int rx239_eos
    .local int rx239_rep
    .local pmc rx239_cur
    (rx239_cur, rx239_pos, rx239_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx239_cur
    length rx239_eos, rx239_tgt
    set rx239_off, 0
    lt $I10, 2, rx239_start
    sub rx239_off, $I10, 1
    substr rx239_tgt, rx239_tgt, rx239_off
  rx239_start:
    ge rx239_pos, 0, rxscan240_done
  rxscan240_loop:
    ($P10) = rx239_cur."from"()
    inc $P10
    set rx239_pos, $P10
    ge rx239_pos, rx239_eos, rxscan240_done
    set_addr $I10, rxscan240_loop
    rx239_cur."!mark_push"(0, rx239_pos, $I10)
  rxscan240_done:
  # rx literal  ">"
    add $I11, rx239_pos, 1
    gt $I11, rx239_eos, rx239_fail
    sub $I11, rx239_pos, rx239_off
    substr $S10, rx239_tgt, $I11, 1
    ne $S10, ">", rx239_fail
    add rx239_pos, 1
  # rx pass
    rx239_cur."!cursor_pass"(rx239_pos, "")
    .return (rx239_cur)
  rx239_fail:
    (rx239_rep, rx239_pos, $I10, $P10) = rx239_cur."!mark_fail"(0)
    lt rx239_pos, -1, rx239_done
    eq rx239_pos, -1, rx239_fail
    jump $I10
  rx239_done:
    rx239_cur."!cursor_fail"()
    .return (rx239_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "assertion:sym<[>"  :subid("72_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 132
    .const 'Sub' $P245 = "73_1256021810.94784" 
    capture_lex $P245
    .local string rx243_tgt
    .local int rx243_pos
    .local int rx243_off
    .local int rx243_eos
    .local int rx243_rep
    .local pmc rx243_cur
    (rx243_cur, rx243_pos, rx243_tgt, $I10) = self."!cursor_start"()
    rx243_cur."!cursor_caparray"("cclass_elem")
    .lex unicode:"$\x{a2}", rx243_cur
    length rx243_eos, rx243_tgt
    set rx243_off, 0
    lt $I10, 2, rx243_start
    sub rx243_off, $I10, 1
    substr rx243_tgt, rx243_tgt, rx243_off
  rx243_start:
  # rx subrule "before" subtype=zerowidth negate=
    rx243_cur."!cursor_pos"(rx243_pos)
    .const 'Sub' $P245 = "73_1256021810.94784" 
    capture_lex $P245
    $P10 = rx243_cur."before"($P245)
    unless $P10, rx243_fail
  # rx rxquantr249 ** 1..*
    set_addr $I250, rxquantr249_done
    rx243_cur."!mark_push"(0, -1, $I250)
  rxquantr249_loop:
  # rx subrule "cclass_elem" subtype=capture negate=
    rx243_cur."!cursor_pos"(rx243_pos)
    $P10 = rx243_cur."cclass_elem"()
    unless $P10, rx243_fail
    rx243_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("cclass_elem")
    rx243_pos = $P10."pos"()
    (rx243_rep) = rx243_cur."!mark_commit"($I250)
    rx243_cur."!mark_push"(rx243_rep, rx243_pos, $I250)
    goto rxquantr249_loop
  rxquantr249_done:
  # rx pass
    rx243_cur."!cursor_pass"(rx243_pos, "assertion:sym<[>")
    .return (rx243_cur)
  rx243_fail:
    (rx243_rep, rx243_pos, $I10, $P10) = rx243_cur."!mark_fail"(0)
    lt rx243_pos, -1, rx243_done
    eq rx243_pos, -1, rx243_fail
    jump $I10
  rx243_done:
    rx243_cur."!cursor_fail"()
    .return (rx243_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block244"  :anon :subid("73_1256021810.94784") :method :outer("72_1256021810.94784")
.annotate "line", 132
    .local string rx246_tgt
    .local int rx246_pos
    .local int rx246_off
    .local int rx246_eos
    .local int rx246_rep
    .local pmc rx246_cur
    (rx246_cur, rx246_pos, rx246_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx246_cur
    length rx246_eos, rx246_tgt
    set rx246_off, 0
    lt $I10, 2, rx246_start
    sub rx246_off, $I10, 1
    substr rx246_tgt, rx246_tgt, rx246_off
  rx246_start:
    ge rx246_pos, 0, rxscan247_done
  rxscan247_loop:
    ($P10) = rx246_cur."from"()
    inc $P10
    set rx246_pos, $P10
    ge rx246_pos, rx246_eos, rxscan247_done
    set_addr $I10, rxscan247_loop
    rx246_cur."!mark_push"(0, rx246_pos, $I10)
  rxscan247_done:
  alt248_0:
    set_addr $I10, alt248_1
    rx246_cur."!mark_push"(0, rx246_pos, $I10)
  # rx literal  "["
    add $I11, rx246_pos, 1
    gt $I11, rx246_eos, rx246_fail
    sub $I11, rx246_pos, rx246_off
    substr $S10, rx246_tgt, $I11, 1
    ne $S10, "[", rx246_fail
    add rx246_pos, 1
    goto alt248_end
  alt248_1:
    set_addr $I10, alt248_2
    rx246_cur."!mark_push"(0, rx246_pos, $I10)
  # rx literal  "+"
    add $I11, rx246_pos, 1
    gt $I11, rx246_eos, rx246_fail
    sub $I11, rx246_pos, rx246_off
    substr $S10, rx246_tgt, $I11, 1
    ne $S10, "+", rx246_fail
    add rx246_pos, 1
    goto alt248_end
  alt248_2:
  # rx literal  "-"
    add $I11, rx246_pos, 1
    gt $I11, rx246_eos, rx246_fail
    sub $I11, rx246_pos, rx246_off
    substr $S10, rx246_tgt, $I11, 1
    ne $S10, "-", rx246_fail
    add rx246_pos, 1
  alt248_end:
  # rx pass
    rx246_cur."!cursor_pass"(rx246_pos, "")
    .return (rx246_cur)
  rx246_fail:
    (rx246_rep, rx246_pos, $I10, $P10) = rx246_cur."!mark_fail"(0)
    lt rx246_pos, -1, rx246_done
    eq rx246_pos, -1, rx246_fail
    jump $I10
  rx246_done:
    rx246_cur."!cursor_fail"()
    .return (rx246_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "cclass_elem"  :subid("74_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 134
    .const 'Sub' $P260 = "75_1256021810.94784" 
    capture_lex $P260
    .local string rx252_tgt
    .local int rx252_pos
    .local int rx252_off
    .local int rx252_eos
    .local int rx252_rep
    .local pmc rx252_cur
    (rx252_cur, rx252_pos, rx252_tgt, $I10) = self."!cursor_start"()
    rx252_cur."!cursor_caparray"("charspec")
    .lex unicode:"$\x{a2}", rx252_cur
    length rx252_eos, rx252_tgt
    set rx252_off, 0
    lt $I10, 2, rx252_start
    sub rx252_off, $I10, 1
    substr rx252_tgt, rx252_tgt, rx252_off
  rx252_start:
.annotate "line", 135
  # rx subcapture "sign"
    set_addr $I10, rxcap_254_fail
    rx252_cur."!mark_push"(0, rx252_pos, $I10)
  alt253_0:
    set_addr $I10, alt253_1
    rx252_cur."!mark_push"(0, rx252_pos, $I10)
  # rx literal  "+"
    add $I11, rx252_pos, 1
    gt $I11, rx252_eos, rx252_fail
    sub $I11, rx252_pos, rx252_off
    substr $S10, rx252_tgt, $I11, 1
    ne $S10, "+", rx252_fail
    add rx252_pos, 1
    goto alt253_end
  alt253_1:
    set_addr $I10, alt253_2
    rx252_cur."!mark_push"(0, rx252_pos, $I10)
  # rx literal  "-"
    add $I11, rx252_pos, 1
    gt $I11, rx252_eos, rx252_fail
    sub $I11, rx252_pos, rx252_off
    substr $S10, rx252_tgt, $I11, 1
    ne $S10, "-", rx252_fail
    add rx252_pos, 1
    goto alt253_end
  alt253_2:
  alt253_end:
    set_addr $I10, rxcap_254_fail
    ($I12, $I11) = rx252_cur."!mark_peek"($I10)
    rx252_cur."!cursor_pos"($I11)
    ($P10) = rx252_cur."!cursor_start"()
    $P10."!cursor_pass"(rx252_pos, "")
    rx252_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sign")
    goto rxcap_254_done
  rxcap_254_fail:
    goto rx252_fail
  rxcap_254_done:
.annotate "line", 136
  # rx rxquantr255 ** 0..1
    set_addr $I256, rxquantr255_done
    rx252_cur."!mark_push"(0, rx252_pos, $I256)
  rxquantr255_loop:
  # rx subrule "normspace" subtype=method negate=
    rx252_cur."!cursor_pos"(rx252_pos)
    $P10 = rx252_cur."normspace"()
    unless $P10, rx252_fail
    rx252_pos = $P10."pos"()
    (rx252_rep) = rx252_cur."!mark_commit"($I256)
  rxquantr255_done:
  alt257_0:
.annotate "line", 137
    set_addr $I10, alt257_1
    rx252_cur."!mark_push"(0, rx252_pos, $I10)
.annotate "line", 138
  # rx literal  "["
    add $I11, rx252_pos, 1
    gt $I11, rx252_eos, rx252_fail
    sub $I11, rx252_pos, rx252_off
    substr $S10, rx252_tgt, $I11, 1
    ne $S10, "[", rx252_fail
    add rx252_pos, 1
.annotate "line", 141
  # rx rxquantr258 ** 0..*
    set_addr $I279, rxquantr258_done
    rx252_cur."!mark_push"(0, rx252_pos, $I279)
  rxquantr258_loop:
.annotate "line", 138
  # rx subrule $P260 subtype=capture negate=
    rx252_cur."!cursor_pos"(rx252_pos)
    .const 'Sub' $P260 = "75_1256021810.94784" 
    capture_lex $P260
    $P10 = rx252_cur.$P260()
    unless $P10, rx252_fail
    rx252_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("charspec")
    rx252_pos = $P10."pos"()
.annotate "line", 141
    (rx252_rep) = rx252_cur."!mark_commit"($I279)
    rx252_cur."!mark_push"(rx252_rep, rx252_pos, $I279)
    goto rxquantr258_loop
  rxquantr258_done:
.annotate "line", 142
  # rx charclass_q s r 0..-1
    sub $I10, rx252_pos, rx252_off
    find_not_cclass $I11, 32, rx252_tgt, $I10, rx252_eos
    add rx252_pos, rx252_off, $I11
  # rx literal  "]"
    add $I11, rx252_pos, 1
    gt $I11, rx252_eos, rx252_fail
    sub $I11, rx252_pos, rx252_off
    substr $S10, rx252_tgt, $I11, 1
    ne $S10, "]", rx252_fail
    add rx252_pos, 1
.annotate "line", 138
    goto alt257_end
  alt257_1:
.annotate "line", 143
  # rx subcapture "name"
    set_addr $I10, rxcap_280_fail
    rx252_cur."!mark_push"(0, rx252_pos, $I10)
  # rx charclass_q w r 1..-1
    sub $I10, rx252_pos, rx252_off
    find_not_cclass $I11, 8192, rx252_tgt, $I10, rx252_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx252_fail
    add rx252_pos, rx252_off, $I11
    set_addr $I10, rxcap_280_fail
    ($I12, $I11) = rx252_cur."!mark_peek"($I10)
    rx252_cur."!cursor_pos"($I11)
    ($P10) = rx252_cur."!cursor_start"()
    $P10."!cursor_pass"(rx252_pos, "")
    rx252_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("name")
    goto rxcap_280_done
  rxcap_280_fail:
    goto rx252_fail
  rxcap_280_done:
  alt257_end:
.annotate "line", 145
  # rx rxquantr281 ** 0..1
    set_addr $I282, rxquantr281_done
    rx252_cur."!mark_push"(0, rx252_pos, $I282)
  rxquantr281_loop:
  # rx subrule "normspace" subtype=method negate=
    rx252_cur."!cursor_pos"(rx252_pos)
    $P10 = rx252_cur."normspace"()
    unless $P10, rx252_fail
    rx252_pos = $P10."pos"()
    (rx252_rep) = rx252_cur."!mark_commit"($I282)
  rxquantr281_done:
.annotate "line", 134
  # rx pass
    rx252_cur."!cursor_pass"(rx252_pos, "cclass_elem")
    .return (rx252_cur)
  rx252_fail:
    (rx252_rep, rx252_pos, $I10, $P10) = rx252_cur."!mark_fail"(0)
    lt rx252_pos, -1, rx252_done
    eq rx252_pos, -1, rx252_fail
    jump $I10
  rx252_done:
    rx252_cur."!cursor_fail"()
    .return (rx252_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block259"  :anon :subid("75_1256021810.94784") :method :outer("74_1256021810.94784")
.annotate "line", 138
    .const 'Sub' $P275 = "78_1256021810.94784" 
    capture_lex $P275
    .const 'Sub' $P270 = "77_1256021810.94784" 
    capture_lex $P270
    .const 'Sub' $P266 = "76_1256021810.94784" 
    capture_lex $P266
    .local string rx261_tgt
    .local int rx261_pos
    .local int rx261_off
    .local int rx261_eos
    .local int rx261_rep
    .local pmc rx261_cur
    (rx261_cur, rx261_pos, rx261_tgt, $I10) = self."!cursor_start"()
    rx261_cur."!cursor_caparray"("1")
    .lex unicode:"$\x{a2}", rx261_cur
    length rx261_eos, rx261_tgt
    set rx261_off, 0
    lt $I10, 2, rx261_start
    sub rx261_off, $I10, 1
    substr rx261_tgt, rx261_tgt, rx261_off
  rx261_start:
    ge rx261_pos, 0, rxscan262_done
  rxscan262_loop:
    ($P10) = rx261_cur."from"()
    inc $P10
    set rx261_pos, $P10
    ge rx261_pos, rx261_eos, rxscan262_done
    set_addr $I10, rxscan262_loop
    rx261_cur."!mark_push"(0, rx261_pos, $I10)
  rxscan262_done:
  alt263_0:
    set_addr $I10, alt263_1
    rx261_cur."!mark_push"(0, rx261_pos, $I10)
.annotate "line", 139
  # rx charclass_q s r 0..-1
    sub $I10, rx261_pos, rx261_off
    find_not_cclass $I11, 32, rx261_tgt, $I10, rx261_eos
    add rx261_pos, rx261_off, $I11
  # rx literal  "-"
    add $I11, rx261_pos, 1
    gt $I11, rx261_eos, rx261_fail
    sub $I11, rx261_pos, rx261_off
    substr $S10, rx261_tgt, $I11, 1
    ne $S10, "-", rx261_fail
    add rx261_pos, 1
  # rx subrule "obs" subtype=method negate=
    rx261_cur."!cursor_pos"(rx261_pos)
    $P10 = rx261_cur."obs"("hyphen in enumerated character class;..")
    unless $P10, rx261_fail
    rx261_pos = $P10."pos"()
    goto alt263_end
  alt263_1:
.annotate "line", 140
  # rx charclass_q s r 0..-1
    sub $I10, rx261_pos, rx261_off
    find_not_cclass $I11, 32, rx261_tgt, $I10, rx261_eos
    add rx261_pos, rx261_off, $I11
  alt264_0:
    set_addr $I10, alt264_1
    rx261_cur."!mark_push"(0, rx261_pos, $I10)
  # rx literal  "\\"
    add $I11, rx261_pos, 1
    gt $I11, rx261_eos, rx261_fail
    sub $I11, rx261_pos, rx261_off
    substr $S10, rx261_tgt, $I11, 1
    ne $S10, "\\", rx261_fail
    add rx261_pos, 1
  # rx subrule $P266 subtype=capture negate=
    rx261_cur."!cursor_pos"(rx261_pos)
    .const 'Sub' $P266 = "76_1256021810.94784" 
    capture_lex $P266
    $P10 = rx261_cur.$P266()
    unless $P10, rx261_fail
    rx261_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"(0)
    rx261_pos = $P10."pos"()
    goto alt264_end
  alt264_1:
  # rx subrule $P270 subtype=capture negate=
    rx261_cur."!cursor_pos"(rx261_pos)
    .const 'Sub' $P270 = "77_1256021810.94784" 
    capture_lex $P270
    $P10 = rx261_cur.$P270()
    unless $P10, rx261_fail
    rx261_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"(0)
    rx261_pos = $P10."pos"()
  alt264_end:
  # rx rxquantr273 ** 0..1
    set_addr $I278, rxquantr273_done
    rx261_cur."!mark_push"(0, rx261_pos, $I278)
  rxquantr273_loop:
  # rx charclass_q s r 0..-1
    sub $I10, rx261_pos, rx261_off
    find_not_cclass $I11, 32, rx261_tgt, $I10, rx261_eos
    add rx261_pos, rx261_off, $I11
  # rx literal  ".."
    add $I11, rx261_pos, 2
    gt $I11, rx261_eos, rx261_fail
    sub $I11, rx261_pos, rx261_off
    substr $S10, rx261_tgt, $I11, 2
    ne $S10, "..", rx261_fail
    add rx261_pos, 2
  # rx charclass_q s r 0..-1
    sub $I10, rx261_pos, rx261_off
    find_not_cclass $I11, 32, rx261_tgt, $I10, rx261_eos
    add rx261_pos, rx261_off, $I11
  # rx subrule $P275 subtype=capture negate=
    rx261_cur."!cursor_pos"(rx261_pos)
    .const 'Sub' $P275 = "78_1256021810.94784" 
    capture_lex $P275
    $P10 = rx261_cur.$P275()
    unless $P10, rx261_fail
    rx261_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("1")
    rx261_pos = $P10."pos"()
    (rx261_rep) = rx261_cur."!mark_commit"($I278)
  rxquantr273_done:
  alt263_end:
.annotate "line", 138
  # rx pass
    rx261_cur."!cursor_pass"(rx261_pos, "")
    .return (rx261_cur)
  rx261_fail:
    (rx261_rep, rx261_pos, $I10, $P10) = rx261_cur."!mark_fail"(0)
    lt rx261_pos, -1, rx261_done
    eq rx261_pos, -1, rx261_fail
    jump $I10
  rx261_done:
    rx261_cur."!cursor_fail"()
    .return (rx261_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block265"  :anon :subid("76_1256021810.94784") :method :outer("75_1256021810.94784")
.annotate "line", 140
    .local string rx267_tgt
    .local int rx267_pos
    .local int rx267_off
    .local int rx267_eos
    .local int rx267_rep
    .local pmc rx267_cur
    (rx267_cur, rx267_pos, rx267_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx267_cur
    length rx267_eos, rx267_tgt
    set rx267_off, 0
    lt $I10, 2, rx267_start
    sub rx267_off, $I10, 1
    substr rx267_tgt, rx267_tgt, rx267_off
  rx267_start:
    ge rx267_pos, 0, rxscan268_done
  rxscan268_loop:
    ($P10) = rx267_cur."from"()
    inc $P10
    set rx267_pos, $P10
    ge rx267_pos, rx267_eos, rxscan268_done
    set_addr $I10, rxscan268_loop
    rx267_cur."!mark_push"(0, rx267_pos, $I10)
  rxscan268_done:
  # rx charclass .
    ge rx267_pos, rx267_eos, rx267_fail
    inc rx267_pos
  # rx pass
    rx267_cur."!cursor_pass"(rx267_pos, "")
    .return (rx267_cur)
  rx267_fail:
    (rx267_rep, rx267_pos, $I10, $P10) = rx267_cur."!mark_fail"(0)
    lt rx267_pos, -1, rx267_done
    eq rx267_pos, -1, rx267_fail
    jump $I10
  rx267_done:
    rx267_cur."!cursor_fail"()
    .return (rx267_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block269"  :anon :subid("77_1256021810.94784") :method :outer("75_1256021810.94784")
.annotate "line", 140
    .local string rx271_tgt
    .local int rx271_pos
    .local int rx271_off
    .local int rx271_eos
    .local int rx271_rep
    .local pmc rx271_cur
    (rx271_cur, rx271_pos, rx271_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx271_cur
    length rx271_eos, rx271_tgt
    set rx271_off, 0
    lt $I10, 2, rx271_start
    sub rx271_off, $I10, 1
    substr rx271_tgt, rx271_tgt, rx271_off
  rx271_start:
    ge rx271_pos, 0, rxscan272_done
  rxscan272_loop:
    ($P10) = rx271_cur."from"()
    inc $P10
    set rx271_pos, $P10
    ge rx271_pos, rx271_eos, rxscan272_done
    set_addr $I10, rxscan272_loop
    rx271_cur."!mark_push"(0, rx271_pos, $I10)
  rxscan272_done:
  # rx enumcharlist negate=1 
    ge rx271_pos, rx271_eos, rx271_fail
    sub $I10, rx271_pos, rx271_off
    substr $S10, rx271_tgt, $I10, 1
    index $I11, "]\\", $S10
    ge $I11, 0, rx271_fail
    inc rx271_pos
  # rx pass
    rx271_cur."!cursor_pass"(rx271_pos, "")
    .return (rx271_cur)
  rx271_fail:
    (rx271_rep, rx271_pos, $I10, $P10) = rx271_cur."!mark_fail"(0)
    lt rx271_pos, -1, rx271_done
    eq rx271_pos, -1, rx271_fail
    jump $I10
  rx271_done:
    rx271_cur."!cursor_fail"()
    .return (rx271_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block274"  :anon :subid("78_1256021810.94784") :method :outer("75_1256021810.94784")
.annotate "line", 140
    .local string rx276_tgt
    .local int rx276_pos
    .local int rx276_off
    .local int rx276_eos
    .local int rx276_rep
    .local pmc rx276_cur
    (rx276_cur, rx276_pos, rx276_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx276_cur
    length rx276_eos, rx276_tgt
    set rx276_off, 0
    lt $I10, 2, rx276_start
    sub rx276_off, $I10, 1
    substr rx276_tgt, rx276_tgt, rx276_off
  rx276_start:
    ge rx276_pos, 0, rxscan277_done
  rxscan277_loop:
    ($P10) = rx276_cur."from"()
    inc $P10
    set rx276_pos, $P10
    ge rx276_pos, rx276_eos, rxscan277_done
    set_addr $I10, rxscan277_loop
    rx276_cur."!mark_push"(0, rx276_pos, $I10)
  rxscan277_done:
  # rx charclass .
    ge rx276_pos, rx276_eos, rx276_fail
    inc rx276_pos
  # rx pass
    rx276_cur."!cursor_pass"(rx276_pos, "")
    .return (rx276_cur)
  rx276_fail:
    (rx276_rep, rx276_pos, $I10, $P10) = rx276_cur."!mark_fail"(0)
    lt rx276_pos, -1, rx276_done
    eq rx276_pos, -1, rx276_fail
    jump $I10
  rx276_done:
    rx276_cur."!cursor_fail"()
    .return (rx276_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "mod_internal"  :subid("79_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 148
    .const 'Sub' $P288 = "80_1256021810.94784" 
    capture_lex $P288
    .local string rx284_tgt
    .local int rx284_pos
    .local int rx284_off
    .local int rx284_eos
    .local int rx284_rep
    .local pmc rx284_cur
    (rx284_cur, rx284_pos, rx284_tgt, $I10) = self."!cursor_start"()
    rx284_cur."!cursor_caparray"("n")
    .lex unicode:"$\x{a2}", rx284_cur
    length rx284_eos, rx284_tgt
    set rx284_off, 0
    lt $I10, 2, rx284_start
    sub rx284_off, $I10, 1
    substr rx284_tgt, rx284_tgt, rx284_off
  rx284_start:
  alt285_0:
.annotate "line", 149
    set_addr $I10, alt285_1
    rx284_cur."!mark_push"(0, rx284_pos, $I10)
.annotate "line", 150
  # rx literal  ":"
    add $I11, rx284_pos, 1
    gt $I11, rx284_eos, rx284_fail
    sub $I11, rx284_pos, rx284_off
    substr $S10, rx284_tgt, $I11, 1
    ne $S10, ":", rx284_fail
    add rx284_pos, 1
  # rx rxquantr286 ** 1..1
    set_addr $I292, rxquantr286_done
    rx284_cur."!mark_push"(0, -1, $I292)
  rxquantr286_loop:
  # rx subrule $P288 subtype=capture negate=
    rx284_cur."!cursor_pos"(rx284_pos)
    .const 'Sub' $P288 = "80_1256021810.94784" 
    capture_lex $P288
    $P10 = rx284_cur.$P288()
    unless $P10, rx284_fail
    rx284_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("n")
    rx284_pos = $P10."pos"()
    (rx284_rep) = rx284_cur."!mark_commit"($I292)
  rxquantr286_done:
  # rx subrule "mod_ident" subtype=capture negate=
    rx284_cur."!cursor_pos"(rx284_pos)
    $P10 = rx284_cur."mod_ident"()
    unless $P10, rx284_fail
    rx284_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("mod_ident")
    rx284_pos = $P10."pos"()
  # rxanchor rwb
    le rx284_pos, 0, rx284_fail
    sub $I10, rx284_pos, rx284_off
    is_cclass $I11, 8192, rx284_tgt, $I10
    if $I11, rx284_fail
    dec $I10
    is_cclass $I11, 8192, rx284_tgt, $I10
    unless $I11, rx284_fail
    goto alt285_end
  alt285_1:
.annotate "line", 151
  # rx literal  ":"
    add $I11, rx284_pos, 1
    gt $I11, rx284_eos, rx284_fail
    sub $I11, rx284_pos, rx284_off
    substr $S10, rx284_tgt, $I11, 1
    ne $S10, ":", rx284_fail
    add rx284_pos, 1
  # rx subrule "mod_ident" subtype=capture negate=
    rx284_cur."!cursor_pos"(rx284_pos)
    $P10 = rx284_cur."mod_ident"()
    unless $P10, rx284_fail
    rx284_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("mod_ident")
    rx284_pos = $P10."pos"()
  # rx rxquantr293 ** 0..1
    set_addr $I295, rxquantr293_done
    rx284_cur."!mark_push"(0, rx284_pos, $I295)
  rxquantr293_loop:
  # rx literal  "("
    add $I11, rx284_pos, 1
    gt $I11, rx284_eos, rx284_fail
    sub $I11, rx284_pos, rx284_off
    substr $S10, rx284_tgt, $I11, 1
    ne $S10, "(", rx284_fail
    add rx284_pos, 1
  # rx subcapture "n"
    set_addr $I10, rxcap_294_fail
    rx284_cur."!mark_push"(0, rx284_pos, $I10)
  # rx charclass_q d r 1..-1
    sub $I10, rx284_pos, rx284_off
    find_not_cclass $I11, 8, rx284_tgt, $I10, rx284_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx284_fail
    add rx284_pos, rx284_off, $I11
    set_addr $I10, rxcap_294_fail
    ($I12, $I11) = rx284_cur."!mark_peek"($I10)
    rx284_cur."!cursor_pos"($I11)
    ($P10) = rx284_cur."!cursor_start"()
    $P10."!cursor_pass"(rx284_pos, "")
    rx284_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("n")
    goto rxcap_294_done
  rxcap_294_fail:
    goto rx284_fail
  rxcap_294_done:
  # rx literal  ")"
    add $I11, rx284_pos, 1
    gt $I11, rx284_eos, rx284_fail
    sub $I11, rx284_pos, rx284_off
    substr $S10, rx284_tgt, $I11, 1
    ne $S10, ")", rx284_fail
    add rx284_pos, 1
    (rx284_rep) = rx284_cur."!mark_commit"($I295)
  rxquantr293_done:
  alt285_end:
.annotate "line", 148
  # rx pass
    rx284_cur."!cursor_pass"(rx284_pos, "mod_internal")
    .return (rx284_cur)
  rx284_fail:
    (rx284_rep, rx284_pos, $I10, $P10) = rx284_cur."!mark_fail"(0)
    lt rx284_pos, -1, rx284_done
    eq rx284_pos, -1, rx284_fail
    jump $I10
  rx284_done:
    rx284_cur."!cursor_fail"()
    .return (rx284_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "_block287"  :anon :subid("80_1256021810.94784") :method :outer("79_1256021810.94784")
.annotate "line", 150
    .local string rx289_tgt
    .local int rx289_pos
    .local int rx289_off
    .local int rx289_eos
    .local int rx289_rep
    .local pmc rx289_cur
    (rx289_cur, rx289_pos, rx289_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx289_cur
    length rx289_eos, rx289_tgt
    set rx289_off, 0
    lt $I10, 2, rx289_start
    sub rx289_off, $I10, 1
    substr rx289_tgt, rx289_tgt, rx289_off
  rx289_start:
    ge rx289_pos, 0, rxscan290_done
  rxscan290_loop:
    ($P10) = rx289_cur."from"()
    inc $P10
    set rx289_pos, $P10
    ge rx289_pos, rx289_eos, rxscan290_done
    set_addr $I10, rxscan290_loop
    rx289_cur."!mark_push"(0, rx289_pos, $I10)
  rxscan290_done:
  alt291_0:
    set_addr $I10, alt291_1
    rx289_cur."!mark_push"(0, rx289_pos, $I10)
  # rx literal  "!"
    add $I11, rx289_pos, 1
    gt $I11, rx289_eos, rx289_fail
    sub $I11, rx289_pos, rx289_off
    substr $S10, rx289_tgt, $I11, 1
    ne $S10, "!", rx289_fail
    add rx289_pos, 1
    goto alt291_end
  alt291_1:
  # rx charclass_q d r 1..-1
    sub $I10, rx289_pos, rx289_off
    find_not_cclass $I11, 8, rx289_tgt, $I10, rx289_eos
    add $I12, $I10, 1
    lt $I11, $I12, rx289_fail
    add rx289_pos, rx289_off, $I11
  alt291_end:
  # rx pass
    rx289_cur."!cursor_pass"(rx289_pos, "")
    .return (rx289_cur)
  rx289_fail:
    (rx289_rep, rx289_pos, $I10, $P10) = rx289_cur."!mark_fail"(0)
    lt rx289_pos, -1, rx289_done
    eq rx289_pos, -1, rx289_fail
    jump $I10
  rx289_done:
    rx289_cur."!cursor_fail"()
    .return (rx289_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "mod_ident"  :subid("81_1256021810.94784") :method
.annotate "line", 155
    $P297 = self."!protoregex"("mod_ident")
    .return ($P297)
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "mod_ident:sym<ignorecase>"  :subid("82_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 156
    .local string rx299_tgt
    .local int rx299_pos
    .local int rx299_off
    .local int rx299_eos
    .local int rx299_rep
    .local pmc rx299_cur
    (rx299_cur, rx299_pos, rx299_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx299_cur
    length rx299_eos, rx299_tgt
    set rx299_off, 0
    lt $I10, 2, rx299_start
    sub rx299_off, $I10, 1
    substr rx299_tgt, rx299_tgt, rx299_off
  rx299_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_300_fail
    rx299_cur."!mark_push"(0, rx299_pos, $I10)
  # rx literal  "i"
    add $I11, rx299_pos, 1
    gt $I11, rx299_eos, rx299_fail
    sub $I11, rx299_pos, rx299_off
    substr $S10, rx299_tgt, $I11, 1
    ne $S10, "i", rx299_fail
    add rx299_pos, 1
    set_addr $I10, rxcap_300_fail
    ($I12, $I11) = rx299_cur."!mark_peek"($I10)
    rx299_cur."!cursor_pos"($I11)
    ($P10) = rx299_cur."!cursor_start"()
    $P10."!cursor_pass"(rx299_pos, "")
    rx299_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_300_done
  rxcap_300_fail:
    goto rx299_fail
  rxcap_300_done:
  # rx rxquantr301 ** 0..1
    set_addr $I302, rxquantr301_done
    rx299_cur."!mark_push"(0, rx299_pos, $I302)
  rxquantr301_loop:
  # rx literal  "gnorecase"
    add $I11, rx299_pos, 9
    gt $I11, rx299_eos, rx299_fail
    sub $I11, rx299_pos, rx299_off
    substr $S10, rx299_tgt, $I11, 9
    ne $S10, "gnorecase", rx299_fail
    add rx299_pos, 9
    (rx299_rep) = rx299_cur."!mark_commit"($I302)
  rxquantr301_done:
  # rx pass
    rx299_cur."!cursor_pass"(rx299_pos, "mod_ident:sym<ignorecase>")
    .return (rx299_cur)
  rx299_fail:
    (rx299_rep, rx299_pos, $I10, $P10) = rx299_cur."!mark_fail"(0)
    lt rx299_pos, -1, rx299_done
    eq rx299_pos, -1, rx299_fail
    jump $I10
  rx299_done:
    rx299_cur."!cursor_fail"()
    .return (rx299_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "mod_ident:sym<ratchet>"  :subid("83_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 157
    .local string rx304_tgt
    .local int rx304_pos
    .local int rx304_off
    .local int rx304_eos
    .local int rx304_rep
    .local pmc rx304_cur
    (rx304_cur, rx304_pos, rx304_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx304_cur
    length rx304_eos, rx304_tgt
    set rx304_off, 0
    lt $I10, 2, rx304_start
    sub rx304_off, $I10, 1
    substr rx304_tgt, rx304_tgt, rx304_off
  rx304_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_305_fail
    rx304_cur."!mark_push"(0, rx304_pos, $I10)
  # rx literal  "r"
    add $I11, rx304_pos, 1
    gt $I11, rx304_eos, rx304_fail
    sub $I11, rx304_pos, rx304_off
    substr $S10, rx304_tgt, $I11, 1
    ne $S10, "r", rx304_fail
    add rx304_pos, 1
    set_addr $I10, rxcap_305_fail
    ($I12, $I11) = rx304_cur."!mark_peek"($I10)
    rx304_cur."!cursor_pos"($I11)
    ($P10) = rx304_cur."!cursor_start"()
    $P10."!cursor_pass"(rx304_pos, "")
    rx304_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_305_done
  rxcap_305_fail:
    goto rx304_fail
  rxcap_305_done:
  # rx rxquantr306 ** 0..1
    set_addr $I307, rxquantr306_done
    rx304_cur."!mark_push"(0, rx304_pos, $I307)
  rxquantr306_loop:
  # rx literal  "atchet"
    add $I11, rx304_pos, 6
    gt $I11, rx304_eos, rx304_fail
    sub $I11, rx304_pos, rx304_off
    substr $S10, rx304_tgt, $I11, 6
    ne $S10, "atchet", rx304_fail
    add rx304_pos, 6
    (rx304_rep) = rx304_cur."!mark_commit"($I307)
  rxquantr306_done:
  # rx pass
    rx304_cur."!cursor_pass"(rx304_pos, "mod_ident:sym<ratchet>")
    .return (rx304_cur)
  rx304_fail:
    (rx304_rep, rx304_pos, $I10, $P10) = rx304_cur."!mark_fail"(0)
    lt rx304_pos, -1, rx304_done
    eq rx304_pos, -1, rx304_fail
    jump $I10
  rx304_done:
    rx304_cur."!cursor_fail"()
    .return (rx304_cur)
    .return ()
.end


.namespace ["Regex";"P6Regex";"Grammar"]
.sub "mod_ident:sym<sigspace>"  :subid("84_1256021810.94784") :method :outer("10_1256021810.94784")
.annotate "line", 158
    .local string rx309_tgt
    .local int rx309_pos
    .local int rx309_off
    .local int rx309_eos
    .local int rx309_rep
    .local pmc rx309_cur
    (rx309_cur, rx309_pos, rx309_tgt, $I10) = self."!cursor_start"()
    .lex unicode:"$\x{a2}", rx309_cur
    length rx309_eos, rx309_tgt
    set rx309_off, 0
    lt $I10, 2, rx309_start
    sub rx309_off, $I10, 1
    substr rx309_tgt, rx309_tgt, rx309_off
  rx309_start:
  # rx subcapture "sym"
    set_addr $I10, rxcap_310_fail
    rx309_cur."!mark_push"(0, rx309_pos, $I10)
  # rx literal  "s"
    add $I11, rx309_pos, 1
    gt $I11, rx309_eos, rx309_fail
    sub $I11, rx309_pos, rx309_off
    substr $S10, rx309_tgt, $I11, 1
    ne $S10, "s", rx309_fail
    add rx309_pos, 1
    set_addr $I10, rxcap_310_fail
    ($I12, $I11) = rx309_cur."!mark_peek"($I10)
    rx309_cur."!cursor_pos"($I11)
    ($P10) = rx309_cur."!cursor_start"()
    $P10."!cursor_pass"(rx309_pos, "")
    rx309_cur."!mark_push"(0, -1, 0, $P10)
    $P10."!cursor_names"("sym")
    goto rxcap_310_done
  rxcap_310_fail:
    goto rx309_fail
  rxcap_310_done:
  # rx rxquantr311 ** 0..1
    set_addr $I312, rxquantr311_done
    rx309_cur."!mark_push"(0, rx309_pos, $I312)
  rxquantr311_loop:
  # rx literal  "igspace"
    add $I11, rx309_pos, 7
    gt $I11, rx309_eos, rx309_fail
    sub $I11, rx309_pos, rx309_off
    substr $S10, rx309_tgt, $I11, 7
    ne $S10, "igspace", rx309_fail
    add rx309_pos, 7
    (rx309_rep) = rx309_cur."!mark_commit"($I312)
  rxquantr311_done:
  # rx pass
    rx309_cur."!cursor_pass"(rx309_pos, "mod_ident:sym<sigspace>")
    .return (rx309_cur)
  rx309_fail:
    (rx309_rep, rx309_pos, $I10, $P10) = rx309_cur."!mark_fail"(0)
    lt rx309_pos, -1, rx309_done
    eq rx309_pos, -1, rx309_fail
    jump $I10
  rx309_done:
    rx309_cur."!cursor_fail"()
    .return (rx309_cur)
    .return ()
.end

### .include 'src/gen/p6regex-actions.pir'

.namespace []
.sub "_block11"  :anon :subid("10_1256021422.69758")
.annotate "line", 4
    get_hll_global $P14, ["Regex";"P6Regex";"Actions"], "_block13" 
.annotate "line", 1
    .return ($P14)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block13" :init :load :subid("11_1256021422.69758")
.annotate "line", 4
    .const 'Sub' $P1390 = "120_1256021422.69758" 
    capture_lex $P1390
    .const 'Sub' $P1349 = "116_1256021422.69758" 
    capture_lex $P1349
    .const 'Sub' $P1086 = "98_1256021422.69758" 
    capture_lex $P1086
    .const 'Sub' $P1066 = "97_1256021422.69758" 
    capture_lex $P1066
    .const 'Sub' $P1039 = "96_1256021422.69758" 
    capture_lex $P1039
    .const 'Sub' $P971 = "90_1256021422.69758" 
    capture_lex $P971
    .const 'Sub' $P902 = "85_1256021422.69758" 
    capture_lex $P902
    .const 'Sub' $P832 = "79_1256021422.69758" 
    capture_lex $P832
    .const 'Sub' $P820 = "78_1256021422.69758" 
    capture_lex $P820
    .const 'Sub' $P792 = "75_1256021422.69758" 
    capture_lex $P792
    .const 'Sub' $P770 = "72_1256021422.69758" 
    capture_lex $P770
    .const 'Sub' $P757 = "71_1256021422.69758" 
    capture_lex $P757
    .const 'Sub' $P742 = "70_1256021422.69758" 
    capture_lex $P742
    .const 'Sub' $P727 = "69_1256021422.69758" 
    capture_lex $P727
    .const 'Sub' $P712 = "68_1256021422.69758" 
    capture_lex $P712
    .const 'Sub' $P697 = "67_1256021422.69758" 
    capture_lex $P697
    .const 'Sub' $P682 = "66_1256021422.69758" 
    capture_lex $P682
    .const 'Sub' $P667 = "65_1256021422.69758" 
    capture_lex $P667
    .const 'Sub' $P652 = "64_1256021422.69758" 
    capture_lex $P652
    .const 'Sub' $P630 = "63_1256021422.69758" 
    capture_lex $P630
    .const 'Sub' $P559 = "57_1256021422.69758" 
    capture_lex $P559
    .const 'Sub' $P539 = "56_1256021422.69758" 
    capture_lex $P539
    .const 'Sub' $P529 = "55_1256021422.69758" 
    capture_lex $P529
    .const 'Sub' $P519 = "54_1256021422.69758" 
    capture_lex $P519
    .const 'Sub' $P509 = "53_1256021422.69758" 
    capture_lex $P509
    .const 'Sub' $P498 = "52_1256021422.69758" 
    capture_lex $P498
    .const 'Sub' $P487 = "51_1256021422.69758" 
    capture_lex $P487
    .const 'Sub' $P476 = "50_1256021422.69758" 
    capture_lex $P476
    .const 'Sub' $P465 = "49_1256021422.69758" 
    capture_lex $P465
    .const 'Sub' $P454 = "48_1256021422.69758" 
    capture_lex $P454
    .const 'Sub' $P443 = "47_1256021422.69758" 
    capture_lex $P443
    .const 'Sub' $P432 = "46_1256021422.69758" 
    capture_lex $P432
    .const 'Sub' $P421 = "45_1256021422.69758" 
    capture_lex $P421
    .const 'Sub' $P406 = "44_1256021422.69758" 
    capture_lex $P406
    .const 'Sub' $P390 = "43_1256021422.69758" 
    capture_lex $P390
    .const 'Sub' $P380 = "42_1256021422.69758" 
    capture_lex $P380
    .const 'Sub' $P363 = "41_1256021422.69758" 
    capture_lex $P363
    .const 'Sub' $P303 = "36_1256021422.69758" 
    capture_lex $P303
    .const 'Sub' $P287 = "35_1256021422.69758" 
    capture_lex $P287
    .const 'Sub' $P273 = "34_1256021422.69758" 
    capture_lex $P273
    .const 'Sub' $P259 = "33_1256021422.69758" 
    capture_lex $P259
    .const 'Sub' $P225 = "29_1256021422.69758" 
    capture_lex $P225
    .const 'Sub' $P168 = "24_1256021422.69758" 
    capture_lex $P168
    .const 'Sub' $P107 = "19_1256021422.69758" 
    capture_lex $P107
    .const 'Sub' $P49 = "14_1256021422.69758" 
    capture_lex $P49
    .const 'Sub' $P35 = "13_1256021422.69758" 
    capture_lex $P35
    .const 'Sub' $P17 = "12_1256021422.69758" 
    capture_lex $P17
$P15 = get_root_global ["parrot"], "P6metaclass"
    $P15."new_class"("Regex::P6Regex::Actions")
 
        $P16 = new ['ResizablePMCArray'] 
        $P0 = new ['Hash']
        push $P16, $P0
    
    set_global "@MODIFIERS", $P16
.annotate "line", 485
    .const 'Sub' $P1390 = "120_1256021422.69758" 
    capture_lex $P1390
.annotate "line", 4
    .return ($P1390)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "arg"  :subid("12_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_20
.annotate "line", 10
    new $P19, 'ExceptionHandler'
    set_addr $P19, control_18
    $P19."handle_types"(58)
    push_eh $P19
    .lex "self", self
    .lex "$/", param_20
.annotate "line", 11
    find_lex $P21, "$/"
    find_lex $P24, "$/"
    set $P25, $P24["quote"]
    unless_null $P25, vivify_122
    new $P25, "Undef"
  vivify_122:
    if $P25, if_23
    find_lex $P30, "$/"
    set $P31, $P30["val"]
    unless_null $P31, vivify_123
    new $P31, "Undef"
  vivify_123:
    set $N32, $P31
    new $P22, 'Float'
    set $P22, $N32
    goto if_23_end
  if_23:
    find_lex $P26, "$/"
    set $P27, $P26["quote"]
    unless_null $P27, vivify_124
    new $P27, "Hash"
  vivify_124:
    set $P28, $P27["val"]
    unless_null $P28, vivify_125
    new $P28, "Undef"
  vivify_125:
    set $S29, $P28
    new $P22, 'String'
    set $P22, $S29
  if_23_end:
    $P33 = $P21."!make"($P22)
.annotate "line", 10
    .return ($P33)
  control_18:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P34, exception, "payload"
    .return ($P34)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "TOP"  :subid("13_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_38
.annotate "line", 14
    new $P37, 'ExceptionHandler'
    set_addr $P37, control_36
    $P37."handle_types"(58)
    push_eh $P37
    .lex "self", self
    .lex "$/", param_38
.annotate "line", 15
    find_lex $P39, "$/"
    set $P40, $P39["nibbler"]
    unless_null $P40, vivify_126
    new $P40, "Undef"
  vivify_126:
    $P41 = $P40."ast"()
    $P42 = "buildsub"($P41)
    .lex "$past", $P42
.annotate "line", 16
    find_lex $P43, "$past"
    unless_null $P43, vivify_127
    new $P43, "Undef"
  vivify_127:
    find_lex $P44, "$/"
    unless_null $P44, vivify_128
    new $P44, "Undef"
  vivify_128:
    $P43."node"($P44)
    find_lex $P45, "$/"
.annotate "line", 17
    find_lex $P46, "$past"
    unless_null $P46, vivify_129
    new $P46, "Undef"
  vivify_129:
    $P47 = $P45."!make"($P46)
.annotate "line", 14
    .return ($P47)
  control_36:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P48, exception, "payload"
    .return ($P48)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "nibbler"  :subid("14_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_52
    .param pmc param_53 :optional
    .param int has_param_53 :opt_flag
.annotate "line", 20
    .const 'Sub' $P98 = "18_1256021422.69758" 
    capture_lex $P98
    .const 'Sub' $P78 = "16_1256021422.69758" 
    capture_lex $P78
    .const 'Sub' $P60 = "15_1256021422.69758" 
    capture_lex $P60
    new $P51, 'ExceptionHandler'
    set_addr $P51, control_50
    $P51."handle_types"(58)
    push_eh $P51
    .lex "self", self
    .lex "$/", param_52
    if has_param_53, optparam_130
    new $P54, "Undef"
    set param_53, $P54
  optparam_130:
    .lex "$key", param_53
.annotate "line", 21
    find_lex $P56, "$key"
    unless_null $P56, vivify_131
    new $P56, "Undef"
  vivify_131:
    set $S57, $P56
    iseq $I58, $S57, "open"
    unless $I58, if_55_end
    .const 'Sub' $P60 = "15_1256021422.69758" 
    capture_lex $P60
    $P60()
  if_55_end:
.annotate "line", 31
    get_global $P68, "@MODIFIERS"
    unless_null $P68, vivify_136
    new $P68, "ResizablePMCArray"
  vivify_136:
    $P68."shift"()
.annotate "line", 32
    new $P69, "Undef"
    .lex "$past", $P69
.annotate "line", 33
    find_lex $P71, "$/"
    set $P72, $P71["termish"]
    unless_null $P72, vivify_137
    new $P72, "Undef"
  vivify_137:
    set $N73, $P72
    new $P74, "Integer"
    assign $P74, 1
    set $N75, $P74
    isgt $I76, $N73, $N75
    if $I76, if_70
.annotate "line", 39
    .const 'Sub' $P98 = "18_1256021422.69758" 
    capture_lex $P98
    $P98()
    goto if_70_end
  if_70:
.annotate "line", 33
    .const 'Sub' $P78 = "16_1256021422.69758" 
    capture_lex $P78
    $P78()
  if_70_end:
    find_lex $P103, "$/"
.annotate "line", 42
    find_lex $P104, "$past"
    unless_null $P104, vivify_145
    new $P104, "Undef"
  vivify_145:
    $P105 = $P103."!make"($P104)
.annotate "line", 20
    .return ($P105)
  control_50:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P106, exception, "payload"
    .return ($P106)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block59"  :anon :subid("15_1256021422.69758") :outer("14_1256021422.69758")
.annotate "line", 22
    get_global $P61, "@MODIFIERS"
    unless_null $P61, vivify_132
    new $P61, "ResizablePMCArray"
  vivify_132:
    set $P62, $P61[0]
    unless_null $P62, vivify_133
    new $P62, "Undef"
  vivify_133:
    .lex "%old", $P62
.annotate "line", 23

                       $P0 = find_lex '%old'
                       $P63 = clone $P0
                   
    .lex "%new", $P63
.annotate "line", 27
    get_global $P64, "@MODIFIERS"
    unless_null $P64, vivify_134
    new $P64, "ResizablePMCArray"
  vivify_134:
    find_lex $P65, "%new"
    unless_null $P65, vivify_135
    new $P65, "Hash"
  vivify_135:
    $P64."unshift"($P65)
.annotate "line", 28
    new $P66, "Exception"
    set $P66['type'], 58
    new $P67, "Integer"
    assign $P67, 1
    setattribute $P66, 'payload', $P67
    throw $P66
.annotate "line", 21
    .return ()
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block97"  :anon :subid("18_1256021422.69758") :outer("14_1256021422.69758")
.annotate "line", 40
    find_lex $P99, "$/"
    set $P100, $P99["termish"]
    unless_null $P100, vivify_138
    new $P100, "ResizablePMCArray"
  vivify_138:
    set $P101, $P100[0]
    unless_null $P101, vivify_139
    new $P101, "Undef"
  vivify_139:
    $P102 = $P101."ast"()
    store_lex "$past", $P102
.annotate "line", 39
    .return ($P102)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block77"  :anon :subid("16_1256021422.69758") :outer("14_1256021422.69758")
.annotate "line", 33
    .const 'Sub' $P88 = "17_1256021422.69758" 
    capture_lex $P88
.annotate "line", 34
    get_hll_global $P79, ["PAST"], "Regex"
    find_lex $P80, "$/"
    unless_null $P80, vivify_140
    new $P80, "Undef"
  vivify_140:
    $P81 = $P79."new"("alt" :named("pasttype"), $P80 :named("node"))
    store_lex "$past", $P81
.annotate "line", 35
    find_lex $P83, "$/"
    set $P84, $P83["termish"]
    unless_null $P84, vivify_141
    new $P84, "Undef"
  vivify_141:
    defined $I85, $P84
    unless $I85, for_undef_142
    iter $P82, $P84
    new $P95, 'ExceptionHandler'
    set_addr $P95, loop94_handler
    $P95."handle_types"(65, 67, 66)
    push_eh $P95
  loop94_test:
    unless $P82, loop94_done
    shift $P86, $P82
  loop94_redo:
    .const 'Sub' $P88 = "17_1256021422.69758" 
    capture_lex $P88
    $P88($P86)
  loop94_next:
    goto loop94_test
  loop94_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P96, exception, 'type'
    eq $P96, 65, loop94_next
    eq $P96, 67, loop94_redo
  loop94_done:
    pop_eh 
  for_undef_142:
.annotate "line", 33
    .return ($P82)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block87"  :anon :subid("17_1256021422.69758") :outer("16_1256021422.69758")
    .param pmc param_89
.annotate "line", 35
    .lex "$_", param_89
.annotate "line", 36
    find_lex $P90, "$past"
    unless_null $P90, vivify_143
    new $P90, "Undef"
  vivify_143:
    find_lex $P91, "$_"
    unless_null $P91, vivify_144
    new $P91, "Undef"
  vivify_144:
    $P92 = $P91."ast"()
    $P93 = $P90."push"($P92)
.annotate "line", 35
    .return ($P93)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "termish"  :subid("19_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_110
.annotate "line", 45
    .const 'Sub' $P121 = "20_1256021422.69758" 
    capture_lex $P121
    new $P109, 'ExceptionHandler'
    set_addr $P109, control_108
    $P109."handle_types"(58)
    push_eh $P109
    .lex "self", self
    .lex "$/", param_110
.annotate "line", 46
    get_hll_global $P111, ["PAST"], "Regex"
    find_lex $P112, "$/"
    unless_null $P112, vivify_146
    new $P112, "Undef"
  vivify_146:
    $P113 = $P111."new"("concat" :named("pasttype"), $P112 :named("node"))
    .lex "$past", $P113
.annotate "line", 47
    new $P114, "Integer"
    assign $P114, 0
    .lex "$lastlit", $P114
.annotate "line", 48
    find_lex $P116, "$/"
    set $P117, $P116["noun"]
    unless_null $P117, vivify_147
    new $P117, "Undef"
  vivify_147:
    defined $I118, $P117
    unless $I118, for_undef_148
    iter $P115, $P117
    new $P162, 'ExceptionHandler'
    set_addr $P162, loop161_handler
    $P162."handle_types"(65, 67, 66)
    push_eh $P162
  loop161_test:
    unless $P115, loop161_done
    shift $P119, $P115
  loop161_redo:
    .const 'Sub' $P121 = "20_1256021422.69758" 
    capture_lex $P121
    $P121($P119)
  loop161_next:
    goto loop161_test
  loop161_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P163, exception, 'type'
    eq $P163, 65, loop161_next
    eq $P163, 67, loop161_redo
  loop161_done:
    pop_eh 
  for_undef_148:
    find_lex $P164, "$/"
.annotate "line", 59
    find_lex $P165, "$past"
    unless_null $P165, vivify_162
    new $P165, "Undef"
  vivify_162:
    $P166 = $P164."!make"($P165)
.annotate "line", 45
    .return ($P166)
  control_108:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P167, exception, "payload"
    .return ($P167)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block120"  :anon :subid("20_1256021422.69758") :outer("19_1256021422.69758")
    .param pmc param_122
.annotate "line", 48
    .const 'Sub' $P150 = "23_1256021422.69758" 
    capture_lex $P150
    .const 'Sub' $P141 = "22_1256021422.69758" 
    capture_lex $P141
    .const 'Sub' $P130 = "21_1256021422.69758" 
    capture_lex $P130
    .lex "$_", param_122
.annotate "line", 49
    find_lex $P123, "$_"
    unless_null $P123, vivify_149
    new $P123, "Undef"
  vivify_149:
    $P124 = $P123."ast"()
    .lex "$ast", $P124
.annotate "line", 50
    find_lex $P127, "$ast"
    unless_null $P127, vivify_150
    new $P127, "Undef"
  vivify_150:
    isfalse $I128, $P127
    if $I128, if_126
.annotate "line", 51
    find_lex $P136, "$lastlit"
    unless_null $P136, vivify_151
    new $P136, "Undef"
  vivify_151:
    if $P136, if_135
    set $P134, $P136
    goto if_135_end
  if_135:
    find_lex $P137, "$ast"
    unless_null $P137, vivify_152
    new $P137, "Undef"
  vivify_152:
    $S138 = $P137."pasttype"()
    iseq $I139, $S138, "literal"
    new $P134, 'Integer'
    set $P134, $I139
  if_135_end:
    if $P134, if_133
.annotate "line", 54
    .const 'Sub' $P150 = "23_1256021422.69758" 
    capture_lex $P150
    $P160 = $P150()
    set $P132, $P160
.annotate "line", 51
    goto if_133_end
  if_133:
    .const 'Sub' $P141 = "22_1256021422.69758" 
    capture_lex $P141
    $P148 = $P141()
    set $P132, $P148
  if_133_end:
.annotate "line", 50
    set $P125, $P132
    goto if_126_end
  if_126:
    .const 'Sub' $P130 = "21_1256021422.69758" 
    capture_lex $P130
    $P131 = $P130()
    set $P125, $P131
  if_126_end:
.annotate "line", 48
    .return ($P125)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block149"  :anon :subid("23_1256021422.69758") :outer("20_1256021422.69758")
.annotate "line", 55
    find_lex $P151, "$past"
    unless_null $P151, vivify_153
    new $P151, "Undef"
  vivify_153:
    find_lex $P152, "$ast"
    unless_null $P152, vivify_154
    new $P152, "Undef"
  vivify_154:
    $P151."push"($P152)
.annotate "line", 56
    find_lex $P155, "$ast"
    unless_null $P155, vivify_155
    new $P155, "Undef"
  vivify_155:
    $S156 = $P155."pasttype"()
    iseq $I157, $S156, "literal"
    if $I157, if_154
    new $P159, "Integer"
    assign $P159, 0
    set $P153, $P159
    goto if_154_end
  if_154:
    find_lex $P158, "$ast"
    unless_null $P158, vivify_156
    new $P158, "Undef"
  vivify_156:
    set $P153, $P158
  if_154_end:
    store_lex "$lastlit", $P153
.annotate "line", 54
    .return ($P153)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block140"  :anon :subid("22_1256021422.69758") :outer("20_1256021422.69758")
.annotate "line", 52
    find_lex $P142, "$lastlit"
    unless_null $P142, vivify_157
    new $P142, "ResizablePMCArray"
  vivify_157:
    set $P143, $P142[0]
    unless_null $P143, vivify_158
    new $P143, "Undef"
  vivify_158:
    find_lex $P144, "$ast"
    unless_null $P144, vivify_159
    new $P144, "ResizablePMCArray"
  vivify_159:
    set $P145, $P144[0]
    unless_null $P145, vivify_160
    new $P145, "Undef"
  vivify_160:
    concat $P146, $P143, $P145
    find_lex $P147, "$lastlit"
    unless_null $P147, vivify_161
    new $P147, "ResizablePMCArray"
    store_lex "$lastlit", $P147
  vivify_161:
    set $P147[0], $P146
.annotate "line", 51
    .return ($P146)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block129"  :anon :subid("21_1256021422.69758") :outer("20_1256021422.69758")
.annotate "line", 50
    .return ()
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "quantified_atom"  :subid("24_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_171
.annotate "line", 62
    .const 'Sub' $P218 = "28_1256021422.69758" 
    capture_lex $P218
    .const 'Sub' $P199 = "27_1256021422.69758" 
    capture_lex $P199
    .const 'Sub' $P179 = "25_1256021422.69758" 
    capture_lex $P179
    new $P170, 'ExceptionHandler'
    set_addr $P170, control_169
    $P170."handle_types"(58)
    push_eh $P170
    .lex "self", self
    .lex "$/", param_171
.annotate "line", 63
    find_lex $P172, "$/"
    set $P173, $P172["atom"]
    unless_null $P173, vivify_163
    new $P173, "Undef"
  vivify_163:
    $P174 = $P173."ast"()
    .lex "$past", $P174
.annotate "line", 64
    find_lex $P176, "$/"
    set $P177, $P176["quantifier"]
    unless_null $P177, vivify_164
    new $P177, "Undef"
  vivify_164:
    if $P177, if_175
.annotate "line", 70
    find_lex $P195, "$/"
    set $P196, $P195["backmod"]
    unless_null $P196, vivify_165
    new $P196, "ResizablePMCArray"
  vivify_165:
    set $P197, $P196[0]
    unless_null $P197, vivify_166
    new $P197, "Undef"
  vivify_166:
    unless $P197, if_194_end
    .const 'Sub' $P199 = "27_1256021422.69758" 
    capture_lex $P199
    $P199()
  if_194_end:
.annotate "line", 64
    goto if_175_end
  if_175:
    .const 'Sub' $P179 = "25_1256021422.69758" 
    capture_lex $P179
    $P179()
  if_175_end:
.annotate "line", 71
    find_lex $P210, "$past"
    unless_null $P210, vivify_177
    new $P210, "Undef"
  vivify_177:
    if $P210, if_209
    set $P208, $P210
    goto if_209_end
  if_209:
    find_lex $P211, "$past"
    unless_null $P211, vivify_178
    new $P211, "Undef"
  vivify_178:
    $P212 = $P211."backtrack"()
    isfalse $I213, $P212
    new $P208, 'Integer'
    set $P208, $I213
  if_209_end:
    if $P208, if_207
    set $P206, $P208
    goto if_207_end
  if_207:
    get_global $P214, "@MODIFIERS"
    unless_null $P214, vivify_179
    new $P214, "ResizablePMCArray"
  vivify_179:
    set $P215, $P214[0]
    unless_null $P215, vivify_180
    new $P215, "Hash"
  vivify_180:
    set $P216, $P215["r"]
    unless_null $P216, vivify_181
    new $P216, "Undef"
  vivify_181:
    set $P206, $P216
  if_207_end:
    unless $P206, if_205_end
    .const 'Sub' $P218 = "28_1256021422.69758" 
    capture_lex $P218
    $P218()
  if_205_end:
    find_lex $P221, "$/"
.annotate "line", 74
    find_lex $P222, "$past"
    unless_null $P222, vivify_183
    new $P222, "Undef"
  vivify_183:
    $P223 = $P221."!make"($P222)
.annotate "line", 62
    .return ($P223)
  control_169:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P224, exception, "payload"
    .return ($P224)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block198"  :anon :subid("27_1256021422.69758") :outer("24_1256021422.69758")
.annotate "line", 70
    find_lex $P200, "$past"
    unless_null $P200, vivify_167
    new $P200, "Undef"
  vivify_167:
    find_lex $P201, "$/"
    set $P202, $P201["backmod"]
    unless_null $P202, vivify_168
    new $P202, "ResizablePMCArray"
  vivify_168:
    set $P203, $P202[0]
    unless_null $P203, vivify_169
    new $P203, "Undef"
  vivify_169:
    $P204 = "backmod"($P200, $P203)
    .return ($P204)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block178"  :anon :subid("25_1256021422.69758") :outer("24_1256021422.69758")
.annotate "line", 64
    .const 'Sub' $P184 = "26_1256021422.69758" 
    capture_lex $P184
.annotate "line", 65
    find_lex $P181, "$past"
    unless_null $P181, vivify_170
    new $P181, "Undef"
  vivify_170:
    isfalse $I182, $P181
    unless $I182, if_180_end
    .const 'Sub' $P184 = "26_1256021422.69758" 
    capture_lex $P184
    $P184()
  if_180_end:
.annotate "line", 66
    find_lex $P187, "$/"
    set $P188, $P187["quantifier"]
    unless_null $P188, vivify_172
    new $P188, "ResizablePMCArray"
  vivify_172:
    set $P189, $P188[0]
    unless_null $P189, vivify_173
    new $P189, "Undef"
  vivify_173:
    $P190 = $P189."ast"()
    .lex "$qast", $P190
.annotate "line", 67
    find_lex $P191, "$qast"
    unless_null $P191, vivify_174
    new $P191, "Undef"
  vivify_174:
    find_lex $P192, "$past"
    unless_null $P192, vivify_175
    new $P192, "Undef"
  vivify_175:
    $P191."unshift"($P192)
.annotate "line", 68
    find_lex $P193, "$qast"
    unless_null $P193, vivify_176
    new $P193, "Undef"
  vivify_176:
    store_lex "$past", $P193
.annotate "line", 64
    .return ($P193)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block183"  :anon :subid("26_1256021422.69758") :outer("25_1256021422.69758")
.annotate "line", 65
    find_lex $P185, "$/"
    unless_null $P185, vivify_171
    new $P185, "Undef"
  vivify_171:
    $P186 = $P185."panic"("Can't quantify zero-width atom")
    .return ($P186)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block217"  :anon :subid("28_1256021422.69758") :outer("24_1256021422.69758")
.annotate "line", 72
    find_lex $P219, "$past"
    unless_null $P219, vivify_182
    new $P219, "Undef"
  vivify_182:
    $P220 = $P219."backtrack"("r")
.annotate "line", 71
    .return ($P220)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "atom"  :subid("29_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_228
.annotate "line", 77
    .const 'Sub' $P239 = "31_1256021422.69758" 
    capture_lex $P239
    .const 'Sub' $P234 = "30_1256021422.69758" 
    capture_lex $P234
    new $P227, 'ExceptionHandler'
    set_addr $P227, control_226
    $P227."handle_types"(58)
    push_eh $P227
    .lex "self", self
    .lex "$/", param_228
.annotate "line", 78
    new $P229, "Undef"
    .lex "$past", $P229
.annotate "line", 79
    find_lex $P231, "$/"
    set $P232, $P231["metachar"]
    unless_null $P232, vivify_184
    new $P232, "Undef"
  vivify_184:
    if $P232, if_230
.annotate "line", 80
    .const 'Sub' $P239 = "31_1256021422.69758" 
    capture_lex $P239
    $P239()
    goto if_230_end
  if_230:
.annotate "line", 79
    .const 'Sub' $P234 = "30_1256021422.69758" 
    capture_lex $P234
    $P234()
  if_230_end:
    find_lex $P255, "$/"
.annotate "line", 84
    find_lex $P256, "$past"
    unless_null $P256, vivify_192
    new $P256, "Undef"
  vivify_192:
    $P257 = $P255."!make"($P256)
.annotate "line", 77
    .return ($P257)
  control_226:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P258, exception, "payload"
    .return ($P258)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block238"  :anon :subid("31_1256021422.69758") :outer("29_1256021422.69758")
.annotate "line", 80
    .const 'Sub' $P251 = "32_1256021422.69758" 
    capture_lex $P251
.annotate "line", 81
    get_hll_global $P240, ["PAST"], "Regex"
    find_lex $P241, "$/"
    unless_null $P241, vivify_185
    new $P241, "Undef"
  vivify_185:
    set $S242, $P241
    find_lex $P243, "$/"
    unless_null $P243, vivify_186
    new $P243, "Undef"
  vivify_186:
    $P244 = $P240."new"($S242, "literal" :named("pasttype"), $P243 :named("node"))
    store_lex "$past", $P244
.annotate "line", 82
    get_global $P247, "@MODIFIERS"
    unless_null $P247, vivify_187
    new $P247, "ResizablePMCArray"
  vivify_187:
    set $P248, $P247[0]
    unless_null $P248, vivify_188
    new $P248, "Hash"
  vivify_188:
    set $P249, $P248["i"]
    unless_null $P249, vivify_189
    new $P249, "Undef"
  vivify_189:
    if $P249, if_246
    set $P245, $P249
    goto if_246_end
  if_246:
    .const 'Sub' $P251 = "32_1256021422.69758" 
    capture_lex $P251
    $P254 = $P251()
    set $P245, $P254
  if_246_end:
.annotate "line", 80
    .return ($P245)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block250"  :anon :subid("32_1256021422.69758") :outer("31_1256021422.69758")
.annotate "line", 82
    find_lex $P252, "$past"
    unless_null $P252, vivify_190
    new $P252, "Undef"
  vivify_190:
    $P253 = $P252."subtype"("ignorecase")
    .return ($P253)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block233"  :anon :subid("30_1256021422.69758") :outer("29_1256021422.69758")
.annotate "line", 79
    find_lex $P235, "$/"
    set $P236, $P235["metachar"]
    unless_null $P236, vivify_191
    new $P236, "Undef"
  vivify_191:
    $P237 = $P236."ast"()
    store_lex "$past", $P237
    .return ($P237)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "quantifier:sym<*>"  :subid("33_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_262
.annotate "line", 87
    new $P261, 'ExceptionHandler'
    set_addr $P261, control_260
    $P261."handle_types"(58)
    push_eh $P261
    .lex "self", self
    .lex "$/", param_262
.annotate "line", 88
    get_hll_global $P263, ["PAST"], "Regex"
    find_lex $P264, "$/"
    unless_null $P264, vivify_193
    new $P264, "Undef"
  vivify_193:
    $P265 = $P263."new"("quant" :named("pasttype"), $P264 :named("node"))
    .lex "$past", $P265
    find_lex $P266, "$/"
.annotate "line", 89
    find_lex $P267, "$past"
    unless_null $P267, vivify_194
    new $P267, "Undef"
  vivify_194:
    find_lex $P268, "$/"
    set $P269, $P268["backmod"]
    unless_null $P269, vivify_195
    new $P269, "Undef"
  vivify_195:
    $P270 = "backmod"($P267, $P269)
    $P271 = $P266."!make"($P270)
.annotate "line", 87
    .return ($P271)
  control_260:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P272, exception, "payload"
    .return ($P272)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "quantifier:sym<+>"  :subid("34_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_276
.annotate "line", 92
    new $P275, 'ExceptionHandler'
    set_addr $P275, control_274
    $P275."handle_types"(58)
    push_eh $P275
    .lex "self", self
    .lex "$/", param_276
.annotate "line", 93
    get_hll_global $P277, ["PAST"], "Regex"
    find_lex $P278, "$/"
    unless_null $P278, vivify_196
    new $P278, "Undef"
  vivify_196:
    $P279 = $P277."new"("quant" :named("pasttype"), 1 :named("min"), $P278 :named("node"))
    .lex "$past", $P279
    find_lex $P280, "$/"
.annotate "line", 94
    find_lex $P281, "$past"
    unless_null $P281, vivify_197
    new $P281, "Undef"
  vivify_197:
    find_lex $P282, "$/"
    set $P283, $P282["backmod"]
    unless_null $P283, vivify_198
    new $P283, "Undef"
  vivify_198:
    $P284 = "backmod"($P281, $P283)
    $P285 = $P280."!make"($P284)
.annotate "line", 92
    .return ($P285)
  control_274:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P286, exception, "payload"
    .return ($P286)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "quantifier:sym<?>"  :subid("35_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_290
.annotate "line", 97
    new $P289, 'ExceptionHandler'
    set_addr $P289, control_288
    $P289."handle_types"(58)
    push_eh $P289
    .lex "self", self
    .lex "$/", param_290
.annotate "line", 98
    get_hll_global $P291, ["PAST"], "Regex"
    find_lex $P292, "$/"
    unless_null $P292, vivify_199
    new $P292, "Undef"
  vivify_199:
    $P293 = $P291."new"("quant" :named("pasttype"), 0 :named("min"), 1 :named("max"), $P292 :named("node"))
    .lex "$past", $P293
    find_lex $P294, "$/"
.annotate "line", 99
    find_lex $P295, "$past"
    unless_null $P295, vivify_200
    new $P295, "Undef"
  vivify_200:
    find_lex $P296, "$/"
    set $P297, $P296["backmod"]
    unless_null $P297, vivify_201
    new $P297, "Undef"
  vivify_201:
    $P298 = "backmod"($P295, $P297)
    $P294."!make"($P298)
.annotate "line", 98
    find_lex $P299, "$/"
.annotate "line", 100
    find_lex $P300, "$past"
    unless_null $P300, vivify_202
    new $P300, "Undef"
  vivify_202:
    $P301 = $P299."!make"($P300)
.annotate "line", 97
    .return ($P301)
  control_288:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P302, exception, "payload"
    .return ($P302)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "quantifier:sym<**>"  :subid("36_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_306
.annotate "line", 103
    .const 'Sub' $P320 = "38_1256021422.69758" 
    capture_lex $P320
    .const 'Sub' $P312 = "37_1256021422.69758" 
    capture_lex $P312
    new $P305, 'ExceptionHandler'
    set_addr $P305, control_304
    $P305."handle_types"(58)
    push_eh $P305
    .lex "self", self
    .lex "$/", param_306
.annotate "line", 104
    new $P307, "Undef"
    .lex "$past", $P307
.annotate "line", 105
    find_lex $P309, "$/"
    set $P310, $P309["quantified_atom"]
    unless_null $P310, vivify_203
    new $P310, "Undef"
  vivify_203:
    if $P310, if_308
.annotate "line", 109
    .const 'Sub' $P320 = "38_1256021422.69758" 
    capture_lex $P320
    $P320()
    goto if_308_end
  if_308:
.annotate "line", 105
    .const 'Sub' $P312 = "37_1256021422.69758" 
    capture_lex $P312
    $P312()
  if_308_end:
    find_lex $P356, "$/"
.annotate "line", 114
    find_lex $P357, "$past"
    unless_null $P357, vivify_216
    new $P357, "Undef"
  vivify_216:
    find_lex $P358, "$/"
    set $P359, $P358["backmod"]
    unless_null $P359, vivify_217
    new $P359, "Undef"
  vivify_217:
    $P360 = "backmod"($P357, $P359)
    $P361 = $P356."!make"($P360)
.annotate "line", 103
    .return ($P361)
  control_304:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P362, exception, "payload"
    .return ($P362)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block319"  :anon :subid("38_1256021422.69758") :outer("36_1256021422.69758")
.annotate "line", 109
    .const 'Sub' $P348 = "40_1256021422.69758" 
    capture_lex $P348
    .const 'Sub' $P333 = "39_1256021422.69758" 
    capture_lex $P333
.annotate "line", 110
    get_hll_global $P321, ["PAST"], "Regex"
    find_lex $P322, "$/"
    set $P323, $P322["min"]
    unless_null $P323, vivify_204
    new $P323, "Undef"
  vivify_204:
    set $N324, $P323
    find_lex $P325, "$/"
    unless_null $P325, vivify_205
    new $P325, "Undef"
  vivify_205:
    $P326 = $P321."new"("quant" :named("pasttype"), $N324 :named("min"), $P325 :named("node"))
    store_lex "$past", $P326
.annotate "line", 111
    find_lex $P329, "$/"
    set $P330, $P329["max"]
    unless_null $P330, vivify_206
    new $P330, "Undef"
  vivify_206:
    isfalse $I331, $P330
    if $I331, if_328
.annotate "line", 112
    find_lex $P342, "$/"
    set $P343, $P342["max"]
    unless_null $P343, vivify_207
    new $P343, "ResizablePMCArray"
  vivify_207:
    set $P344, $P343[0]
    unless_null $P344, vivify_208
    new $P344, "Undef"
  vivify_208:
    set $S345, $P344
    isne $I346, $S345, "*"
    if $I346, if_341
    new $P340, 'Integer'
    set $P340, $I346
    goto if_341_end
  if_341:
    .const 'Sub' $P348 = "40_1256021422.69758" 
    capture_lex $P348
    $P355 = $P348()
    set $P340, $P355
  if_341_end:
.annotate "line", 111
    set $P327, $P340
    goto if_328_end
  if_328:
    .const 'Sub' $P333 = "39_1256021422.69758" 
    capture_lex $P333
    $P339 = $P333()
    set $P327, $P339
  if_328_end:
.annotate "line", 109
    .return ($P327)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block347"  :anon :subid("40_1256021422.69758") :outer("38_1256021422.69758")
.annotate "line", 112
    find_lex $P349, "$past"
    unless_null $P349, vivify_209
    new $P349, "Undef"
  vivify_209:
    find_lex $P350, "$/"
    set $P351, $P350["max"]
    unless_null $P351, vivify_210
    new $P351, "ResizablePMCArray"
  vivify_210:
    set $P352, $P351[0]
    unless_null $P352, vivify_211
    new $P352, "Undef"
  vivify_211:
    set $N353, $P352
    $P354 = $P349."max"($N353)
    .return ($P354)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block332"  :anon :subid("39_1256021422.69758") :outer("38_1256021422.69758")
.annotate "line", 111
    find_lex $P334, "$past"
    unless_null $P334, vivify_212
    new $P334, "Undef"
  vivify_212:
    find_lex $P335, "$/"
    set $P336, $P335["min"]
    unless_null $P336, vivify_213
    new $P336, "Undef"
  vivify_213:
    set $N337, $P336
    $P338 = $P334."max"($N337)
    .return ($P338)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block311"  :anon :subid("37_1256021422.69758") :outer("36_1256021422.69758")
.annotate "line", 106
    get_hll_global $P313, ["PAST"], "Regex"
.annotate "line", 107
    find_lex $P314, "$/"
    set $P315, $P314["quantified_atom"]
    unless_null $P315, vivify_214
    new $P315, "Undef"
  vivify_214:
    $P316 = $P315."ast"()
    find_lex $P317, "$/"
    unless_null $P317, vivify_215
    new $P317, "Undef"
  vivify_215:
    $P318 = $P313."new"("quant" :named("pasttype"), 1 :named("min"), $P316 :named("sep"), $P317 :named("node"))
.annotate "line", 106
    store_lex "$past", $P318
.annotate "line", 105
    .return ($P318)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<ws>"  :subid("41_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_366
.annotate "line", 117
    new $P365, 'ExceptionHandler'
    set_addr $P365, control_364
    $P365."handle_types"(58)
    push_eh $P365
    .lex "self", self
    .lex "$/", param_366
.annotate "line", 118
    get_global $P369, "@MODIFIERS"
    unless_null $P369, vivify_218
    new $P369, "ResizablePMCArray"
  vivify_218:
    set $P370, $P369[0]
    unless_null $P370, vivify_219
    new $P370, "Hash"
  vivify_219:
    set $P371, $P370["s"]
    unless_null $P371, vivify_220
    new $P371, "Undef"
  vivify_220:
    if $P371, if_368
.annotate "line", 121
    new $P375, "Integer"
    assign $P375, 0
    set $P367, $P375
.annotate "line", 118
    goto if_368_end
  if_368:
.annotate "line", 119
    get_hll_global $P372, ["PAST"], "Regex"
.annotate "line", 120
    find_lex $P373, "$/"
    unless_null $P373, vivify_221
    new $P373, "Undef"
  vivify_221:
    $P374 = $P372."new"("ws", "subrule" :named("pasttype"), "method" :named("subtype"), $P373 :named("node"))
.annotate "line", 119
    set $P367, $P374
  if_368_end:
    .lex "$past", $P367
.annotate "line", 118
    find_lex $P376, "$/"
.annotate "line", 122
    find_lex $P377, "$past"
    unless_null $P377, vivify_222
    new $P377, "Undef"
  vivify_222:
    $P378 = $P376."!make"($P377)
.annotate "line", 117
    .return ($P378)
  control_364:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P379, exception, "payload"
    .return ($P379)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<[ ]>"  :subid("42_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_383
.annotate "line", 126
    new $P382, 'ExceptionHandler'
    set_addr $P382, control_381
    $P382."handle_types"(58)
    push_eh $P382
    .lex "self", self
    .lex "$/", param_383
.annotate "line", 127
    find_lex $P384, "$/"
    find_lex $P385, "$/"
    set $P386, $P385["nibbler"]
    unless_null $P386, vivify_223
    new $P386, "Undef"
  vivify_223:
    $P387 = $P386."ast"()
    $P388 = $P384."!make"($P387)
.annotate "line", 126
    .return ($P388)
  control_381:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P389, exception, "payload"
    .return ($P389)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<( )>"  :subid("43_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_393
.annotate "line", 130
    new $P392, 'ExceptionHandler'
    set_addr $P392, control_391
    $P392."handle_types"(58)
    push_eh $P392
    .lex "self", self
    .lex "$/", param_393
.annotate "line", 131
    find_lex $P394, "$/"
    set $P395, $P394["nibbler"]
    unless_null $P395, vivify_224
    new $P395, "Undef"
  vivify_224:
    $P396 = $P395."ast"()
    $P397 = "buildsub"($P396)
    .lex "$subpast", $P397
.annotate "line", 132
    get_hll_global $P398, ["PAST"], "Regex"
    find_lex $P399, "$subpast"
    unless_null $P399, vivify_225
    new $P399, "Undef"
  vivify_225:
.annotate "line", 133
    find_lex $P400, "$/"
    unless_null $P400, vivify_226
    new $P400, "Undef"
  vivify_226:
    $P401 = $P398."new"($P399, "subrule" :named("pasttype"), "capture" :named("subtype"), $P400 :named("node"))
.annotate "line", 132
    .lex "$past", $P401
    find_lex $P402, "$/"
.annotate "line", 134
    find_lex $P403, "$past"
    unless_null $P403, vivify_227
    new $P403, "Undef"
  vivify_227:
    $P404 = $P402."!make"($P403)
.annotate "line", 130
    .return ($P404)
  control_391:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P405, exception, "payload"
    .return ($P405)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<'>"  :subid("44_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_409
.annotate "line", 137
    new $P408, 'ExceptionHandler'
    set_addr $P408, control_407
    $P408."handle_types"(58)
    push_eh $P408
    .lex "self", self
    .lex "$/", param_409
.annotate "line", 138
    get_hll_global $P410, ["PAST"], "Regex"
    find_lex $P411, "$/"
    set $P412, $P411["quote"]
    unless_null $P412, vivify_228
    new $P412, "Hash"
  vivify_228:
    set $P413, $P412["val"]
    unless_null $P413, vivify_229
    new $P413, "Undef"
  vivify_229:
    set $S414, $P413
    find_lex $P415, "$/"
    unless_null $P415, vivify_230
    new $P415, "Undef"
  vivify_230:
    $P416 = $P410."new"($S414, "literal" :named("pasttype"), $P415 :named("node"))
    .lex "$past", $P416
    find_lex $P417, "$/"
.annotate "line", 139
    find_lex $P418, "$past"
    unless_null $P418, vivify_231
    new $P418, "Undef"
  vivify_231:
    $P419 = $P417."!make"($P418)
.annotate "line", 137
    .return ($P419)
  control_407:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P420, exception, "payload"
    .return ($P420)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<.>"  :subid("45_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_424
.annotate "line", 142
    new $P423, 'ExceptionHandler'
    set_addr $P423, control_422
    $P423."handle_types"(58)
    push_eh $P423
    .lex "self", self
    .lex "$/", param_424
.annotate "line", 143
    get_hll_global $P425, ["PAST"], "Regex"
    find_lex $P426, "$/"
    unless_null $P426, vivify_232
    new $P426, "Undef"
  vivify_232:
    $P427 = $P425."new"("charclass" :named("pasttype"), "." :named("subtype"), $P426 :named("node"))
    .lex "$past", $P427
    find_lex $P428, "$/"
.annotate "line", 144
    find_lex $P429, "$past"
    unless_null $P429, vivify_233
    new $P429, "Undef"
  vivify_233:
    $P430 = $P428."!make"($P429)
.annotate "line", 142
    .return ($P430)
  control_422:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P431, exception, "payload"
    .return ($P431)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<^>"  :subid("46_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_435
.annotate "line", 147
    new $P434, 'ExceptionHandler'
    set_addr $P434, control_433
    $P434."handle_types"(58)
    push_eh $P434
    .lex "self", self
    .lex "$/", param_435
.annotate "line", 148
    get_hll_global $P436, ["PAST"], "Regex"
    find_lex $P437, "$/"
    unless_null $P437, vivify_234
    new $P437, "Undef"
  vivify_234:
    $P438 = $P436."new"("anchor" :named("pasttype"), "bos" :named("subtype"), $P437 :named("node"))
    .lex "$past", $P438
    find_lex $P439, "$/"
.annotate "line", 149
    find_lex $P440, "$past"
    unless_null $P440, vivify_235
    new $P440, "Undef"
  vivify_235:
    $P441 = $P439."!make"($P440)
.annotate "line", 147
    .return ($P441)
  control_433:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P442, exception, "payload"
    .return ($P442)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<^^>"  :subid("47_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_446
.annotate "line", 152
    new $P445, 'ExceptionHandler'
    set_addr $P445, control_444
    $P445."handle_types"(58)
    push_eh $P445
    .lex "self", self
    .lex "$/", param_446
.annotate "line", 153
    get_hll_global $P447, ["PAST"], "Regex"
    find_lex $P448, "$/"
    unless_null $P448, vivify_236
    new $P448, "Undef"
  vivify_236:
    $P449 = $P447."new"("anchor" :named("pasttype"), "bol" :named("subtype"), $P448 :named("node"))
    .lex "$past", $P449
    find_lex $P450, "$/"
.annotate "line", 154
    find_lex $P451, "$past"
    unless_null $P451, vivify_237
    new $P451, "Undef"
  vivify_237:
    $P452 = $P450."!make"($P451)
.annotate "line", 152
    .return ($P452)
  control_444:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P453, exception, "payload"
    .return ($P453)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<$>"  :subid("48_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_457
.annotate "line", 157
    new $P456, 'ExceptionHandler'
    set_addr $P456, control_455
    $P456."handle_types"(58)
    push_eh $P456
    .lex "self", self
    .lex "$/", param_457
.annotate "line", 158
    get_hll_global $P458, ["PAST"], "Regex"
    find_lex $P459, "$/"
    unless_null $P459, vivify_238
    new $P459, "Undef"
  vivify_238:
    $P460 = $P458."new"("anchor" :named("pasttype"), "eos" :named("subtype"), $P459 :named("node"))
    .lex "$past", $P460
    find_lex $P461, "$/"
.annotate "line", 159
    find_lex $P462, "$past"
    unless_null $P462, vivify_239
    new $P462, "Undef"
  vivify_239:
    $P463 = $P461."!make"($P462)
.annotate "line", 157
    .return ($P463)
  control_455:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P464, exception, "payload"
    .return ($P464)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<$$>"  :subid("49_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_468
.annotate "line", 162
    new $P467, 'ExceptionHandler'
    set_addr $P467, control_466
    $P467."handle_types"(58)
    push_eh $P467
    .lex "self", self
    .lex "$/", param_468
.annotate "line", 163
    get_hll_global $P469, ["PAST"], "Regex"
    find_lex $P470, "$/"
    unless_null $P470, vivify_240
    new $P470, "Undef"
  vivify_240:
    $P471 = $P469."new"("anchor" :named("pasttype"), "eol" :named("subtype"), $P470 :named("node"))
    .lex "$past", $P471
    find_lex $P472, "$/"
.annotate "line", 164
    find_lex $P473, "$past"
    unless_null $P473, vivify_241
    new $P473, "Undef"
  vivify_241:
    $P474 = $P472."!make"($P473)
.annotate "line", 162
    .return ($P474)
  control_466:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P475, exception, "payload"
    .return ($P475)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<:::>"  :subid("50_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_479
.annotate "line", 167
    new $P478, 'ExceptionHandler'
    set_addr $P478, control_477
    $P478."handle_types"(58)
    push_eh $P478
    .lex "self", self
    .lex "$/", param_479
.annotate "line", 168
    get_hll_global $P480, ["PAST"], "Regex"
    find_lex $P481, "$/"
    unless_null $P481, vivify_242
    new $P481, "Undef"
  vivify_242:
    $P482 = $P480."new"("cut" :named("pasttype"), $P481 :named("node"))
    .lex "$past", $P482
    find_lex $P483, "$/"
.annotate "line", 169
    find_lex $P484, "$past"
    unless_null $P484, vivify_243
    new $P484, "Undef"
  vivify_243:
    $P485 = $P483."!make"($P484)
.annotate "line", 167
    .return ($P485)
  control_477:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P486, exception, "payload"
    .return ($P486)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<lwb>"  :subid("51_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_490
.annotate "line", 172
    new $P489, 'ExceptionHandler'
    set_addr $P489, control_488
    $P489."handle_types"(58)
    push_eh $P489
    .lex "self", self
    .lex "$/", param_490
.annotate "line", 173
    get_hll_global $P491, ["PAST"], "Regex"
    find_lex $P492, "$/"
    unless_null $P492, vivify_244
    new $P492, "Undef"
  vivify_244:
    $P493 = $P491."new"("anchor" :named("pasttype"), "lwb" :named("subtype"), $P492 :named("node"))
    .lex "$past", $P493
    find_lex $P494, "$/"
.annotate "line", 174
    find_lex $P495, "$past"
    unless_null $P495, vivify_245
    new $P495, "Undef"
  vivify_245:
    $P496 = $P494."!make"($P495)
.annotate "line", 172
    .return ($P496)
  control_488:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P497, exception, "payload"
    .return ($P497)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<rwb>"  :subid("52_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_501
.annotate "line", 177
    new $P500, 'ExceptionHandler'
    set_addr $P500, control_499
    $P500."handle_types"(58)
    push_eh $P500
    .lex "self", self
    .lex "$/", param_501
.annotate "line", 178
    get_hll_global $P502, ["PAST"], "Regex"
    find_lex $P503, "$/"
    unless_null $P503, vivify_246
    new $P503, "Undef"
  vivify_246:
    $P504 = $P502."new"("anchor" :named("pasttype"), "rwb" :named("subtype"), $P503 :named("node"))
    .lex "$past", $P504
    find_lex $P505, "$/"
.annotate "line", 179
    find_lex $P506, "$past"
    unless_null $P506, vivify_247
    new $P506, "Undef"
  vivify_247:
    $P507 = $P505."!make"($P506)
.annotate "line", 177
    .return ($P507)
  control_499:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P508, exception, "payload"
    .return ($P508)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<bs>"  :subid("53_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_512
.annotate "line", 182
    new $P511, 'ExceptionHandler'
    set_addr $P511, control_510
    $P511."handle_types"(58)
    push_eh $P511
    .lex "self", self
    .lex "$/", param_512
.annotate "line", 183
    find_lex $P513, "$/"
    find_lex $P514, "$/"
    set $P515, $P514["backslash"]
    unless_null $P515, vivify_248
    new $P515, "Undef"
  vivify_248:
    $P516 = $P515."ast"()
    $P517 = $P513."!make"($P516)
.annotate "line", 182
    .return ($P517)
  control_510:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P518, exception, "payload"
    .return ($P518)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<mod>"  :subid("54_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_522
.annotate "line", 186
    new $P521, 'ExceptionHandler'
    set_addr $P521, control_520
    $P521."handle_types"(58)
    push_eh $P521
    .lex "self", self
    .lex "$/", param_522
.annotate "line", 187
    find_lex $P523, "$/"
    find_lex $P524, "$/"
    set $P525, $P524["mod_internal"]
    unless_null $P525, vivify_249
    new $P525, "Undef"
  vivify_249:
    $P526 = $P525."ast"()
    $P527 = $P523."!make"($P526)
.annotate "line", 186
    .return ($P527)
  control_520:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P528, exception, "payload"
    .return ($P528)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<assert>"  :subid("55_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_532
.annotate "line", 190
    new $P531, 'ExceptionHandler'
    set_addr $P531, control_530
    $P531."handle_types"(58)
    push_eh $P531
    .lex "self", self
    .lex "$/", param_532
.annotate "line", 191
    find_lex $P533, "$/"
    find_lex $P534, "$/"
    set $P535, $P534["assertion"]
    unless_null $P535, vivify_250
    new $P535, "Undef"
  vivify_250:
    $P536 = $P535."ast"()
    $P537 = $P533."!make"($P536)
.annotate "line", 190
    .return ($P537)
  control_530:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P538, exception, "payload"
    .return ($P538)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<{*}>"  :subid("56_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_542
.annotate "line", 194
    new $P541, 'ExceptionHandler'
    set_addr $P541, control_540
    $P541."handle_types"(58)
    push_eh $P541
    .lex "self", self
    .lex "$/", param_542
.annotate "line", 196
    find_lex $P545, "$/"
    set $P546, $P545["key"]
    unless_null $P546, vivify_251
    new $P546, "Undef"
  vivify_251:
    if $P546, if_544
.annotate "line", 197
    new $P554, "Integer"
    assign $P554, 0
    set $P543, $P554
.annotate "line", 196
    goto if_544_end
  if_544:
    get_hll_global $P547, ["PAST"], "Regex"
    find_lex $P548, "$/"
    set $P549, $P548["key"]
    unless_null $P549, vivify_252
    new $P549, "ResizablePMCArray"
  vivify_252:
    set $P550, $P549[0]
    unless_null $P550, vivify_253
    new $P550, "Undef"
  vivify_253:
    set $S551, $P550
    find_lex $P552, "$/"
    unless_null $P552, vivify_254
    new $P552, "Undef"
  vivify_254:
    $P553 = $P547."new"($S551, "reduce" :named("pasttype"), $P552 :named("node"))
    set $P543, $P553
  if_544_end:
    .lex "$past", $P543
.annotate "line", 195
    find_lex $P555, "$/"
.annotate "line", 198
    find_lex $P556, "$past"
    unless_null $P556, vivify_255
    new $P556, "Undef"
  vivify_255:
    $P557 = $P555."!make"($P556)
.annotate "line", 194
    .return ($P557)
  control_540:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P558, exception, "payload"
    .return ($P558)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "metachar:sym<var>"  :subid("57_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_562
.annotate "line", 201
    .const 'Sub' $P621 = "62_1256021422.69758" 
    capture_lex $P621
    .const 'Sub' $P578 = "58_1256021422.69758" 
    capture_lex $P578
    new $P561, 'ExceptionHandler'
    set_addr $P561, control_560
    $P561."handle_types"(58)
    push_eh $P561
    .lex "self", self
    .lex "$/", param_562
.annotate "line", 202
    new $P563, "Undef"
    .lex "$past", $P563
.annotate "line", 203
    find_lex $P566, "$/"
    set $P567, $P566["pos"]
    unless_null $P567, vivify_256
    new $P567, "Undef"
  vivify_256:
    if $P567, if_565
    find_lex $P571, "$/"
    set $P572, $P571["name"]
    unless_null $P572, vivify_257
    new $P572, "Undef"
  vivify_257:
    set $S573, $P572
    new $P564, 'String'
    set $P564, $S573
    goto if_565_end
  if_565:
    find_lex $P568, "$/"
    set $P569, $P568["pos"]
    unless_null $P569, vivify_258
    new $P569, "Undef"
  vivify_258:
    set $N570, $P569
    new $P564, 'Float'
    set $P564, $N570
  if_565_end:
    .lex "$name", $P564
.annotate "line", 204
    find_lex $P575, "$/"
    set $P576, $P575["quantified_atom"]
    unless_null $P576, vivify_259
    new $P576, "Undef"
  vivify_259:
    if $P576, if_574
.annotate "line", 214
    .const 'Sub' $P621 = "62_1256021422.69758" 
    capture_lex $P621
    $P621()
    goto if_574_end
  if_574:
.annotate "line", 204
    .const 'Sub' $P578 = "58_1256021422.69758" 
    capture_lex $P578
    $P578()
  if_574_end:
    find_lex $P626, "$/"
.annotate "line", 218
    find_lex $P627, "$past"
    unless_null $P627, vivify_276
    new $P627, "Undef"
  vivify_276:
    $P628 = $P626."!make"($P627)
.annotate "line", 201
    .return ($P628)
  control_560:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P629, exception, "payload"
    .return ($P629)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block620"  :anon :subid("62_1256021422.69758") :outer("57_1256021422.69758")
.annotate "line", 215
    get_hll_global $P622, ["PAST"], "Regex"
    find_lex $P623, "$name"
    unless_null $P623, vivify_260
    new $P623, "Undef"
  vivify_260:
.annotate "line", 216
    find_lex $P624, "$/"
    unless_null $P624, vivify_261
    new $P624, "Undef"
  vivify_261:
    $P625 = $P622."new"("!BACKREF", $P623, "subrule" :named("pasttype"), "method" :named("subtype"), $P624 :named("node"))
.annotate "line", 215
    store_lex "$past", $P625
.annotate "line", 214
    .return ($P625)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block577"  :anon :subid("58_1256021422.69758") :outer("57_1256021422.69758")
.annotate "line", 204
    .const 'Sub' $P613 = "61_1256021422.69758" 
    capture_lex $P613
    .const 'Sub' $P607 = "60_1256021422.69758" 
    capture_lex $P607
    .const 'Sub' $P595 = "59_1256021422.69758" 
    capture_lex $P595
.annotate "line", 205
    find_lex $P579, "$/"
    set $P580, $P579["quantified_atom"]
    unless_null $P580, vivify_262
    new $P580, "ResizablePMCArray"
  vivify_262:
    set $P581, $P580[0]
    unless_null $P581, vivify_263
    new $P581, "Undef"
  vivify_263:
    $P582 = $P581."ast"()
    store_lex "$past", $P582
.annotate "line", 206
    find_lex $P587, "$past"
    unless_null $P587, vivify_264
    new $P587, "Undef"
  vivify_264:
    $S588 = $P587."pasttype"()
    iseq $I589, $S588, "quant"
    if $I589, if_586
    new $P585, 'Integer'
    set $P585, $I589
    goto if_586_end
  if_586:
    find_lex $P590, "$past"
    unless_null $P590, vivify_265
    new $P590, "ResizablePMCArray"
  vivify_265:
    set $P591, $P590[0]
    unless_null $P591, vivify_266
    new $P591, "Undef"
  vivify_266:
    $S592 = $P591."pasttype"()
    iseq $I593, $S592, "subrule"
    new $P585, 'Integer'
    set $P585, $I593
  if_586_end:
    if $P585, if_584
.annotate "line", 209
    find_lex $P603, "$past"
    unless_null $P603, vivify_267
    new $P603, "Undef"
  vivify_267:
    $S604 = $P603."pasttype"()
    iseq $I605, $S604, "subrule"
    if $I605, if_602
.annotate "line", 210
    .const 'Sub' $P613 = "61_1256021422.69758" 
    capture_lex $P613
    $P619 = $P613()
    set $P601, $P619
.annotate "line", 209
    goto if_602_end
  if_602:
    .const 'Sub' $P607 = "60_1256021422.69758" 
    capture_lex $P607
    $P611 = $P607()
    set $P601, $P611
  if_602_end:
.annotate "line", 206
    set $P583, $P601
    goto if_584_end
  if_584:
    .const 'Sub' $P595 = "59_1256021422.69758" 
    capture_lex $P595
    $P600 = $P595()
    set $P583, $P600
  if_584_end:
.annotate "line", 204
    .return ($P583)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block612"  :anon :subid("61_1256021422.69758") :outer("58_1256021422.69758")
.annotate "line", 211
    get_hll_global $P614, ["PAST"], "Regex"
    find_lex $P615, "$past"
    unless_null $P615, vivify_268
    new $P615, "Undef"
  vivify_268:
    find_lex $P616, "$name"
    unless_null $P616, vivify_269
    new $P616, "Undef"
  vivify_269:
    find_lex $P617, "$/"
    unless_null $P617, vivify_270
    new $P617, "Undef"
  vivify_270:
    $P618 = $P614."new"($P615, $P616 :named("name"), "subcapture" :named("pasttype"), $P617 :named("node"))
    store_lex "$past", $P618
.annotate "line", 210
    .return ($P618)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block606"  :anon :subid("60_1256021422.69758") :outer("58_1256021422.69758")
.annotate "line", 209
    find_lex $P608, "$past"
    unless_null $P608, vivify_271
    new $P608, "Undef"
  vivify_271:
    find_lex $P609, "$name"
    unless_null $P609, vivify_272
    new $P609, "Undef"
  vivify_272:
    $P610 = "subrule_alias"($P608, $P609)
    .return ($P610)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block594"  :anon :subid("59_1256021422.69758") :outer("58_1256021422.69758")
.annotate "line", 207
    find_lex $P596, "$past"
    unless_null $P596, vivify_273
    new $P596, "ResizablePMCArray"
  vivify_273:
    set $P597, $P596[0]
    unless_null $P597, vivify_274
    new $P597, "Undef"
  vivify_274:
    find_lex $P598, "$name"
    unless_null $P598, vivify_275
    new $P598, "Undef"
  vivify_275:
    $P599 = "subrule_alias"($P597, $P598)
.annotate "line", 206
    .return ($P599)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<w>"  :subid("63_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_633
.annotate "line", 221
    new $P632, 'ExceptionHandler'
    set_addr $P632, control_631
    $P632."handle_types"(58)
    push_eh $P632
    .lex "self", self
    .lex "$/", param_633
.annotate "line", 222
    find_lex $P636, "$/"
    set $P637, $P636["sym"]
    unless_null $P637, vivify_277
    new $P637, "Undef"
  vivify_277:
    set $S638, $P637
    iseq $I639, $S638, "n"
    if $I639, if_635
    find_lex $P641, "$/"
    set $P642, $P641["sym"]
    unless_null $P642, vivify_278
    new $P642, "Undef"
  vivify_278:
    set $S643, $P642
    new $P634, 'String'
    set $P634, $S643
    goto if_635_end
  if_635:
    new $P640, "String"
    assign $P640, "nl"
    set $P634, $P640
  if_635_end:
    .lex "$subtype", $P634
.annotate "line", 223
    get_hll_global $P644, ["PAST"], "Regex"
    find_lex $P645, "$subtype"
    unless_null $P645, vivify_279
    new $P645, "Undef"
  vivify_279:
    find_lex $P646, "$/"
    unless_null $P646, vivify_280
    new $P646, "Undef"
  vivify_280:
    $P647 = $P644."new"("charclass" :named("pasttype"), $P645 :named("subtype"), $P646 :named("node"))
    .lex "$past", $P647
    find_lex $P648, "$/"
.annotate "line", 224
    find_lex $P649, "$past"
    unless_null $P649, vivify_281
    new $P649, "Undef"
  vivify_281:
    $P650 = $P648."!make"($P649)
.annotate "line", 221
    .return ($P650)
  control_631:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P651, exception, "payload"
    .return ($P651)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<b>"  :subid("64_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_655
.annotate "line", 227
    new $P654, 'ExceptionHandler'
    set_addr $P654, control_653
    $P654."handle_types"(58)
    push_eh $P654
    .lex "self", self
    .lex "$/", param_655
.annotate "line", 228
    get_hll_global $P656, ["PAST"], "Regex"
.annotate "line", 229
    find_lex $P657, "$/"
    set $P658, $P657["sym"]
    unless_null $P658, vivify_282
    new $P658, "Undef"
  vivify_282:
    set $S659, $P658
    iseq $I660, $S659, "B"
    find_lex $P661, "$/"
    unless_null $P661, vivify_283
    new $P661, "Undef"
  vivify_283:
    $P662 = $P656."new"("\b", "enumcharlist" :named("pasttype"), $I660 :named("negate"), $P661 :named("node"))
.annotate "line", 228
    .lex "$past", $P662
    find_lex $P663, "$/"
.annotate "line", 230
    find_lex $P664, "$past"
    unless_null $P664, vivify_284
    new $P664, "Undef"
  vivify_284:
    $P665 = $P663."!make"($P664)
.annotate "line", 227
    .return ($P665)
  control_653:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P666, exception, "payload"
    .return ($P666)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<e>"  :subid("65_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_670
.annotate "line", 233
    new $P669, 'ExceptionHandler'
    set_addr $P669, control_668
    $P669."handle_types"(58)
    push_eh $P669
    .lex "self", self
    .lex "$/", param_670
.annotate "line", 234
    get_hll_global $P671, ["PAST"], "Regex"
.annotate "line", 235
    find_lex $P672, "$/"
    set $P673, $P672["sym"]
    unless_null $P673, vivify_285
    new $P673, "Undef"
  vivify_285:
    set $S674, $P673
    iseq $I675, $S674, "E"
    find_lex $P676, "$/"
    unless_null $P676, vivify_286
    new $P676, "Undef"
  vivify_286:
    $P677 = $P671."new"("\e", "enumcharlist" :named("pasttype"), $I675 :named("negate"), $P676 :named("node"))
.annotate "line", 234
    .lex "$past", $P677
    find_lex $P678, "$/"
.annotate "line", 236
    find_lex $P679, "$past"
    unless_null $P679, vivify_287
    new $P679, "Undef"
  vivify_287:
    $P680 = $P678."!make"($P679)
.annotate "line", 233
    .return ($P680)
  control_668:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P681, exception, "payload"
    .return ($P681)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<f>"  :subid("66_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_685
.annotate "line", 239
    new $P684, 'ExceptionHandler'
    set_addr $P684, control_683
    $P684."handle_types"(58)
    push_eh $P684
    .lex "self", self
    .lex "$/", param_685
.annotate "line", 240
    get_hll_global $P686, ["PAST"], "Regex"
.annotate "line", 241
    find_lex $P687, "$/"
    set $P688, $P687["sym"]
    unless_null $P688, vivify_288
    new $P688, "Undef"
  vivify_288:
    set $S689, $P688
    iseq $I690, $S689, "F"
    find_lex $P691, "$/"
    unless_null $P691, vivify_289
    new $P691, "Undef"
  vivify_289:
    $P692 = $P686."new"("\f", "enumcharlist" :named("pasttype"), $I690 :named("negate"), $P691 :named("node"))
.annotate "line", 240
    .lex "$past", $P692
    find_lex $P693, "$/"
.annotate "line", 242
    find_lex $P694, "$past"
    unless_null $P694, vivify_290
    new $P694, "Undef"
  vivify_290:
    $P695 = $P693."!make"($P694)
.annotate "line", 239
    .return ($P695)
  control_683:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P696, exception, "payload"
    .return ($P696)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<h>"  :subid("67_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_700
.annotate "line", 245
    new $P699, 'ExceptionHandler'
    set_addr $P699, control_698
    $P699."handle_types"(58)
    push_eh $P699
    .lex "self", self
    .lex "$/", param_700
.annotate "line", 246
    get_hll_global $P701, ["PAST"], "Regex"
.annotate "line", 247
    find_lex $P702, "$/"
    set $P703, $P702["sym"]
    unless_null $P703, vivify_291
    new $P703, "Undef"
  vivify_291:
    set $S704, $P703
    iseq $I705, $S704, "H"
    find_lex $P706, "$/"
    unless_null $P706, vivify_292
    new $P706, "Undef"
  vivify_292:
    $P707 = $P701."new"(unicode:"\t \x{a0}\u1680\u180e\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u202f\u205f\u3000", "enumcharlist" :named("pasttype"), $I705 :named("negate"), $P706 :named("node"))
.annotate "line", 246
    .lex "$past", $P707
    find_lex $P708, "$/"
.annotate "line", 248
    find_lex $P709, "$past"
    unless_null $P709, vivify_293
    new $P709, "Undef"
  vivify_293:
    $P710 = $P708."!make"($P709)
.annotate "line", 245
    .return ($P710)
  control_698:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P711, exception, "payload"
    .return ($P711)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<r>"  :subid("68_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_715
.annotate "line", 251
    new $P714, 'ExceptionHandler'
    set_addr $P714, control_713
    $P714."handle_types"(58)
    push_eh $P714
    .lex "self", self
    .lex "$/", param_715
.annotate "line", 252
    get_hll_global $P716, ["PAST"], "Regex"
.annotate "line", 253
    find_lex $P717, "$/"
    set $P718, $P717["sym"]
    unless_null $P718, vivify_294
    new $P718, "Undef"
  vivify_294:
    set $S719, $P718
    iseq $I720, $S719, "R"
    find_lex $P721, "$/"
    unless_null $P721, vivify_295
    new $P721, "Undef"
  vivify_295:
    $P722 = $P716."new"("\r", "enumcharlist" :named("pasttype"), $I720 :named("negate"), $P721 :named("node"))
.annotate "line", 252
    .lex "$past", $P722
    find_lex $P723, "$/"
.annotate "line", 254
    find_lex $P724, "$past"
    unless_null $P724, vivify_296
    new $P724, "Undef"
  vivify_296:
    $P725 = $P723."!make"($P724)
.annotate "line", 251
    .return ($P725)
  control_713:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P726, exception, "payload"
    .return ($P726)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<t>"  :subid("69_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_730
.annotate "line", 257
    new $P729, 'ExceptionHandler'
    set_addr $P729, control_728
    $P729."handle_types"(58)
    push_eh $P729
    .lex "self", self
    .lex "$/", param_730
.annotate "line", 258
    get_hll_global $P731, ["PAST"], "Regex"
.annotate "line", 259
    find_lex $P732, "$/"
    set $P733, $P732["sym"]
    unless_null $P733, vivify_297
    new $P733, "Undef"
  vivify_297:
    set $S734, $P733
    iseq $I735, $S734, "T"
    find_lex $P736, "$/"
    unless_null $P736, vivify_298
    new $P736, "Undef"
  vivify_298:
    $P737 = $P731."new"("\t", "enumcharlist" :named("pasttype"), $I735 :named("negate"), $P736 :named("node"))
.annotate "line", 258
    .lex "$past", $P737
    find_lex $P738, "$/"
.annotate "line", 260
    find_lex $P739, "$past"
    unless_null $P739, vivify_299
    new $P739, "Undef"
  vivify_299:
    $P740 = $P738."!make"($P739)
.annotate "line", 257
    .return ($P740)
  control_728:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P741, exception, "payload"
    .return ($P741)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<v>"  :subid("70_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_745
.annotate "line", 263
    new $P744, 'ExceptionHandler'
    set_addr $P744, control_743
    $P744."handle_types"(58)
    push_eh $P744
    .lex "self", self
    .lex "$/", param_745
.annotate "line", 264
    get_hll_global $P746, ["PAST"], "Regex"
.annotate "line", 265
    find_lex $P747, "$/"
    set $P748, $P747["sym"]
    unless_null $P748, vivify_300
    new $P748, "Undef"
  vivify_300:
    set $S749, $P748
    iseq $I750, $S749, "V"
    find_lex $P751, "$/"
    unless_null $P751, vivify_301
    new $P751, "Undef"
  vivify_301:
    $P752 = $P746."new"(unicode:"\n\x{b}\f\r\x{85}\u2028\u2029", "enumcharlist" :named("pasttype"), $I750 :named("negate"), $P751 :named("node"))
.annotate "line", 264
    .lex "$past", $P752
    find_lex $P753, "$/"
.annotate "line", 266
    find_lex $P754, "$past"
    unless_null $P754, vivify_302
    new $P754, "Undef"
  vivify_302:
    $P755 = $P753."!make"($P754)
.annotate "line", 263
    .return ($P755)
  control_743:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P756, exception, "payload"
    .return ($P756)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backslash:sym<misc>"  :subid("71_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_760
.annotate "line", 270
    new $P759, 'ExceptionHandler'
    set_addr $P759, control_758
    $P759."handle_types"(58)
    push_eh $P759
    .lex "self", self
    .lex "$/", param_760
.annotate "line", 271
    get_hll_global $P761, ["PAST"], "Regex"
    find_lex $P762, "$/"
    unless_null $P762, vivify_303
    new $P762, "Undef"
  vivify_303:
    set $S763, $P762
    find_lex $P764, "$/"
    unless_null $P764, vivify_304
    new $P764, "Undef"
  vivify_304:
    $P765 = $P761."new"($S763, "literal" :named("pasttype"), $P764 :named("node"))
    .lex "$past", $P765
    find_lex $P766, "$/"
.annotate "line", 272
    find_lex $P767, "$past"
    unless_null $P767, vivify_305
    new $P767, "Undef"
  vivify_305:
    $P768 = $P766."!make"($P767)
.annotate "line", 270
    .return ($P768)
  control_758:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P769, exception, "payload"
    .return ($P769)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "assertion:sym<?>"  :subid("72_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_773
.annotate "line", 276
    .const 'Sub' $P786 = "74_1256021422.69758" 
    capture_lex $P786
    .const 'Sub' $P779 = "73_1256021422.69758" 
    capture_lex $P779
    new $P772, 'ExceptionHandler'
    set_addr $P772, control_771
    $P772."handle_types"(58)
    push_eh $P772
    .lex "self", self
    .lex "$/", param_773
.annotate "line", 277
    new $P774, "Undef"
    .lex "$past", $P774
.annotate "line", 278
    find_lex $P776, "$/"
    set $P777, $P776["assertion"]
    unless_null $P777, vivify_306
    new $P777, "Undef"
  vivify_306:
    if $P777, if_775
.annotate "line", 282
    .const 'Sub' $P786 = "74_1256021422.69758" 
    capture_lex $P786
    $P786()
    goto if_775_end
  if_775:
.annotate "line", 278
    .const 'Sub' $P779 = "73_1256021422.69758" 
    capture_lex $P779
    $P779()
  if_775_end:
    find_lex $P788, "$/"
.annotate "line", 283
    find_lex $P789, "$past"
    unless_null $P789, vivify_309
    new $P789, "Undef"
  vivify_309:
    $P790 = $P788."!make"($P789)
.annotate "line", 276
    .return ($P790)
  control_771:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P791, exception, "payload"
    .return ($P791)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block785"  :anon :subid("74_1256021422.69758") :outer("72_1256021422.69758")
.annotate "line", 282
    new $P787, "Integer"
    assign $P787, 0
    store_lex "$past", $P787
    .return ($P787)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block778"  :anon :subid("73_1256021422.69758") :outer("72_1256021422.69758")
.annotate "line", 279
    find_lex $P780, "$/"
    set $P781, $P780["assertion"]
    unless_null $P781, vivify_307
    new $P781, "Undef"
  vivify_307:
    $P782 = $P781."ast"()
    store_lex "$past", $P782
.annotate "line", 280
    find_lex $P783, "$past"
    unless_null $P783, vivify_308
    new $P783, "Undef"
  vivify_308:
    $P784 = $P783."subtype"("zerowidth")
.annotate "line", 278
    .return ($P784)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "assertion:sym<!>"  :subid("75_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_795
.annotate "line", 286
    .const 'Sub' $P812 = "77_1256021422.69758" 
    capture_lex $P812
    .const 'Sub' $P801 = "76_1256021422.69758" 
    capture_lex $P801
    new $P794, 'ExceptionHandler'
    set_addr $P794, control_793
    $P794."handle_types"(58)
    push_eh $P794
    .lex "self", self
    .lex "$/", param_795
.annotate "line", 287
    new $P796, "Undef"
    .lex "$past", $P796
.annotate "line", 288
    find_lex $P798, "$/"
    set $P799, $P798["assertion"]
    unless_null $P799, vivify_310
    new $P799, "Undef"
  vivify_310:
    if $P799, if_797
.annotate "line", 293
    .const 'Sub' $P812 = "77_1256021422.69758" 
    capture_lex $P812
    $P812()
    goto if_797_end
  if_797:
.annotate "line", 288
    .const 'Sub' $P801 = "76_1256021422.69758" 
    capture_lex $P801
    $P801()
  if_797_end:
    find_lex $P816, "$/"
.annotate "line", 296
    find_lex $P817, "$past"
    unless_null $P817, vivify_316
    new $P817, "Undef"
  vivify_316:
    $P818 = $P816."!make"($P817)
.annotate "line", 286
    .return ($P818)
  control_793:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P819, exception, "payload"
    .return ($P819)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block811"  :anon :subid("77_1256021422.69758") :outer("75_1256021422.69758")
.annotate "line", 294
    get_hll_global $P813, ["PAST"], "Regex"
    find_lex $P814, "$/"
    unless_null $P814, vivify_311
    new $P814, "Undef"
  vivify_311:
    $P815 = $P813."new"("anchor" :named("pasttype"), "fail" :named("subtype"), $P814 :named("node"))
    store_lex "$past", $P815
.annotate "line", 293
    .return ($P815)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block800"  :anon :subid("76_1256021422.69758") :outer("75_1256021422.69758")
.annotate "line", 289
    find_lex $P802, "$/"
    set $P803, $P802["assertion"]
    unless_null $P803, vivify_312
    new $P803, "Undef"
  vivify_312:
    $P804 = $P803."ast"()
    store_lex "$past", $P804
.annotate "line", 290
    find_lex $P805, "$past"
    unless_null $P805, vivify_313
    new $P805, "Undef"
  vivify_313:
    find_lex $P806, "$past"
    unless_null $P806, vivify_314
    new $P806, "Undef"
  vivify_314:
    $P807 = $P806."negate"()
    isfalse $I808, $P807
    $P805."negate"($I808)
.annotate "line", 291
    find_lex $P809, "$past"
    unless_null $P809, vivify_315
    new $P809, "Undef"
  vivify_315:
    $P810 = $P809."subtype"("zerowidth")
.annotate "line", 288
    .return ($P810)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "assertion:sym<method>"  :subid("78_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_823
.annotate "line", 299
    new $P822, 'ExceptionHandler'
    set_addr $P822, control_821
    $P822."handle_types"(58)
    push_eh $P822
    .lex "self", self
    .lex "$/", param_823
.annotate "line", 300
    find_lex $P824, "$/"
    set $P825, $P824["assertion"]
    unless_null $P825, vivify_317
    new $P825, "Undef"
  vivify_317:
    $P826 = $P825."ast"()
    .lex "$past", $P826
.annotate "line", 301
    find_lex $P827, "$past"
    unless_null $P827, vivify_318
    new $P827, "Undef"
  vivify_318:
    $P827."subtype"("method")
    find_lex $P828, "$/"
.annotate "line", 302
    find_lex $P829, "$past"
    unless_null $P829, vivify_319
    new $P829, "Undef"
  vivify_319:
    $P830 = $P828."!make"($P829)
.annotate "line", 299
    .return ($P830)
  control_821:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P831, exception, "payload"
    .return ($P831)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "assertion:sym<name>"  :subid("79_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_835
.annotate "line", 305
    .const 'Sub' $P854 = "81_1256021422.69758" 
    capture_lex $P854
    .const 'Sub' $P845 = "80_1256021422.69758" 
    capture_lex $P845
    new $P834, 'ExceptionHandler'
    set_addr $P834, control_833
    $P834."handle_types"(58)
    push_eh $P834
    .lex "self", self
    .lex "$/", param_835
.annotate "line", 306
    find_lex $P836, "$/"
    set $P837, $P836["longname"]
    unless_null $P837, vivify_320
    new $P837, "Undef"
  vivify_320:
    set $S838, $P837
    new $P839, 'String'
    set $P839, $S838
    .lex "$name", $P839
.annotate "line", 307
    new $P840, "Undef"
    .lex "$past", $P840
.annotate "line", 308
    find_lex $P842, "$/"
    set $P843, $P842["assertion"]
    unless_null $P843, vivify_321
    new $P843, "Undef"
  vivify_321:
    if $P843, if_841
.annotate "line", 312
    .const 'Sub' $P854 = "81_1256021422.69758" 
    capture_lex $P854
    $P854()
    goto if_841_end
  if_841:
.annotate "line", 308
    .const 'Sub' $P845 = "80_1256021422.69758" 
    capture_lex $P845
    $P845()
  if_841_end:
    find_lex $P898, "$/"
.annotate "line", 324
    find_lex $P899, "$past"
    unless_null $P899, vivify_340
    new $P899, "Undef"
  vivify_340:
    $P900 = $P898."!make"($P899)
.annotate "line", 305
    .return ($P900)
  control_833:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P901, exception, "payload"
    .return ($P901)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block853"  :anon :subid("81_1256021422.69758") :outer("79_1256021422.69758")
.annotate "line", 312
    .const 'Sub' $P879 = "83_1256021422.69758" 
    capture_lex $P879
    .const 'Sub' $P865 = "82_1256021422.69758" 
    capture_lex $P865
.annotate "line", 313
    get_hll_global $P855, ["PAST"], "Regex"
    find_lex $P856, "$name"
    unless_null $P856, vivify_322
    new $P856, "Undef"
  vivify_322:
    find_lex $P857, "$name"
    unless_null $P857, vivify_323
    new $P857, "Undef"
  vivify_323:
.annotate "line", 314
    find_lex $P858, "$/"
    unless_null $P858, vivify_324
    new $P858, "Undef"
  vivify_324:
    $P859 = $P855."new"($P856, $P857 :named("name"), "subrule" :named("pasttype"), "capture" :named("subtype"), $P858 :named("node"))
.annotate "line", 313
    store_lex "$past", $P859
.annotate "line", 315
    find_lex $P862, "$/"
    set $P863, $P862["nibbler"]
    unless_null $P863, vivify_325
    new $P863, "Undef"
  vivify_325:
    if $P863, if_861
    find_lex $P876, "$/"
    set $P877, $P876["arglist"]
    unless_null $P877, vivify_326
    new $P877, "Undef"
  vivify_326:
    if $P877, if_875
    set $P874, $P877
    goto if_875_end
  if_875:
.annotate "line", 318
    .const 'Sub' $P879 = "83_1256021422.69758" 
    capture_lex $P879
    $P897 = $P879()
    set $P874, $P897
  if_875_end:
.annotate "line", 315
    set $P860, $P874
    goto if_861_end
  if_861:
    .const 'Sub' $P865 = "82_1256021422.69758" 
    capture_lex $P865
    $P873 = $P865()
    set $P860, $P873
  if_861_end:
.annotate "line", 312
    .return ($P860)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block878"  :anon :subid("83_1256021422.69758") :outer("81_1256021422.69758")
.annotate "line", 318
    .const 'Sub' $P888 = "84_1256021422.69758" 
    capture_lex $P888
.annotate "line", 319
    find_lex $P881, "$/"
    set $P882, $P881["arglist"]
    unless_null $P882, vivify_327
    new $P882, "ResizablePMCArray"
  vivify_327:
    set $P883, $P882[0]
    unless_null $P883, vivify_328
    new $P883, "Hash"
  vivify_328:
    set $P884, $P883["arg"]
    unless_null $P884, vivify_329
    new $P884, "Undef"
  vivify_329:
    defined $I885, $P884
    unless $I885, for_undef_330
    iter $P880, $P884
    new $P895, 'ExceptionHandler'
    set_addr $P895, loop894_handler
    $P895."handle_types"(65, 67, 66)
    push_eh $P895
  loop894_test:
    unless $P880, loop894_done
    shift $P886, $P880
  loop894_redo:
    .const 'Sub' $P888 = "84_1256021422.69758" 
    capture_lex $P888
    $P888($P886)
  loop894_next:
    goto loop894_test
  loop894_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P896, exception, 'type'
    eq $P896, 65, loop894_next
    eq $P896, 67, loop894_redo
  loop894_done:
    pop_eh 
  for_undef_330:
.annotate "line", 318
    .return ($P880)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block887"  :anon :subid("84_1256021422.69758") :outer("83_1256021422.69758")
    .param pmc param_889
.annotate "line", 319
    .lex "$_", param_889
.annotate "line", 320
    find_lex $P890, "$past"
    unless_null $P890, vivify_331
    new $P890, "Undef"
  vivify_331:
    find_lex $P891, "$_"
    unless_null $P891, vivify_332
    new $P891, "Undef"
  vivify_332:
    $P892 = $P891."ast"()
    $P893 = $P890."push"($P892)
.annotate "line", 319
    .return ($P893)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block864"  :anon :subid("82_1256021422.69758") :outer("81_1256021422.69758")
.annotate "line", 316
    find_lex $P866, "$past"
    unless_null $P866, vivify_333
    new $P866, "Undef"
  vivify_333:
    find_lex $P867, "$/"
    set $P868, $P867["nibbler"]
    unless_null $P868, vivify_334
    new $P868, "ResizablePMCArray"
  vivify_334:
    set $P869, $P868[0]
    unless_null $P869, vivify_335
    new $P869, "Undef"
  vivify_335:
    $P870 = $P869."ast"()
    $P871 = "buildsub"($P870)
    $P872 = $P866."push"($P871)
.annotate "line", 315
    .return ($P872)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block844"  :anon :subid("80_1256021422.69758") :outer("79_1256021422.69758")
.annotate "line", 309
    find_lex $P846, "$/"
    set $P847, $P846["assertion"]
    unless_null $P847, vivify_336
    new $P847, "ResizablePMCArray"
  vivify_336:
    set $P848, $P847[0]
    unless_null $P848, vivify_337
    new $P848, "Undef"
  vivify_337:
    $P849 = $P848."ast"()
    store_lex "$past", $P849
.annotate "line", 310
    find_lex $P850, "$past"
    unless_null $P850, vivify_338
    new $P850, "Undef"
  vivify_338:
    find_lex $P851, "$name"
    unless_null $P851, vivify_339
    new $P851, "Undef"
  vivify_339:
    $P852 = "subrule_alias"($P850, $P851)
.annotate "line", 308
    .return ($P852)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "assertion:sym<[>"  :subid("85_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_905
.annotate "line", 327
    .const 'Sub' $P938 = "87_1256021422.69758" 
    capture_lex $P938
    .const 'Sub' $P920 = "86_1256021422.69758" 
    capture_lex $P920
    new $P904, 'ExceptionHandler'
    set_addr $P904, control_903
    $P904."handle_types"(58)
    push_eh $P904
    .lex "self", self
    .lex "$/", param_905
.annotate "line", 328
    find_lex $P906, "$/"
    set $P907, $P906["cclass_elem"]
    unless_null $P907, vivify_341
    new $P907, "Undef"
  vivify_341:
    .lex "$clist", $P907
.annotate "line", 329
    find_lex $P908, "$clist"
    unless_null $P908, vivify_342
    new $P908, "ResizablePMCArray"
  vivify_342:
    set $P909, $P908[0]
    unless_null $P909, vivify_343
    new $P909, "Undef"
  vivify_343:
    $P910 = $P909."ast"()
    .lex "$past", $P910
.annotate "line", 330
    find_lex $P914, "$past"
    unless_null $P914, vivify_344
    new $P914, "Undef"
  vivify_344:
    $P915 = $P914."negate"()
    if $P915, if_913
    set $P912, $P915
    goto if_913_end
  if_913:
    find_lex $P916, "$past"
    unless_null $P916, vivify_345
    new $P916, "Undef"
  vivify_345:
    $S917 = $P916."pasttype"()
    iseq $I918, $S917, "subrule"
    new $P912, 'Integer'
    set $P912, $I918
  if_913_end:
    unless $P912, if_911_end
    .const 'Sub' $P920 = "86_1256021422.69758" 
    capture_lex $P920
    $P920()
  if_911_end:
.annotate "line", 338
    new $P928, "Integer"
    assign $P928, 1
    .lex "$i", $P928
.annotate "line", 339
    find_lex $P929, "$clist"
    unless_null $P929, vivify_349
    new $P929, "Undef"
  vivify_349:
    set $N930, $P929
    new $P931, 'Float'
    set $P931, $N930
    .lex "$n", $P931
.annotate "line", 340
    new $P965, 'ExceptionHandler'
    set_addr $P965, loop964_handler
    $P965."handle_types"(65, 67, 66)
    push_eh $P965
  loop964_test:
    find_lex $P932, "$i"
    unless_null $P932, vivify_350
    new $P932, "Undef"
  vivify_350:
    set $N933, $P932
    find_lex $P934, "$n"
    unless_null $P934, vivify_351
    new $P934, "Undef"
  vivify_351:
    set $N935, $P934
    islt $I936, $N933, $N935
    unless $I936, loop964_done
  loop964_redo:
    .const 'Sub' $P938 = "87_1256021422.69758" 
    capture_lex $P938
    $P938()
  loop964_next:
    goto loop964_test
  loop964_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P966, exception, 'type'
    eq $P966, 65, loop964_next
    eq $P966, 67, loop964_redo
  loop964_done:
    pop_eh 
    find_lex $P967, "$/"
.annotate "line", 351
    find_lex $P968, "$past"
    unless_null $P968, vivify_364
    new $P968, "Undef"
  vivify_364:
    $P969 = $P967."!make"($P968)
.annotate "line", 327
    .return ($P969)
  control_903:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P970, exception, "payload"
    .return ($P970)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block919"  :anon :subid("86_1256021422.69758") :outer("85_1256021422.69758")
.annotate "line", 331
    find_lex $P921, "$past"
    unless_null $P921, vivify_346
    new $P921, "Undef"
  vivify_346:
    $P921."subtype"("zerowidth")
.annotate "line", 332
    get_hll_global $P922, ["PAST"], "Regex"
.annotate "line", 333
    find_lex $P923, "$past"
    unless_null $P923, vivify_347
    new $P923, "Undef"
  vivify_347:
.annotate "line", 334
    get_hll_global $P924, ["PAST"], "Regex"
    $P925 = $P924."new"("charclass" :named("pasttype"), "." :named("subtype"))
.annotate "line", 335
    find_lex $P926, "$/"
    unless_null $P926, vivify_348
    new $P926, "Undef"
  vivify_348:
    $P927 = $P922."new"($P923, $P925, $P926 :named("node"))
.annotate "line", 332
    store_lex "$past", $P927
.annotate "line", 330
    .return ($P927)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block937"  :anon :subid("87_1256021422.69758") :outer("85_1256021422.69758")
.annotate "line", 340
    .const 'Sub' $P956 = "89_1256021422.69758" 
    capture_lex $P956
    .const 'Sub' $P948 = "88_1256021422.69758" 
    capture_lex $P948
.annotate "line", 341
    find_lex $P939, "$i"
    unless_null $P939, vivify_352
    new $P939, "Undef"
  vivify_352:
    set $I940, $P939
    find_lex $P941, "$clist"
    unless_null $P941, vivify_353
    new $P941, "ResizablePMCArray"
  vivify_353:
    set $P942, $P941[$I940]
    unless_null $P942, vivify_354
    new $P942, "Undef"
  vivify_354:
    $P943 = $P942."ast"()
    .lex "$ast", $P943
.annotate "line", 342
    find_lex $P945, "$ast"
    unless_null $P945, vivify_355
    new $P945, "Undef"
  vivify_355:
    $P946 = $P945."negate"()
    if $P946, if_944
.annotate "line", 346
    .const 'Sub' $P956 = "89_1256021422.69758" 
    capture_lex $P956
    $P956()
    goto if_944_end
  if_944:
.annotate "line", 342
    .const 'Sub' $P948 = "88_1256021422.69758" 
    capture_lex $P948
    $P948()
  if_944_end:
.annotate "line", 349
    find_lex $P962, "$i"
    unless_null $P962, vivify_363
    new $P962, "Undef"
  vivify_363:
    add $P963, $P962, 1
    store_lex "$i", $P963
.annotate "line", 340
    .return ($P963)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block955"  :anon :subid("89_1256021422.69758") :outer("87_1256021422.69758")
.annotate "line", 347
    get_hll_global $P957, ["PAST"], "Regex"
    find_lex $P958, "$past"
    unless_null $P958, vivify_356
    new $P958, "Undef"
  vivify_356:
    find_lex $P959, "$ast"
    unless_null $P959, vivify_357
    new $P959, "Undef"
  vivify_357:
    find_lex $P960, "$/"
    unless_null $P960, vivify_358
    new $P960, "Undef"
  vivify_358:
    $P961 = $P957."new"($P958, $P959, "alt" :named("pasttype"), $P960 :named("node"))
    store_lex "$past", $P961
.annotate "line", 346
    .return ($P961)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block947"  :anon :subid("88_1256021422.69758") :outer("87_1256021422.69758")
.annotate "line", 343
    find_lex $P949, "$ast"
    unless_null $P949, vivify_359
    new $P949, "Undef"
  vivify_359:
    $P949."subtype"("zerowidth")
.annotate "line", 344
    get_hll_global $P950, ["PAST"], "Regex"
    find_lex $P951, "$ast"
    unless_null $P951, vivify_360
    new $P951, "Undef"
  vivify_360:
    find_lex $P952, "$past"
    unless_null $P952, vivify_361
    new $P952, "Undef"
  vivify_361:
    find_lex $P953, "$/"
    unless_null $P953, vivify_362
    new $P953, "Undef"
  vivify_362:
    $P954 = $P950."new"($P951, $P952, "concat" :named("pasttype"), $P953 :named("node"))
    store_lex "$past", $P954
.annotate "line", 342
    .return ($P954)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "cclass_elem"  :subid("90_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_974
.annotate "line", 354
    .const 'Sub' $P991 = "92_1256021422.69758" 
    capture_lex $P991
    .const 'Sub' $P981 = "91_1256021422.69758" 
    capture_lex $P981
    new $P973, 'ExceptionHandler'
    set_addr $P973, control_972
    $P973."handle_types"(58)
    push_eh $P973
    .lex "self", self
    .lex "$/", param_974
.annotate "line", 355
    new $P975, "String"
    assign $P975, ""
    .lex "$str", $P975
.annotate "line", 356
    new $P976, "Undef"
    .lex "$past", $P976
.annotate "line", 357
    find_lex $P978, "$/"
    set $P979, $P978["name"]
    unless_null $P979, vivify_365
    new $P979, "Undef"
  vivify_365:
    if $P979, if_977
.annotate "line", 360
    .const 'Sub' $P991 = "92_1256021422.69758" 
    capture_lex $P991
    $P991()
    goto if_977_end
  if_977:
.annotate "line", 357
    .const 'Sub' $P981 = "91_1256021422.69758" 
    capture_lex $P981
    $P981()
  if_977_end:
.annotate "line", 388
    find_lex $P1030, "$past"
    unless_null $P1030, vivify_385
    new $P1030, "Undef"
  vivify_385:
    find_lex $P1031, "$/"
    set $P1032, $P1031["sign"]
    unless_null $P1032, vivify_386
    new $P1032, "Undef"
  vivify_386:
    set $S1033, $P1032
    iseq $I1034, $S1033, "-"
    $P1030."negate"($I1034)
    find_lex $P1035, "$/"
.annotate "line", 389
    find_lex $P1036, "$past"
    unless_null $P1036, vivify_387
    new $P1036, "Undef"
  vivify_387:
    $P1037 = $P1035."!make"($P1036)
.annotate "line", 354
    .return ($P1037)
  control_972:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1038, exception, "payload"
    .return ($P1038)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block990"  :anon :subid("92_1256021422.69758") :outer("90_1256021422.69758")
.annotate "line", 360
    .const 'Sub' $P998 = "93_1256021422.69758" 
    capture_lex $P998
.annotate "line", 361
    find_lex $P993, "$/"
    set $P994, $P993["charspec"]
    unless_null $P994, vivify_366
    new $P994, "Undef"
  vivify_366:
    defined $I995, $P994
    unless $I995, for_undef_367
    iter $P992, $P994
    new $P1024, 'ExceptionHandler'
    set_addr $P1024, loop1023_handler
    $P1024."handle_types"(65, 67, 66)
    push_eh $P1024
  loop1023_test:
    unless $P992, loop1023_done
    shift $P996, $P992
  loop1023_redo:
    .const 'Sub' $P998 = "93_1256021422.69758" 
    capture_lex $P998
    $P998($P996)
  loop1023_next:
    goto loop1023_test
  loop1023_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1025, exception, 'type'
    eq $P1025, 65, loop1023_next
    eq $P1025, 67, loop1023_redo
  loop1023_done:
    pop_eh 
  for_undef_367:
.annotate "line", 386
    get_hll_global $P1026, ["PAST"], "Regex"
    find_lex $P1027, "$str"
    unless_null $P1027, vivify_380
    new $P1027, "Undef"
  vivify_380:
    find_lex $P1028, "$/"
    unless_null $P1028, vivify_381
    new $P1028, "Undef"
  vivify_381:
    $P1029 = $P1026."new"($P1027, "enumcharlist" :named("pasttype"), $P1028 :named("node"))
    store_lex "$past", $P1029
.annotate "line", 360
    .return ($P1029)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block997"  :anon :subid("93_1256021422.69758") :outer("92_1256021422.69758")
    .param pmc param_999
.annotate "line", 361
    .const 'Sub' $P1017 = "95_1256021422.69758" 
    capture_lex $P1017
    .const 'Sub' $P1005 = "94_1256021422.69758" 
    capture_lex $P1005
    .lex "$_", param_999
.annotate "line", 362
    find_lex $P1002, "$_"
    unless_null $P1002, vivify_368
    new $P1002, "ResizablePMCArray"
  vivify_368:
    set $P1003, $P1002[1]
    unless_null $P1003, vivify_369
    new $P1003, "Undef"
  vivify_369:
    if $P1003, if_1001
.annotate "line", 384
    .const 'Sub' $P1017 = "95_1256021422.69758" 
    capture_lex $P1017
    $P1022 = $P1017()
    set $P1000, $P1022
.annotate "line", 362
    goto if_1001_end
  if_1001:
    .const 'Sub' $P1005 = "94_1256021422.69758" 
    capture_lex $P1005
    $P1015 = $P1005()
    set $P1000, $P1015
  if_1001_end:
.annotate "line", 361
    .return ($P1000)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1016"  :anon :subid("95_1256021422.69758") :outer("93_1256021422.69758")
.annotate "line", 384
    find_lex $P1018, "$str"
    unless_null $P1018, vivify_370
    new $P1018, "Undef"
  vivify_370:
    find_lex $P1019, "$_"
    unless_null $P1019, vivify_371
    new $P1019, "ResizablePMCArray"
  vivify_371:
    set $P1020, $P1019[0]
    unless_null $P1020, vivify_372
    new $P1020, "Undef"
  vivify_372:
    concat $P1021, $P1018, $P1020
    store_lex "$str", $P1021
    .return ($P1021)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1004"  :anon :subid("94_1256021422.69758") :outer("93_1256021422.69758")
.annotate "line", 363
    find_lex $P1006, "$_"
    unless_null $P1006, vivify_373
    new $P1006, "ResizablePMCArray"
  vivify_373:
    set $P1007, $P1006[0]
    unless_null $P1007, vivify_374
    new $P1007, "Undef"
  vivify_374:
    .lex "$a", $P1007
.annotate "line", 364
    find_lex $P1008, "$_"
    unless_null $P1008, vivify_375
    new $P1008, "ResizablePMCArray"
  vivify_375:
    set $P1009, $P1008[1]
    unless_null $P1009, vivify_376
    new $P1009, "ResizablePMCArray"
  vivify_376:
    set $P1010, $P1009[0]
    unless_null $P1010, vivify_377
    new $P1010, "Undef"
  vivify_377:
    .lex "$b", $P1010
.annotate "line", 365

                             $P0 = find_lex '$a'
                             $S0 = $P0
                             $I0 = ord $S0
                             $P1 = find_lex '$b'
                             $S1 = $P1
                             $I1 = ord $S1
                             $S2 = ''
                           cclass_loop:
                             if $I0 > $I1 goto cclass_done
                             $S0 = chr $I0
                             $S2 .= $S0
                             inc $I0
                             goto cclass_loop
                           cclass_done:
                             $P1011 = box $S2
                         
    .lex "$c", $P1011
.annotate "line", 382
    find_lex $P1012, "$str"
    unless_null $P1012, vivify_378
    new $P1012, "Undef"
  vivify_378:
    find_lex $P1013, "$c"
    unless_null $P1013, vivify_379
    new $P1013, "Undef"
  vivify_379:
    concat $P1014, $P1012, $P1013
    store_lex "$str", $P1014
.annotate "line", 362
    .return ($P1014)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block980"  :anon :subid("91_1256021422.69758") :outer("90_1256021422.69758")
.annotate "line", 358
    find_lex $P982, "$/"
    set $P983, $P982["name"]
    unless_null $P983, vivify_382
    new $P983, "Undef"
  vivify_382:
    set $S984, $P983
    new $P985, 'String'
    set $P985, $S984
    .lex "$name", $P985
.annotate "line", 359
    get_hll_global $P986, ["PAST"], "Regex"
    find_lex $P987, "$name"
    unless_null $P987, vivify_383
    new $P987, "Undef"
  vivify_383:
    find_lex $P988, "$/"
    unless_null $P988, vivify_384
    new $P988, "Undef"
  vivify_384:
    $P989 = $P986."new"($P987, "subrule" :named("pasttype"), "method" :named("subtype"), $P988 :named("node"))
    store_lex "$past", $P989
.annotate "line", 357
    .return ($P989)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "mod_internal"  :subid("96_1256021422.69758") :method :outer("11_1256021422.69758")
    .param pmc param_1042
.annotate "line", 392
    new $P1041, 'ExceptionHandler'
    set_addr $P1041, control_1040
    $P1041."handle_types"(58)
    push_eh $P1041
    .lex "self", self
    .lex "$/", param_1042
.annotate "line", 393
    get_global $P1043, "@MODIFIERS"
    unless_null $P1043, vivify_388
    new $P1043, "ResizablePMCArray"
  vivify_388:
    set $P1044, $P1043[0]
    unless_null $P1044, vivify_389
    new $P1044, "Undef"
  vivify_389:
    .lex "%mods", $P1044
.annotate "line", 394
    find_lex $P1047, "$/"
    set $P1048, $P1047["n"]
    unless_null $P1048, vivify_390
    new $P1048, "ResizablePMCArray"
  vivify_390:
    set $P1049, $P1048[0]
    unless_null $P1049, vivify_391
    new $P1049, "Undef"
  vivify_391:
    set $S1050, $P1049
    isgt $I1051, $S1050, ""
    if $I1051, if_1046
    new $P1056, "Integer"
    assign $P1056, 1
    set $P1045, $P1056
    goto if_1046_end
  if_1046:
    find_lex $P1052, "$/"
    set $P1053, $P1052["n"]
    unless_null $P1053, vivify_392
    new $P1053, "ResizablePMCArray"
  vivify_392:
    set $P1054, $P1053[0]
    unless_null $P1054, vivify_393
    new $P1054, "Undef"
  vivify_393:
    set $N1055, $P1054
    new $P1045, 'Float'
    set $P1045, $N1055
  if_1046_end:
    .lex "$n", $P1045
.annotate "line", 395
    find_lex $P1057, "$n"
    unless_null $P1057, vivify_394
    new $P1057, "Undef"
  vivify_394:
    find_lex $P1058, "$/"
    set $P1059, $P1058["mod_ident"]
    unless_null $P1059, vivify_395
    new $P1059, "Hash"
  vivify_395:
    set $P1060, $P1059["sym"]
    unless_null $P1060, vivify_396
    new $P1060, "Undef"
  vivify_396:
    set $S1061, $P1060
    find_lex $P1062, "%mods"
    unless_null $P1062, vivify_397
    new $P1062, "Hash"
    store_lex "%mods", $P1062
  vivify_397:
    set $P1062[$S1061], $P1057
    find_lex $P1063, "$/"
.annotate "line", 396
    $P1064 = $P1063."!make"(0)
.annotate "line", 392
    .return ($P1064)
  control_1040:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1065, exception, "payload"
    .return ($P1065)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "buildsub"  :subid("97_1256021422.69758") :outer("11_1256021422.69758")
    .param pmc param_1069
.annotate "line", 399
    new $P1068, 'ExceptionHandler'
    set_addr $P1068, control_1067
    $P1068."handle_types"(58)
    push_eh $P1068
    .lex "$rpast", param_1069
.annotate "line", 400
    find_lex $P1070, "$rpast"
    unless_null $P1070, vivify_398
    new $P1070, "Undef"
  vivify_398:
    $P1071 = "capnames"($P1070, 0)
    .lex "%capnames", $P1071
.annotate "line", 401
    new $P1072, "Integer"
    assign $P1072, 0
    find_lex $P1073, "%capnames"
    unless_null $P1073, vivify_399
    new $P1073, "Hash"
    store_lex "%capnames", $P1073
  vivify_399:
    set $P1073[""], $P1072
.annotate "line", 402
    get_hll_global $P1074, ["PAST"], "Regex"
.annotate "line", 403
    get_hll_global $P1075, ["PAST"], "Regex"
    $P1076 = $P1075."new"("scan" :named("pasttype"))
.annotate "line", 404
    find_lex $P1077, "$rpast"
    unless_null $P1077, vivify_400
    new $P1077, "Undef"
  vivify_400:
.annotate "line", 405
    get_hll_global $P1078, ["PAST"], "Regex"
    $P1079 = $P1078."new"("pass" :named("pasttype"))
.annotate "line", 407
    find_lex $P1080, "%capnames"
    unless_null $P1080, vivify_401
    new $P1080, "Hash"
  vivify_401:
    $P1081 = $P1074."new"($P1076, $P1077, $P1079, "concat" :named("pasttype"), $P1080 :named("capnames"))
.annotate "line", 402
    store_lex "$rpast", $P1081
.annotate "line", 409
    get_hll_global $P1082, ["PAST"], "Block"
    find_lex $P1083, "$rpast"
    unless_null $P1083, vivify_402
    new $P1083, "Undef"
  vivify_402:
    $P1084 = $P1082."new"($P1083, "method" :named("blocktype"))
.annotate "line", 399
    .return ($P1084)
  control_1067:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1085, exception, "payload"
    .return ($P1085)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "capnames"  :subid("98_1256021422.69758") :outer("11_1256021422.69758")
    .param pmc param_1089
    .param pmc param_1090
.annotate "line", 412
    .const 'Sub' $P1325 = "114_1256021422.69758" 
    capture_lex $P1325
    .const 'Sub' $P1261 = "110_1256021422.69758" 
    capture_lex $P1261
    .const 'Sub' $P1214 = "106_1256021422.69758" 
    capture_lex $P1214
    .const 'Sub' $P1166 = "103_1256021422.69758" 
    capture_lex $P1166
    .const 'Sub' $P1099 = "99_1256021422.69758" 
    capture_lex $P1099
    new $P1088, 'ExceptionHandler'
    set_addr $P1088, control_1087
    $P1088."handle_types"(58)
    push_eh $P1088
    .lex "$ast", param_1089
    .lex "$count", param_1090
.annotate "line", 413
    new $P1091, "Hash"
    .lex "%capnames", $P1091
.annotate "line", 414
    find_lex $P1092, "$ast"
    unless_null $P1092, vivify_403
    new $P1092, "Undef"
  vivify_403:
    $P1093 = $P1092."pasttype"()
    .lex "$pasttype", $P1093
.annotate "line", 415
    find_lex $P1095, "$pasttype"
    unless_null $P1095, vivify_404
    new $P1095, "Undef"
  vivify_404:
    set $S1096, $P1095
    iseq $I1097, $S1096, "alt"
    if $I1097, if_1094
.annotate "line", 428
    find_lex $P1162, "$pasttype"
    unless_null $P1162, vivify_405
    new $P1162, "Undef"
  vivify_405:
    set $S1163, $P1162
    iseq $I1164, $S1163, "concat"
    if $I1164, if_1161
.annotate "line", 437
    find_lex $P1207, "$pasttype"
    unless_null $P1207, vivify_406
    new $P1207, "Undef"
  vivify_406:
    set $S1208, $P1207
    iseq $I1209, $S1208, "subrule"
    if $I1209, if_1206
    new $P1205, 'Integer'
    set $P1205, $I1209
    goto if_1206_end
  if_1206:
    find_lex $P1210, "$ast"
    unless_null $P1210, vivify_407
    new $P1210, "Undef"
  vivify_407:
    $S1211 = $P1210."subtype"()
    iseq $I1212, $S1211, "capture"
    new $P1205, 'Integer'
    set $P1205, $I1212
  if_1206_end:
    if $P1205, if_1204
.annotate "line", 450
    find_lex $P1257, "$pasttype"
    unless_null $P1257, vivify_408
    new $P1257, "Undef"
  vivify_408:
    set $S1258, $P1257
    iseq $I1259, $S1258, "subcapture"
    if $I1259, if_1256
.annotate "line", 467
    find_lex $P1321, "$pasttype"
    unless_null $P1321, vivify_409
    new $P1321, "Undef"
  vivify_409:
    set $S1322, $P1321
    iseq $I1323, $S1322, "quant"
    unless $I1323, if_1320_end
    .const 'Sub' $P1325 = "114_1256021422.69758" 
    capture_lex $P1325
    $P1325()
  if_1320_end:
.annotate "line", 415
    goto if_1256_end
  if_1256:
.annotate "line", 450
    .const 'Sub' $P1261 = "110_1256021422.69758" 
    capture_lex $P1261
    $P1261()
  if_1256_end:
.annotate "line", 415
    goto if_1204_end
  if_1204:
.annotate "line", 437
    .const 'Sub' $P1214 = "106_1256021422.69758" 
    capture_lex $P1214
    $P1214()
  if_1204_end:
.annotate "line", 415
    goto if_1161_end
  if_1161:
.annotate "line", 428
    .const 'Sub' $P1166 = "103_1256021422.69758" 
    capture_lex $P1166
    $P1166()
  if_1161_end:
.annotate "line", 415
    goto if_1094_end
  if_1094:
    .const 'Sub' $P1099 = "99_1256021422.69758" 
    capture_lex $P1099
    $P1099()
  if_1094_end:
.annotate "line", 474
    find_lex $P1345, "$count"
    unless_null $P1345, vivify_491
    new $P1345, "Undef"
  vivify_491:
    find_lex $P1346, "%capnames"
    unless_null $P1346, vivify_492
    new $P1346, "Hash"
    store_lex "%capnames", $P1346
  vivify_492:
    set $P1346[""], $P1345
.annotate "line", 475
    find_lex $P1347, "%capnames"
    unless_null $P1347, vivify_493
    new $P1347, "Hash"
  vivify_493:
.annotate "line", 412
    .return ($P1347)
  control_1087:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1348, exception, "payload"
    .return ($P1348)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1324"  :anon :subid("114_1256021422.69758") :outer("98_1256021422.69758")
.annotate "line", 467
    .const 'Sub' $P1335 = "115_1256021422.69758" 
    capture_lex $P1335
.annotate "line", 468
    find_lex $P1326, "$ast"
    unless_null $P1326, vivify_410
    new $P1326, "ResizablePMCArray"
  vivify_410:
    set $P1327, $P1326[0]
    unless_null $P1327, vivify_411
    new $P1327, "Undef"
  vivify_411:
    find_lex $P1328, "$count"
    unless_null $P1328, vivify_412
    new $P1328, "Undef"
  vivify_412:
    $P1329 = "capnames"($P1327, $P1328)
    .lex "%astcap", $P1329
.annotate "line", 469
    find_lex $P1331, "%astcap"
    unless_null $P1331, vivify_413
    new $P1331, "Hash"
  vivify_413:
    defined $I1332, $P1331
    unless $I1332, for_undef_414
    iter $P1330, $P1331
    new $P1341, 'ExceptionHandler'
    set_addr $P1341, loop1340_handler
    $P1341."handle_types"(65, 67, 66)
    push_eh $P1341
  loop1340_test:
    unless $P1330, loop1340_done
    shift $P1333, $P1330
  loop1340_redo:
    .const 'Sub' $P1335 = "115_1256021422.69758" 
    capture_lex $P1335
    $P1335($P1333)
  loop1340_next:
    goto loop1340_test
  loop1340_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1342, exception, 'type'
    eq $P1342, 65, loop1340_next
    eq $P1342, 67, loop1340_redo
  loop1340_done:
    pop_eh 
  for_undef_414:
.annotate "line", 472
    find_lex $P1343, "%astcap"
    unless_null $P1343, vivify_417
    new $P1343, "Hash"
  vivify_417:
    set $P1344, $P1343[""]
    unless_null $P1344, vivify_418
    new $P1344, "Undef"
  vivify_418:
    store_lex "$count", $P1344
.annotate "line", 467
    .return ($P1344)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1334"  :anon :subid("115_1256021422.69758") :outer("114_1256021422.69758")
    .param pmc param_1336
.annotate "line", 469
    .lex "$_", param_1336
.annotate "line", 470
    new $P1337, "Integer"
    assign $P1337, 2
    find_lex $P1338, "$_"
    unless_null $P1338, vivify_415
    new $P1338, "Undef"
  vivify_415:
    find_lex $P1339, "%capnames"
    unless_null $P1339, vivify_416
    new $P1339, "Hash"
    store_lex "%capnames", $P1339
  vivify_416:
    set $P1339[$P1338], $P1337
.annotate "line", 469
    .return ($P1337)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1260"  :anon :subid("110_1256021422.69758") :outer("98_1256021422.69758")
.annotate "line", 450
    .const 'Sub' $P1302 = "113_1256021422.69758" 
    capture_lex $P1302
    .const 'Sub' $P1270 = "111_1256021422.69758" 
    capture_lex $P1270
.annotate "line", 451
    find_lex $P1262, "$ast"
    unless_null $P1262, vivify_419
    new $P1262, "Undef"
  vivify_419:
    $P1263 = $P1262."name"()
    .lex "$name", $P1263
.annotate "line", 452

            $P0 = find_lex '$name'
            $S0 = $P0
            $P1264 = split '=', $S0
        
    .lex "@names", $P1264
.annotate "line", 457
    find_lex $P1266, "@names"
    unless_null $P1266, vivify_420
    new $P1266, "ResizablePMCArray"
  vivify_420:
    defined $I1267, $P1266
    unless $I1267, for_undef_421
    iter $P1265, $P1266
    new $P1291, 'ExceptionHandler'
    set_addr $P1291, loop1290_handler
    $P1291."handle_types"(65, 67, 66)
    push_eh $P1291
  loop1290_test:
    unless $P1265, loop1290_done
    shift $P1268, $P1265
  loop1290_redo:
    .const 'Sub' $P1270 = "111_1256021422.69758" 
    capture_lex $P1270
    $P1270($P1268)
  loop1290_next:
    goto loop1290_test
  loop1290_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1292, exception, 'type'
    eq $P1292, 65, loop1290_next
    eq $P1292, 67, loop1290_redo
  loop1290_done:
    pop_eh 
  for_undef_421:
.annotate "line", 461
    find_lex $P1293, "$ast"
    unless_null $P1293, vivify_427
    new $P1293, "ResizablePMCArray"
  vivify_427:
    set $P1294, $P1293[0]
    unless_null $P1294, vivify_428
    new $P1294, "Undef"
  vivify_428:
    find_lex $P1295, "$count"
    unless_null $P1295, vivify_429
    new $P1295, "Undef"
  vivify_429:
    $P1296 = "capnames"($P1294, $P1295)
    .lex "%x", $P1296
.annotate "line", 462
    find_lex $P1298, "%x"
    unless_null $P1298, vivify_430
    new $P1298, "Hash"
  vivify_430:
    defined $I1299, $P1298
    unless $I1299, for_undef_431
    iter $P1297, $P1298
    new $P1316, 'ExceptionHandler'
    set_addr $P1316, loop1315_handler
    $P1316."handle_types"(65, 67, 66)
    push_eh $P1316
  loop1315_test:
    unless $P1297, loop1315_done
    shift $P1300, $P1297
  loop1315_redo:
    .const 'Sub' $P1302 = "113_1256021422.69758" 
    capture_lex $P1302
    $P1302($P1300)
  loop1315_next:
    goto loop1315_test
  loop1315_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1317, exception, 'type'
    eq $P1317, 65, loop1315_next
    eq $P1317, 67, loop1315_redo
  loop1315_done:
    pop_eh 
  for_undef_431:
.annotate "line", 465
    find_lex $P1318, "%x"
    unless_null $P1318, vivify_440
    new $P1318, "Hash"
  vivify_440:
    set $P1319, $P1318[""]
    unless_null $P1319, vivify_441
    new $P1319, "Undef"
  vivify_441:
    store_lex "$count", $P1319
.annotate "line", 450
    .return ($P1319)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1269"  :anon :subid("111_1256021422.69758") :outer("110_1256021422.69758")
    .param pmc param_1271
.annotate "line", 457
    .const 'Sub' $P1284 = "112_1256021422.69758" 
    capture_lex $P1284
    .lex "$_", param_1271
.annotate "line", 458
    find_lex $P1275, "$_"
    unless_null $P1275, vivify_422
    new $P1275, "Undef"
  vivify_422:
    set $S1276, $P1275
    iseq $I1277, $S1276, "0"
    unless $I1277, unless_1274
    new $P1273, 'Integer'
    set $P1273, $I1277
    goto unless_1274_end
  unless_1274:
    find_lex $P1278, "$_"
    unless_null $P1278, vivify_423
    new $P1278, "Undef"
  vivify_423:
    set $N1279, $P1278
    new $P1280, "Integer"
    assign $P1280, 0
    set $N1281, $P1280
    isgt $I1282, $N1279, $N1281
    new $P1273, 'Integer'
    set $P1273, $I1282
  unless_1274_end:
    unless $P1273, if_1272_end
    .const 'Sub' $P1284 = "112_1256021422.69758" 
    capture_lex $P1284
    $P1284()
  if_1272_end:
.annotate "line", 459
    new $P1287, "Integer"
    assign $P1287, 1
    find_lex $P1288, "$_"
    unless_null $P1288, vivify_425
    new $P1288, "Undef"
  vivify_425:
    find_lex $P1289, "%capnames"
    unless_null $P1289, vivify_426
    new $P1289, "Hash"
    store_lex "%capnames", $P1289
  vivify_426:
    set $P1289[$P1288], $P1287
.annotate "line", 457
    .return ($P1287)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1283"  :anon :subid("112_1256021422.69758") :outer("111_1256021422.69758")
.annotate "line", 458
    find_lex $P1285, "$_"
    unless_null $P1285, vivify_424
    new $P1285, "Undef"
  vivify_424:
    add $P1286, $P1285, 1
    store_lex "$count", $P1286
    .return ($P1286)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1301"  :anon :subid("113_1256021422.69758") :outer("110_1256021422.69758")
    .param pmc param_1303
.annotate "line", 462
    .lex "$_", param_1303
.annotate "line", 463
    find_lex $P1304, "$_"
    unless_null $P1304, vivify_432
    new $P1304, "Undef"
  vivify_432:
    find_lex $P1305, "%capnames"
    unless_null $P1305, vivify_433
    new $P1305, "Hash"
  vivify_433:
    set $P1306, $P1305[$P1304]
    unless_null $P1306, vivify_434
    new $P1306, "Undef"
  vivify_434:
    set $N1307, $P1306
    new $P1308, 'Float'
    set $P1308, $N1307
    find_lex $P1309, "$_"
    unless_null $P1309, vivify_435
    new $P1309, "Undef"
  vivify_435:
    find_lex $P1310, "%x"
    unless_null $P1310, vivify_436
    new $P1310, "Hash"
  vivify_436:
    set $P1311, $P1310[$P1309]
    unless_null $P1311, vivify_437
    new $P1311, "Undef"
  vivify_437:
    add $P1312, $P1308, $P1311
    find_lex $P1313, "$_"
    unless_null $P1313, vivify_438
    new $P1313, "Undef"
  vivify_438:
    find_lex $P1314, "%capnames"
    unless_null $P1314, vivify_439
    new $P1314, "Hash"
    store_lex "%capnames", $P1314
  vivify_439:
    set $P1314[$P1313], $P1312
.annotate "line", 462
    .return ($P1312)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1213"  :anon :subid("106_1256021422.69758") :outer("98_1256021422.69758")
.annotate "line", 437
    .const 'Sub' $P1233 = "108_1256021422.69758" 
    capture_lex $P1233
    .const 'Sub' $P1222 = "107_1256021422.69758" 
    capture_lex $P1222
.annotate "line", 438
    find_lex $P1215, "$ast"
    unless_null $P1215, vivify_442
    new $P1215, "Undef"
  vivify_442:
    $P1216 = $P1215."name"()
    .lex "$name", $P1216
.annotate "line", 439
    find_lex $P1218, "$name"
    unless_null $P1218, vivify_443
    new $P1218, "Undef"
  vivify_443:
    set $S1219, $P1218
    iseq $I1220, $S1219, ""
    unless $I1220, if_1217_end
    .const 'Sub' $P1222 = "107_1256021422.69758" 
    capture_lex $P1222
    $P1222()
  if_1217_end:
.annotate "line", 440

            $P0 = find_lex '$name'
            $S0 = $P0
            $P1227 = split '=', $S0
        
    .lex "@names", $P1227
.annotate "line", 445
    find_lex $P1229, "@names"
    unless_null $P1229, vivify_447
    new $P1229, "ResizablePMCArray"
  vivify_447:
    defined $I1230, $P1229
    unless $I1230, for_undef_448
    iter $P1228, $P1229
    new $P1254, 'ExceptionHandler'
    set_addr $P1254, loop1253_handler
    $P1254."handle_types"(65, 67, 66)
    push_eh $P1254
  loop1253_test:
    unless $P1228, loop1253_done
    shift $P1231, $P1228
  loop1253_redo:
    .const 'Sub' $P1233 = "108_1256021422.69758" 
    capture_lex $P1233
    $P1233($P1231)
  loop1253_next:
    goto loop1253_test
  loop1253_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1255, exception, 'type'
    eq $P1255, 65, loop1253_next
    eq $P1255, 67, loop1253_redo
  loop1253_done:
    pop_eh 
  for_undef_448:
.annotate "line", 437
    .return ($P1228)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1221"  :anon :subid("107_1256021422.69758") :outer("106_1256021422.69758")
.annotate "line", 439
    find_lex $P1223, "$count"
    unless_null $P1223, vivify_444
    new $P1223, "Undef"
  vivify_444:
    store_lex "$name", $P1223
    find_lex $P1224, "$ast"
    unless_null $P1224, vivify_445
    new $P1224, "Undef"
  vivify_445:
    find_lex $P1225, "$name"
    unless_null $P1225, vivify_446
    new $P1225, "Undef"
  vivify_446:
    $P1226 = $P1224."name"($P1225)
    .return ($P1226)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1232"  :anon :subid("108_1256021422.69758") :outer("106_1256021422.69758")
    .param pmc param_1234
.annotate "line", 445
    .const 'Sub' $P1247 = "109_1256021422.69758" 
    capture_lex $P1247
    .lex "$_", param_1234
.annotate "line", 446
    find_lex $P1238, "$_"
    unless_null $P1238, vivify_449
    new $P1238, "Undef"
  vivify_449:
    set $S1239, $P1238
    iseq $I1240, $S1239, "0"
    unless $I1240, unless_1237
    new $P1236, 'Integer'
    set $P1236, $I1240
    goto unless_1237_end
  unless_1237:
    find_lex $P1241, "$_"
    unless_null $P1241, vivify_450
    new $P1241, "Undef"
  vivify_450:
    set $N1242, $P1241
    new $P1243, "Integer"
    assign $P1243, 0
    set $N1244, $P1243
    isgt $I1245, $N1242, $N1244
    new $P1236, 'Integer'
    set $P1236, $I1245
  unless_1237_end:
    unless $P1236, if_1235_end
    .const 'Sub' $P1247 = "109_1256021422.69758" 
    capture_lex $P1247
    $P1247()
  if_1235_end:
.annotate "line", 447
    new $P1250, "Integer"
    assign $P1250, 1
    find_lex $P1251, "$_"
    unless_null $P1251, vivify_452
    new $P1251, "Undef"
  vivify_452:
    find_lex $P1252, "%capnames"
    unless_null $P1252, vivify_453
    new $P1252, "Hash"
    store_lex "%capnames", $P1252
  vivify_453:
    set $P1252[$P1251], $P1250
.annotate "line", 445
    .return ($P1250)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1246"  :anon :subid("109_1256021422.69758") :outer("108_1256021422.69758")
.annotate "line", 446
    find_lex $P1248, "$_"
    unless_null $P1248, vivify_451
    new $P1248, "Undef"
  vivify_451:
    add $P1249, $P1248, 1
    store_lex "$count", $P1249
    .return ($P1249)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1165"  :anon :subid("103_1256021422.69758") :outer("98_1256021422.69758")
.annotate "line", 428
    .const 'Sub' $P1173 = "104_1256021422.69758" 
    capture_lex $P1173
.annotate "line", 429
    find_lex $P1168, "$ast"
    unless_null $P1168, vivify_454
    new $P1168, "Undef"
  vivify_454:
    $P1169 = $P1168."list"()
    defined $I1170, $P1169
    unless $I1170, for_undef_455
    iter $P1167, $P1169
    new $P1202, 'ExceptionHandler'
    set_addr $P1202, loop1201_handler
    $P1202."handle_types"(65, 67, 66)
    push_eh $P1202
  loop1201_test:
    unless $P1167, loop1201_done
    shift $P1171, $P1167
  loop1201_redo:
    .const 'Sub' $P1173 = "104_1256021422.69758" 
    capture_lex $P1173
    $P1173($P1171)
  loop1201_next:
    goto loop1201_test
  loop1201_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1203, exception, 'type'
    eq $P1203, 65, loop1201_next
    eq $P1203, 67, loop1201_redo
  loop1201_done:
    pop_eh 
  for_undef_455:
.annotate "line", 428
    .return ($P1167)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1172"  :anon :subid("104_1256021422.69758") :outer("103_1256021422.69758")
    .param pmc param_1174
.annotate "line", 429
    .const 'Sub' $P1183 = "105_1256021422.69758" 
    capture_lex $P1183
    .lex "$_", param_1174
.annotate "line", 430
    find_lex $P1175, "$_"
    unless_null $P1175, vivify_456
    new $P1175, "Undef"
  vivify_456:
    find_lex $P1176, "$count"
    unless_null $P1176, vivify_457
    new $P1176, "Undef"
  vivify_457:
    $P1177 = "capnames"($P1175, $P1176)
    .lex "%x", $P1177
.annotate "line", 431
    find_lex $P1179, "%x"
    unless_null $P1179, vivify_458
    new $P1179, "Hash"
  vivify_458:
    defined $I1180, $P1179
    unless $I1180, for_undef_459
    iter $P1178, $P1179
    new $P1197, 'ExceptionHandler'
    set_addr $P1197, loop1196_handler
    $P1197."handle_types"(65, 67, 66)
    push_eh $P1197
  loop1196_test:
    unless $P1178, loop1196_done
    shift $P1181, $P1178
  loop1196_redo:
    .const 'Sub' $P1183 = "105_1256021422.69758" 
    capture_lex $P1183
    $P1183($P1181)
  loop1196_next:
    goto loop1196_test
  loop1196_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1198, exception, 'type'
    eq $P1198, 65, loop1196_next
    eq $P1198, 67, loop1196_redo
  loop1196_done:
    pop_eh 
  for_undef_459:
.annotate "line", 434
    find_lex $P1199, "%x"
    unless_null $P1199, vivify_468
    new $P1199, "Hash"
  vivify_468:
    set $P1200, $P1199[""]
    unless_null $P1200, vivify_469
    new $P1200, "Undef"
  vivify_469:
    store_lex "$count", $P1200
.annotate "line", 429
    .return ($P1200)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1182"  :anon :subid("105_1256021422.69758") :outer("104_1256021422.69758")
    .param pmc param_1184
.annotate "line", 431
    .lex "$_", param_1184
.annotate "line", 432
    find_lex $P1185, "$_"
    unless_null $P1185, vivify_460
    new $P1185, "Undef"
  vivify_460:
    find_lex $P1186, "%capnames"
    unless_null $P1186, vivify_461
    new $P1186, "Hash"
  vivify_461:
    set $P1187, $P1186[$P1185]
    unless_null $P1187, vivify_462
    new $P1187, "Undef"
  vivify_462:
    set $N1188, $P1187
    new $P1189, 'Float'
    set $P1189, $N1188
    find_lex $P1190, "$_"
    unless_null $P1190, vivify_463
    new $P1190, "Undef"
  vivify_463:
    find_lex $P1191, "%x"
    unless_null $P1191, vivify_464
    new $P1191, "Hash"
  vivify_464:
    set $P1192, $P1191[$P1190]
    unless_null $P1192, vivify_465
    new $P1192, "Undef"
  vivify_465:
    add $P1193, $P1189, $P1192
    find_lex $P1194, "$_"
    unless_null $P1194, vivify_466
    new $P1194, "Undef"
  vivify_466:
    find_lex $P1195, "%capnames"
    unless_null $P1195, vivify_467
    new $P1195, "Hash"
    store_lex "%capnames", $P1195
  vivify_467:
    set $P1195[$P1194], $P1193
.annotate "line", 431
    .return ($P1193)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1098"  :anon :subid("99_1256021422.69758") :outer("98_1256021422.69758")
.annotate "line", 415
    .const 'Sub' $P1107 = "100_1256021422.69758" 
    capture_lex $P1107
.annotate "line", 416
    find_lex $P1100, "$count"
    unless_null $P1100, vivify_470
    new $P1100, "Undef"
  vivify_470:
    .lex "$max", $P1100
.annotate "line", 417
    find_lex $P1102, "$ast"
    unless_null $P1102, vivify_471
    new $P1102, "Undef"
  vivify_471:
    $P1103 = $P1102."list"()
    defined $I1104, $P1103
    unless $I1104, for_undef_472
    iter $P1101, $P1103
    new $P1158, 'ExceptionHandler'
    set_addr $P1158, loop1157_handler
    $P1158."handle_types"(65, 67, 66)
    push_eh $P1158
  loop1157_test:
    unless $P1101, loop1157_done
    shift $P1105, $P1101
  loop1157_redo:
    .const 'Sub' $P1107 = "100_1256021422.69758" 
    capture_lex $P1107
    $P1107($P1105)
  loop1157_next:
    goto loop1157_test
  loop1157_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1159, exception, 'type'
    eq $P1159, 65, loop1157_next
    eq $P1159, 67, loop1157_redo
  loop1157_done:
    pop_eh 
  for_undef_472:
.annotate "line", 426
    find_lex $P1160, "$max"
    unless_null $P1160, vivify_490
    new $P1160, "Undef"
  vivify_490:
    store_lex "$count", $P1160
.annotate "line", 415
    .return ($P1160)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1106"  :anon :subid("100_1256021422.69758") :outer("99_1256021422.69758")
    .param pmc param_1108
.annotate "line", 417
    .const 'Sub' $P1153 = "102_1256021422.69758" 
    capture_lex $P1153
    .const 'Sub' $P1117 = "101_1256021422.69758" 
    capture_lex $P1117
    .lex "$_", param_1108
.annotate "line", 418
    find_lex $P1109, "$_"
    unless_null $P1109, vivify_473
    new $P1109, "Undef"
  vivify_473:
    find_lex $P1110, "$count"
    unless_null $P1110, vivify_474
    new $P1110, "Undef"
  vivify_474:
    $P1111 = "capnames"($P1109, $P1110)
    .lex "%x", $P1111
.annotate "line", 419
    find_lex $P1113, "%x"
    unless_null $P1113, vivify_475
    new $P1113, "Hash"
  vivify_475:
    defined $I1114, $P1113
    unless $I1114, for_undef_476
    iter $P1112, $P1113
    new $P1142, 'ExceptionHandler'
    set_addr $P1142, loop1141_handler
    $P1142."handle_types"(65, 67, 66)
    push_eh $P1142
  loop1141_test:
    unless $P1112, loop1141_done
    shift $P1115, $P1112
  loop1141_redo:
    .const 'Sub' $P1117 = "101_1256021422.69758" 
    capture_lex $P1117
    $P1117($P1115)
  loop1141_next:
    goto loop1141_test
  loop1141_handler:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1143, exception, 'type'
    eq $P1143, 65, loop1141_next
    eq $P1143, 67, loop1141_redo
  loop1141_done:
    pop_eh 
  for_undef_476:
.annotate "line", 424
    find_lex $P1146, "%x"
    unless_null $P1146, vivify_485
    new $P1146, "Hash"
  vivify_485:
    set $P1147, $P1146[""]
    unless_null $P1147, vivify_486
    new $P1147, "Undef"
  vivify_486:
    set $N1148, $P1147
    find_lex $P1149, "$max"
    unless_null $P1149, vivify_487
    new $P1149, "Undef"
  vivify_487:
    set $N1150, $P1149
    isgt $I1151, $N1148, $N1150
    if $I1151, if_1145
    new $P1144, 'Integer'
    set $P1144, $I1151
    goto if_1145_end
  if_1145:
    .const 'Sub' $P1153 = "102_1256021422.69758" 
    capture_lex $P1153
    $P1156 = $P1153()
    set $P1144, $P1156
  if_1145_end:
.annotate "line", 417
    .return ($P1144)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1116"  :anon :subid("101_1256021422.69758") :outer("100_1256021422.69758")
    .param pmc param_1118
.annotate "line", 419
    .lex "$_", param_1118
.annotate "line", 420
    find_lex $P1123, "$_"
    unless_null $P1123, vivify_477
    new $P1123, "Undef"
  vivify_477:
    find_lex $P1124, "%capnames"
    unless_null $P1124, vivify_478
    new $P1124, "Hash"
  vivify_478:
    set $P1125, $P1124[$P1123]
    unless_null $P1125, vivify_479
    new $P1125, "Undef"
  vivify_479:
    set $N1126, $P1125
    new $P1127, "Integer"
    assign $P1127, 2
    set $N1128, $P1127
    islt $I1129, $N1126, $N1128
    if $I1129, if_1122
    new $P1121, 'Integer'
    set $P1121, $I1129
    goto if_1122_end
  if_1122:
    find_lex $P1130, "$_"
    unless_null $P1130, vivify_480
    new $P1130, "Undef"
  vivify_480:
    find_lex $P1131, "%x"
    unless_null $P1131, vivify_481
    new $P1131, "Hash"
  vivify_481:
    set $P1132, $P1131[$P1130]
    unless_null $P1132, vivify_482
    new $P1132, "Undef"
  vivify_482:
    set $N1133, $P1132
    new $P1134, "Integer"
    assign $P1134, 1
    set $N1135, $P1134
    iseq $I1136, $N1133, $N1135
    new $P1121, 'Integer'
    set $P1121, $I1136
  if_1122_end:
    if $P1121, if_1120
.annotate "line", 422
    new $P1138, "Integer"
    assign $P1138, 2
    set $P1119, $P1138
.annotate "line", 420
    goto if_1120_end
  if_1120:
.annotate "line", 421
    new $P1137, "Integer"
    assign $P1137, 1
    set $P1119, $P1137
  if_1120_end:
.annotate "line", 420
    find_lex $P1139, "$_"
    unless_null $P1139, vivify_483
    new $P1139, "Undef"
  vivify_483:
    find_lex $P1140, "%capnames"
    unless_null $P1140, vivify_484
    new $P1140, "Hash"
    store_lex "%capnames", $P1140
  vivify_484:
    set $P1140[$P1139], $P1119
.annotate "line", 419
    .return ($P1119)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1152"  :anon :subid("102_1256021422.69758") :outer("100_1256021422.69758")
.annotate "line", 424
    find_lex $P1154, "%x"
    unless_null $P1154, vivify_488
    new $P1154, "Hash"
  vivify_488:
    set $P1155, $P1154[""]
    unless_null $P1155, vivify_489
    new $P1155, "Undef"
  vivify_489:
    store_lex "$max", $P1155
    .return ($P1155)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "backmod"  :subid("116_1256021422.69758") :outer("11_1256021422.69758")
    .param pmc param_1352
    .param pmc param_1353
.annotate "line", 478
    .const 'Sub' $P1385 = "119_1256021422.69758" 
    capture_lex $P1385
    .const 'Sub' $P1372 = "118_1256021422.69758" 
    capture_lex $P1372
    .const 'Sub' $P1359 = "117_1256021422.69758" 
    capture_lex $P1359
    new $P1351, 'ExceptionHandler'
    set_addr $P1351, control_1350
    $P1351."handle_types"(58)
    push_eh $P1351
    .lex "$ast", param_1352
    .lex "$backmod", param_1353
.annotate "line", 479
    find_lex $P1355, "$backmod"
    unless_null $P1355, vivify_494
    new $P1355, "Undef"
  vivify_494:
    set $S1356, $P1355
    iseq $I1357, $S1356, ":"
    if $I1357, if_1354
.annotate "line", 480
    find_lex $P1365, "$backmod"
    unless_null $P1365, vivify_495
    new $P1365, "Undef"
  vivify_495:
    set $S1366, $P1365
    iseq $I1367, $S1366, ":?"
    unless $I1367, unless_1364
    new $P1363, 'Integer'
    set $P1363, $I1367
    goto unless_1364_end
  unless_1364:
    find_lex $P1368, "$backmod"
    unless_null $P1368, vivify_496
    new $P1368, "Undef"
  vivify_496:
    set $S1369, $P1368
    iseq $I1370, $S1369, "?"
    new $P1363, 'Integer'
    set $P1363, $I1370
  unless_1364_end:
    if $P1363, if_1362
.annotate "line", 481
    find_lex $P1378, "$backmod"
    unless_null $P1378, vivify_497
    new $P1378, "Undef"
  vivify_497:
    set $S1379, $P1378
    iseq $I1380, $S1379, ":!"
    unless $I1380, unless_1377
    new $P1376, 'Integer'
    set $P1376, $I1380
    goto unless_1377_end
  unless_1377:
    find_lex $P1381, "$backmod"
    unless_null $P1381, vivify_498
    new $P1381, "Undef"
  vivify_498:
    set $S1382, $P1381
    iseq $I1383, $S1382, "!"
    new $P1376, 'Integer'
    set $P1376, $I1383
  unless_1377_end:
    unless $P1376, if_1375_end
    .const 'Sub' $P1385 = "119_1256021422.69758" 
    capture_lex $P1385
    $P1385()
  if_1375_end:
.annotate "line", 479
    goto if_1362_end
  if_1362:
.annotate "line", 480
    .const 'Sub' $P1372 = "118_1256021422.69758" 
    capture_lex $P1372
    $P1372()
  if_1362_end:
.annotate "line", 479
    goto if_1354_end
  if_1354:
    .const 'Sub' $P1359 = "117_1256021422.69758" 
    capture_lex $P1359
    $P1359()
  if_1354_end:
.annotate "line", 482
    find_lex $P1388, "$ast"
    unless_null $P1388, vivify_502
    new $P1388, "Undef"
  vivify_502:
.annotate "line", 478
    .return ($P1388)
  control_1350:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1389, exception, "payload"
    .return ($P1389)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1384"  :anon :subid("119_1256021422.69758") :outer("116_1256021422.69758")
.annotate "line", 481
    find_lex $P1386, "$ast"
    unless_null $P1386, vivify_499
    new $P1386, "Undef"
  vivify_499:
    $P1387 = $P1386."backtrack"("g")
    .return ($P1387)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1371"  :anon :subid("118_1256021422.69758") :outer("116_1256021422.69758")
.annotate "line", 480
    find_lex $P1373, "$ast"
    unless_null $P1373, vivify_500
    new $P1373, "Undef"
  vivify_500:
    $P1374 = $P1373."backtrack"("f")
    .return ($P1374)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1358"  :anon :subid("117_1256021422.69758") :outer("116_1256021422.69758")
.annotate "line", 479
    find_lex $P1360, "$ast"
    unless_null $P1360, vivify_501
    new $P1360, "Undef"
  vivify_501:
    $P1361 = $P1360."backtrack"("r")
    .return ($P1361)
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "subrule_alias"  :subid("120_1256021422.69758") :outer("11_1256021422.69758")
    .param pmc param_1393
    .param pmc param_1394
.annotate "line", 485
    .const 'Sub' $P1399 = "121_1256021422.69758" 
    capture_lex $P1399
    new $P1392, 'ExceptionHandler'
    set_addr $P1392, control_1391
    $P1392."handle_types"(58)
    push_eh $P1392
    .lex "$past", param_1393
    .lex "$name", param_1394
.annotate "line", 486
    find_lex $P1396, "$past"
    unless_null $P1396, vivify_503
    new $P1396, "Hash"
  vivify_503:
    set $P1397, $P1396["aliased"]
    unless_null $P1397, vivify_504
    new $P1397, "Undef"
  vivify_504:
    unless $P1397, if_1395_end
    .const 'Sub' $P1399 = "121_1256021422.69758" 
    capture_lex $P1399
    $P1399()
  if_1395_end:
.annotate "line", 487
    find_lex $P1405, "$past"
    unless_null $P1405, vivify_507
    new $P1405, "Undef"
  vivify_507:
    find_lex $P1406, "$name"
    unless_null $P1406, vivify_508
    new $P1406, "Undef"
  vivify_508:
    $P1405."name"($P1406)
.annotate "line", 488
    new $P1407, "Integer"
    assign $P1407, 1
    find_lex $P1408, "$past"
    unless_null $P1408, vivify_509
    new $P1408, "Hash"
    store_lex "$past", $P1408
  vivify_509:
    set $P1408["aliased"], $P1407
.annotate "line", 485
    .return ($P1407)
  control_1391:
    .local pmc exception 
    .get_results (exception) 
    getattribute $P1409, exception, "payload"
    .return ($P1409)
    rethrow exception
.end


.namespace ["Regex";"P6Regex";"Actions"]
.sub "_block1398"  :anon :subid("121_1256021422.69758") :outer("120_1256021422.69758")
.annotate "line", 486
    find_lex $P1400, "$name"
    unless_null $P1400, vivify_505
    new $P1400, "Undef"
  vivify_505:
    concat $P1401, $P1400, "="
    find_lex $P1402, "$past"
    unless_null $P1402, vivify_506
    new $P1402, "Undef"
  vivify_506:
    $S1403 = $P1402."name"()
    concat $P1404, $P1401, $S1403
    store_lex "$name", $P1404
    .return ($P1404)
.end

### .include 'src/cheats/p6regex-grammar.pir'
.namespace ['Regex';'P6Regex';'Grammar']

.sub 'panic' :method
    .param pmc args            :slurpy

    .local int pos
    .local pmc target
    $I0 = isa self, ['Regex';'Cursor']
    if $I0 goto cursor_pos
    pos = self.'to'()
    target = self.'orig'()
    goto have_pos
  cursor_pos:
    pos = self.'pos'()
    target = getattribute self, '$!target'
  have_pos:

    $I1 = target.'lineof'(pos)
    push args, ' at line '
    push args, $I1

    $S0 = target
    $S0 = substr $S0, pos, 10
    $S0 = escape $S0
    push args, ', near "'
    push args, $S0
    push args, '"'

    .local string message
    message = join '', args

    die message
.end

.sub 'obs' :method
    .param string oldstr
    .param pmc options         :slurpy :named

    .local string newstr
    $P0 = split ';', oldstr
    oldstr = $P0[0]
    newstr = $P0[1]

    self.'panic'('Obsolete use of ', oldstr, '; please use ', newstr, ' instead')
.end

.namespace ['Regex';'P6Regex';'Compiler']

.sub '' :anon :load :init
    load_bytecode 'PCT.pbc'
    .local pmc p6meta, p6regex
    p6meta = get_hll_global 'P6metaclass'
    p6regex = p6meta.'new_class'('Regex::P6Regex::Compiler', 'parent'=>'HLL::Compiler')
    p6regex.'language'('Regex::P6Regex')
    $P0 = get_hll_global ['Regex';'P6Regex'], 'Grammar'
    p6regex.'parsegrammar'($P0)
    $P0 = get_hll_global ['Regex';'P6Regex'], 'Actions'
    p6regex.'parseactions'($P0)
.end


.sub 'main' :main
    .param pmc args_str

    $P0 = compreg 'Regex::P6Regex'
    $P1 = $P0.'command_line'(args_str, 'encoding'=>'utf8', 'transcode'=>'ascii iso-8859-1')
    exit 0
.end


=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir: