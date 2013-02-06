import markdown
import sys

# script to convert some input markdown file to HTML, which
# is printed to stdio
# requires the "markdown" package
# useful for testing, although this only gives an idea
# for a single Markdown parser

if len(sys.argv) != 2:
    print "Needs an input file name"
    sys.exit(1)

with open(sys.argv[1]) as fh:
    md = markdown.markdown(fh.read())
    for line in md.split("\n"):
        print line

