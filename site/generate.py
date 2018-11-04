import sqlite3
import logging
import sys
import json
import io
import csv
from argparse import ArgumentParser
from pathlib import Path
from string import Template

log = logging.getLogger(__name__)


def get_args():
    parser = ArgumentParser()
    parser.add_argument('database')
    parser.add_argument('template')
    parser.add_argument('--output', '-o')
    return parser.parse_args()


def _write_all(out, template):
    c = conn.cursor()
    cols = 'course_code, credits, cycle, course_name, links_W, ceq_url, ceq_pass_share, ceq_answers, ceq_overall_score, ceq_important, ceq_good_teaching, ceq_clear_goals, ceq_assessment, ceq_workload'
    query = c.execute(f'SELECT {cols} FROM courses')
    courses = _query_to_csv(cols.split(', '), query)
    specializations = _process_specializations(c.execute('SELECT * FROM specializations'))
    out.write(template.substitute(courses=courses, specializations=specializations))


def _process_specializations(query):
    return json.dumps({code: [name, json.loads(courses)] for code, name, courses in query}, indent=4)


def _query_to_csv(header, query):
    f = io.StringIO()
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(header)
    writer.writerows([k] + v for k, *v in query)
    out = f.getvalue()
    f.close()
    return out


if __name__ == '__main__':
    args = get_args()
    conn = sqlite3.connect(args.database)

    template = Template(Path(args.template).read_text())
    if args.output:
        with open(args.output, 'w') as out:
            _write_all(out, template)
    else:
        _write_all(sys.stdout, template)
