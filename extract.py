#!/usr/bin/env python3
import urllib.request
import sqlite3
from collections import defaultdict
from re import sub, match
from urllib.parse import urlparse
from argparse import ArgumentParser
from pathlib import Path
from itertools import chain
from enum import Enum
from bs4 import BeautifulSoup


base_url = "https://kurser.lth.se/lot/?"
conn = sqlite3.connect('lot.db')


class CacheFile():
    def __init__(self, site, url_path, query):
        path = Path(site) / (url_path + query.replace('&', '.'))
        if path.is_absolute():
            path = path.relative_to('/')
        if not path.suffix:
            path = path.with_suffix('.html')
        self.file = 'cache' / path

    def __bool__(self):
        return self.file.exists()

    def write(self, text):
        self.file.parent.mkdir(parents=True, exist_ok=True)
        self.file.write_bytes(text)

    def read(self):
        return self.file.read_bytes()


def get_soup(url):
    parsed = urlparse(url)
    cache = CacheFile(parsed.netloc, parsed.path, parsed.query)

    if cache:
        contents = cache.read()
    else:
        with urllib.request.urlopen(url) as req:
            contents = req.read()
            cache.write(contents)

    return BeautifulSoup(contents, 'html.parser')


def compose(f, g):
    return lambda x: f(g(x))


def text(node):
    if type(node) is str:
        return node
    return node.get_text().strip()


def check(mark):
    return lambda x: x == mark


def session_time(text):
    return text


def enumfield(clsname, values):
    def value(enum):
        return enum.value

    cls = Enum(clsname, values)
    sqlite3.register_adapter(cls, value)

    return cls


Cycle = enumfield('Cycle', 'G1 G2 A')
Lang = enumfield('Lang', 'S E E1 E2')
Mandatory = enumfield('Mandatory', 'O A V E')

sqlite3.register_adapter(list, str)

index = 'course_code'

field_types = {
    'course_code': 'text',
    'credits': 'float',
    'cycle': 'cycle',
    'mand_elect': 'mand_elect',
    'year': 'int',
    'from_year': 'int',
    'sex_stud': 'check',
    'language': 'lang',
    'course_name': 'text',
    'footnote': 'text',
    'links': 'links',
    '': 'none',
    'sp1': 'session_time',
    'sp2': 'session_time',
    'sp3': 'session_time',
    'sp4': 'session_time'
}

type_funcs = {
    'text': text,
    'float': compose(float, text),
    'cycle': compose(Cycle.__getitem__, text),
    'mand_elect': compose(Mandatory.__getitem__, text),
    'int': compose(int, text),
    'check': compose(check('X'), text),
    'lang': compose(Lang.__getitem__, text),
    'links': lambda x: [a['href'] for a in x.find_all('a')],
    'none': lambda x: None,
    'session_time': compose(session_time, text)
}


def parse_field(field, value):
    return type_funcs[field_types[field]](value)


type_affinities = {
    'text': 'TEXT',
    'float': 'REAL',
    'cycle': 'INTEGER',
    'mand_elect': 'INTEGER',
    'int': 'INTEGER',
    'check': 'INTEGER',
    'lang': 'INTEGER',
    'links': 'TEXT',
    'none': 'INTEGER',
    'session_time': 'TEXT'
}

prog_specific = {'mand_elect', 'year', 'from_year'}


def _process_header(thead):
    th_lst = thead.tr.find_all('th')

    def clean(x):
        # Think carefully about SQL before changing the following
        return sub(r'[^A-z0-9_]', '', x.replace(' ', '_'))

    def title(x):
        return x.lstrip('0123456789/\n ').split('\n')[0]

    header = [clean(title(text(h))).lower() for h in th_lst]
    return header


def process_prog(soup, prog):
    failures = defaultdict(list)
    for course_lst in soup.find_all('table', class_='CourseListView'):
        course_type = course_lst.parent.previous_sibling.previous_sibling.get('id')

        header = _process_header(course_lst.thead)

        addition = []
        if course_type:
            m = match(r'ak(\d)_([OAVE])', course_type)
            if m:
                addition = [m[1], m[1], m[2]]
                header.extend(["year", "from_year", "mand_elect"])
                course_type = None

        index_column = header.index(index)
        header.pop(index_column)

        for tr in course_lst.tbody.find_all('tr'):
            row = tr.find_all('td')
            name = parse_field(index, row.pop(index_column))
            if course_type:
                courses.specializations[prog][course_type].add(name)
            for h, r in zip(header, chain(row, addition)):
                try:
                    val = parse_field(h, r)

                    field_name = h
                    if h in prog_specific:
                        field_name = prog + '_' + field_name

                    courses.fields[field_name] = type_affinities[field_types[h]]
                    courses.set(name, field_name, val)

                except (ValueError, KeyError):
                    failures[name].append((h, r))
    return failures


def get_query(**kwargs):
    return get_soup(base_url + "&".join("{}={}".format(k, v) for k, v in kwargs.items()))


class CourseList():

    def __init__(self):
        self.fields = dict()
        self.courses = defaultdict(dict)
        self.conflicts = []
        self.specializations = defaultdict(lambda: defaultdict(set))

    def set(self, course, key, value):
        row = self.courses[course]
        if key in row and value != row[key]:
            self.conflicts.append((course, key, value))
        else:
            row[key] = value

    def columns(self):
        return chain([(index, 'TEXT')], self.fields.items())

    def __iter__(self):
        for name, fields in self.courses.items():
            row = chain([name], (fields.get(f, None) for f in self.fields))
            yield list(row)


courses = CourseList()
soup = get_query(val='program', lang='en')
for prog in soup.find_all('input', attrs={'type': 'radio', 'name': 'prog'}):
    name = prog['value']
    prog_soup = get_query(val='program', prog=name, lang='en')
    failures = process_prog(prog_soup, name)

c = conn.cursor()

# To generate the table string interpolation has to be used since
# there is no equivalent to parameter substitution for objects.
c.execute('CREATE TABLE courses ({})'.format(
    ', '.join(f"'{name}' {affinity}" for name, affinity in courses.columns()))
)

c.executemany(
    'INSERT INTO courses VALUES ({})'.format(','.join(['?']*(len(courses.fields) + 1))),
    iter(courses)
)

conn.commit()
conn.close()
