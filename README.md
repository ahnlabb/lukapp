# lukapp

This is an application for fetching data from the LTH
[Curricula and Time Tables](https://kurser.lth.se/lot/?val=program) and
[Course Evaluations](http://www.ceq.lth.se/) into a database.

This database is then used to build a static single page application for faster
and more flexible filtering, sorting and course comparison.

See this application in action [here](https://ahnlabb.github.io/lukapp/).

## Dependencies
- [`elm`](https://guide.elm-lang.org/install.html)
- [`poetry`](https://github.com/python-poetry/poetry)
- [`npm`](https://linuxconfig.org/install-npm-on-linux)
- `make`

## Usage

If you just want to fetch the database run:

```bash
make db
```

To build the single page application you first need to
- [install elm](https://guide.elm-lang.org/install.html).
- install packing dependencies `cd site && npm install`

Then run:

```bash
make page
```

which puts the application in the file `./index.html`.

## Deploy latest master-commit on gh-pages:

```bash
git checkout gh-pages
git rebase master
touch lot.db
make page
git add site/app.js
git commit --amend --reset-author
git push -f
```
