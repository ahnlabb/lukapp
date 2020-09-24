.PHONY : page clean reactor db

page: index.html

db: lot.db

site/src/SiteData.elm: site/generate.py site/src/SiteData.template.elm lot.db
	poetry run python3 site/generate.py ./lot.db ./site/src/SiteData.template.elm -o ./site/src/SiteData.elm

index.html: site/app.js

site/app.js: site/src/SiteData.elm site/src/Main.elm site/style.css site/index.js site/webpack.config.js
	(cd site && npx webpack)

reactor: site/src/SiteData.elm
	cd site && elm reactor

lot.db:
	poetry run python3 src/extract.py create
	poetry run python3 src/extract.py ceq

clean:
	rm -f site/src/TableData.elm
	rm -f lot.db
