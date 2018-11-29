#!/usr/bin/python

import argparse

parser = argparse.ArgumentParser(description='Search for a keyword within a Windows Registry text file.')

parser.add_argument("--keyword", dest="keyword", required=True)
parser.add_argument("--filename", dest="regfile", required=True)

args = parser.parse_args()

klower = args.keyword.lower()
buffer = ''
match = False

with open(args.regfile) as f:
	while True:
		line = f.readline()

		if not line:
			break

		if line.startswith('[') and line.rstrip().endswith(']'):
			if match:
				print buffer
			buffer = line
			match = False
		else:
			buffer += line

		if klower in line.lower():
			match = True

