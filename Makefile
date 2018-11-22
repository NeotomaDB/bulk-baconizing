#########################
# Makefile
# Simon Goring
#########################

agegen: bulk_baconizing.Rmd
	Rscript -e 'rmarkdown::render(c("$<"))'

clean:
	rm -rf *.html *.md *.docx figure/ cache/
