#########################
# Makefile
# Simon Goring
#########################

agegen: bulk_baconizing.Rmd
	Rscript -e 'rmarkdown::render(c("$<"))'

clean:
	rm -rf bulk_baconizing.html bulk_baconizing.md *.docx figure/ cache/

localbuild: bulk_baconizing.Rmd
	Rscript -e 'rmarkdown::render(c("$<"))' || Rscript -e 'knitr::purl(c("$<"))'
