# lot-extract

This is an application for fetching data from the LTH
[Curricula and Time Tables](https://kurser.lth.se/lot/?val=program) and
[Course Evaluations](http://www.ceq.lth.se/) into a database.

This database is then used to build a static single page application for faster
and more flexible filtering, sorting and course comparison.

## Usage

If you just want to fetch the database run:
``` bash
make db
```

To build the single page application you first need to
[install elm](https://guide.elm-lang.org/install.html).

Then run:
``` bash
make page
```

which puts the application in the file `./index.html`.
