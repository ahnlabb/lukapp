import sqlite3
import logging
import sys
from argparse import ArgumentParser
from pathlib import Path

log = logging.getLogger(__name__)


def elmstr(x):
    if type(x) is str:
        return f'(Just "{x}")'
    if x is None:
        return 'Nothing'
    return f'(Just {x})'


def coursestr(c):
    return 'Course ' + ' '.join(map(elmstr, c))


def get_args():
    parser = ArgumentParser()
    parser.add_argument('database')
    parser.add_argument('template')
    parser.add_argument('--output', '-o')
    return parser.parse_args()


def _write_table(out, template):
    out.write(Path(template).read_text())
    out.write('    ([')
    try:
        while True:
            out.write(coursestr(next(query)) + '\n')
            for _ in range(19):
                out.write('    ,' + coursestr(next(query)) + '\n')
            out.write('    ] ++ [')
    except StopIteration:
        out.write('    ])')


if __name__ == '__main__':
    args = get_args()
    conn = sqlite3.connect(args.database)
    c = conn.cursor()
    query = c.execute('SELECT course_code, credits, cycle, course_name, links_W, ceq_url, ceq_pass_share, ceq_overall_score, ceq_important, ceq_good_teaching, ceq_clear_goals, ceq_assessment, ceq_workload  FROM courses')
    if args.output:
        with open(args.output, 'w') as out:
            _write_table(out, args.template)
    else:
        _write_table(sys.stdout, args.template)
