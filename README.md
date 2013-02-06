bibtex-markdown
===============

A terrible little hack to integrate BibTeX into markdown in a way that is independent of the markdown parser.

## Installation
Requires BibTeX::Parser, available from CPAN.


## Usage
To make a citation, use the syntax:
```
\cite{key}
```

...where `key` is the BibTeX key of the citation.
The script will add a special "References" section to the end, if it's not already there.
It is sensitive to the name of the section; it expects "## References".
