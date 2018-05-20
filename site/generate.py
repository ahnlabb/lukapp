import sqlite3
import logging
import sys
from argparse import ArgumentParser
from pathlib import Path

log = logging.getLogger(__name__)


def elmstr(x):
    if type(x) is str:
        return '"{}"'.format(x)
    else:
        return str(x)


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
    query = c.execute('SELECT course_code, credits, IFNULL(cycle,0), course_name, IFNULL(ceq_pass_share,-1), IFNULL(ceq_overall_score,-1), IFNULL(ceq_important,-1) FROM courses')
    if args.output:
        with open(args.output, 'w') as out:
            _write_table(out, args.template)
    else:
        _write_table(sys.stdout, args.template)
