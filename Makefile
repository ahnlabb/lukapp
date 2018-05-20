page:
	python3 site/generate.py ./lot.db ./site/TableData.template.elm -o ./site/TableData.elm
	(cd site && elm make Main.elm --output ../index.html)
