#!/bin/sh

cd $1
perl ../../apply_references.pl references.bib input.md.ref output.md
python3 ../to_html.py output.md > output.html
