#!/usr/bin/env python3
import urllib.request
import sqlite3
import logging
import json
from collections import defaultdict
from re import sub, match
import re
import asyncio
from urllib.parse import urlparse
from argparse import ArgumentParser
from pathlib import Path
from itertools import chain, islice
from enum import Enum
from bs4 import BeautifulSoup
import aiohttp


base_url = "https://kurser.lth.se/lot/?"
log = logging.getLogger(__name__)


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


def session_time(node):
    try:
        it = map(lambda x: clean(x).lower(), node.span.span.strings)
        return dict(zip(it, it))

    except AttributeError:
        return None


def enumfield(clsname, values):
    def value(enum):
        return enum.value

    cls = Enum(clsname, values)
    sqlite3.register_adapter(cls, value)

    return cls


Cycle = enumfield('Cycle', 'G1 G2 A')
Lang = enumfield('Lang', 'S E E1 E2')
Mandatory = enumfield('Mandatory', 'O A V E')

sqlite3.register_adapter(list, json.dumps)
sqlite3.register_adapter(dict, json.dumps)

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
    'links': lambda x: {clean(a.get_text()): a['href'] for a in x.find_all('a')},
    'none': lambda x: None,
    'session_time': session_time
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


def clean(x):
    # Think carefully about SQL before changing the following
    return sub(r'[^A-z0-9_]', '', x.replace(' ', '_'))


def _process_header(thead):
    th_lst = thead.tr.find_all('th')

    def title(x):
        return x.lstrip('0123456789/\n ').split('\n')[0]

    header = [clean(title(text(h))).lower() for h in th_lst]
    return header


def get_query(**kwargs):
    return get_soup(base_url + "&".join("{}={}".format(k, v) for k, v in kwargs.items()))


class CourseList():

    def __init__(self):
        self.fields = dict()
        self.courses = defaultdict(dict)
        self.conflicts = []
        self.specializations = defaultdict(lambda: list())

    def set(self, course, key, value):
        row = self.courses[course]
        if key in row and value != row[key]:
            self.conflicts.append((course, key, value))
        else:
            row[key] = value

    def columns(self):
        return self.fields.items()

    def __iter__(self):
        for name, fields in self.courses.items():
            yield [fields.get(f, None) for f in self.fields]

    def process_prog(self, soup, prog):
        for course_lst in soup.find_all('table', class_='CourseListView'):
            section_title = course_lst.parent.previous_sibling.previous_sibling
            course_type = section_title.get('id')
            spec_name = section_title.string

            header = _process_header(course_lst.thead)

            addition = []
            if course_type:
                m = match(r'ak(\d)_([OAVE])', course_type)
                if m:
                    addition = [m[1], m[1], m[2]]
                    header.extend(["year", "from_year", "mand_elect"])

            index_column = header.index(index)

            course_names = []
            for tr in course_lst.tbody.find_all('tr'):
                row = tr.find_all('td')
                name = parse_field(index, row[index_column])
                course_names.append(name)
                for h, r in zip(header, chain(row, addition)):
                    try:
                        val = parse_field(h, r)

                        field_name = h
                        if h in prog_specific:
                            field_name = prog + '_' + field_name
                        if type(val) is dict:
                            for key in val:
                                f = field_name + '_' + key
                                self.fields[f] = type_affinities[field_types[h]]
                                self.set(name, f, val[key])
                        else:
                            self.fields[field_name] = type_affinities[field_types[h]]
                            self.set(name, field_name, val)

                    except (ValueError, KeyError):
                        log.debug(f"failed to process field: {h:<15} on course: {name:<6} {prog:<8}")
            if spec_name:
                if not course_type:
                    course_type = ""
                self.specializations[prog].append((course_type, spec_name, course_names))


def _build_courselist():
    courses = CourseList()
    soup = get_query(val='program', lang='en')
    for prog in soup.find_all('input', attrs={'type': 'radio', 'name': 'prog'}):
        name = prog['value']
        prog_soup = get_query(val='program', prog=name, lang='en')
        courses.process_prog(prog_soup, name)

    return courses


def _create_course_table(courses, conn):
    c = conn.cursor()

    # To generate the table string interpolation has to be used since
    # there is no equivalent to parameter substitution for objects.
    c.execute('CREATE TABLE courses ({})'.format(
        ', '.join(f"'{name}' {affinity}" for name, affinity in courses.columns()))
    )

    c.executemany(
        'INSERT INTO courses VALUES ({})'.format(','.join(['?'] * len(courses.fields))),
        iter(courses)
    )

    conn.commit()


def get_args(commands):
    parser = ArgumentParser()
    parser.add_argument('-l', '--log', default='debug', help="set the log level")
    parser.add_argument('command', action='store', choices=commands)
    return parser.parse_args()


def init_log():
    loglvls = {
        'debug': logging.DEBUG,
        'info': logging.INFO,
        'warning': logging.WARNING,
        'error': logging.ERROR,
        'critical': logging.CRITICAL
    }
    logging.basicConfig(level=loglvls[args.log])


def _create_specializations_table(courses, conn):
    c = conn.cursor()

    c.execute('CREATE TABLE specializations (program TEXT, courses TEXT)')

    c.executemany(
        'INSERT INTO specializations VALUES (?,?)',
        ((k, json.dumps(v)) for k, v in courses.specializations.items())
    )

    conn.commit()


def _create():
    courses = _build_courselist()
    _create_course_table(courses, conn)
    _create_specializations_table(courses, conn)
    conn.close()


def _table_info():
    c = conn.cursor()
    query = c.execute('PRAGMA table_info(courses)')
    _, name, affinity, _, _, _ = map(list, zip(*query))
    return name, affinity


def _table():
    print(_table_info())


def _add_column_if_absent(cursor, colname, affinity):
    names, affinities = _table_info()
    if colname not in names:
        cursor.execute(f'ALTER TABLE courses ADD COLUMN {colname} {affinity}')


async def _ceq_get_query(code, year, sp):
    semester = 'HT'
    if sp > 2:
        semester = 'VT'
        sp -= 2

    url = f'http://www.ceq.lth.se/rapporter/{year}_{semester}/LP{sp}/{code}_{year}_{semester}_LP{sp}_slutrapport_en.html'
    log.debug(f'requesting url: {url}')
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            return resp.status, await resp.read(), str(resp.url)


async def _get_latest_ceq(code, sp, oldcoursecode=None):
    allsp = chain([sp], set(range(1, 5)) - {sp})
    for testsp in allsp:
        for year in range(2018, 2014, -1):
            status, resp, url = await _ceq_get_query(code, year, testsp)
            if status == 200:
                soup = BeautifulSoup(resp, 'html.parser')
                return soup, url

    # LTH changed course codes recently, so some courses have no ceq reports yet.
    # If we don't find a ceq report we try to fetch an old one.
    if oldcoursecode and code in oldcoursecode:
        return await _get_latest_ceq(oldcoursecode[code], sp)

    return None, None


def _update_courses(coursedict, columns, cursor):
    values = list((*v, k) for k, v in coursedict.items())
    sql = f"UPDATE courses SET {', '.join(col + ' = ?' for col in columns)} WHERE course_code = ?"
    cursor.executemany(sql, values)


def _ceq():
    def tablevalue(soup, rowname):
        return soup.find(string=rowname).parent.find_next_sibling('td').string

    # Mapping from new to old course codes.
    oldcoursecodes = dict()
    with open('coursecodes.csv', 'r') as f:
        for l in f:
            old, new = l.strip().split(',')
            oldcoursecodes[new] = old

    c = conn.cursor()
    ceq_columns = [
        'ceq_url',
        'ceq_pass_share',
        'ceq_answers',
        'ceq_overall_score',
        'ceq_important',
        'ceq_good_teaching',
        'ceq_clear_goals',
        'ceq_assessment',
        'ceq_workload'
    ]
    for col in ceq_columns:
        _add_column_if_absent(c, col, 'INTEGER')

    query = c.execute('SELECT course_code, sp1_lectures, sp2_lectures, sp3_lectures, sp4_lectures FROM courses')
    courses_complete = dict()  # Complete CEQ containing scores
    courses_basic = dict()  # Basic CEQ e.g. containing share of student that passed

    async def process_ceq(code, sp):
        try:
            last, _ = next(filter(lambda x: x[1], enumerate(sp[::-1])))
        except StopIteration:
            log.debug(f'Course {code} lacks sp data')
            return
        soup, url = await _get_latest_ceq(code, 4 - last, oldcoursecodes)
        if soup:
            passed = tablevalue(soup, re.compile('Number and share of passed students.*'))
            pass_share = int(match(r'\d+\s*/\s*(\d+)\s*%', passed)[1])
            try:
                answer_field = tablevalue(soup, 'Number answers and response rate')
                answers = int(match(r'(\d+)\s*/\s*\d+\s*%', answer_field)[1])
                overall_score = int(tablevalue(soup, 'Overall, I am satisfied with this course'))
                important = int(tablevalue(soup, 'The course seems important for my education'))
                good_teaching = int(tablevalue(soup, 'Good Teaching'))
                clear_goals = int(tablevalue(soup, 'Clear Goals and Standards'))
                assessment = int(tablevalue(soup, 'Appropriate Assessment'))
                workload = int(tablevalue(soup, 'Appropriate Workload'))
                return code, (url, pass_share, answers, overall_score, important, good_teaching, clear_goals, assessment, workload)
            except AttributeError:
                return code, (url, pass_share)
            except TypeError:
                return code, (url, pass_share)
        else:
            log.debug(f'No CEQ found for {code} SP{last}')

    loop = asyncio.get_event_loop()

    ceq_tasks = [process_ceq(code, sp) for code, *sp in query]
    chunk_size = 50
    task_groups = [ceq_tasks[i:i + chunk_size] for i in range(0, len(ceq_tasks), chunk_size)]
    for group in task_groups:
        getall = asyncio.gather(*group)
        loop.run_until_complete(getall)
        for code, ceq_data in filter(None, getall.result()):
            if len(ceq_data) == len(ceq_columns):
                courses_complete[code] = ceq_data
            else:
                courses_basic[code] = ceq_data

    log.info(f'No. courses with a complete CEQ: {len(courses_complete)}')
    log.info(f'No. courses with a basic CEQ: {len(courses_basic)}')
    _update_courses(courses_complete, ceq_columns, c)
    _update_courses(courses_basic, ceq_columns[0:2], c)

    conn.commit()


if __name__ == '__main__':
    conn = sqlite3.connect('lot.db')
    commands = {
        'create': _create,
        'ceq': _ceq,
        'table': _table
    }
    args = get_args(commands)
    init_log()
    commands[args.command]()
