bibtex-Markdown
===============

A terrible little hack to integrate BibTeX into Markdown in a way that is independent of the Markdown parser.

## Installation
Requires IO:File, BibTeX::Parser, and Text::Unidecode, all available from CPAN.  Other than these dependencies, you can simply run the script.


## Usage
To make a citation in your Markdown, use the syntax:
```
\cite{key}
```

...where `key` is the BibTeX key of the citation.

Once you've added your citations, you can run the script like so:
```console
$ perl apply_references list.bib input.md.ref output.md
```

...where the parameters are:
- `list.bib`: A bibtex file holding all your bibtex information.
- `input.md.ref`: An input Markdown file, possibly containing `\cite{some_bibtex_key}` entries.
- `output.md`: An output Markdown file, where the `\cite{some_bibtex_key}` entries have been converted to normal Markdown/HTML.

If there are `\cite{some_bibtex_key}` entries in the input file, the script will add a special "References" section to the end, if it's not already there. It is sensitive to the name of the section; it expects "## References". References will be put in order by author's names, titles, and years in the typical fashion.  In the text, the citation will be shown as `[num]`, where `num` refers to which citation in the references it is.  Each of these citations also acts as an html anchor; you can click on them to immediately go to the corresponding citation.

## Recommended Practices
Given that the input Markdown files are Markdown + the special `\cite{some_bibtex_key}` entries, you should distinguish these somehow.  Personally I use the extension `.md.ref`.  I also use a makefile that calls `apply_references.pl` for each input `.md.ref` file, producing normal Markdown (`.md`) files.

## Known Issues
### Unicode
Depending on what source you're looking at, at least one of the following is true about Markdown:
- It only supports ASCII
- It has some limited unicode support
- It has mostly full unicode support
- It has full unicode support

This is a relevant issue when it comes to putting BibTeX information into Markdown files, since BibTeX can encode things that are only representable correctly in unicode. Given that unicode support is ultimately a Markdown parser issue, and that this script is intended to be independent of the Markdown parser used, I've opted to go with the lowest common denominator: convert any BibTeX information to pure ASCII.

### Testing
Overall, not a lot of it has been done. It works for me and my use case, but we all know how that works.
