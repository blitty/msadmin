#!/usr/bin/python

import re
import argparse

parser = argparse.ArgumentParser(description='Search for a keyword within a Windows Registry text file.')

parser.add_argument("--keyword", dest="keyword", required=True)
parser.add_argument("--filename", dest="regfile", required=True)

args = parser.parse_args()

current_section = ''
match_section = ''

def check(line):
	global current_section
	global match_section

	# is line a section header?
	if re.match( r'\[.*\]', line ):
		current_section = line
		if match_section != '':
			print match_section
			match_section = ''

	# does line contain our keyword?
	if re.match( args.keyword, line, re.I ):
		match_section = current_section


with open(args.regfile) as f:
	line = f.readline()
	check(line)
	while line:
		line = f.readline()
		check(line)

