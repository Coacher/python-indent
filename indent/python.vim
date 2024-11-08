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


" https://peps.python.org/pep-0008/#indentation
let g:python_indent_line_up_closing_bracket_with_last_line =
	\ get(g:, 'python_indent_line_up_closing_bracket_with_last_line', 1)

" https://peps.python.org/pep-0008/#multiline-if-statements
" https://peps.python.org/pep-0008/#maximum-line-length
let g:python_indent_extra_indent_in_multiline_if_condition =
	\ get(g:, 'python_indent_extra_indent_in_multiline_if_condition', 1)

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
" > Python 3 disallows mixing the use of tabs and spaces for indentation.
" > Python 2 code indented with a mixture of tabs and spaces
" > should be converted to using spaces exclusively.
setlocal softtabstop=0

if (g:python_indent_use_spaces_for_indentation)
	" > Spaces are the preferred indentation method.
	" > Tabs should be used solely to remain consistent
	" > with code that is already indented with tabs.
	setlocal expandtab
endif


" Recalculate indent after typing <CR>, ':', closing brackets, 'except', and 'elif'.
setlocal indentexpr=GetPythonIndent()
setlocal indentkeys=!^F,o,O,<:>,0),0],0},0=except,0=elif


" Search for pairs within 150 lines range and no longer than 400 milliseconds.
let s:searchpair_offset = 150
let s:searchpair_timeout = 400


" Match keywords that start non-trivial clause headers.
" https://docs.python.org/2/reference/compound_stmts.html
" https://docs.python.org/3/reference/compound_stmts.html
let s:compound_stmt_kwrd = '\C\_^\s*\%(def\s\+\h\w*\|if\|for\|class\s\+\h\w*\|with\|except\|elif'.
						\  '\|while\|match\|case\|async\s\+\%(def\s\+\h\w*\|for\|while\)\)\>\s*'

" Match keywords that stop execution of code suites.
" https://docs.python.org/2/reference/simple_stmts.html
" https://docs.python.org/3/reference/simple_stmts.html
let s:code_suite_stop = '^\s*\%(return\|raise\|pass\|continue\|break\)\>'

" Match keywords that can start explicit line joins,
" except for keywords that can use implicit continuation.
let s:multiline_kwrd = '\C\_^\s*\%(for\|with\|except\|raise\|yield\|assert\|async\s\+for\)\>\s*'

" Map clause headers to the appropriate preceding ones.
let s:header2preceding = {
	\ '^\s*else\>':    '^\s*\%(if\|for\|except\|elif\|while\|async\s\+for\)\>',
	\ '^\s*except\>':  '^\s*\%(try\|except\)\>',
	\ '^\s*elif\>':    '^\s*\%(if\|elif\)\>',
	\ '^\s*finally\>': '^\s*\%(try\|except\|else\)\>',
	\ '^\s*case\>':    '^\s*\%(case\)\>',
\}


" {{{
" Return the list of syntax item names at the given position
" or at the current cursor position if none is given.
function! s:SynStackNames(...)
	let [l:lnum, l:col] = !(a:0) ? [line('.'), col('.')] : a:000
	return map(synstack(l:lnum, l:col), 'synIDattr(v:val, ''name'')')
endfunction


" Return the syntax item name at the given position
" or at the current cursor position if none is given.
function! s:SyntaxItemName(...)
	let [l:lnum, l:col] = !(a:0) ? [line('.'), col('.')] : a:000
	return synIDattr(synID(l:lnum, l:col, 1), 'name')
endfunction


" Search from the current cursor position backwards
" until the closest unmatched opening quote is found.
let s:quotes_skip = 's:SyntaxItemName() !~# ''python\%(Triple\)\=Quotes'''

function! s:FindOpeningQuote()
	return searchpairpos(
		\ '["'']', '', '["'']', 'bnW', s:quotes_skip,
		\ max([line('.') - s:searchpair_offset, 1]), s:searchpair_timeout
	\)
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
let s:brackets_skip = 's:SyntaxItemName() !=# ''pythonDelimiter'''

function! s:FindInnermostOpeningBracket()
	let l:brackets_positions = []

	" Order brackets to make positions already sorted in most cases.
	for l:brackets in ['{}', '[]', '()']
		call add(l:brackets_positions,
				\searchpairpos(
					\ '\V'.l:brackets[0], '', '\V'.l:brackets[1], 'bnW', s:brackets_skip,
					\ max([line('.') - s:searchpair_offset, 1]), s:searchpair_timeout
				\)
			\)
	endfor

	return get(sort(l:brackets_positions, 's:LexSortPairs'), -1)
endfunction


" Search from the current cursor position backwards
" until the outermost unmatched opening bracket is found.
function! s:FindOutermostOpeningBracket()
	let l:brackets_positions = []

	" Order brackets to make positions already sorted in most cases.
	for l:brackets in ['{}', '[]', '()']
		call add(l:brackets_positions,
				\searchpairpos(
					\ '\V'.l:brackets[0], '', '\V'.l:brackets[1], 'bnWr', s:brackets_skip,
					\ max([line('.') - s:searchpair_offset, 1]), s:searchpair_timeout
				\)
			\)
	endfor

	return get(sort(filter(l:brackets_positions, 'v:val[0]'), 's:LexSortPairs'), 0, [0, 0])
endfunction


" Search from the current cursor position backwards
" until the beginning of the explicit line join is found.
function! s:FindLineJoinStart()
	let l:curlnum = line('.')
	let l:prevlnum = l:curlnum - 1

	while ((getline(l:prevlnum) =~# '\\$') &&
		\  (s:SyntaxItemName(l:prevlnum, col([l:prevlnum, '$']) - 1) ==# 'pythonLineJoin'))
		let l:curlnum = l:prevlnum
		let l:prevlnum = l:curlnum - 1
	endwhile

	return l:curlnum
endfunction


" Search from the given line backwards
" until the beginning of the logical line is found.
function! s:FindLogicalLineStart(line)
	let l:curlnum = a:line

	" Unfortunately VimL doesn't have the do...while loop.
	call cursor(l:curlnum, 1)

	let l:bracket_lnum = s:FindOutermostOpeningBracket()[0]
	if (l:bracket_lnum > 0)
		let l:curlnum = l:bracket_lnum
		call cursor(l:curlnum, 1)
	endif

	if !(match(s:SynStackNames(), '\Cpython\a*\%(String\|Quotes\)') < 0)
		let [l:quote_lnum, l:quote_col] = s:FindOpeningQuote()
		" Make sure it isn't a closing quote(s) before the opening one(s).
		if !(match(s:SynStackNames(l:quote_lnum, l:quote_col), '\Cpython\a*String') < 0)
			let l:curlnum = l:quote_lnum
			call cursor(l:curlnum, 1)
		endif
	endif

	let l:linejoinstart = s:FindLineJoinStart()

	while (l:curlnum != l:linejoinstart)
		let l:curlnum = l:linejoinstart

		call cursor(l:curlnum, 1)

		let l:bracket_lnum = s:FindOutermostOpeningBracket()[0]
		if (l:bracket_lnum > 0)
			let l:curlnum = l:bracket_lnum
			call cursor(l:curlnum, 1)
		endif

		if !(match(s:SynStackNames(), '\Cpython\a*\%(String\|Quotes\)') < 0)
			let [l:quote_lnum, l:quote_col] = s:FindOpeningQuote()
			" Make sure it isn't a closing quote(s) before the opening one(s).
			if !(match(s:SynStackNames(l:quote_lnum, l:quote_col), '\Cpython\a*String') < 0)
				let l:curlnum = l:quote_lnum
				call cursor(l:curlnum, 1)
			endif
		endif

		let l:linejoinstart = s:FindLineJoinStart()
	endwhile

	return l:curlnum
endfunction


" Search from the current cursor position backwards
" until the clause header that matches the given regex is found.
function! s:FindPrecedingHeader(regex)
	let l:curlnum = prevnonblank(line('.') - 1)
	let l:curindent = indent(l:curlnum)
	let l:minindent = l:curindent + 1

	while ((l:curlnum > 0) && (l:minindent > 0))
		if (l:curindent < l:minindent)
			if (getline(l:curlnum) =~# a:regex)
				return [l:curlnum, l:curindent]
			else
				let l:minindent = l:curindent
			endif
		endif

		let l:curlnum = prevnonblank(l:curlnum - 1)
		let l:curindent = indent(l:curlnum)
	endwhile

	return [l:curlnum, l:curindent]
endfunction
" }}}


" Recalculate indentation of the current line.
function! GetPythonIndent()
	let l:cursynstack = s:SynStackNames()

	if !(match(l:cursynstack, '\CpythonComment') < 0)
		" Preserve the current indentation inside comments.
		return -1
	endif

	if !(match(l:cursynstack, '\Cpython\a*\%(String\|Quotes\)') < 0)
		let [l:quote_lnum, l:quote_col] = s:FindOpeningQuote()
		" Make sure it isn't a closing quote(s) before the opening one(s).
		if !(match(s:SynStackNames(l:quote_lnum, l:quote_col), '\Cpython\a*String') < 0)
			" Inside strings proceed as follows.
			if (l:quote_lnum != v:lnum - 1)
				" Preserve the current indentation, unless ...
				return -1
			else
				" the opening quote(s) is on the previous line.
				" In the latter case, vertically align
				" docstrings with the indentation of the opening quotes and
				" add one extra level of indentation for regular strings.
				return (l:quote_col == matchend(getline(l:quote_lnum), '^\s*\%("""\|''''''\)'))
					\  ? -1 : indent(l:quote_lnum) + &shiftwidth
			endif
		endif
	endif

	let l:curline = getline(v:lnum)
	let l:curspos = getcurpos()

	" Put the cursor at the beginning of the current line
	" since we don't want to indent inside brackets when
	" the opening bracket is on the current line and
	" we don't want to indent after long strings when
	" the closing quotes are on the current line.
	call cursor(0, 1)

	if !(match(s:SynStackNames(), '\Cpython\%(\a*LongString\|TripleQuotes\)') < 0)
		let [l:quote_lnum, l:quote_col] = s:FindOpeningQuote()
		" Make sure it isn't a closing quote(s) before the opening one(s).
		if !(match(s:SynStackNames(l:quote_lnum, l:quote_col), '\Cpython\a*String') < 0)
			" If the current line starts with the ending of a long string,
			" preserve the current indentation and the cursor position.
			call setpos('.', l:curspos)
			return -1
		endif
	endif

	let [l:bracket_lnum, l:bracket_col] = s:FindInnermostOpeningBracket()
	if (l:bracket_lnum > 0)
		" Between brackets proceed as follows.
		let l:bracket_line = getline(l:bracket_lnum)
		let l:bracket_indent = indent(l:bracket_lnum)

		if (match(strpart(l:bracket_line, l:bracket_col), '^\s*\%(\_$\|#\)') < 0)
			" If the opening bracket isn't followed only by spaces or a comment ...
			if (l:bracket_col != matchend(l:bracket_line, '\C\_^\s*if\s') + 1)
				" align vertically after the opening bracket, unless ...
				return l:bracket_col
			else
				" the 'if' keyword precedes the opening bracket.
				" In the latter case, align vertically after the opening bracket
				" and add one extra level of indentation if configured by user.
				return l:bracket_col +
					\  &shiftwidth * g:python_indent_extra_indent_in_multiline_if_condition
			endif
		else
			" If the opening bracket is followed only by spaces or a comment ...
			if !((l:curline =~# '^\s*[)\]}]$') && !g:python_indent_line_up_closing_bracket_with_last_line)
				" add one level of indentation to the indentation of the line with the opening bracket
				" and add one more level when a keyword precedes the opening bracket, unless ...
				return l:bracket_indent + &shiftwidth +
					\  &shiftwidth * (l:bracket_col == matchend(l:bracket_line, s:compound_stmt_kwrd) + 1)
			else
				" the current line is the hanging closing bracket
				" and it is configured by user to be aligned with
				" the indentation of the line with the opening bracket.
				return l:bracket_indent
			endif
		endif
	endif

	let l:linejoinstart = s:FindLineJoinStart()
	if (l:linejoinstart == v:lnum)
		" Outside of explicit line joins proceed as follows.
		let l:curindent = indent(v:lnum)
		let l:prevlnum = prevnonblank(v:lnum - 1)

		let l:colon = matchend(getline(l:prevlnum), ':\ze\s*\%(\_$\|#\)')
		let l:prevline_ends_with_colon = (!(l:colon < 0) && (s:SyntaxItemName(l:prevlnum, l:colon) ==# 'pythonDelimiter'))

		let l:prevlnum = s:FindLogicalLineStart(l:prevlnum)
		let l:previndent = indent(l:prevlnum)

		if (getline(l:prevlnum) =~# s:code_suite_stop)
			" If the previous logical line is the end of a code suite,
			" remove one level of indentation when
			" the current line wasn't already dedented.
			return min([l:curindent, max([l:previndent - &shiftwidth, 0])])
		endif

		if (l:prevline_ends_with_colon)
			" If the previous logical line ends with a colon outside of a comment,
			" add one level of indentation.
			return l:previndent + &shiftwidth
		endif

		for [l:header, l:preceding] in items(s:header2preceding)
			if (l:curline =~# l:header)
				" If the current line begins with a non-leading header from a compound statement,
				" vertically align with the preceding header(s) from the same compound statement.
				return s:FindPrecedingHeader(l:preceding)[1]
			endif
		endfor

		" Otherwise vertically align with the previous logical line when
		" the current line wasn't already dedented.
		return min([l:curindent, l:previndent])
	elseif (l:linejoinstart == v:lnum - 1)
		" If the beginning of the current explicit line join is on the previous line ...
		let l:prevline = getline(l:linejoinstart)

		let l:nonspace_after_keyword = matchend(l:prevline, s:multiline_kwrd)

		if (l:nonspace_after_keyword < 0)
			" add one level of indentation when
			" the current line wasn't already indented more, unless ...
			return max([indent(v:lnum), indent(l:linejoinstart) + &shiftwidth])
		else
			" the previous line begins with a keyword.
			" In the latter case, vertically align
			" with the first non-space character after the keyword and
			" add one extra level of indentation when it's needed to distinguish
			" from the following code suite and is also configured by user.
			return l:nonspace_after_keyword +
				\  &shiftwidth * g:python_indent_extra_indent_in_multiline_if_condition *
				\  (l:prevline =~# '^\s*for\s\S')
		endif
	else
		" Otherwise preserve the current indentation.
		return -1
	endif
endfunction

" vim:set ts=4 sts=0 noet sw=4 ff=unix foldenable foldmethod=marker:
