" Python indent file for Vim written with PEP 8 compatibility in mind
" Author: Ilya Tumaykin <itumaykin (plus) github (at) gmail (dot) com>
" License: Vim license or MIT
"
" All the code was written by me from scratch, though some ideas were reused
" from Eric Mc Sween's, Hynek Schlawack's and the upstream Vim indent files.
"
" Comments beginning with '>' are quotes from the PEP 8 document available at:
" https://peps.python.org/pep-0008/


if exists('b:did_indent')
	finish
endif
let b:did_indent = 1


" https://peps.python.org/pep-0008/#multiline-if-statements
let g:python_indent_extra_indent_in_multiline_if_condition =
	\ get(g:, 'python_indent_extra_indent_in_multiline_if_condition', 0)

" https://peps.python.org/pep-0008/#indentation
let g:python_indent_line_up_closing_bracket_with_last_line =
	\ get(g:, 'python_indent_line_up_closing_bracket_with_last_line', 1)

" https://peps.python.org/pep-0008/#tabs-or-spaces
let g:python_indent_use_spaces_for_indentation =
	\ get(g:, 'python_indent_use_spaces_for_indentation', 1)


" Disable Lisp mode.
setlocal nolisp
" Copy indentation from the current line when starting a new line.
setlocal autoindent

" > Use 4 spaces per indentation level.
setlocal tabstop=4
setlocal shiftwidth=4
" > Python disallows mixing tabs and spaces for indentation.
setlocal softtabstop=0

if g:python_indent_use_spaces_for_indentation
	" > Spaces are the preferred indentation method.
	" > Tabs should be used solely to remain consistent
	" > with code that is already indented with tabs.
	setlocal expandtab
endif


" Reindent after typing <CR>, ':', closing brackets, 'except', 'elif', 'case'.
setlocal indentexpr=GetPythonIndent()
setlocal indentkeys=!^F,o,O,<:>,0),0],0},0=except,0=elif,0=case


" Search for pairs within 250 lines range and no longer than 400 milliseconds.
let s:searchpair_offset = 250
let s:searchpair_timeout = 400


" Match keywords that start non-trivial clause headers.
" https://docs.python.org/2/reference/compound_stmts.html
" https://docs.python.org/3/reference/compound_stmts.html
let s:compound_stmt_kwrd =
	\ '\C\_^\s*\%(def\s\+\h\w*\|if\|for\|class\s\+\h\w*\|with\|except\|elif'.
	\ '\|while\|match\|case\|async\s\+\%(def\s\+\h\w*\|for\|while\)\)\>\s*'

" Match keywords that stop execution of code suites.
" https://docs.python.org/2/reference/simple_stmts.html
" https://docs.python.org/3/reference/simple_stmts.html
let s:code_suite_stop = '\C\_^\s*\%(return\|raise\|pass\|continue\|break\)\>'

" Match keywords that can start explicit line joins,
" except for keywords that can use implicit continuation.
let s:multiline_kwrd =
	\ '\C\_^\s*\%(for\|with\|except\|raise\|yield\|assert\|async\s\+for\)\>\s*'

" Map clause headers to the appropriate preceding ones.
let s:header2preceding = {
	\ '\C\_^\s*else\>':    '\C\_^\s*\%(if\|for\|except\|elif\|while\|async\s\+for\)\>',
	\ '\C\_^\s*except\>':  '\C\_^\s*\%(try\|except\)\>',
	\ '\C\_^\s*elif\>':    '\C\_^\s*\%(if\|elif\)\>',
	\ '\C\_^\s*finally\>': '\C\_^\s*\%(try\|except\|else\)\>',
	\ '\C\_^\s*case\>':    '\C\_^\s*case\>',
\}


" {{{
" Return the list of syntax item names at the current cursor position.
function! s:AllSyntaxNames()
	return map(synstack(line('.'), col('.')), 'synIDattr(v:val, ''name'')')
endfunction


" Search from the current cursor position backwards
" until the closest unmatched opening quote is found.
let s:quotes_skip = 'match(s:AllSyntaxNames(), ''\Cpython\a*String'') < 0'

function! s:FindOpeningQuote()
	return searchpairpos(
		\ '["'']', '', '["'']', 'bnW', s:quotes_skip,
		\ max([line('.') - s:searchpair_offset, 1]), s:searchpair_timeout
	\)
endfunction


" Return the syntax item name at the given position
" or at the current cursor position if none is given.
function! s:SyntaxName(...)
	let [l:lnum, l:col] = a:0 ? a:000 : [line('.'), col('.')]
	return synIDattr(synID(l:lnum, l:col, v:true), 'name')
endfunction


" Sort pairs lexicographically.
function! s:LexSortPairs(i1, i2)
	if (a:i1[0] != a:i2[0])
		return (a:i1[0] > a:i2[0]) ? 1 : -1
	elseif (a:i1[1] != a:i2[1])
		return (a:i1[1] > a:i2[1]) ? 1 : -1
	else
		return 0
	endif
endfunction


" Search from the current cursor position backwards
" until the innermost unmatched opening bracket is found.
let s:brackets_skip = 's:SyntaxName() !=# ''pythonDelimiter'''

function! s:FindInnermostOpeningBracket()
	let l:brackets_positions = []
	let l:stopline = max([line('.') - s:searchpair_offset, 1])

	" Order brackets to make positions already sorted in most cases.
	for l:brackets in ['{}', '[]', '()']
		call add(l:brackets_positions,
				\searchpairpos(
					\ '\V'.l:brackets[0], '', '\V'.l:brackets[1], 'bnW',
					\ s:brackets_skip, l:stopline, s:searchpair_timeout
				\)
			\)
	endfor

	return get(sort(l:brackets_positions, 's:LexSortPairs'), -1)
endfunction


" Search from the current cursor position backwards
" until the outermost unmatched opening bracket is found.
function! s:FindOutermostOpeningBracket()
	let l:brackets_positions = []
	let l:stopline = max([line('.') - s:searchpair_offset, 1])

	" Order brackets to make positions already sorted in most cases.
	for l:brackets in ['{}', '[]', '()']
		call add(l:brackets_positions,
				\searchpairpos(
					\ '\V'.l:brackets[0], '', '\V'.l:brackets[1], 'bnWr',
					\ s:brackets_skip, l:stopline, s:searchpair_timeout
				\)
			\)
	endfor

	return get(sort(filter(l:brackets_positions, 'v:val[0]'), 's:LexSortPairs'), 0, [0, 0])
endfunction


" Search from the current line backwards
" until the beginning of the explicit line join is found.
function! s:FindLineJoinStart()
	let l:prevlnum = line('.') - 1
	let l:lastchar = col([l:prevlnum, '$']) - 1

	while (getline(l:prevlnum)[l:lastchar] ==# '\') &&
		\ (s:SyntaxName(l:prevlnum, l:lastchar) ==# 'pythonLineJoin')
		let l:prevlnum -= 1
		let l:lastchar = col([l:prevlnum, '$']) - 1
	endwhile

	return l:prevlnum + 1
endfunction


" Search from the given line backwards
" until the beginning of the logical line is found.
" NB: This function moves the cursor.
function! s:FindLogicalLineStart(line)
	let l:curlnum = a:line
	let l:startlnum = -1

	while (l:startlnum != l:curlnum)
		let l:startlnum = l:curlnum
		call cursor(l:curlnum, 1)

		let l:bracket_lnum = s:FindOutermostOpeningBracket()[0]
		if (l:bracket_lnum > 0)
			let l:curlnum = l:bracket_lnum
			call cursor(l:curlnum, 1)
		endif

		if (match(s:AllSyntaxNames(), '\Cpython\a*\%(String\|Quotes\)') >= 0)
			let l:quote_lnum = s:FindOpeningQuote()[0]
			if (l:quote_lnum > 0)
				let l:curlnum = l:quote_lnum
				call cursor(l:curlnum, 1)
			endif
		endif

		let l:curlnum = s:FindLineJoinStart()
	endwhile

	return l:startlnum
endfunction


" Search from the given line backwards
" until the clause header that matches the given regex is found,
" return the indentation of the found clause header.
function! s:FindPrecedingHeaderIndent(line, regex)
	let l:curlnum = a:line
	let l:curindent = indent(l:curlnum)
	let l:maxindent = l:curindent

	while (l:curlnum > 0) && (l:maxindent > 0)
		if (l:curindent <= l:maxindent)
			if (getline(l:curlnum) =~# a:regex)
				return l:curindent
			else
				let l:maxindent = l:curindent
			endif
		endif

		let l:curlnum = prevnonblank(l:curlnum - 1)
		let l:curindent = indent(l:curlnum)
	endwhile

	return l:curindent
endfunction
" }}}


" Recalculate the indentation for the current line.
function! GetPythonIndent()
	let l:cursynstack = s:AllSyntaxNames()

	if (match(l:cursynstack, '\CpythonComment') >= 0)
		" Inside comments keep the current indentation.
		return -1
	endif

	if (match(l:cursynstack, '\Cpython\a*\%(String\|Quotes\)') >= 0)
		let [l:quote_lnum, l:quote_col] = s:FindOpeningQuote()
		if (l:quote_lnum > 0)
			" Inside strings proceed as follows.
			if (l:quote_lnum == v:lnum - 1)
				" If the opening quote(s) is on the previous line, ...
				if (l:quote_col == matchend(getline(l:quote_lnum), '^\s*') + 3) &&
				\  (s:SyntaxName(l:quote_lnum, l:quote_col) ==# 'pythonTripleQuotes')
					" keep the current indentation for docstrings or ...
					return -1
				else
					" add one level of indentation for regular strings.
					return indent(l:quote_lnum) + &shiftwidth
				endif
			else
				" Otherwise, keep the current indentation.
				return -1
			endif
		endif
	endif

	" Put the cursor at the beginning of the current line
	" as we don't want to indent inside brackets when
	" the opening bracket is on the current line and
	" we don't want to indent after strings when
	" the closing quote(s) is on the current line.
	call cursor(0, 1)

	let l:cursynstack = s:AllSyntaxNames()

	if (len(l:cursynstack) == 1) &&
	\  (match(l:cursynstack, '\Cpython\a*\%(String\|Quotes\)') >= 0)
		" If the current line starts with the ending of a string,
		" keep the current indentation.
		return -1
	endif

	let [l:bracket_lnum, l:bracket_col] = s:FindInnermostOpeningBracket()
	if (l:bracket_lnum > 0)
		" Around brackets proceed as follows.
		let l:bracket_line = getline(l:bracket_lnum)
		if (match(l:bracket_line, '^\s*\%(\_$\|#\)', l:bracket_col) >= 0)
			" If the opening bracket is followed only by spaces or a comment, ...
			if (getline(v:lnum) !~# '^\s*[)\]}]')
				" if the current line doesn't start with the closing bracket,
				" add one level to the opening bracket's indentation, ...
				return indent(l:bracket_lnum) + &shiftwidth
			elseif (l:bracket_col == matchend(l:bracket_line, s:compound_stmt_kwrd) + 1)
				" if the current line starts with the closing bracket of a compound statement,
				" use the opening bracket's indentation, ...
				return indent(l:bracket_lnum)
			else
				" if the current line starts with the regular closing bracket,
				" use the opening bracket's indentation or
				" use the previous non-blank line's indentation when configured by user.
				return g:python_indent_line_up_closing_bracket_with_last_line
					\  ? indent(prevnonblank(v:lnum - 1)) : indent(l:bracket_lnum)
			endif
		else
			" If the opening bracket isn't followed only by spaces or a comment, ...
			if (l:bracket_col != matchend(l:bracket_line, '\C\_^\s*if\s') + 1)
				" if the 'if' keyword doesn't precede the opening bracket,
				" vertically align with the opening bracket, ...
				return l:bracket_col
			else
				" if the 'if' keyword precedes the opening bracket,
				" vertically align with the opening bracket and
				" add one extra level of indentation when configured by user.
				return l:bracket_col +
					\  &shiftwidth * g:python_indent_extra_indent_in_multiline_if_condition
			endif
		endif
	endif

	" Inside regular code proceed as follows.
	let l:linejoinstart = s:FindLineJoinStart()
	if (l:linejoinstart == v:lnum)
		" Outside of explicit line joins proceed as follows.
		let l:prevlnum = prevnonblank(v:lnum - 1)

		let l:colon = matchend(getline(l:prevlnum), ':\ze\s*\%(\_$\|#\)')
		if (l:colon >= 0) && (s:SyntaxName(l:prevlnum, l:colon) ==# 'pythonDelimiter')
			" If the previous screen line ends with a colon outside of a comment,
			" add one level to the previous logical line's indentation.
			return indent(s:FindLogicalLineStart(l:prevlnum)) + &shiftwidth
		endif

		let l:prevlnum = s:FindLogicalLineStart(l:prevlnum)

		if (getline(l:prevlnum) =~# s:code_suite_stop)
			" If the previous logical line is the end of a code suite,
			" remove one level from the previous logical line's indentation when
			" the current line wasn't dedented more.
			return min([indent(v:lnum), max([indent(l:prevlnum) - &shiftwidth, 0])])
		endif

		let l:curline = getline(v:lnum)
		for [l:header, l:preceding] in items(s:header2preceding)
			if (l:curline =~# l:header)
				" If the current line starts with a non-leading header of a compound statement,
				" use the indentation of the preceding header of the same compound statement when
				" the current line wasn't dedented more.
				return min([indent(v:lnum), s:FindPrecedingHeaderIndent(l:prevlnum, l:preceding)])
			endif
		endfor

		" Otherwise, use the previous logical line's indentation when
		" the current line wasn't dedented more.
		return min([indent(v:lnum), indent(l:prevlnum)])
	elseif (l:linejoinstart == v:lnum - 1)
		" If the current line is a part of an explicit line join and
		" the explicit line join starts on the previous line, ...
		let l:prevline = getline(l:linejoinstart)
		let l:nonspace_after_keyword = matchend(l:prevline, s:multiline_kwrd)

		if (l:nonspace_after_keyword >= 0)
			" if the previous line starts with a multiline keyword,
			" vertically align with the first non-whitespace character after the keyword and
			" add one extra level of indentation when
			" it's required to distinguish the current line from the nested code suite and
			" it's also configured by user, ...
			return l:nonspace_after_keyword +
				\  &shiftwidth * g:python_indent_extra_indent_in_multiline_if_condition *
				\  (l:prevline =~# '^\s*for\s\S')
		else
			" if the previous line doesn't start with a multiline keyword,
			" add one level to the previous line's indentation when
			" the current line wasn't indented more.
			return max([indent(v:lnum), indent(l:linejoinstart) + &shiftwidth])
		endif
	else
		" If the current line is a part of an explicit line join and
		" the explicit line join doesn't start on the previous line,
		" keep the current indentation.
		return -1
	endif
endfunction

" vim:set ts=4 sts=0 noet sw=4 ff=unix foldenable foldmethod=marker:
